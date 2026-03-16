import http from 'k6/http';
import ws from 'k6/ws';
import exec from 'k6/execution';
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

const LOGIN_ID = __ENV.LOGIN_ID || 'aritest12345';
const LOGIN_PASSWORD = __ENV.LOGIN_PASSWORD || 'Aritest123!';

const TRIP_ID = Number(__ENV.TRIP_ID || 37);

// =========================
// 단계 설정
// =========================
// 기준 부하
const BASE_TOTAL_RPS = Number(__ENV.BASE_TOTAL_RPS || 212);
const BASE_TOTAL_CCU = Number(__ENV.BASE_TOTAL_CCU || 1700);

// 단계 배수
const LOAD_LEVELS = (__ENV.LOAD_LEVELS || '0.1,0.25,0.5,1,1.5,2,3,4,5,8,10')
  .split(',')
  .map((v) => Number(v.trim()))
  .filter((v) => v > 0);

// 단계 지속 시간 / 단계 간 간격
const STEP_DURATION = __ENV.STEP_DURATION || '2m';
const GAP_DURATION = __ENV.GAP_DURATION || '10s';

// =========================
// 비율
// =========================
const NORMAL_CHAT_RATIO = 0.40;
const BOT_CHAT_RATIO = 0.10;
const MAIN_PAGE_RATIO = 0.15;
const POSTS_LIST_RATIO = 0.30;
const CREATE_POST_RATIO = 0.05;

// =========================
// WS 설정
// =========================
const SOCKET_LIFETIME_MS = Number(__ENV.SOCKET_LIFETIME_MS || 60000);
const BOT_MESSAGE_TEXT = __ENV.BOT_MESSAGE_TEXT || '@AI 1일차 일정 알려줘';
const NORMAL_MESSAGE_TEXT_PREFIX =
  __ENV.NORMAL_MESSAGE_TEXT_PREFIX || 'k6 normal chat';

// 기준 전송량 기반 interval 계산에 사용할 base
const NORMAL_CHAT_BASE_RPS = Math.round(BASE_TOTAL_RPS * NORMAL_CHAT_RATIO);
const BOT_CHAT_BASE_RPS = Math.round(BASE_TOTAL_RPS * BOT_CHAT_RATIO);
const NORMAL_CHAT_BASE_VUS = Math.round(BASE_TOTAL_CCU * NORMAL_CHAT_RATIO);
const BOT_CHAT_BASE_VUS = Math.round(BASE_TOTAL_CCU * BOT_CHAT_RATIO);

// =========================
// 메트릭
// =========================
const loginSuccess = new Rate('login_success');

const wsConnectSuccess = new Rate('ws_connect_success');
const stompConnectSuccess = new Rate('stomp_connect_success');

const mainPageSuccess = new Rate('main_page_success');
const postsListSuccess = new Rate('posts_list_success');
const createPostSuccess = new Rate('create_post_success');

const normalChatSendCount = new Counter('normal_chat_send_count');
const botChatSendCount = new Counter('bot_chat_send_count');

const normalChatReceiveCount = new Counter('normal_chat_receive_count');
const botChatReceiveCount = new Counter('bot_chat_receive_count');

const stompErrorCount = new Counter('stomp_error_count');

const normalChatApproxLatency = new Trend('normal_chat_approx_latency', true);
const botChatApproxLatency = new Trend('bot_chat_approx_latency', true);

// =========================
// 유틸
// =========================
function parseDurationToSeconds(duration) {
  const trimmed = String(duration).trim();
  if (trimmed.endsWith('ms')) return Math.ceil(Number(trimmed.slice(0, -2)) / 1000);
  if (trimmed.endsWith('s')) return Number(trimmed.slice(0, -1));
  if (trimmed.endsWith('m')) return Number(trimmed.slice(0, -1)) * 60;
  if (trimmed.endsWith('h')) return Number(trimmed.slice(0, -1)) * 3600;
  throw new Error(`Unsupported duration format: ${duration}`);
}

function stompFrame(command, headers = {}, body = '') {
  let frame = `${command}\n`;
  for (const [key, value] of Object.entries(headers)) {
    frame += `${key}:${value}\n`;
  }
  frame += `\n${body}\u0000`;
  return frame;
}

function getScenarioName() {
  return exec.scenario.name;
}

function extractLevelFromScenarioName() {
  const match = getScenarioName().match(/level_([0-9_]+)/);
  return match ? match[1].replace(/_/g, '.') : '';
}

function levelToKey(level) {
  return String(level).replace(/\./g, '_');
}

function calcTotalRps(level) {
  return Math.max(1, Math.round(BASE_TOTAL_RPS * level));
}

function calcTotalCcu(level) {
  return Math.max(1, Math.round(BASE_TOTAL_CCU * level));
}

function calcSplit(level) {
  const totalRps = calcTotalRps(level);
  const totalCcu = calcTotalCcu(level);

  const normalChatRps = Math.round(totalRps * NORMAL_CHAT_RATIO);
  const botChatRps = Math.round(totalRps * BOT_CHAT_RATIO);
  const mainPageRps = Math.round(totalRps * MAIN_PAGE_RATIO);
  const postsListRps = Math.round(totalRps * POSTS_LIST_RATIO);
  const createPostRps = Math.max(
    1,
    totalRps -
      normalChatRps -
      botChatRps -
      mainPageRps -
      postsListRps
  );

  const normalChatVus = Math.max(1, Math.round(totalCcu * NORMAL_CHAT_RATIO));
  const botChatVus = Math.max(1, Math.round(totalCcu * BOT_CHAT_RATIO));
  const mainPageVus = Math.max(1, Math.round(totalCcu * MAIN_PAGE_RATIO));
  const postsListVus = Math.max(1, Math.round(totalCcu * POSTS_LIST_RATIO));
  const createPostVus = Math.max(
    1,
    totalCcu -
      normalChatVus -
      botChatVus -
      mainPageVus -
      postsListVus
  );

  return {
    totalRps,
    totalCcu,
    normalChatRps,
    botChatRps,
    mainPageRps,
    postsListRps,
    createPostRps,
    normalChatVus,
    botChatVus,
    mainPageVus,
    postsListVus,
    createPostVus,
  };
}

function calcWsIntervalMs(vus, targetRps) {
  return Math.max(1, Math.round((vus * 1000) / Math.max(1, targetRps)));
}

// =========================
// 단계별 scenario 생성
// =========================
function buildScenarios() {
  const scenarios = {};
  let startOffsetSec = 0;

  for (const level of LOAD_LEVELS) {
    const key = levelToKey(level);
    const split = calcSplit(level);

    scenarios[`normal_chat_ws_level_${key}`] = {
      executor: 'constant-vus',
      exec: 'normal_chat_ws_test',
      vus: split.normalChatVus,
      duration: STEP_DURATION,
      gracefulStop: '10s',
      startTime: `${startOffsetSec}s`,
      tags: {
        level: String(level),
        feature: 'normal_chat_ws',
      },
      env: {
        NORMAL_CHAT_INTERVAL_MS: String(
          calcWsIntervalMs(split.normalChatVus, split.normalChatRps)
        ),
      },
    };

    scenarios[`bot_chat_ws_level_${key}`] = {
      executor: 'constant-vus',
      exec: 'bot_chat_ws_test',
      vus: split.botChatVus,
      duration: STEP_DURATION,
      gracefulStop: '10s',
      startTime: `${startOffsetSec}s`,
      tags: {
        level: String(level),
        feature: 'bot_chat_ws',
      },
      env: {
        BOT_CHAT_INTERVAL_MS: String(
          calcWsIntervalMs(split.botChatVus, split.botChatRps)
        ),
      },
    };

    scenarios[`load_main_page_level_${key}`] = {
      executor: 'constant-arrival-rate',
      exec: 'main_page_test',
      rate: split.mainPageRps,
      timeUnit: '1s',
      duration: STEP_DURATION,
      startTime: `${startOffsetSec}s`,
      preAllocatedVUs: Math.max(20, split.mainPageVus),
      maxVUs: Math.max(split.mainPageVus * 2, split.mainPageVus + 50),
      tags: {
        level: String(level),
        feature: 'load_main_page',
      },
    };

    scenarios[`load_posts_list_level_${key}`] = {
      executor: 'constant-arrival-rate',
      exec: 'posts_list_test',
      rate: split.postsListRps,
      timeUnit: '1s',
      duration: STEP_DURATION,
      startTime: `${startOffsetSec}s`,
      preAllocatedVUs: Math.max(20, split.postsListVus),
      maxVUs: Math.max(split.postsListVus * 2, split.postsListVus + 50),
      tags: {
        level: String(level),
        feature: 'load_posts_list',
      },
    };

    scenarios[`create_free_post_level_${key}`] = {
      executor: 'constant-arrival-rate',
      exec: 'free_post_create_test',
      rate: split.createPostRps,
      timeUnit: '1s',
      duration: STEP_DURATION,
      startTime: `${startOffsetSec}s`,
      preAllocatedVUs: Math.max(10, split.createPostVus),
      maxVUs: Math.max(split.createPostVus * 2, split.createPostVus + 30),
      tags: {
        level: String(level),
        feature: 'create_free_post',
      },
    };

    startOffsetSec += parseDurationToSeconds(STEP_DURATION);
    startOffsetSec += parseDurationToSeconds(GAP_DURATION);
  }

  return scenarios;
}

// =========================
// 옵션
// =========================
export const options = {
  scenarios: buildScenarios(),
  summaryTrendStats: ['avg', 'min', 'med', 'max', 'p(90)', 'p(95)', 'p(99)'],
  thresholds: {
    login_success: ['rate > 0.99'],

    ws_connect_success: ['rate > 0.95'],
    stomp_connect_success: ['rate > 0.95'],

    main_page_success: ['rate > 0.99'],
    posts_list_success: ['rate > 0.99'],
    create_post_success: ['rate > 0.99'],

    'http_req_failed{feature:load_main_page}': ['rate < 0.01'],
    'http_req_duration{feature:load_main_page}': ['p(99) < 300'],

    'http_req_failed{feature:load_posts_list}': ['rate < 0.01'],
    'http_req_duration{feature:load_posts_list}': ['p(99) < 500'],

    'http_req_failed{feature:create_free_post}': ['rate < 0.01'],
    'http_req_duration{feature:create_free_post}': ['p(99) < 10000'],

    normal_chat_approx_latency: ['p(99) < 2000'],
    bot_chat_approx_latency: ['p(99) < 15000'],
  },
};

// =========================
// 로그인
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
  const success = loginRes.status === 200 && !!token;
  loginSuccess.add(success);

  check(loginRes, {
    'login successful': (r) => r.status === 200 && !!token,
  });

  return { token };
}

// =========================
// WebSocket 공통
// =========================
function runChatWs(token, tripId, mode) {
  const intervalMs =
    mode === 'bot'
      ? Number(__ENV.BOT_CHAT_INTERVAL_MS || 5000)
      : Number(__ENV.NORMAL_CHAT_INTERVAL_MS || 1000);

  const params = {
    headers: {
      Authorization: `Bearer ${token}`,
      Origin: BASE_URL,
    },
    tags: {
      feature: mode === 'bot' ? 'bot_chat_ws' : 'normal_chat_ws',
      level: extractLevelFromScenarioName(),
    },
  };

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
// 시나리오 함수
// =========================
export function normal_chat_ws_test(data) {
  runChatWs(data.token, TRIP_ID, 'normal');
}

export function bot_chat_ws_test(data) {
  runChatWs(data.token, TRIP_ID, 'bot');
}

export function main_page_test(data) {
  const res = http.get(`${BASE_URL}/`, {
    headers: {
      Authorization: `Bearer ${data.token}`,
    },
    tags: {
      feature: 'load_main_page',
      level: extractLevelFromScenarioName(),
    },
    timeout: '60s',
  });

  const success = res.status === 200;
  mainPageSuccess.add(success);

  check(res, {
    'main page status is 200': (r) => r.status === 200,
  });
}

export function posts_list_test(data) {
  const boardType = encodeURIComponent('자유 게시판');
  const url = `${BASE_URL}${POSTS_LIST_PATH}?boardType=${boardType}&sort=latest&page=1&size=10`;

  const res = http.get(url, {
    headers: {
      Accept: 'application/json, text/plain, */*',
      Authorization: `Bearer ${data.token}`,
    },
    tags: {
      feature: 'load_posts_list',
      level: extractLevelFromScenarioName(),
    },
    timeout: '60s',
  });

  const success = res.status === 200;
  postsListSuccess.add(success);

  check(res, {
    'posts list status is 200': (r) => r.status === 200,
  });
}

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
    tags: {
      feature: 'create_free_post',
      level: extractLevelFromScenarioName(),
    },
    timeout: '60s',
  });

  const success = res.status === 200 || res.status === 201;
  createPostSuccess.add(success);

  check(res, {
    'create post status is 200/201': (r) => r.status === 200 || r.status === 201,
  });

  return res;
}