import http from 'k6/http';
import { check } from 'k6';


// --- 기본 설정 ---
const BASE_URL = 'https://planit-ai.store';
// API paths
const LOGIN_PATH = '/api/auth/login';
const POSTS_LIST_PATH = '/api/posts'; // 명세: GET /posts
const CREATE_POST_PATH = '/api/posts';

// ===== 시나리오 선택 실행 지원 =====
// 사용법:
// 1) 전체 실행(기본): k6 run loadtest.js
// 2) 특정 시나리오만:  SCENARIO=load_posts_list k6 run load-test.js
// 가능한 값: load_main_page | load_posts_list | create_free_post | load_ai_itinerary | all
const SELECTED = (__ENV.SCENARIO || 'all').trim();

// --- 시나리오 정의(원본 그대로) ---
const ALL_SCENARIOS = {
  load_main_page: {
    executor: 'ramping-vus',
    exec: 'main_page_test',
    startVUs: 0,
    stages: [
      { duration: '1m', target: 300 },
      { duration: '1m', target: 300 },
    ],
    gracefulRampDown: '30s',
  },

  load_posts_list: {
    executor: 'ramping-vus',
    exec: 'posts_list_test',
    startVUs: 0,
    stages: [
      { duration: '1m', target: 300 },
      { duration: '1m', target: 300 },
    ],
    gracefulRampDown: '30s',
  },
/*
  load_ai_itinerary: {
    executor: 'ramping-vus',
    exec: 'ai_itinerary_test',
    startVUs: 0,
    stages: [
      { duration: '1m', target: 10 },
      { duration: '5m', target: 10 },
    ],
    gracefulRampDown: '30s',
  },
*/
  create_free_post: {
    executor: 'ramping-vus',
    exec: 'free_post_create_test',
    startVUs: 0,
    stages: [
      { duration: '1m', target: 8000 },
      { duration: '1m', target: 8000 },
    ],
    gracefulRampDown: '30s',
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
  // 옵션에 잘못된 시나리오를 넣었을 때, 테스트 시작 전에 즉시 실패 처리
  throw new Error(
    `Invalid SCENARIO="${SELECTED}". Valid values: ${VALID_KEYS.join(
      ', '
    )}, all`
  );
}

// --- 테스트 옵션 ---
export const options = {
  thresholds: {
    'http_req_failed{scenario:load_main_page}': ['rate < 0.01'],
    'http_req_duration{scenario:load_main_page}': ['p(95) < 1000'],

    'http_req_failed{scenario:load_posts_list}': ['rate < 0.01'],
    'http_req_duration{scenario:load_posts_list}': ['p(95) < 1000'],

    'http_req_failed{scenario:create_free_post}': ['rate < 0.01'],
    'http_req_duration{scenario:create_free_post}': ['p(95) < 1500'],

    //'http_req_failed{scenario:load_ai_itinerary}': ['rate < 0.01'],
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

// ===== 테스트 함수 =====

// 1) 메인페이지 조회
export function main_page_test(data) {
  const res = http.get(`${BASE_URL}/`, {
    headers: { Authorization: `Bearer ${data.token}` },
  });

  check(res, { 'status is 200': (r) => r.status === 200 });
}

// 2) 게시물 목록 조회 (명세: GET /posts, boardType 필수)
export function posts_list_test(data) {
  const boardType = encodeURIComponent('자유 게시판');
  const url = `${BASE_URL}/api/posts?boardType=${boardType}&sort=latest&page=1&size=10`;
  

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
    console.log('LIST body=', res.body); // 응답 스키마 확인용
  }

  check(res, {
    'status is 200': (r) => r.status === 200,
  });
}
// 3) 게시물 작성(자유)
export function free_post_create_test(ctx) {
  const title = `k6-${__VU}-${Date.now()}-${__ITER}`.slice(0, 24);
  const content = `content from k6 vu=${__VU} iter=${__ITER}`.slice(0, 2000);

  const body = JSON.stringify({
    boardType: 'FREE',
    title,
    content,
    imageKeys: [], // 이미지 없어도 빈 배열로
  });

  const res = http.post(`${BASE_URL}${CREATE_POST_PATH}`, body, {
    headers: {
      Authorization: `Bearer ${ctx.token}`,
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
  });

  if (__VU === 1 && __ITER === 0) {
    console.log('CREATE status=', res.status);
    console.log('CREATE body=', res.body);
  }

  check(res, {
    'create status is 200/201': (r) => r.status === 200 || r.status === 201,
  });

  return res;
}

// 4) AI 일정 생성 (추후 구현)
export function ai_itinerary_test(_data) {
  // TODO
}