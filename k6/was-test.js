import http from 'k6/http';
import { check, sleep } from 'k6';

// --- 기본 설정 ---
const BASE_URL = 'https://planit-ai.store';

// API paths
const LOGIN_PATH = '/api/auth/login';
const POSTS_LIST_PATH = '/api/posts';

// ===== 시나리오 선택 실행 지원 =====
const SELECTED = (__ENV.SCENARIO || 'all').trim();
const DURATION = __ENV.DURATION || '2m';

// --- 시나리오 정의 ---
const ALL_SCENARIOS = {
  load_main_page: {
    executor: 'constant-vus',
    exec: 'main_page_test',
    vus: 100,
    duration: DURATION,
    gracefulStop: '10s',
  },

  load_posts_list: {
    executor: 'constant-vus',
    exec: 'posts_list_test',
    vus: 100,
    duration: DURATION,
    gracefulStop: '10s',
  },
};

// --- 시나리오 선택 검증 + 필터링 ---
const VALID_KEYS = Object.keys(ALL_SCENARIOS);
let scenarios;

if (SELECTED === 'all' || SELECTED === '') {
  scenarios = ALL_SCENARIOS;
} else if (Object.prototype.hasOwnProperty.call(ALL_SCENARIOS, SELECTED)) {
  scenarios = { [SELECTED]: ALL_SCENARIOS[SELECTED] };
} else {
  throw new Error(
    `Invalid SCENARIO="${SELECTED}". Valid values: ${VALID_KEYS.join(', ')}, all`
  );
}

// --- 테스트 옵션 ---
export const options = {
  thresholds: {
    'http_req_failed{scenario:load_main_page}': ['rate < 0.01'],
    'http_req_duration{scenario:load_main_page}': ['p(95) < 1000'],

    'http_req_failed{scenario:load_posts_list}': ['rate < 0.01'],
    'http_req_duration{scenario:load_posts_list}': ['p(95) < 1000'],
  },
  scenarios,
};

// ===== JWT token 세팅 =====
export function setup() {
  const loginPayload = JSON.stringify({
    loginId: 'test123',
    password: 'Test123!',
  });

  const loginRes = http.post(`${BASE_URL}${LOGIN_PATH}`, loginPayload, {
    headers: { 'Content-Type': 'application/json' },
  });

  const authToken = loginRes.json('accessToken');

  check(loginRes, {
    'login successful': (r) => r.status === 200 && !!authToken,
  });

  return { token: authToken };
}

// 1) 메인페이지 조회
export function main_page_test(data) {
  const res = http.get(`${BASE_URL}/`, {
    headers: { Authorization: `Bearer ${data.token}` },
    timeout: '60s',
  });

  check(res, {
    'status is 200': (r) => r.status === 200,
  });

  sleep(1);
}

// 2) 게시물 목록 조회
export function posts_list_test(data) {
  const boardType = encodeURIComponent('자유 게시판');
  const url = `${BASE_URL}${POSTS_LIST_PATH}?boardType=${boardType}&sort=latest&page=1&size=10`;

  const res = http.get(url, {
    headers: {
      Accept: 'application/json, text/plain, */*',
      Authorization: `Bearer ${data.token}`,
    },
    timeout: '60s',
  });

  if (__VU === 1 && __ITER === 0) {
    console.log('LIST url=', url);
    console.log('LIST status=', res.status);
    console.log('LIST body=', res.body);
  }

  check(res, {
    'status is 200': (r) => r.status === 200,
  });

  sleep(1);
}