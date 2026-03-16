import http from 'k6/http';
import ws from 'k6/ws';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

// =========================
// 기본 설정
// =========================
const BASE_URL = 'https://planit-ai.store';
const WS_URL = 'wss://planit-ai.store/api/ws/chat';
const LOGIN_PATH = '/api/auth/login';

// =========================
// [직접 수정하기 쉬운 설정]
// =========================

// 실행 시간
const DURATION = __ENV.DURATION || '2m';

// 채팅방
const DEFAULT_TRIP_ID = Number(__ENV.TRIP_ID || 42);

// -------------------------
// [웹소켓 동접 수]
// -------------------------
const VUS = Number(__ENV.VUS || 20);

// -------------------------
// [일반 채팅 전송 간격]
// 1000 = 1초마다
// 500 = 0.5초마다
// -------------------------
const NORMAL_MESSAGE_INTERVAL_MS =
  Number(__ENV.NORMAL_MESSAGE_INTERVAL_MS || 1000);

// -------------------------
// [챗봇 요청 전송 간격]
// 5000 = 5초마다
// -------------------------
const BOT_MESSAGE_INTERVAL_MS =
  Number(__ENV.BOT_MESSAGE_INTERVAL_MS || 5000);

// -------------------------
// [웹소켓 유지 시간]
// -------------------------
const SOCKET_LIFETIME_MS =
  Number(__ENV.SOCKET_LIFETIME_MS || 60000);

// -------------------------
// [챗봇 메시지 내용]
// -------------------------
const BOT_MESSAGE_TEXT =
  __ENV.BOT_MESSAGE_TEXT || '@AI 1일차 일정 알려줘';

// -------------------------
// [일반 채팅 메시지 prefix]
// -------------------------
const NORMAL_MESSAGE_TEXT_PREFIX =
  __ENV.NORMAL_MESSAGE_TEXT_PREFIX || 'k6 normal chat';

// =========================
// 커스텀 메트릭
// =========================

const wsConnectSuccess = new Rate('ws_connect_success');
const stompConnectSuccess = new Rate('stomp_connect_success');

const normalChatSendCount = new Counter('normal_chat_send_count');
const botChatSendCount = new Counter('bot_chat_send_count');

const normalChatReceiveCount = new Counter('normal_chat_receive_count');
const botChatReceiveCount = new Counter('bot_chat_receive_count');

const stompErrorCount = new Counter('stomp_error_count');

const normalChatApproxLatency =
  new Trend('normal_chat_approx_latency', true);

const botChatApproxLatency =
  new Trend('bot_chat_approx_latency', true);

// =========================
// k6 옵션
// =========================
export const options = {

  scenarios: {

    chat_same_room: {

      executor: 'constant-vus',
      exec: 'chat_same_room_test',

      // -------------------------
      // [동접 사용자 수]
      // -------------------------
      vus: VUS,

      duration: DURATION,
      gracefulStop: '10s',
    },

  },

  thresholds: {

    // 연결 성공률
    ws_connect_success: ['rate > 0.95'],
    stomp_connect_success: ['rate > 0.95'],

    // 일반 채팅 응답시간 기준
    normal_chat_approx_latency: ['p(95) < 3000'],

    // 챗봇은 느려도 허용
    bot_chat_approx_latency: ['p(95) < 10000'],
  },

};

// =========================
// STOMP frame 생성
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
// =========================
export function setup() {

  const loginPayload = JSON.stringify({
    loginId: 'aritest123',
    password: 'Aritest123!',
  });

  const loginRes = http.post(
    `${BASE_URL}${LOGIN_PATH}`,
    loginPayload,
    { headers: { 'Content-Type': 'application/json' } }
  );

  const token = loginRes.json('accessToken');

  check(loginRes, {
    'login successful': (r) => r.status === 200 && !!token,
  });

  return { token };
}

// =========================
// 채팅 테스트
// =========================
function runChatTest(token, tripId) {

  const params = {
    headers: {
      Authorization: `Bearer ${token}`,
      Origin: 'https://planit-ai.store',
    },
  };

  const res = ws.connect(WS_URL, params, function (socket) {

    let stompConnected = false;
    let subscribed = false;

    let lastNormalSentAt = null;
    let lastBotSentAt = null;

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
            id: `sub-${__VU}-${__ITER}`,
            destination: `/topic/trips/${tripId}/chat`,
            ack: 'auto',
          })
        );

        subscribed = true;

        // =========================
        // 일반 채팅 루프
        // =========================
        socket.setInterval(() => {

          if (!stompConnected || !subscribed) return;

          const payload = JSON.stringify({

            content:
              `${NORMAL_MESSAGE_TEXT_PREFIX} | vu=${__VU} | ts=${Date.now()}`

          });

          lastNormalSentAt = Date.now();

          normalChatSendCount.add(1);

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

        }, NORMAL_MESSAGE_INTERVAL_MS);

        // =========================
        // 챗봇 요청 루프
        // =========================
        socket.setInterval(() => {

          if (!stompConnected || !subscribed) return;

          const payload = JSON.stringify({
            content: BOT_MESSAGE_TEXT,
          });

          lastBotSentAt = Date.now();

          botChatSendCount.add(1);

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

        }, BOT_MESSAGE_INTERVAL_MS);

      }

      else if (msg.startsWith('MESSAGE')) {

        const now = Date.now();

        const isBotMessage =
          msg.includes('@AI') ||
          msg.includes('AI') ||
          msg.includes('chatbot');

        if (isBotMessage) {

          botChatReceiveCount.add(1);

          if (lastBotSentAt)
            botChatApproxLatency.add(now - lastBotSentAt);

        }

        else {

          normalChatReceiveCount.add(1);

          if (lastNormalSentAt)
            normalChatApproxLatency.add(now - lastNormalSentAt);

        }

      }

      else if (msg.startsWith('ERROR')) {

        stompErrorCount.add(1);

      }

    });

    socket.setTimeout(() => {

      if (stompConnected)
        socket.send(stompFrame('DISCONNECT'));

      socket.close();

    }, SOCKET_LIFETIME_MS);

  });

  check(res, {
    'websocket handshake status is 101':
      (r) => r && r.status === 101,
  });

  sleep(1);
}

// =========================
// 실행 함수
// =========================
export function chat_same_room_test(data) {

  runChatTest(data.token, DEFAULT_TRIP_ID);

}