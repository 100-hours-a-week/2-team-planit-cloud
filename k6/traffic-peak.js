/**
 * 트래픽 피크: 완만한 램프업 → 목표 VU를 오래 유지 → 램프다운.
 * env: PEAK_WARM, PEAK_WARM_VUS, PEAK_RAMP_UP, PEAK_TARGET_VUS, PEAK_HOLD, PEAK_RAMP_DOWN, GRACEFUL_RAMP_DOWN
 * 공통 env는 traffic-lib.js와 동일(BACKEND_URL, API_PREFIX, …).
 */
import trafficIteration, { setup, handleSummary, thresholds } from './traffic-lib.js';

export { setup, handleSummary };

const PEAK_WARM = __ENV.PEAK_WARM || '3m';
const PEAK_WARM_VUS = Number(__ENV.PEAK_WARM_VUS || 30);
const PEAK_RAMP_UP = __ENV.PEAK_RAMP_UP || '7m';
const PEAK_TARGET_VUS = Number(__ENV.PEAK_TARGET_VUS || 500);
const PEAK_HOLD = __ENV.PEAK_HOLD || '15m';
const PEAK_RAMP_DOWN = __ENV.PEAK_RAMP_DOWN || '5m';
const GRACEFUL_RAMP_DOWN = __ENV.GRACEFUL_RAMP_DOWN || '5m';

export const options = {
  scenarios: {
    traffic_peak: {
      executor: 'ramping-vus',
      startVUs: 0,
      gracefulRampDown: GRACEFUL_RAMP_DOWN,
      stages: [
        { duration: PEAK_WARM, target: PEAK_WARM_VUS },
        { duration: PEAK_RAMP_UP, target: PEAK_TARGET_VUS },
        { duration: PEAK_HOLD, target: PEAK_TARGET_VUS },
        { duration: PEAK_RAMP_DOWN, target: 0 },
      ],
    },
  },
  thresholds,
};

export default trafficIteration;
