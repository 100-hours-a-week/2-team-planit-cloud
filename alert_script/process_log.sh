#!/usr/bin/env bash
# 여러 로그 파일을 스트리밍으로 감시하고 패턴 매칭 시 디스코드로 알림 전송(쿨다운 없음)

set -euo pipefail  # 에러/미정의 변수/파이프 실패 시 즉시 종료

WEBHOOK_URL="${DISCORD_WEBHOOK_URL:?DISCORD_WEBHOOK_URL is required}" # 디스코드 웹훅 URL(필수)
HOST_TAG="${HOST_TAG:-planit-prod}"                                  # 알림 태그(기본값 planit-prod)

LOG_FILES=(                                                           # "로그경로|컴포넌트명" 감시 대상 목록
  "/var/www/planit/backend/app.log|backend"
  "/var/www/planit/ai/app.log|ai"
  "/var/log/caddy/access.log|web"
  "/var/log/caddy/error.log|web"
)

RULES=(                                                               # "키|정규식|심각도|힌트" 감지 규칙 목록
  "db_sql|SQLException|ERROR|DB/SQL 오류 의심"
  "oom|OutOfMemoryError|CRITICAL|메모리(OOM) 의심"
  "timeout|timed out|WARN|타임아웃/지연 의심"
  "boot_fail|APPLICATION FAILED TO START|CRITICAL|기동 실패"
  "upstream|upstream prematurely closed|ERROR|업스트림(백엔드) 문제 의심"

  # --- Caddy Access ---
  "web_5xx|(\"status\":5[0-9]{2}|\\s5[0-9]{2}\\s)|CRITICAL|웹 서버 5xx 응답 발생(서버 오류)"
  "web_429|(\"status\":429|\\s429\\s)|WARN|429 발생(과도 요청/레이트리밋) - 트래픽 스파이크 가능"
  "web_client_abort|(\\s499\\s|client.*(canceled|closed)|context canceled)|WARN|클라이언트 요청 중단 증가(타임아웃/네트워크/프론트 이탈)"
  "web_static_404|(\\s404\\s.*\\.(js|css|png|jpg|jpeg|svg|webp|ico)(\\?|\\s|$)|\"status\":404.*\\.(js|css|png|jpg|jpeg|svg|webp|ico))|WARN|정적 리소스 404(배포 누락/경로 문제) 의심"

  # --- Caddy Error ---
  "web_upstream_refused|(connection refused|connect: connection refused|dial tcp .*: connect: connection refused)|CRITICAL|업스트림(백엔드/AI) 접속 거부 - 서비스 다운/포트 문제 의심"
  "web_upstream_timeout|(i/o timeout|context deadline exceeded|timeout while|timed out)|ERROR|업스트림 타임아웃 - 지연/병목/다운 의심"
  "web_dns|(no such host|SERVFAIL|NXDOMAIN|Temporary failure in name resolution)|ERROR|DNS/호스트 해석 실패"
  "web_tls|(TLS handshake error|remote error: tls|certificate|acme|OCSP|x509)|ERROR|TLS/인증서 문제 의심(인증서/핸드셰이크/ACME)"
  "web_fs|(permission denied|no such file or directory|file does not exist)|ERROR|정적 파일/권한 문제 의심(배포/권한/경로)"
  "web_fd|(too many open files|EMFILE)|CRITICAL|파일 디스크립터 부족 - 트래픽/리소스 한계 의심"
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