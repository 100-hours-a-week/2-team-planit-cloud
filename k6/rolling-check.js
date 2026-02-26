import http from 'k6/http';
import { check, sleep } from 'k6';

/*
실행 방법 (롤링 배포 확인용, 저부하)
==================================

1) 기본 실행 (20분, 1 VU, 15초 간격)
   LOGIN_ID='test123' LOGIN_PASSWORD='Test123!' \
   k6 run k6/rolling-check.js

2) "모든 로그"를 파일로 남기기 (권장)
   - 콘솔 로그(console.log): --console-output
   - k6 엔진 로그: --log-output
   - 요약 리포트(JSON): --summary-export
   - 터미널 전체 출력(요약 텍스트 포함): tee

   mkdir -p k6/logs
   TS=$(date +%Y%m%d_%H%M%S)
   LOGIN_ID='test123' LOGIN_PASSWORD='Test123!' \
   k6 run k6/rolling-check.js \
     --console-output "k6/logs/console_${TS}.log" \
     --log-output "file=k6/logs/k6_${TS}.log" \
     --summary-export "k6/logs/summary_${TS}.json" \
     2>&1 | tee "k6/logs/run_${TS}.log"

3) 부하 더 낮추기 (예: 30초 간격)
   LOGIN_ID='test123' LOGIN_PASSWORD='Test123!' \
   INTERVAL_SEC=30 DURATION=20m \
   k6 run k6/rolling-check.js \
     --console-output "k6/logs/console_${TS}.log" \
     --log-output "file=k6/logs/k6_${TS}.log" \
     --summary-export "k6/logs/summary_${TS}.json" \
     2>&1 | tee "k6/logs/run_${TS}.log"

환경변수 설명
- BASE_URL: 대상 서버 주소 (기본: https://planit-ai.store)
- LOGIN_PATH: 로그인 API 경로 (기본: /api/auth/login)
- POSTS_LIST_PATH: 게시물 목록 API 경로 (기본: /api/posts)
- LOGIN_ID / LOGIN_PASSWORD: 로그인 계정
- DURATION: 실행 시간 (기본: 20m)
- INTERVAL_SEC: 요청 간격(초) (기본: 15)
- BOARD_TYPE: 조회 게시판명 (기본: 자유 게시판)
*/

const BASE_URL = (__ENV.BASE_URL || 'https://planit-ai.store').replace(/\/+$/, '');
const LOGIN_PATH = __ENV.LOGIN_PATH || '/api/auth/login';
const POSTS_LIST_PATH = __ENV.POSTS_LIST_PATH || '/api/posts';

const LOGIN_ID = __ENV.LOGIN_ID || 'test123';
const LOGIN_PASSWORD = __ENV.LOGIN_PASSWORD || 'Test123!';

const DURATION = __ENV.DURATION || '20m';
const INTERVAL_SEC = Number(__ENV.INTERVAL_SEC || 15);
const BOARD_TYPE = __ENV.BOARD_TYPE || '자유 게시판';

if (!Number.isFinite(INTERVAL_SEC) || INTERVAL_SEC <= 0) {
  throw new Error(`Invalid INTERVAL_SEC="${__ENV.INTERVAL_SEC}". Use a positive number.`);
}

export const options = {
  thresholds: {
    http_req_failed: ['rate < 0.05'],
    http_req_duration: ['p(95) < 1500'],
  },
  scenarios: {
    rolling_posts_list_check: {
      executor: 'constant-vus',
      vus: 1,
      duration: DURATION,
      exec: 'posts_list_check',
      gracefulStop: '10s',
    },
  },
};

export function setup() {
  const payload = JSON.stringify({
    loginId: LOGIN_ID,
    password: LOGIN_PASSWORD,
  });

  const loginRes = http.post(`${BASE_URL}${LOGIN_PATH}`, payload, {
    headers: { 'Content-Type': 'application/json' },
    timeout: '10s',
  });

  const token = loginRes.json('accessToken');

  check(loginRes, {
    'login status is 200': (r) => r.status === 200,
    'login token exists': () => !!token,
  });

  if (!token) {
    throw new Error(`Login failed (status=${loginRes.status}).`);
  }

  return { token };
}

export function posts_list_check(data) {
  const boardType = encodeURIComponent(BOARD_TYPE);
  const url = `${BASE_URL}${POSTS_LIST_PATH}?boardType=${boardType}&sort=latest&page=1&size=10`;

  const res = http.get(url, {
    headers: {
      Authorization: `Bearer ${data.token}`,
      Accept: 'application/json',
    },
    timeout: '10s',
  });

  check(res, {
    'posts list status is 200': (r) => r.status === 200,
  });

  console.log(
    `[${new Date().toISOString()}] status=${res.status} duration=${res.timings.duration}ms`
  );

  sleep(INTERVAL_SEC);
}
