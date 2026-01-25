#!/usr/bin/env bash
# 포트 기반 CPU/RSS 임계치 감시 후 디스코드로 알림 전송

set -euo pipefail

WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-}"     # 디스코드 웹훅 URL
HOST_TAG="${HOST_TAG:-planit-prod}"        # 알림에 붙일 서버/환경 태그

TARGETS=(                                 # "이름|포트" 감시 대상 목록
  "backend|8080"
  "ai|3000"
  "caddy|80"
)

CPU_THRESHOLD="${CPU_THRESHOLD:-90}"       # CPU 사용률 임계치(%)
RSS_THRESHOLD_MB="${RSS_THRESHOLD_MB:-1500}" # 메모리(RSS) 임계치(MB)

now_kst() { TZ=Asia/Seoul date '+%Y-%m-%d %H:%M:%S KST'; } # KST 시간 문자열 생성

send_discord() {                           # 디스코드 웹훅으로 메시지 전송
  local title="$1"
  local body="$2"
  [[ -z "$WEBHOOK_URL" ]] && return 0
  body="${body//\\/\\\\}"
  body="${body//\"/\\\"}"
  body="${body//$'\n'/\\n}"
  curl -sS -H "Content-Type: application/json" \
    -X POST \
    -d "{\"content\":\"**[${HOST_TAG}] ${title}**\\n${body}\"}" \
    "$WEBHOOK_URL" >/dev/null || true
}

pid_by_port() {                            # 해당 포트를 LISTEN 중인 PID 조회
  local port="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -lntp 2>/dev/null \
      | awk -v p=":${port}" '$4 ~ p"$" && $0 ~ /pid=/ {print $0}' \
      | sed -n 's/.*pid=\([0-9]\+\).*/\1/p' \
      | head -n1
    return 0
  fi
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"$port" -sTCP:LISTEN -t 2>/dev/null | head -n1
    return 0
  fi
  echo ""
}

proc_cpu() {                               # PID의 CPU 사용률(%cpu) 조회
  local pid="$1"
  ps -p "$pid" -o %cpu= 2>/dev/null | awk '{printf "%.0f\n", $1}'
}

proc_rss_mb() {                            # PID의 RSS 메모리(MB) 조회
  local pid="$1"
  local rss_kb
  rss_kb="$(ps -p "$pid" -o rss= 2>/dev/null | awk '{print $1}')"
  [[ -z "${rss_kb:-}" ]] && { echo 0; return; }
  echo $((rss_kb / 1024))
}

declare -a alerts=()                       # 알림 메시지 누적 배열

for item in "${TARGETS[@]}"; do            # 대상(포트)별로 PID/리소스 측정
  IFS='|' read -r name port <<< "$item"
  pid="$(pid_by_port "$port")"
  [[ -z "${pid:-}" ]] && continue

  cpu="$(proc_cpu "$pid" || echo 0)"
  rss_mb="$(proc_rss_mb "$pid" || echo 0)"

  (( cpu >= CPU_THRESHOLD )) && alerts+=("${name}(pid ${pid}, port ${port}): CPU ${cpu}% ≥ ${CPU_THRESHOLD}%")
  (( rss_mb >= RSS_THRESHOLD_MB )) && alerts+=("${name}(pid ${pid}, port ${port}): RSS ${rss_mb}MB ≥ ${RSS_THRESHOLD_MB}MB")
done

if (( ${#alerts[@]} > 0 )); then           # 임계치 초과가 있으면 디스코드로 전송
  msg="시간: $(now_kst)\n내용:\n- $(printf "%s\n" "${alerts[@]}" | sed 's/^/- /')"
  send_discord "성능 이상(임계치 초과) 감지" "$msg"
fi

exit 0                                     # 정상 종료