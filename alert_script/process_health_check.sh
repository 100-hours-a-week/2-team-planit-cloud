#!/usr/bin/env bash
# 여러 서비스의 health URL을 호출해서 실패 시 디스코드로 알림 전송

set -euo pipefail  # 에러/미정의 변수/파이프 실패 시 즉시 종료

WEBHOOK_URL="${DISCORD_FAILURE_ALERT_WEBHOOK_URL}" # 디스코드 웹훅 URL(필수)
HOST_TAG="${HOST_TAG:-planit-prod}"                                  # 알림 태그(기본값 planit-prod)
COOLDOWN_SECONDS="${COOLDOWN_SECONDS:-300}"                         # 동일 대상 중복 알림 쿨다운(기본 5분)
COOLDOWN_STATE="${COOLDOWN_STATE:-/tmp/planit_alert_cooldown_${0##*/}.tsv}"

URLS=(                                                                # "이름|URL" 형태로 헬스체크 대상 목록
  "backend|http://127.0.0.1:8080/api/health"
  "ai|http://127.0.0.1:8000/health"
)

now_kst() { TZ=Asia/Seoul date '+%Y-%m-%d %H:%M:%S KST'; }           # 현재 시간을 KST로 출력
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
cooldown_status() {                                                 # 쿨다운 상태 파일 기반 중복 알림 방지
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

send_discord() {                                                     # 디스코드 웹훅으로 메시지 전송
  local title="$1"
  local body="$2"
  body="${body//$'\n'/__NL__}"
  body="${body//\\/\\\\}"
  body="${body//\"/\\\"}"
  body="${body//__NL__/\\n}"
  curl -sS -H "Content-Type: application/json" \
    -X POST \
    -d "{\"content\":\"**[${HOST_TAG}] ${title}**\\n${body}\"}" \
    "$WEBHOOK_URL" >/dev/null || true
}

check() {                                                            # URL에 curl 요청 후 정상 상태코드(200/401)면 성공 처리
  local url="$1"
  local code
  code="$(curl -sS -o /dev/null -w "%{http_code}" --max-time 3 "$url" || echo 000)"
  [[ "$code" == "200" || "$code" == "401" ]]
}

for item in "${URLS[@]}"; do                                          # 각 대상에 대해 헬스체크 수행
  IFS='|' read -r name url <<< "$item"
  if ! check "$url"; then                                             # 헬스체크 실패 시 디스코드 알림 전송
    read -r summary_count send_now last_epoch <<< "$(cooldown_status "health|${name}")"
    if (( summary_count > 0 )); then
      send_discord "[🔴 HEALTH] 헬스체크 요약: ${name}" \
        "====================\nTYPE: HEALTH SUMMARY\n====================\n시간: $(now_kst)\n대상: ${name}\n요약:\n- 마지막 알림: $(fmt_kst_from_epoch "$last_epoch")\n- 마지막 알림 이후 추가 ${summary_count}회 실패"
    fi
    if (( send_now == 1 )); then
      send_discord "[🔴 HEALTH] 헬스체크 실패: ${name}" \
        "====================\nTYPE: HEALTH EVENT\n====================\n시간: $(now_kst)\n대상: ${name}\nURL: ${url}\n조치: 해당 프로세스 상태 확인 후 재기동/롤백 판단"
    fi
  fi
done
