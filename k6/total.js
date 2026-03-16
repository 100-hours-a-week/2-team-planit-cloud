import http from 'k6/http';
import ws from 'k6/ws';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

// =========================
// 기본 설정
// =========================
const BASE_URL = __ENV.BASE_URL || 'https://planit-ai.store';
const WS_URL = __ENV.WS_URL || 'wss://planit-ai.store/api/ws/chat';
const LOGIN_PATH = __ENV.LOGIN_PATH || '/api/auth/login';
const POSTS_LIST_PATH = __ENV.POSTS_LIST_PATH || '/api/posts';
const CREATE_POST_PATH = __ENV.CREATE_POST_PATH || '/api/posts';

// =========================
// 로그인 계정 설정
// 하나의 계정만 로그인해서 모든 시나리오에서 공통 사용
// =========================
const LOGIN_ID = __ENV.LOGIN_ID || 'aritest12345';
const LOGIN_PASSWORD = __ENV.LOGIN_PASSWORD || 'Aritest123!';

// =========================
// 테스트 공통 설정
// =========================
const DURATION = __ENV.DURATION || '2m';
const TRIP_ID = Number(__ENV.TRIP_ID || 37);

// =========================
// 목표 트래픽 분배
// 총 RPS = 212
// =========================
const TOTAL_RPS = Number(__ENV.TOTAL_RPS || 212);

// 비율
const NORMAL_CHAT_RATIO = 0.40; // 일반 채팅
const BOT_CHAT_RATIO = 0.10;    // 챗봇 채팅
const MAIN_PAGE_RATIO = 0.15;   // 메인페이지 조회
const POSTS_LIST_RATIO = 0.30;  // 게시물 리스트 조회
const CREATE_POST_RATIO = 0.05; // 게시물 작성

// 목표 RPS
const NORMAL_CHAT_RPS = Math.round(TOTAL_RPS * NORMAL_CHAT_RATIO);
const BOT_CHAT_RPS = Math.round(TOTAL_RPS * BOT_CHAT_RATIO);
const MAIN_PAGE_RPS = Math.round(TOTAL_RPS * MAIN_PAGE_RATIO);
const POSTS_LIST_RPS = Math.round(TOTAL_RPS * POSTS_LIST_RATIO);
const CREATE_POST_RPS = Math.round(TOTAL_RPS * CREATE_POST_RATIO);

// =========================
// CCU 분배
// 총 CCU = 1700
// WebSocket은 실제 연결 수에 가깝고,
// HTTP는 arrival-rate를 위한 worker pool 크기 역할
// =========================
const TOTAL_CCU = Number(__ENV.TOTAL_CCU || 1700);

const NORMAL_CHAT_VUS = Number(
  __ENV.NORMAL_CHAT_VUS || Math.round(TOTAL_CCU * NORMAL_CHAT_RATIO)
);
const BOT_CHAT_VUS = Number(
  __ENV.BOT_CHAT_VUS || Math.round(TOTAL_CCU * BOT_CHAT_RATIO)
);
const MAIN_PAGE_VUS = Number(
  __ENV.MAIN_PAGE_VUS || Math.round(TOTAL_CCU * MAIN_PAGE_RATIO)
);
const POSTS_LIST_VUS = Number(
  __ENV.POSTS_LIST_VUS || Math.round(TOTAL_CCU * POSTS_LIST_RATIO)
);
const CREATE_POST_VUS = Number(
  __ENV.CREATE_POST_VUS || Math.round(TOTAL_CCU * CREATE_POST_RATIO)
);

// =========================
// WebSocket 전송 간격
// RPS = VUS * (1000 / interval_ms)
// interval_ms = VUS * 1000 / RPS
// 필요하면 ENV로 직접 덮어쓰기 가능
// =========================
const NORMAL_CHAT_INTERVAL_MS = Number(
  __ENV.NORMAL_CHAT_INTERVAL_MS ||
    Math.max(1, Math.round((NORMAL_CHAT_VUS * 1000) / NORMAL_CHAT_RPS))
);

const BOT_CHAT_INTERVAL_MS = Number(
  __ENV.BOT_CHAT_INTERVAL_MS ||
    Math.max(1, Math.round((BOT_CHAT_VUS * 1000) / BOT_CHAT_RPS))
);

const SOCKET_LIFETIME_MS = Number(__ENV.SOCKET_LIFETIME_MS || 60000);

// =========================
// 메시지 내용
// =========================
const BOT_MESSAGE_TEXT =
  __ENV.BOT_MESSAGE_TEXT || '@AI 1일차 일정 알려줘';

const NORMAL_MESSAGE_TEXT_PREFIX =
  __ENV.NORMAL_MESSAGE_TEXT_PREFIX || 'k6 normal chat';

// =========================
// 메트릭
// =========================
const wsConnectSuccess = new Rate('ws_connect_success');
const stompConnectSuccess = new Rate('stomp_connect_success');

const normalChatSendCount = new Counter('normal_chat_send_count');
const botChatSendCount = new Counter('bot_chat_send_count');

const normalChatReceiveCount = new Counter('normal_chat_receive_count');
const botChatReceiveCount = new Counter('bot_chat_receive_count');

const stompErrorCount = new Counter('stomp_error_count');

const normalChatApproxLatency = new Trend('normal_chat_approx_latency', true);
const botChatApproxLatency = new Trend('bot_chat_approx_latency', true);

// =========================
// 옵션
// =========================
export const options = {
  scenarios: {
    // 1. 일반 채팅
    normal_chat_ws: {
      executor: 'constant-vus',
      exec: 'normal_chat_ws_test',
      vus: NORMAL_CHAT_VUS,
      duration: DURATION,
      gracefulStop: '10s',
    },

    // 2. 챗봇 채팅
    bot_chat_ws: {
      executor: 'constant-vus',
      exec: 'bot_chat_ws_test',
      vus: BOT_CHAT_VUS,
      duration: DURATION,
      gracefulStop: '10s',
    },

    // 3. 메인페이지 조회
    load_main_page: {
      executor: 'constant-arrival-rate',
      exec: 'main_page_test',
      rate: MAIN_PAGE_RPS,
      timeUnit: '1s',
      duration: DURATION,
      preAllocatedVUs: MAIN_PAGE_VUS,
      maxVUs: Math.max(MAIN_PAGE_VUS, MAIN_PAGE_VUS * 2),
    },

    // 4. 게시물 리스트 조회
    load_posts_list: {
      executor: 'constant-arrival-rate',
      exec: 'posts_list_test',
      rate: POSTS_LIST_RPS,
      timeUnit: '1s',
      duration: DURATION,
      preAllocatedVUs: POSTS_LIST_VUS,
      maxVUs: Math.max(POSTS_LIST_VUS, POSTS_LIST_VUS * 2),
    },

    // 5. 게시물 작성
    create_free_post: {
      executor: 'constant-arrival-rate',
      exec: 'free_post_create_test',
      rate: CREATE_POST_RPS,
      timeUnit: '1s',
      duration: DURATION,
      preAllocatedVUs: CREATE_POST_VUS,
      maxVUs: Math.max(CREATE_POST_VUS, CREATE_POST_VUS * 2),
    },
  },

  thresholds: {
    ws_connect_success: ['rate > 0.95'],
    stomp_connect_success: ['rate > 0.95'],

    normal_chat_approx_latency: ['p(99) < 200'],
    bot_chat_approx_latency: ['p(99) < 15000'],

    'http_req_failed{scenario:load_main_page}': ['rate < 0.01'],
    'http_req_duration{scenario:load_main_page}': ['p(99) < 300'],

    'http_req_failed{scenario:load_posts_list}': ['rate < 0.01'],
    'http_req_duration{scenario:load_posts_list}': ['p(99) < 500'],

    'http_req_failed{scenario:create_free_post}': ['rate < 0.001'],
    'http_req_duration{scenario:create_free_post}': ['p(99) < 10000'],
  },
};

// =========================
// 유틸
// =========================
function stompFrame(command, headers = {}, body = '') {
  let frame = `${command}\n`;
  for (const [key, value] of Object.entries(headers)) {
    frame += `${key}:${value}\n`;
  }
  frame += `\n${body}\u0000`;
  return frame;
}

// =========================
// 로그인
// 하나의 계정만 사용
// =========================
export function setup() {
  const loginPayload = JSON.stringify({
    loginId: LOGIN_ID,
    password: LOGIN_PASSWORD,
  });

  const loginRes = http.post(`${BASE_URL}${LOGIN_PATH}`, loginPayload, {
    headers: { 'Content-Type': 'application/json' },
    timeout: '60s',
  });

  const token = loginRes.json('accessToken');

  check(loginRes, {
    'login successful': (r) => r.status === 200 && !!token,
  });

  return { token };
}

// =========================
// WebSocket 공통
// mode: normal | bot
// =========================
function runChatWs(token, tripId, mode) {
  const params = {
    headers: {
      Authorization: `Bearer ${token}`,
      Origin: BASE_URL,
    },
  };

  const intervalMs =
    mode === 'bot' ? BOT_CHAT_INTERVAL_MS : NORMAL_CHAT_INTERVAL_MS;

  const res = ws.connect(WS_URL, params, function (socket) {
    let stompConnected = false;
    let subscribed = false;
    let lastSentAt = null;

    socket.on('open', () => {
      wsConnectSuccess.add(true);

      socket.send(
        stompFrame('CONNECT', {
          'accept-version': '1.2',
          'heart-beat': '10000,10000',
          Authorization: `Bearer ${token}`,
        })
      );
    });

    socket.on('message', (msg) => {
      if (typeof msg !== 'string') return;

      if (msg.startsWith('CONNECTED')) {
        stompConnected = true;
        stompConnectSuccess.add(true);

        socket.send(
          stompFrame('SUBSCRIBE', {
            id: `sub-${mode}-${__VU}-${__ITER}`,
            destination: `/topic/trips/${tripId}/chat`,
            ack: 'auto',
          })
        );

        subscribed = true;

        socket.setInterval(() => {
          if (!stompConnected || !subscribed) return;

          const content =
            mode === 'bot'
              ? BOT_MESSAGE_TEXT
              : `${NORMAL_MESSAGE_TEXT_PREFIX} | vu=${__VU} | ts=${Date.now()}`;

          const payload = JSON.stringify({ content });
          lastSentAt = Date.now();

          if (mode === 'bot') {
            botChatSendCount.add(1);
          } else {
            normalChatSendCount.add(1);
          }

          socket.send(
            stompFrame(
              'SEND',
              {
                destination: `/app/trips/${tripId}/chat.send`,
                'content-type': 'application/json',
              },
              payload
            )
          );
        }, intervalMs);
      } else if (msg.startsWith('MESSAGE')) {
        const now = Date.now();

        if (mode === 'bot') {
          botChatReceiveCount.add(1);
          if (lastSentAt) botChatApproxLatency.add(now - lastSentAt);
        } else {
          normalChatReceiveCount.add(1);
          if (lastSentAt) normalChatApproxLatency.add(now - lastSentAt);
        }
      } else if (msg.startsWith('ERROR')) {
        stompErrorCount.add(1);
      }
    });

    socket.on('error', () => {
      wsConnectSuccess.add(false);
      stompConnectSuccess.add(false);
    });

    socket.setTimeout(() => {
      if (stompConnected) {
        socket.send(stompFrame('DISCONNECT'));
      }
      socket.close();
    }, SOCKET_LIFETIME_MS);
  });

  check(res, {
    'websocket handshake status is 101': (r) => r && r.status === 101,
  });

  sleep(1);
}

// =========================
// 1. 일반 채팅
// =========================
export function normal_chat_ws_test(data) {
  runChatWs(data.token, TRIP_ID, 'normal');
}

// =========================
// 2. 챗봇 채팅
// =========================
export function bot_chat_ws_test(data) {
  runChatWs(data.token, TRIP_ID, 'bot');
}

// =========================
// 3. 메인페이지 조회
// =========================
export function main_page_test(data) {
  const res = http.get(`${BASE_URL}/`, {
    headers: {
      Authorization: `Bearer ${data.token}`,
    },
    timeout: '60s',
  });

  check(res, {
    'main page status is 200': (r) => r.status === 200,
  });
}

// =========================
// 4. 게시물 리스트 조회
// =========================
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

  check(res, {
    'posts list status is 200': (r) => r.status === 200,
  });
}

// =========================
// 5. 게시물 작성
// =========================
export function free_post_create_test(data) {
  const title = `k6-${__VU}-${Date.now()}-${__ITER}`.slice(0, 24);
  const content = `content from k6 vu=${__VU} iter=${__ITER}`.slice(0, 2000);

  const body = JSON.stringify({
    boardType: 'FREE',
    title,
    content,
    imageKeys: [],
  });

  const res = http.post(`${BASE_URL}${CREATE_POST_PATH}`, body, {
    headers: {
      Authorization: `Bearer ${data.token}`,
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    timeout: '60s',
  });

  check(res, {
    'create post status is 200/201': (r) => r.status === 200 || r.status === 201,
  });

  return res;
}