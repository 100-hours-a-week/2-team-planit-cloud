#!/usr/bin/env bash
# 포트 기반 CPU/RSS 임계치 감시 후 디스코드로 알림 전송

set -euo pipefail

WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-}"     # 디스코드 웹훅 URL
HOST_TAG="${HOST_TAG:-planit-prod}"        # 알림에 붙일 서버/환경 태그
COOLDOWN_SECONDS="${COOLDOWN_SECONDS:-300}" # 동일 종류 중복 알림 쿨다운(기본 5분)
COOLDOWN_STATE="${COOLDOWN_STATE:-/tmp/planit_alert_cooldown_${0##*/}.tsv}"

TARGETS=(                                 # "이름|포트" 감시 대상 목록
  "backend|8080"
  "ai|8000"
  "caddy|80"
)

CPU_THRESHOLD="${CPU_THRESHOLD:-70}"       # CPU 사용률 임계치(%)
RSS_THRESHOLD_MB="${RSS_THRESHOLD_MB:-1000}" # 메모리(RSS) 임계치(MB)

now_kst() { TZ=Asia/Seoul date '+%Y-%m-%d %H:%M:%S KST'; } # KST 시간 문자열 생성
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
cooldown_status() {                        # 쿨다운 상태 파일 기반 중복 알림 방지
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

conn_count_by_port() {                        # 로컬 포트 기준 TCP 소켓(연결/대기 포함) 개수
  local port="$1"
  if command -v ss >/dev/null 2>&1; then
    # sport=:PORT 로컬 포트만 필터링. 헤더 1줄 제외.
    ss -ant "( sport = :${port} )" 2>/dev/null | tail -n +2 | wc -l | tr -d ' '
    return 0
  fi
  if command -v lsof >/dev/null 2>&1; then
    # LISTEN+ESTABLISHED 등 포함한 TCP 소켓 수(포트 기준)
    lsof -nP -iTCP:"$port" 2>/dev/null | tail -n +2 | wc -l | tr -d ' '
    return 0
  fi
  echo 0
}

declare -a alerts=()                       # 알림 메시지 누적 배열
declare -a conn_lines=()                      # 포트별 연결 수 누적 배열

for item in "${TARGETS[@]}"; do            # 대상(포트)별로 PID/리소스 측정
  IFS='|' read -r name port <<< "$item"
  pid="$(pid_by_port "$port")"
  [[ -z "${pid:-}" ]] && continue

  cpu="$(proc_cpu "$pid" || echo 0)"
  rss_mb="$(proc_rss_mb "$pid" || echo 0)"

  if (( cpu >= CPU_THRESHOLD )); then
    alerts+=("${name}(pid ${pid}, port ${port}): CPU ${cpu}% ≥ ${CPU_THRESHOLD}%")
    conn="$(conn_count_by_port "$port")"
    conn_lines+=("${name} port ${port} connections: ${conn}")
  fi

  if (( rss_mb >= RSS_THRESHOLD_MB )); then
    alerts+=("${name}(pid ${pid}, port ${port}): RSS ${rss_mb}MB ≥ ${RSS_THRESHOLD_MB}MB")
    conn="$(conn_count_by_port "$port")"
    conn_lines+=("${name} port ${port} connections: ${conn}")
  fi
done

if (( ${#alerts[@]} > 0 )); then           # 임계치 초과가 있으면 디스코드로 전송
  msg="시간: $(now_kst)\n내용:\n- $(printf "%s\n" "${alerts[@]}" | sed 's/^/- /')"

  # 같은 대상이 CPU/RSS 둘 다 걸리면 conn_lines 중복될 수 있어서 uniq 처리
  if (( ${#conn_lines[@]} > 0 )); then
    msg="${msg}\n\n포트 연결 수:\n$(printf "%s\n" "${conn_lines[@]}" | awk '!seen[$0]++' | sed 's/^/- /')"
  fi
  read -r summary_count send_now last_epoch <<< "$(cooldown_status "resource|summary")"
  if (( summary_count > 0 )); then
    send_discord "[RESOURCE] 성능 이상 요약" "====================\nTYPE: RESOURCE SUMMARY\n====================\n시간: $(now_kst)\n요약:\n- 마지막 알림: $(fmt_kst_from_epoch "$last_epoch")\n- 마지막 알림 이후 추가 ${summary_count}회 발생"
  fi
  if (( send_now == 1 )); then
    send_discord "[RESOURCE] 성능 이상(임계치 초과) 감지" "====================\nTYPE: RESOURCE EVENT\n====================\n${msg}"
  fi
fi

exit 0                                     # 정상 종료
