/** 공통: traffic-peak.js / traffic-spike.js에서 import. env는 각 엔트리 주석 참고 */

import http from 'k6/http';
import ws from 'k6/ws';
import { check, sleep } from 'k6';
import { SharedArray } from 'k6/data';
import { randomIntBetween } from 'https://jslib.k6.io/k6-utils/1.2.0/index.js';
import { textSummary } from 'https://jslib.k6.io/k6-summary/0.0.2/index.js';

let BACKEND_ORIGIN = (__ENV.BACKEND_URL || 'https://dijh9mhj7vomy.cloudfront.net').replace(/\/$/, '');
let API_PREFIX;
if (__ENV.API_PREFIX !== undefined) {
  API_PREFIX = String(__ENV.API_PREFIX).replace(/\/$/, '');
} else if (BACKEND_ORIGIN.endsWith('/api')) {
  BACKEND_ORIGIN = BACKEND_ORIGIN.replace(/\/api$/, '');
  API_PREFIX = '/api';
} else {
  API_PREFIX = '';
}

function hostnameFromTrafficUrl(raw) {
  const s = String(raw || '').trim();
  if (!s) {
    return '';
  }
  const m =
    s.match(/^https:\/\/([^/?#]+)/i) ||
    s.match(/^http:\/\/([^/?#]+)/i) ||
    s.match(/^wss:\/\/([^/?#]+)/i) ||
    s.match(/^ws:\/\/([^/?#]+)/i);
  return m ? m[1].toLowerCase() : '';
}

function assertAllowedTrafficHost(label, baseUrl) {
  const raw = String(baseUrl || '').trim();
  if (!raw) {
    return;
  }
  if (__ENV.ALLOW_DIRECT_ORIGIN === 'true') {
    return;
  }
  const hostname = hostnameFromTrafficUrl(raw);
  if (!hostname) {
    throw new Error(`${label}: URL에서 호스트를 읽을 수 없습니다 (${raw})`);
  }
  if (hostname === 'planit-ai.store' || hostname.endsWith('.planit-ai.store')) {
    throw new Error(
      `${label}: 운영 직접 도메인(planit-ai.store)으로는 부하를 보낼 수 없습니다. CloudFront URL을 사용하세요.`,
    );
  }
  const okCf = hostname.endsWith('.cloudfront.net');
  const okLocal = hostname === 'localhost' || hostname === '127.0.0.1';
  if (!okCf && !okLocal) {
    throw new Error(
      `${label}: 허용 호스트는 *.cloudfront.net 또는 localhost/127.0.0.1 뿐입니다 (현재: ${hostname}). 우회: ALLOW_DIRECT_ORIGIN=true`,
    );
  }
}

function apiUrl(path) {
  const seg = String(path).replace(/^\//, '');
  if (API_PREFIX) {
    return `${BACKEND_ORIGIN}${API_PREFIX}/${seg}`;
  }
  return `${BACKEND_ORIGIN}/${seg}`;
}

function deriveChatWebSocketUrl() {
  if (!BACKEND_ORIGIN) {
    return '';
  }
  const wsOrigin = BACKEND_ORIGIN.replace(/^https:\/\//i, 'wss://').replace(/^http:\/\//i, 'ws://');
  const prefix = API_PREFIX ? (API_PREFIX.startsWith('/') ? API_PREFIX : `/${API_PREFIX}`) : '';
  return `${wsOrigin}${prefix}/ws/chat`;
}

const RUNPOD_POD_ID = (__ENV.RUNPOD_POD_ID || '').trim();
const AI_URL_EXPLICIT =
  (__ENV.AI_URL || '').replace(/\/$/, '') ||
  (RUNPOD_POD_ID ? `https://${RUNPOD_POD_ID}-8000.proxy.runpod.net` : '');

const CHAT_WS_URL_ENV = (__ENV.CHAT_WS_URL || '').trim();
const CHAT_WS_URL = CHAT_WS_URL_ENV || deriveChatWebSocketUrl();

assertAllowedTrafficHost('BACKEND_URL', BACKEND_ORIGIN);
if (AI_URL_EXPLICIT) {
  assertAllowedTrafficHost('AI_URL', AI_URL_EXPLICIT);
}
if (CHAT_WS_URL) {
  assertAllowedTrafficHost('CHAT_WS_URL', CHAT_WS_URL);
}

const AI_PATH_V1_PREFIX = '/api/v1';

function aiFastapiUrl(pathAfterV1) {
  if (!AI_URL_EXPLICIT) {
    return '';
  }
  const rest = String(pathAfterV1 || '').replace(/^\//, '');
  return `${AI_URL_EXPLICIT}${AI_PATH_V1_PREFIX}/${rest}`;
}

function aiHealthProbeUrl() {
  if (AI_URL_EXPLICIT) {
    return `${AI_URL_EXPLICIT}/health`;
  }
  return apiUrl('health');
}
const JWT_TOKEN_ENV = __ENV.JWT_TOKEN || '';
const AUTH_LOGIN_ID =
  __ENV.AUTH_LOGIN_ID !== undefined ? String(__ENV.AUTH_LOGIN_ID) : 'aritest12345';
const AUTH_PASSWORD =
  __ENV.AUTH_PASSWORD !== undefined ? String(__ENV.AUTH_PASSWORD) : 'Aritest123!';
const TRIP_ID = __ENV.TRIP_ID || '37';

const accountRows = new SharedArray('parsed_accounts', function parseAccountsFile() {
  const path = __ENV.K6_ACCOUNTS_CSV || '';
  if (!path) {
    return [];
  }
  const text = open(path);
  const lines = text.trim().split('\n').filter(function (l) {
    return l.length > 0;
  });
  if (lines.length < 2) {
    return [];
  }
  const out = [];
  for (let i = 1; i < lines.length; i += 1) {
    const line = lines[i];
    const comma = line.indexOf(',');
    if (comma < 0) {
      continue;
    }
    out.push({
      loginId: line.slice(0, comma).trim(),
      password: line.slice(comma + 1).trim(),
    });
  }
  return out;
});

const WEIGHT_BACKEND = Number(__ENV.WEIGHT_BACKEND || 50);
const WEIGHT_AI = Number(__ENV.WEIGHT_AI || 30);
const WEIGHT_CHAT = Number(__ENV.WEIGHT_CHAT || 20);
const WEIGHT_TOTAL = WEIGHT_BACKEND + WEIGHT_AI + WEIGHT_CHAT;

const AI_LOAD_PROFILE = (__ENV.AI_LOAD_PROFILE || 'light').toLowerCase();
const AI_HTTP_TIMEOUT = __ENV.AI_HTTP_TIMEOUT || '660s';

const CHAT_WS_HOLD_MS = Number(__ENV.CHAT_WS_HOLD_MS || 60000);
const CHAT_HTTP_PATH = __ENV.CHAT_HTTP_PATH || `trips/${TRIP_ID}/chat/messages`;
const THINK_TIME_SEC = Number(__ENV.THINK_TIME_SEC || 1);
const POST_WRITE_PROB = Number(__ENV.POST_WRITE_PROB || 0.12);
const CHAT_STOMP = (__ENV.CHAT_STOMP || 'true').toLowerCase() !== 'false';

const jsonHeaders = { 'Content-Type': 'application/json' };

function authHeaders(token) {
  return token
    ? { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }
    : jsonHeaders;
}

function loginRequest(loginId, password) {
  const res = http.post(apiUrl('auth/login'), JSON.stringify({ loginId, password }), {
    headers: jsonHeaders,
    tags: { service: 'auth' },
  });
  check(res, { 'auth login 200': (r) => r.status === 200 });
  if (res.status !== 200) {
    return '';
  }
  const body = res.json();
  return body.accessToken || body.access_token || '';
}

export function setup() {
  if (JWT_TOKEN_ENV) {
    return { token: JWT_TOKEN_ENV };
  }
  if (AUTH_LOGIN_ID && AUTH_PASSWORD && BACKEND_ORIGIN) {
    const token = loginRequest(AUTH_LOGIN_ID, AUTH_PASSWORD);
    return { token };
  }
  return { token: '' };
}

function stompConnectFrame(token) {
  let headers = 'accept-version:1.2\nheart-beat:10000,10000';
  if (token) {
    headers += `\nAuthorization:Bearer ${token}`;
  }
  return `CONNECT\n${headers}\n\n\x00`;
}

let vuTokenCache = '';

function resolveAccessToken(data) {
  if (JWT_TOKEN_ENV) {
    return JWT_TOKEN_ENV;
  }
  if (data && data.token) {
    return data.token;
  }
  if (accountRows.length > 0) {
    if (!vuTokenCache) {
      const row = accountRows[(__VU - 1) % accountRows.length];
      vuTokenCache = loginRequest(row.loginId, row.password);
    }
    return vuTokenCache;
  }
  return '';
}

const itineraryDummyBody = JSON.stringify({
  tripId: randomIntBetween(1, 999999),
  arrivalDate: '2026-06-01',
  arrivalTime: '10:00',
  departureDate: '2026-06-05',
  departureTime: '18:00',
  travelCity: '오사카',
  totalBudget: 500000,
  travelTheme: ['맛집', '관광'],
  wantedPlace: ['도톤보리'],
});

function chatbotBody(tripId, token) {
  return JSON.stringify({
    tripId: Number(tripId),
    content: 'k6 부하테스트 메시지',
    userJWT: token || '',
  });
}

export const thresholds = {
  'http_req_failed{slo:posts_list}': ['rate<0.01'],
  'http_req_failed{slo:main}': ['rate<0.01'],
  'http_req_failed{slo:posts_write}': ['rate<0.01'],
  'http_req_duration{slo:chat_message}': ['p(99)<2000'],
  'http_req_duration{slo:chat_bot}': ['p(99)<15000'],
  'checks{check:ws_connect_ok}': ['rate>0.95'],
  'checks{check:stomp_handshake_ok}': ['rate>0.95'],
};

function hitBackend(token) {
  if (!BACKEND_ORIGIN) {
    return;
  }
  const health = http.get(apiUrl('health'), { tags: { service: 'backend' } });
  check(health, { 'backend health 2xx': (r) => r.status >= 200 && r.status < 300 });

  const posts = http.get(
    `${apiUrl('posts')}?page=0&size=20&boardType=FREE&sort=created_at,desc`,
    { tags: { service: 'backend', slo: 'posts_list' } },
  );
  check(posts, { 'backend posts list 2xx': (r) => r.status >= 200 && r.status < 300 });

  const mainPosts = http.get(
    `${apiUrl('posts')}?page=0&size=3&boardType=FREE&sort=created_at,desc`,
    { tags: { service: 'backend', slo: 'main' } },
  );
  check(mainPosts, { 'backend main posts 2xx': (r) => r.status >= 200 && r.status < 300 });

  if (token && TRIP_ID) {
    const itineraries = http.get(apiUrl(`trips/${TRIP_ID}/itineraries`), {
      headers: authHeaders(token),
      tags: { service: 'backend', slo: 'trip_itineraries' },
    });
    check(itineraries, {
      'backend trips itineraries 2xx/404': (r) =>
        (r.status >= 200 && r.status < 300) || r.status === 404,
    });

    const job = http.get(apiUrl(`trips/${TRIP_ID}/itinerary-job`), {
      headers: authHeaders(token),
      tags: { service: 'backend' },
    });
    check(job, {
      'backend itinerary-job 2xx/404': (r) =>
        (r.status >= 200 && r.status < 300) || r.status === 404,
    });
  }

  if (token && Math.random() < POST_WRITE_PROB) {
    const title = `k6-${__VU}-${Date.now()}`.slice(0, 24);
    const createBody = JSON.stringify({
      title,
      content: 'k6 부하테스트 본문입니다. 최소 길이를 충족합니다.',
      boardType: 'FREE',
      imageKeys: [],
    });
    const created = http.post(apiUrl('posts'), createBody, {
      headers: authHeaders(token),
      tags: { service: 'backend', slo: 'posts_write' },
    });
    check(created, { 'backend post create 2xx': (r) => r.status >= 200 && r.status < 300 });
  }
}

function hitAi(token) {
  if (!BACKEND_ORIGIN && !AI_URL_EXPLICIT) {
    return;
  }
  if (AI_LOAD_PROFILE === 'light') {
    const url = aiHealthProbeUrl();
    const res = http.get(url, { tags: { service: 'ai' } });
    check(res, { 'ai health 2xx': (r) => r.status >= 200 && r.status < 300 });
    return;
  }
  if (!AI_URL_EXPLICIT) {
    return;
  }
  if (AI_LOAD_PROFILE === 'medium') {
    const res = http.post(aiFastapiUrl('itinerary/gen_dummy_redis'), itineraryDummyBody, {
      headers: authHeaders(token),
      tags: { service: 'ai' },
    });
    check(res, { 'ai gen_dummy_redis 2xx': (r) => r.status >= 200 && r.status < 300 });
    return;
  }
  if (AI_LOAD_PROFILE === 'heavy') {
    const res = http.post(aiFastapiUrl('itinerary/gen_dummy'), itineraryDummyBody, {
      headers: authHeaders(token),
      tags: { service: 'ai' },
      timeout: '120s',
    });
    check(res, { 'ai gen_dummy 2xx': (r) => r.status >= 200 && r.status < 300 });
    return;
  }
  if (AI_LOAD_PROFILE === 'production') {
    const res = http.post(aiFastapiUrl('itinerary'), itineraryDummyBody, {
      headers: authHeaders(token),
      tags: { service: 'ai' },
      timeout: AI_HTTP_TIMEOUT,
    });
    check(res, { 'ai itinerary 2xx': (r) => r.status >= 200 && r.status < 300 });
    return;
  }
  if (AI_LOAD_PROFILE === 'chatbot') {
    if (!token) {
      return;
    }
    const res = http.post(aiFastapiUrl('chatbot'), chatbotBody(TRIP_ID, token), {
      headers: authHeaders(token),
      tags: { service: 'ai', slo: 'chat_bot' },
      timeout: AI_HTTP_TIMEOUT,
    });
    check(res, { 'ai chatbot 2xx': (r) => r.status >= 200 && r.status < 300 });
    return;
  }
  const res = http.get(aiHealthProbeUrl(), { tags: { service: 'ai' } });
  check(res, { 'ai health fallback 2xx': (r) => r.status >= 200 && r.status < 300 });
}

function hitChat(token, ctx) {
  if (CHAT_WS_URL) {
    ctx.wsAttempted = true;
    let stompOk = !CHAT_STOMP;
    const res = ws.connect(CHAT_WS_URL, {}, (socket) => {
      socket.on('open', () => {
        if (CHAT_STOMP) {
          socket.send(stompConnectFrame(token));
        }
        if (__ENV.CHAT_WS_OPEN_PAYLOAD) {
          socket.send(__ENV.CHAT_WS_OPEN_PAYLOAD);
        }
      });
      socket.on('message', (msg) => {
        if (CHAT_STOMP && String(msg).indexOf('CONNECTED') >= 0) {
          stompOk = true;
        }
      });
      socket.on('error', (e) => {
        if (__ENV.K6_DEBUG) {
          console.error('ws error', e);
        }
      });
      socket.setTimeout(() => {
        if (CHAT_STOMP) {
          check(stompOk, { stomp_handshake_ok: (v) => v === true });
        } else {
          check(true, { stomp_handshake_ok: () => true });
        }
        socket.close();
      }, CHAT_WS_HOLD_MS);
    });
    check(res, { ws_connect_ok: (r) => r && r.status === 101 });
    return;
  }

  if (token && BACKEND_ORIGIN) {
    const rel = CHAT_HTTP_PATH.replace(/^\//, '');
    const url = apiUrl(rel);
    const res = http.get(url, {
      headers: authHeaders(token),
      tags: { service: 'chat', slo: 'chat_message' },
    });
    check(res, { 'chat messages 2xx': (r) => r.status >= 200 && r.status < 300 });
    return;
  }

  if (BACKEND_ORIGIN) {
    http.get(apiUrl('health'), { tags: { service: 'chat' } });
  }
}

export default function trafficIteration(data) {
  if (!BACKEND_ORIGIN && !AI_URL_EXPLICIT && !CHAT_WS_URL) {
    throw new Error('BACKEND_URL 등 최소 한 오리진이 필요합니다.');
  }

  const token = resolveAccessToken(data);

  const ctx = { wsAttempted: false };
  const roll = Math.random() * WEIGHT_TOTAL;
  if (roll < WEIGHT_BACKEND) {
    hitBackend(token);
  } else if (roll < WEIGHT_BACKEND + WEIGHT_AI) {
    hitAi(token);
  } else {
    hitChat(token, ctx);
  }

  if (!ctx.wsAttempted) {
    check(true, { ws_connect_ok: () => true });
    check(true, { stomp_handshake_ok: () => true });
  }

  sleep(THINK_TIME_SEC);
}

export function handleSummary(data) {
  return {
    stdout: textSummary(data, {
      indent: ' ',
      enableColors: false,
      summaryTrendStats: ['avg', 'min', 'med', 'max', 'p(90)', 'p(95)', 'p(99)'],
    }),
  };
}
