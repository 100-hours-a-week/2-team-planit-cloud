#!/usr/bin/env bash
# 특정 API를 호출해 HTTP 상태코드 + 지연시간(ms)만 점검하고, 실패 시 디스코드로 알림 전송

set -euo pipefail  # 에러/미정의 변수/파이프 실패 시 즉시 종료

WEBHOOK_URL="${DISCORD_FAILURE_ALERT_WEBHOOK_URL}" # 디스코드 웹훅 URL(필수)
HOST_TAG="${HOST_TAG:-planit-prod}"                                   # 알림 태그(기본값 planit-prod)
EC2_HOST="${EC2_PUBLIC_IP:-127.0.0.1}"                                # EC2 public IP(기본값 로컬)
COOLDOWN_SECONDS="${COOLDOWN_SECONDS:-300}"                          # 동일 대상 중복 알림 쿨다운(기본 5분)
COOLDOWN_STATE="${COOLDOWN_STATE:-/tmp/planit_alert_cooldown_${0##*/}.tsv}"

APIS=(                                                                 # "이름|METHOD|URL|허용코드(콤마)|지연임계치(ms)|추가헤더(선택; 세미콜론 구분)"
  "get_backend|GET|http://${EC2_HOST}:8080/api/health|200|700|"
  "get_ai|GET|http://${EC2_HOST}:8000/health|200|900|"
  "get_posts|GET|http://${EC2_HOST}:8080/api/posts|200|1000|"
)

now_kst() { TZ=Asia/Seoul date '+%Y-%m-%d %H:%M:%S KST'; }            # 현재 시간을 KST 문자열로 반환
now_epoch() { date +%s; }
fmt_kst_from_epoch() {
  local ts="$1"
  if [[ -z "${ts:-}" || "$ts" == "0" ]]; then
    echo "없음"
    return 0
  fi
  TZ=Asia/Seoul date -d "@$ts" '+%Y-%m-%d %H:%M:%S KST'
}

# 반환: "<summary_count> <send_now> <last_epoch>"
cooldown_status() {                                                   # 쿨다운 상태 파일 기반 중복 알림 방지
  local key="$1" now last count tmp lock_file fd
  now="$(now_epoch)"
  last=0
  count=0
  [[ -f "$COOLDOWN_STATE" ]] || : > "$COOLDOWN_STATE"
  lock_file="${COOLDOWN_STATE}.lock"
  exec {fd}>"$lock_file"
  flock -x "$fd"
  if read -r last count < <(awk -F'\t' -v k="$key" '$1==k {print $2, $3}' "$COOLDOWN_STATE" | tail -n1); then
    : # use parsed last/count
  else
    last=0
    count=0
  fi

  if (( now - last >= COOLDOWN_SECONDS )); then
    tmp="$(mktemp)"
    awk -F'\t' -v k="$key" 'BEGIN{OFS="\t"} $1!=k {print $0}' "$COOLDOWN_STATE" > "$tmp"
    printf "%s\t%s\t%s\n" "$key" "$now" 0 >> "$tmp"
    mv "$tmp" "$COOLDOWN_STATE"
    exec {fd}>&-
    printf "%s %s %s\n" "${count:-0}" 1 "$last"
    return 0
  fi

  count=$((count + 1))
  tmp="$(mktemp)"
  awk -F'\t' -v k="$key" 'BEGIN{OFS="\t"} $1!=k {print $0}' "$COOLDOWN_STATE" > "$tmp"
  printf "%s\t%s\t%s\n" "$key" "$last" "$count" >> "$tmp"
  mv "$tmp" "$COOLDOWN_STATE"
  exec {fd}>&-
  printf "0 0 %s\n" "$last"
}

json_escape() {                                                       # 디스코드 JSON 전송을 위한 문자열 escape
  local s="$1"
  s="${s//$'\n'/__NL__}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//__NL__/\\n}"
  printf "%s" "$s"
}

send_discord() {                                                      # 디스코드 웹훅으로 메시지 전송
  local title="$1"
  local body="$2"
  local content="**[${HOST_TAG}] ${title}**"$'\n'"${body}"
  content="$(json_escape "$content")"
  curl -sS -H "Content-Type: application/json" \
    -X POST \
    -d "{\"content\":\"${content}\"}" \
    "$WEBHOOK_URL" >/dev/null || true
}

build_header_args() {                                                 # "k:v;k:v" 헤더 문자열을 curl -H 인자로 변환
  local header_str="$1"
  local -a args=()
  if [[ -n "$header_str" ]]; then
    IFS=';' read -r -a hdrs <<< "$header_str"
    for h in "${hdrs[@]}"; do
      [[ -n "$h" ]] && args+=(-H "$h")
    done
  fi
  printf '%s\0' "${args[@]}"
}

is_allowed_code() {                                                   # 허용 코드 목록("200,202")에 현재 코드가 포함되는지 확인
  local code="$1"
  local allowed_csv="$2"
  IFS=',' read -r -a allowed <<< "$allowed_csv"
  for a in "${allowed[@]}"; do
    [[ "$code" == "$a" ]] && return 0
  done
  return 1
}

check_api() {                                                         # API 1개 호출 후 상태코드/지연시간 임계치 검사
  local name="$1"
  local method="$2"
  local url="$3"
  local allowed_codes="$4"
  local max_ms="$5"
  local header_str="$6"

  local -a header_args=()                                             # 헤더 인자 구성
  IFS=$'\0' read -r -d '' -a header_args < <(build_header_args "$header_str" && printf '\0')

  local out http_code time_total latency_ms                           # curl 결과 파싱(코드/총소요시간)
  local max_retries=3                                                 # 총 시도 횟수 (최초 1회 + 재시도 2회)

  for (( i=1; i<=max_retries; i++ )); do

    out="$(curl -sS "${header_args[@]}" -X "$method" \
          --connect-timeout 2 --max-time 5 \
          -o /dev/null -w "%{http_code} %{time_total}" \
          "$url" 2>/dev/null || true)"

    http_code="$(awk '{print $1}' <<< "$out" | tr -d '\r\n')"           # HTTP 상태코드
    time_total="$(awk '{print $2}' <<< "$out" | tr -d '\r\n')"          # 총소요시간(초)
    [[ -n "$http_code" ]] || http_code="000"                            # 연결 실패 등 예외 처리
    [[ -n "$time_total" ]] || time_total="0"
                                                 # 초 -> ms 변환(반올림)
    latency_ms="$(awk -v t="$time_total" 'BEGIN{printf "%.0f", t*1000}')"

    # 성공 여부 판단: 상태코드 OK && 지연시간 OK
    if is_allowed_code "$http_code" "$allowed_codes" && [[ "$latency_ms" -le "$max_ms" ]]; then
        return 0                                                         # 성공 시 즉시 함수 종료 (알림 안 보냄)
    fi

    # 실패했지만 아직 재시도 횟수가 남았다면 대기 후 재시도
    if [[ $i -lt $max_retries ]]; then
        sleep 1  # 1초 대기 (네트워크 깜빡임 해소)
        continue
    fi
  done

  # 3회 모두 실패. 알림 전송 로직 실행
  if ! is_allowed_code "$http_code" "$allowed_codes"; then            # 상태코드 임계치 위반
    read -r summary_count send_now last_epoch <<< "$(cooldown_status "api|${name}|status")"
    if (( summary_count > 0 )); then
      send_discord "[🟠 API] API 체크 요약(상태코드): ${name}" \
"====================
TYPE: API SUMMARY
KIND: STATUS
====================
시간: $(now_kst)
대상: ${name}
요약:
- 마지막 알림: $(fmt_kst_from_epoch "$last_epoch")
- 마지막 알림 이후 추가 ${summary_count}회 실패"
    fi
    if (( send_now == 1 )); then
      send_discord "[🟠 API] API 체크 실패(상태코드): ${name}" \
"====================
TYPE: API EVENT
KIND: STATUS
====================
시간: $(now_kst)
대상: ${name}
METHOD: ${method}
URL: ${url}
HTTP: ${http_code}
Latency: ${latency_ms}ms (limit ${max_ms}ms)"
    fi
    return 1
  fi

  if [[ "$latency_ms" -gt "$max_ms" ]]; then                          # 지연시간 임계치 위반
    read -r summary_count send_now last_epoch <<< "$(cooldown_status "api|${name}|latency")"
    if (( summary_count > 0 )); then
      send_discord "[🟠 API] API 체크 요약(지연): ${name}" \
"====================
TYPE: API SUMMARY
KIND: LATENCY
====================
시간: $(now_kst)
대상: ${name}
요약:
- 마지막 알림: $(fmt_kst_from_epoch "$last_epoch")
- 마지막 알림 이후 추가 ${summary_count}회 실패"
    fi
    if (( send_now == 1 )); then
      send_discord "[🟠 API] API 체크 실패(지연): ${name}" \
"====================
TYPE: API EVENT
KIND: LATENCY
====================
시간: $(now_kst)
대상: ${name}
METHOD: ${method}
URL: ${url}
HTTP: ${http_code}
Latency: ${latency_ms}ms (limit ${max_ms}ms)"
    fi
    return 1
  fi

  return 0                                                            # 정상
}

failed=0                                                              # 전체 실패 플래그(1개라도 실패하면 1)
for item in "${APIS[@]}"; do                                          # 모든 대상 API 순회하며 체크
  IFS='|' read -r name method url allowed_codes max_ms header_str <<< "$item"
  check_api "$name" "$method" "$url" "$allowed_codes" "$max_ms" "$header_str" || failed=1
done

exit "$failed"                                                        # 0: 모두 통과, 1: 하나 이상 실패
