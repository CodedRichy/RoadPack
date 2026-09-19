/* Conversion funnel instrumentation (TRD 7.3, PRD 7.2).
 *
 * link_tap -> map_render -> install_prompt_shown -> store_redirect
 * (-> install -> slot_claimed, which happen inside the app, not here.)
 *
 * PRIVACY, non-negotiable: the share token is a live location credential.
 * It is never put in an event, never in a query string, never in a Referer.
 * Events carry an event name, a millisecond offset from page load, and a
 * random per-session id that exists only to stitch one funnel together and is
 * never persisted. No ride id, no member names, no coordinates.
 *
 * Every event is fire-and-forget. Analytics must never be able to delay or
 * fail the map.
 */

import { config } from './config.js';

const t0 = typeof performance !== 'undefined' ? performance.now() : Date.now();

function randomId() {
  try {
    const buf = new Uint8Array(8);
    crypto.getRandomValues(buf);
    return Array.from(buf, (b) => b.toString(16).padStart(2, '0')).join('');
  } catch {
    return Math.random().toString(16).slice(2, 18);
  }
}

const sessionId = randomId();
const seen = new Set();
const queue = [];
let flushTimer = null;

function flush() {
  flushTimer = null;
  if (queue.length === 0) return;
  const batch = queue.splice(0, queue.length);
  if (!config.ANALYTICS_URL) return;
  const payload = JSON.stringify({ session: sessionId, events: batch });
  try {
    if (navigator.sendBeacon) {
      navigator.sendBeacon(
        config.ANALYTICS_URL,
        new Blob([payload], { type: 'application/json' }),
      );
    } else {
      fetch(config.ANALYTICS_URL, {
        method: 'POST',
        body: payload,
        headers: { 'content-type': 'application/json' },
        keepalive: true,
        credentials: 'omit',
        referrerPolicy: 'no-referrer',
      }).catch(() => {});
    }
  } catch {
    /* Instrumentation is never allowed to surface an error to the viewer. */
  }
}

/**
 * @param {string} name  funnel step
 * @param {object} props small, non-identifying facts only
 * @param {boolean} once true for steps that must fire at most once per session
 */
export function track(name, props = {}, once = true) {
  if (once) {
    if (seen.has(name)) return;
    seen.add(name);
  }
  const now = typeof performance !== 'undefined' ? performance.now() : Date.now();
  const event = { name, at_ms: Math.round(now - t0), ...props };
  queue.push(event);
  if (config.USE_SAMPLES) console.info('[funnel]', name, event);
  if (!flushTimer) flushTimer = setTimeout(flush, 1200);
}

/** Flush anything queued when the page goes away. */
if (typeof document !== 'undefined') {
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) flush();
  });
  window.addEventListener('pagehide', flush);
}
