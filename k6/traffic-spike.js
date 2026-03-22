/**
 * 트래픽 스파이크: 낮은 베이스라인 → 짧은 시간에 급상승 → 짧게 유지 → 하강 → 종료.
 * env: SPIKE_BASELINE, SPIKE_BASELINE_VUS, SPIKE_RAMP_UP, SPIKE_TARGET_VUS, SPIKE_PEAK_HOLD,
 *       SPIKE_RAMP_DOWN, SPIKE_COOLDOWN, GRACEFUL_RAMP_DOWN
 * 공통 env는 traffic-lib.js와 동일.
 */
import trafficIteration, { setup, handleSummary, thresholds } from './traffic-lib.js';

export { setup, handleSummary };

const SPIKE_BASELINE = __ENV.SPIKE_BASELINE || '2m';
const SPIKE_BASELINE_VUS = Number(__ENV.SPIKE_BASELINE_VUS || 20);
const SPIKE_RAMP_UP = __ENV.SPIKE_RAMP_UP || '45s';
const SPIKE_TARGET_VUS = Number(__ENV.SPIKE_TARGET_VUS || 800);
const SPIKE_PEAK_HOLD = __ENV.SPIKE_PEAK_HOLD || '2m';
const SPIKE_RAMP_DOWN = __ENV.SPIKE_RAMP_DOWN || '3m';
const SPIKE_COOLDOWN = __ENV.SPIKE_COOLDOWN || '2m';
const GRACEFUL_RAMP_DOWN = __ENV.GRACEFUL_RAMP_DOWN || '5m';

export const options = {
  scenarios: {
    traffic_spike: {
      executor: 'ramping-vus',
      startVUs: 0,
      gracefulRampDown: GRACEFUL_RAMP_DOWN,
      stages: [
        { duration: SPIKE_BASELINE, target: SPIKE_BASELINE_VUS },
        { duration: SPIKE_RAMP_UP, target: SPIKE_TARGET_VUS },
        { duration: SPIKE_PEAK_HOLD, target: SPIKE_TARGET_VUS },
        { duration: SPIKE_RAMP_DOWN, target: SPIKE_BASELINE_VUS },
        { duration: SPIKE_COOLDOWN, target: 0 },
      ],
    },
  },
  thresholds,
};

export default trafficIteration;
