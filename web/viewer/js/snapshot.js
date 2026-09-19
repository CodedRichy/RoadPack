/* Snapshot transport.
 *
 * Polls a static JSON object from the CDN. No auth, no database round trip, no
 * WebSocket -- link viewers are the uncapped population and a socket per
 * viewer is exactly what breaks when a link goes viral. A 5s poll of an
 * edge-cached object costs the origin nothing and degrades gracefully to
 * "frozen" instead of to a silent, still-connected lie.
 *
 * Outcomes are classified, never collapsed into "error", because the viewer
 * has to tell the difference between "the link is dead" and "your train went
 * into a tunnel", and those two need opposite copy.
 */

import { config, snapshotUrl } from './config.js';
import { hydrateFixture } from './devfixtures.js';

export const Outcome = {
  OK: 'ok',
  GONE: 'gone',        // 403/404 -- ended, revoked, or expired
  OFFLINE: 'offline',  // network unreachable
  SERVER: 'server',    // 5xx, CDN trouble
  MALFORMED: 'malformed',
};

/** One fetch. Never throws; always resolves to a classified outcome. */
export async function fetchSnapshot(token, { signal } = {}) {
  const url = snapshotUrl(token);
  let res;
  try {
    res = await fetch(url, {
      signal,
      /* Freshness comes from the bucketed cache-busting key in the URL, which
       * lets many viewers share one CDN entry. no-store here would defeat
       * that and push every viewer through to the origin. */
      cache: 'default',
      credentials: 'omit',
      referrerPolicy: 'no-referrer',
      mode: 'cors',
    });
  } catch (err) {
    if (err && err.name === 'AbortError') throw err;
    return { outcome: Outcome.OFFLINE, error: err };
  }

  if (res.status === 404 || res.status === 403 || res.status === 410) {
    return { outcome: Outcome.GONE, status: res.status };
  }
  if (!res.ok) {
    return { outcome: Outcome.SERVER, status: res.status };
  }

  let body;
  try {
    body = await res.json();
  } catch (err) {
    return { outcome: Outcome.MALFORMED, error: err };
  }

  if (!body || typeof body !== 'object' || !Array.isArray(body.members)) {
    return { outcome: Outcome.MALFORMED, body };
  }

  /* Local fixtures only. Never reached against a real snapshot. */
  if (config.USE_SAMPLES) body = hydrateFixture(body);

  return { outcome: Outcome.OK, body };
}

/**
 * Poll loop. Backs off on consecutive failures so a dead link or a dead
 * network does not hammer the CDN from every viewer's phone at once, and
 * pauses entirely while the tab is hidden (a backgrounded viewer is not
 * reading the map, and mobile data is not free).
 *
 * @param {string} token
 * @param {(result: object) => void} onResult
 * @returns {{ stop: () => void, poke: () => void }}
 */
export function startPolling(token, onResult) {
  let timer = null;
  let controller = null;
  let failures = 0;
  let stopped = false;

  const delay = () => {
    if (failures === 0) return config.POLL_MS;
    /* 5s, 10s, 20s, 40s, capped at 60s. */
    return Math.min(config.POLL_MS * 2 ** failures, 60000);
  };

  async function tick() {
    if (stopped) return;
    if (typeof document !== 'undefined' && document.hidden) {
      schedule(config.POLL_MS);
      return;
    }
    controller = new AbortController();
    let result;
    try {
      result = await fetchSnapshot(token, { signal: controller.signal });
    } catch (err) {
      if (err && err.name === 'AbortError') return;
      result = { outcome: Outcome.OFFLINE, error: err };
    }
    if (stopped) return;

    failures = result.outcome === Outcome.OK ? 0 : failures + 1;
    result.consecutiveFailures = failures;
    onResult(result);

    /* A gone link never comes back on this token. Stop, rather than pointing
     * a permanent 5s poll at a 404. */
    if (result.outcome === Outcome.GONE) {
      stopped = true;
      return;
    }
    schedule(delay());
  }

  function schedule(ms) {
    clearTimeout(timer);
    timer = setTimeout(tick, ms);
  }

  function poke() {
    if (stopped) return;
    failures = 0;
    schedule(0);
  }

  tick();

  if (typeof document !== 'undefined') {
    document.addEventListener('visibilitychange', () => {
      if (!document.hidden) poke();
    });
  }
  if (typeof window !== 'undefined') {
    window.addEventListener('online', poke);
  }

  return {
    stop() {
      stopped = true;
      clearTimeout(timer);
      if (controller) controller.abort();
    },
    poke,
  };
}
