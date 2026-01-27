import http from 'k6/http';

// --- 기본 설정 ---
const BASE_URL = 'https://planit-ai.store'; // 대상 서비스의 주소를 입력하세요.

// --- 테스트 옵션 ---
export const options = {
  // 스트레스 테스트는 관찰 목적이므로 thresholds는 설정하지 않음
  scenarios: {
    // 1. 메인페이지 조회
    stress_main_page: {
      executor: 'ramping-vus',
      exec: 'main_page_test',
      startVUs: 0,
      stages: [{ duration: '5m', target: 2000 }], // 5분간 2000 VU까지 계속 증가
      gracefulRampDown: '30s',
    },

    // 2. 게시물 목록 조회
    stress_posts_list: {
      executor: 'ramping-vus',
      exec: 'posts_list_test',
      startVUs: 0,
      stages: [{ duration: '5m', target: 2000 }],
      gracefulRampDown: '30s',
    },

    // 3. 챗봇 응답
    stress_chatbot: {
      executor: 'ramping-vus',
      exec: 'chatbot_test',
      startVUs: 0,
      stages: [{ duration: '5m', target: 2000 }],
      gracefulRampDown: '30s',
    },
  },
};


// 1. 메인페이지 조회 테스트
export function main_page_test() {
  http.get(`${BASE_URL}/`);
}

// 2. 게시물 목록 조회 테스트
export function posts_list_test() {
  http.get(`${BASE_URL}/api/posts`);
}

// 3. 챗봇 응답 테스트
export function chatbot_test() {
  const url = `${BASE_URL}/api/v1/chatbot`; // 임시 경로
  const payload = JSON.stringify({ tripId : 1234, userMessage: 'Hello, k6 test!' });
  const params = { headers: { 'Content-Type': 'application/json' } };

  http.post(url, payload, params);
}