#!/usr/bin/env bash
# 여러 서비스의 health URL을 호출해서 실패 시 디스코드로 알림 전송

set -euo pipefail  # 에러/미정의 변수/파이프 실패 시 즉시 종료

WEBHOOK_URL="${DISCORD_WEBHOOK_URL:?DISCORD_WEBHOOK_URL is required}" # 디스코드 웹훅 URL(필수)
HOST_TAG="${HOST_TAG:-planit-prod}"                                  # 알림 태그(기본값 planit-prod)

URLS=(                                                                # "이름|URL" 형태로 헬스체크 대상 목록
  "backend|http://127.0.0.1:8080/api/health"
  "ai|http://127.0.0.1:8000/health"
)

now_kst() { TZ=Asia/Seoul date '+%Y-%m-%d %H:%M:%S KST'; }           # 현재 시간을 KST로 출력

send_discord() {                                                     # 디스코드 웹훅으로 메시지 전송
  local title="$1"
  local body="$2"
  body="${body//\\/\\\\}"
  body="${body//\"/\\\"}"
  body="${body//$'\n'/\\n}"
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
    send_discord "헬스체크 실패: ${name}" \
      "시간: $(now_kst)\nURL: ${url}\n조치: 해당 프로세스 상태 확인 후 재기동/롤백 판단"
  fi
done