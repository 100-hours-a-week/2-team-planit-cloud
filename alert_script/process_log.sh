#!/usr/bin/env bash
# 여러 로그 파일을 스트리밍으로 감시하고 패턴 매칭 시 디스코드로 알림 전송(쿨다운 없음)

set -euo pipefail  # 에러/미정의 변수/파이프 실패 시 즉시 종료

WEBHOOK_URL="${DISCORD_WEBHOOK_URL:?DISCORD_WEBHOOK_URL is required}" # 디스코드 웹훅 URL(필수)
HOST_TAG="${HOST_TAG:-planit-prod}"                                  # 알림 태그(기본값 planit-prod)

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
      send_discord "로그 감지(${sev}): ${current_comp}/${key}" \
"시간: $(now_kst)
힌트: ${hint}
파일: ${current_file}

로그:
\`\`\`
${line}
\`\`\`"
    fi
  done
done