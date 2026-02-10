#!/usr/bin/env bash
# 포트 기반 CPU/RSS 임계치 감시 후 디스코드로 알림 전송
# - 서비스별로 쿨다운/요약 분리 (backend/ai/mysql/caddy 각각)
# - 메시지 포맷은 로그 알림 형식(구분선/TYPE/SEVERITY/필드) 참고
# - 요약은 쿨다운이 풀릴 때만 전송 (스팸 방지)
# - 초과 항목 표기: 1200>1000 형태
# - mysql PID 미표시(권한 문제) 대응: pid 조회 시 sudo -n ss 사용

set -euo pipefail

WEBHOOK_URL="${DISCORD_FAILURE_ALERT_WEBHOOK_URL}"   # 디스코드 웹훅 URL(필수)
HOST_TAG="${HOST_TAG:-planit-prod}"                  # 알림 태그
COOLDOWN_SECONDS="${COOLDOWN_SECONDS:-300}"          # 동일 대상 중복 알림 쿨다운(기본 5분)
COOLDOWN_STATE="${COOLDOWN_STATE:-/tmp/planit_alert_cooldown_${0##*/}.tsv}"

# "이름|포트|CPU_THRESHOLD(%)|RSS_THRESHOLD_MB"
# 요청하신 RSS 임계치: ai=1500 / backend=800 / mysql=1000 / caddy=150
TARGETS=(
  "backend|8080|70|800"
  "ai|8000|70|1500"
  "mysql|3306|70|1000"
  "caddy|80|70|150"
)

now_kst(){ TZ=Asia/Seoul date '+%Y-%m-%d %H:%M:%S KST'; }
now_epoch(){ date +%s; }
fmt_kst_from_epoch() {
  local ts="$1"
  if [[ -z "${ts:-}" || "$ts" == "0" ]]; then
    echo "없음"
    return 0
  fi
  TZ=Asia/Seoul date -d "@$ts" '+%Y-%m-%d %H:%M:%S KST'
}

json_escape() {
  local s="$1"
  s="${s//$'\n'/__NL__}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//__NL__/\\n}"
  printf "%s" "$s"
}

send_discord() {
  local title="$1"
  local body="$2"
  [[ -z "${WEBHOOK_URL:-}" ]] && return 0
  local content="**[${HOST_TAG}] ${title}**"$'\n'"${body}"
  content="$(json_escape "$content")"
  curl -sS -H "Content-Type: application/json" \
    -X POST \
    -d "{\"content\":\"${content}\"}" \
    "$WEBHOOK_URL" >/dev/null || true
}

# 동일 key(여기서는 resource|<서비스명>) 기준으로 중복 알림 방지
# 반환: "<summary_count> <send_now> <last_epoch>"
cooldown_status() {
  local key="$1" now last count tmp lock_file fd
  now="$(now_epoch)"
  last=0
  count=0
  [[ -f "$COOLDOWN_STATE" ]] || : > "$COOLDOWN_STATE"

  lock_file="${COOLDOWN_STATE}.lock"
  exec {fd}>"$lock_file"
  flock -x "$fd"

  if read -r last count < <(awk -F'\t' -v k="$key" '$1==k {print $2, $3}' "$COOLDOWN_STATE" | tail -n1); then
    :
  else
    last=0
    count=0
  fi

  # 쿨다운 만료 -> 이번엔 전송 가능(send_now=1)
  if (( now - last >= COOLDOWN_SECONDS )); then
    tmp="$(mktemp)"
    awk -F'\t' -v k="$key" 'BEGIN{OFS="\t"} $1!=k {print $0}' "$COOLDOWN_STATE" > "$tmp"
    printf "%s\t%s\t%s\n" "$key" "$now" 0 >> "$tmp"
    mv "$tmp" "$COOLDOWN_STATE"
    exec {fd}>&-
    printf "%s %s %s\n" "${count:-0}" 1 "$last"
    return 0
  fi

  # 쿨다운 중 -> 누적 count 증가(send_now=0)
  count=$((count + 1))
  tmp="$(mktemp)"
  awk -F'\t' -v k="$key" 'BEGIN{OFS="\t"} $1!=k {print $0}' "$COOLDOWN_STATE" > "$tmp"
  printf "%s\t%s\t%s\n" "$key" "$last" "$count" >> "$tmp"
  mv "$tmp" "$COOLDOWN_STATE"
  exec {fd}>&-
  printf "%s 0 %s\n" "$count" "$last"
}

pid_by_port() {
  local port="$1"

  # 1) 가능하면 sudo -n ss로 조회 (권한 문제로 mysqld pid 안 보이는 문제 해결)
  if command -v ss >/dev/null 2>&1; then
    sudo -n ss -lntp 2>/dev/null \
      | awk -v p=":${port}" '$4 ~ p"$" && $0 ~ /pid=/ {print $0}' \
      | sed -n 's/.*pid=\([0-9]\+\).*/\1/p' \
      | head -n1 && return 0

    # sudo가 안 되면 일반 ss로 fallback
    ss -lntp 2>/dev/null \
      | awk -v p=":${port}" '$4 ~ p"$" && $0 ~ /pid=/ {print $0}' \
      | sed -n 's/.*pid=\([0-9]\+\).*/\1/p' \
      | head -n1 && return 0
  fi

  # 2) lsof fallback (여기도 sudo 시도)
  if command -v lsof >/dev/null 2>&1; then
    sudo -n lsof -nP -iTCP:"$port" -sTCP:LISTEN -t 2>/dev/null | head -n1 && return 0
    lsof -nP -iTCP:"$port" -sTCP:LISTEN -t 2>/dev/null | head -n1 && return 0
  fi

  echo ""
}

proc_cpu() {
  local pid="$1"
  ps -p "$pid" -o %cpu= 2>/dev/null | awk '{printf "%.0f\n", $1}'
}

proc_rss_mb() {
  local pid="$1"
  local rss_kb
  rss_kb="$(ps -p "$pid" -o rss= 2>/dev/null | awk '{print $1}')"
  [[ -z "${rss_kb:-}" ]] && { echo 0; return; }
  echo $((rss_kb / 1024))
}

conn_count_by_port() {
  local port="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -ant "( sport = :${port} )" 2>/dev/null | tail -n +2 | wc -l | tr -d ' '
    return 0
  fi
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"$port" 2>/dev/null | tail -n +2 | wc -l | tr -d ' '
    return 0
  fi
  echo 0
}

for item in "${TARGETS[@]}"; do
  IFS='|' read -r name port cpu_th rss_th <<< "$item"

  pid="$(pid_by_port "$port")"
  [[ -z "${pid:-}" ]] && continue

  cpu="$(proc_cpu "$pid" || echo 0)"
  rss_mb="$(proc_rss_mb "$pid" || echo 0)"
  conn="$(conn_count_by_port "$port" || echo 0)"

  # 이 서비스에서 실제로 초과가 발생했는지 판단
  breaches=()
  if (( cpu >= cpu_th )); then
    breaches+=("CPU: ${cpu}>${cpu_th}%")
  fi
  if (( rss_mb >= rss_th )); then
    breaches+=("RSS: ${rss_mb}>${rss_th}MB")
  fi

  # 이 서비스는 정상 -> 다음 서비스로
  (( ${#breaches[@]} > 0 )) || continue

  # ✅ 서비스별 쿨다운 키
  cooldown_key="resource|${name}"
  read -r summary_count send_now last_epoch <<< "$(cooldown_status "$cooldown_key")"

  # ✅ 요약은 "쿨다운이 풀릴 때"만 전송 (지저분함 방지)
  if (( send_now == 1 && summary_count > 0 )); then
    send_discord "[🟠 RESOURCE] 성능 이상 요약: ${name}" \
"====================
TYPE: RESOURCE SUMMARY
SEVERITY: WARN
====================
시간: $(now_kst)
대상: ${name}
요약:
- 마지막 알림: $(fmt_kst_from_epoch "$last_epoch")
- 마지막 알림 이후 추가 ${summary_count}회 발생"
  fi

  # ✅ 이벤트도 send_now==1일 때만 전송
  if (( send_now == 1 )); then
    send_discord "[🟠 RESOURCE] 성능 이상(임계치 초과) 감지: ${name}" \
"====================
TYPE: RESOURCE EVENT
SEVERITY: WARN
====================
시간: $(now_kst)
대상: ${name}
PID: ${pid}
PORT: ${port}
임계치:
- CPU: ${cpu_th}%
- RSS: ${rss_th}MB

내용:
- 현재 CPU: ${cpu}%
- 현재 RSS: ${rss_mb}MB
- 포트 연결 수: ${conn}

초과 항목:
$(printf "%s\n" "${breaches[@]}" | sed 's/^/- /')"
  fi
done

exit 0