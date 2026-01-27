import http from 'k6/http';
import { check } from 'k6';

// --- 기본 설정 ---
const BASE_URL = 'https://planit-ai.store'; // 서버 도메인

// --- 테스트 옵션 ---
export const options = {
  // 테스트 성공/실패 기준
  thresholds: {
    // 메인페이지 조회
    'http_req_failed{scenario:load_main_page}': ['rate < 0.001'],
    'http_req_duration{scenario:load_main_page}': ['p(95) < 500'],

    // 게시물 목록 조회
    'http_req_failed{scenario:load_posts_list}': ['rate < 0.001'],
    'http_req_duration{scenario:load_posts_list}': ['p(95) < 500'],

    // 챗봇 응답
    'http_req_failed{scenario:load_chatbot}': ['rate < 0.001'],
    'http_req_duration{scenario:load_chatbot}': ['p(95) < 10000'],

    // AI 일정 생성
    'http_req_failed{scenario:load_ai_itinerary}': ['rate < 0.001'],
  },

  // 시나리오 정의
  scenarios: {
    // 1. 메인페이지 조회
    load_main_page: {
      executor: 'ramping-vus',
      exec: 'main_page_test',
      startVUs: 0,
      stages: [
        { duration: '1m', target: 300 }, // 1분 동안 300 VU까지 증가
        { duration: '5m', target: 300 }, // 5분 동안 300 VU 유지
      ],
      gracefulRampDown: '30s',
    },

    // 2. 게시물 목록 조회
    load_posts_list: {
      executor: 'ramping-vus',
      exec: 'posts_list_test',
      startVUs: 0,
      stages: [
        { duration: '1m', target: 300 },
        { duration: '5m', target: 300 },
      ],
      gracefulRampDown: '30s',
    },

    // 3. 챗봇 응답
    load_chatbot: {
      executor: 'ramping-vus',
      exec: 'chatbot_test',
      startVUs: 0,
      stages: [
        { duration: '1m', target: 30 },
        { duration: '5m', target: 30 },
      ],
      gracefulRampDown: '30s',
    },

    // 4. AI 일정 생성
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
  },
};

// --- 테스트 함수 ---

// 1. 메인페이지 조회 테스트
export function main_page_test() {
  const res = http.get(`${BASE_URL}/`);
  check(res, { 'status is 200': (r) => r.status === 200 });
}

// 2. 게시물 목록 조회 테스트
export function posts_list_test() {
  const res = http.get(`${BASE_URL}/posts`);
  check(res, { 'status is 200': (r) => r.status === 200 });
}

// 3. 챗봇 응답 테스트
export function chatbot_test() {
  const url = `${BASE_URL}/api/v1/chatbot`; // 임시 경로
  const payload = JSON.stringify({ tripId : 1234, userMessage: 'Hello, k6 test!' });
  const params = { headers: { 'Content-Type': 'application/json' } };

  const res = http.post(url, payload, params);
  check(res, { 'status is 200': (r) => r.status === 200 });
}

// 4. AI 일정 생성 테스트
export function ai_itinerary_test() {
    // 추후 세부 구현 필요
}