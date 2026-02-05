#!/usr/bin/env bash
# 여러 로그 파일을 스트리밍으로 감시하고 패턴 매칭 시 디스코드로 알림 전송(쿨다운/요약 포함)

set -euo pipefail  # 에러/미정의 변수/파이프 실패 시 즉시 종료

WEBHOOK_URL="${DISCORD_WEBHOOK_URL:?DISCORD_WEBHOOK_URL is required}" # 디스코드 웹훅 URL(필수)
HOST_TAG="${HOST_TAG:-planit-prod}"                                  # 알림 태그(기본값 planit-prod)
COOLDOWN_SECONDS="${COOLDOWN_SECONDS:-300}"                         # 동일 룰/컴포넌트 중복 알림 쿨다운(기본 5분)
COOLDOWN_STATE="${COOLDOWN_STATE:-/tmp/planit_alert_cooldown_${0##*/}.tsv}"

LOG_FILES=(                                                           # "로그경로|컴포넌트명" 감시 대상 목록
  "/var/www/planit/backend/app.log|backend"
  "/var/www/planit/ai/app.log|ai"
  "/var/log/caddy/access.log|web"
)

# RULES 내부 정규식에 '|'(OR)이 들어가서, 필드 구분자를 '|'로 쓰면 파싱이 깨짐.
# 그래서 거의 안 쓰는 구분자(0x1F, Unit Separator)를 사용.
SEP=$'\x1f'

RULES=(                                                               # "키<SEP>정규식<SEP>심각도<SEP>힌트"
  "db_sql${SEP}SQLException${SEP}ERROR${SEP}DB/SQL 오류 의심"
  "oom${SEP}OutOfMemoryError${SEP}CRITICAL${SEP}메모리(OOM) 의심"
  "timeout${SEP}timed out${SEP}WARN${SEP}타임아웃/지연 의심"
  "boot_fail${SEP}APPLICATION FAILED TO START${SEP}CRITICAL${SEP}기동 실패"
  "upstream${SEP}upstream prematurely closed${SEP}ERROR${SEP}업스트림(백엔드) 문제 의심"

  # --- Caddy Access ---
  "web_5xx${SEP}(\"status\":5[0-9]{2}|\\s5[0-9]{2}\\s)${SEP}CRITICAL${SEP}웹 서버 5xx 응답 발생(서버 오류)"
  "web_429${SEP}(\"status\":429|\\s429\\s)${SEP}WARN${SEP}429 발생(과도 요청/레이트리밋) - 트래픽 스파이크 가능"
  "web_client_abort${SEP}(\\s499\\s|client.*(canceled|closed)|context canceled)${SEP}WARN${SEP}클라이언트 요청 중단 증가(타임아웃/네트워크/프론트 이탈)"
  "web_static_404${SEP}(\\s404\\s.*\\.(js|css|png|jpg|jpeg|svg|webp|ico)(\\?|\\s|$)|\"status\":404.*\\.(js|css|png|jpg|jpeg|svg|webp|ico))${SEP}WARN${SEP}정적 리소스 404(배포 누락/경로 문제) 의심"
)

now_kst(){ TZ=Asia/Seoul date '+%Y-%m-%d %H:%M:%S KST'; }
now_epoch(){ date +%s; }

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\n'/\\n}"
  printf "%s" "$s"
}

send_discord() {
  local title="$1"
  local body="$2"
  local content="**[${HOST_TAG}] ${title}**\n${body}"
  content="$(json_escape "$content")"
  curl -sS -H "Content-Type: application/json" \
    -X POST \
    -d "{\"content\":\"${content}\"}" \
    "$WEBHOOK_URL" >/dev/null || true
}

# 동일 룰/컴포넌트 기준으로 요약+쿨다운 동작
# 반환: "<summary_count> <send_now>"
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
    printf "%s %s\n" "${count:-0}" 1
    return 0
  fi

  count=$((count + 1))
  tmp="$(mktemp)"
  awk -F'\t' -v k="$key" 'BEGIN{OFS="\t"} $1!=k {print $0}' "$COOLDOWN_STATE" > "$tmp"
  printf "%s\t%s\t%s\n" "$key" "$last" "$count" >> "$tmp"
  mv "$tmp" "$COOLDOWN_STATE"
  exec {fd}>&-
  printf "0 0\n"
}

# tail -v 헤더(==> file <==)로 현재 파일을 추적해서 컴포넌트를 매핑
tail -n 0 -F -v $(printf "%q " "${LOG_FILES[@]%%|*}") 2>/dev/null |
while IFS= read -r line; do
  if [[ "$line" =~ ^==\>\ (.*)\ \<== ]]; then
    current_file="${BASH_REMATCH[1]}"
    current_comp="unknown"
    for pair in "${LOG_FILES[@]}"; do
      f="${pair%%|*}"
      c="${pair##*|}"
      [[ "$f" == "$current_file" ]] && current_comp="$c"
    done
    continue
  fi

  for rule in "${RULES[@]}"; do
    IFS=$'\x1f' read -r key regex sev hint <<< "$rule"
    if echo "$line" | grep -Eiq "$regex"; then
      cooldown_key="${current_comp}|${key}"
      read -r summary_count send_now <<< "$(cooldown_status "$cooldown_key")"
      if (( summary_count > 0 )); then
        send_discord "로그 요약(${sev}): ${current_comp}/${key}" \
"시간: $(now_kst)
요약:
- 마지막 알림 이후 추가 ${summary_count}회 발생"
      fi
      if (( send_now == 0 )); then
        continue
      fi
      send_discord "로그 감지(${sev}): ${current_comp}/${key}" \
"시간: $(now_kst)
컴포넌트: ${current_comp}
규칙: ${key}
힌트: ${hint}
파일: ${current_file}

로그:
\`\`\`
${line}
\`\`\`"
    fi
  done
done
