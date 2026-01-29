import http from 'k6/http';
import { check, sleep } from 'k6';

// --- 기본 설정 ---
const BASE_URL = 'https://planit-ai.store'; // 대상 서비스의 주소를 입력하세요.

// --- 테스트 옵션 ---
export const options = {
  // 테스트 성공/실패 기준
  thresholds: {
    // 메인페이지 조회
    'http_req_failed{scenario:stress_main_page}': ['rate < 0.01'],
    'http_req_duration{scenario:stress_main_page}': ['p(95) < 1000'],

    // 게시물 목록 조회
    'http_req_failed{scenario:stress_posts_list}': ['rate < 0.01'],
    'http_req_duration{scenario:stress_posts_list}': ['p(95) < 1000'],
  },

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
  },
};

//jwt token 세팅
export function setup() {
	const loginRes = http.post(`${BASE_URL}/api/auth/login`, {
		loginId:'test123',
		password: 'test123!'
	});
	
	const authToken = loginRes.json().accessToken;
	
	check(loginRes, {'login successful' : (r) => r.status === 200 && authToken});
	if(!authToken){
		throw new Error('Login failed, could not get auth token');
	}
	return {token: authToken};
}


// 1. 메인페이지 조회 테스트
export function main_page_test(data) {
	const params = {
		headers: {
			'Authorization': `Bearer ${data.token}`,
		},
	}
  const res = http.get(`${BASE_URL}/`, params);
  check(res, { 'status is 200': (r) => r.status === 200 })
}

// 2. 게시물 목록 조회 테스트
export function posts_list_test(data) {
	const params = {
		headers: {
			'Authorization': `Bearer ${data.token}`,
		},
	}
  const res = http.get(`${BASE_URL}/posts`, params);
  check(res, { 'status is 200': (r) => r.status === 200 });
}
