#!/usr/bin/env bash
# 여러 로그 파일을 스트리밍으로 감시하고 패턴 매칭 시 디스코드로 알림 전송(쿨다운 없음)

set -euo pipefail  # 에러/미정의 변수/파이프 실패 시 즉시 종료

WEBHOOK_URL="${DISCORD_WEBHOOK_URL:?DISCORD_WEBHOOK_URL is required}" # 디스코드 웹훅 URL(필수)
HOST_TAG="${HOST_TAG:-planit-prod}"                                  # 알림 태그(기본값 planit-prod)

LOG_FILES=(                                                           # "로그경로|컴포넌트명" 감시 대상 목록
  "/var/www/planit/backend/app.log|backend"
  "/var/www/planit/ai/app.log|ai"
  "/var/log/caddy/error.log|web"
)

RULES=(                                                               # "키|정규식|심각도|힌트" 감지 규칙 목록
  "db_sql|SQLException|ERROR|DB/SQL 오류 의심"
  "oom|OutOfMemoryError|CRITICAL|메모리(OOM) 의심"
  "timeout|timed out|WARN|타임아웃/지연 의심"
  "boot_fail|APPLICATION FAILED TO START|CRITICAL|기동 실패"
  "upstream|upstream prematurely closed|ERROR|업스트림(백엔드) 문제 의심"
)

now_kst(){ TZ=Asia/Seoul date '+%Y-%m-%d %H:%M:%S KST'; }            # 현재 시간을 KST 문자열로 반환

json_escape() {                                                      # 디스코드 JSON 전송을 위한 문자열 escape
  local s="$1"
  s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\n'/\\n}"
  printf "%s" "$s"
}

send_discord() {                                                     # 디스코드 웹훅으로 메시지 전송
  local title="$1"
  local body="$2"
  local content="**[${HOST_TAG}] ${title}**\n${body}"
  content="$(json_escape "$content")"
  curl -sS -H "Content-Type: application/json" \
    -X POST \
    -d "{\"content\":\"${content}\"}" \
    "$WEBHOOK_URL" >/dev/null || true
}

tail -n 0 -F -v $(printf "%q " "${LOG_FILES[@]%%|*}") 2>/dev/null | \ # 로그 파일을 새로 추가되는 줄만 스트리밍으로 읽기
while IFS= read -r line; do                                          # 들어오는 로그 라인을 한 줄씩 처리
  if [[ "$line" =~ ^==\>\ (.*)\ \<== ]]; then                        # tail -v가 출력하는 "현재 파일" 헤더를 감지
    current_file="${BASH_REMATCH[1]}"                                 # 현재 읽고 있는 파일 경로 저장
    current_comp="unknown"                                            # 현재 컴포넌트 기본값 설정
    for pair in "${LOG_FILES[@]}"; do                                 # 파일 경로에 맞는 컴포넌트명 매핑
      f="${pair%%|*}"
      c="${pair##*|}"
      [[ "$f" == "$current_file" ]] && current_comp="$c"
    done
    continue                                                          # 헤더 라인은 규칙 매칭 대상이 아니므로 다음 줄로
  fi

  for rule in "${RULES[@]}"; do                                      # 각 규칙을 현재 로그 라인에 매칭
    IFS='|' read -r key regex sev hint <<< "$rule"
    if echo "$line" | grep -Eiq "$regex"; then                        # 정규식이 매칭되면 해당 장애로 판단
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