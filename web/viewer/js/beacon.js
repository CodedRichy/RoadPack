/* Viewer beacon (PM-55 / PM-73, TRD 8.2 "visible audience").
 *
 * Riders can see how many people are watching their link. Social pressure is
 * the most effective anti-abuse control available here, and it only works if
 * the number is TRUE -- so the count exists only because viewers report
 * themselves, and this page does.
 *
 * Three properties this module must have, in order of importance:
 *
 *  1. It can never break the map. Every failure path -- refused token, dead
 *     network, no config, storage disabled, malformed response -- resolves
 *     silently to "no beacon sent". Nothing is thrown, nothing is logged to
 *     the viewer, no count is shown. This is telemetry for a safety control,
 *     not a dependency of the thing people came to look at.
 *
 *  2. The session id identifies nobody. It is a per-tab random, generated
 *     fresh, held in `sessionStorage` and never in `localStorage`. Closing the
 *     tab loses it; a second visit is a different viewer. A stable id would
 *     make this page a visit tracker, which is exactly the posture the whole
 *     feature is built against. It never leaves this origin except as the
 *     opaque argument to the counting function.
 *
 *  3. The count on screen comes from the SNAPSHOT, never from this call's
 *     return value. The function does return the live count, but rendering it
 *     here would give one viewer a private number the riders cannot see, and
 *     would make the header flicker between two sources of truth.
 *
 * The server side (migration 00019 `fn_pack_viewer_beacon`) upserts on
 * (ride_id, session_id), counts a 90s window, prunes at 5 minutes, and raises
 * on a revoked, expired or unknown token.
 */

import { config } from './config.js';

/* The server validates `^[A-Za-z0-9_-]{8,64}$` and rejects anything else, so
 * the id is generated inside that alphabet rather than hoping base64 lands
 * there. 16 hex characters = 64 bits, which is far more than enough to avoid
 * a collision inside one ride's 5-minute window. */
const SESSION_KEY = 'roadpack.viewer.session';
const SESSION_RE = /^[A-Za-z0-9_-]{8,64}$/;

function randomHex(bytes) {
  try {
    const buf = new Uint8Array(bytes);
    crypto.getRandomValues(buf);
    return Array.from(buf, (b) => b.toString(16).padStart(2, '0')).join('');
  } catch {
    /* No crypto (very old browser, or a locked-down context). A weaker random
     * is acceptable here: this value is a counting bucket, not a credential. */
    let out = '';
    while (out.length < bytes * 2) out += Math.random().toString(16).slice(2);
    return out.slice(0, bytes * 2);
  }
}

/**
 * Per-tab id, reused for the life of the tab so repeat beacons collapse onto
 * one row instead of inflating the count.
 *
 * @param {Storage|null} storage injected for tests; defaults to sessionStorage
 */
export function viewerSessionId(storage) {
  const store = storage === undefined ? safeSessionStorage() : storage;
  if (store) {
    try {
      const existing = store.getItem(SESSION_KEY);
      if (typeof existing === 'string' && SESSION_RE.test(existing)) {
        return existing;
      }
    } catch {
      /* fall through to a fresh, unstored id */
    }
  }
  const id = randomHex(8);
  if (store) {
    try {
      store.setItem(SESSION_KEY, id);
    } catch {
      /* Private mode, or storage disabled. An id that lives only in memory
       * still works for this tab; it just does not survive a reload. */
    }
  }
  return id;
}

/* sessionStorage, and NEVER localStorage. Reading it can throw outright in
 * some privacy configurations, so even the access is guarded. */
function safeSessionStorage() {
  try {
    return typeof sessionStorage === 'undefined' ? null : sessionStorage;
  } catch {
    return null;
  }
}

/** Where the RPC lives, or null when the deploy has no backend configured. */
export function beaconUrl(cfg = config) {
  if (!cfg.SUPABASE_URL) return null;
  return `${String(cfg.SUPABASE_URL).replace(/\/+$/, '')}/rest/v1/rpc/fn_pack_viewer_beacon`;
}

/**
 * Send one beacon. Never throws, never rejects, never reports.
 *
 * @returns {Promise<boolean>} true only if the server accepted it. The caller
 *   uses this for nothing except deciding whether to keep trying.
 */
export async function sendBeacon(token, sessionId, opts = {}) {
  const cfg = opts.config ?? config;
  const url = beaconUrl(cfg);
  if (!url || !token || !sessionId) return false;

  const doFetch = opts.fetch ?? (typeof fetch === 'function' ? fetch : null);
  if (!doFetch) return false;

  try {
    const headers = { 'content-type': 'application/json' };
    if (cfg.SUPABASE_ANON_KEY) {
      headers.apikey = cfg.SUPABASE_ANON_KEY;
      headers.authorization = `Bearer ${cfg.SUPABASE_ANON_KEY}`;
    }
    const res = await doFetch(url, {
      method: 'POST',
      headers,
      /* The share token is a live location credential: it goes in the body,
       * never in a URL, and no referrer leaves with it. */
      body: JSON.stringify({ p_share_token: token, p_session_id: sessionId }),
      credentials: 'omit',
      referrerPolicy: 'no-referrer',
      keepalive: true,
      signal: opts.signal,
    });
    /* A refusal (revoked, expired, unknown token) is a normal outcome of a
     * dead link, not an error worth telling anyone about. The map has already
     * said the link is dead, in words, from the snapshot. */
    return !!(res && res.ok);
  } catch {
    return false;
  }
}

/**
 * Start beaconing about every `BEACON_MS`, pausing while the tab is hidden --
 * nobody is watching a backgrounded tab, and counting them as an audience
 * would make the number a lie in the direction that matters.
 *
 * @returns {{ stop: () => void, sessionId: string }}
 */
export function startBeacon(token, opts = {}) {
  const cfg = opts.config ?? config;
  const sessionId = opts.sessionId ?? viewerSessionId();
  let timer = null;
  let stopped = false;

  const hidden = () =>
    typeof document !== 'undefined' && document.hidden === true;

  async function tick() {
    if (stopped) return;
    if (!hidden()) await sendBeacon(token, sessionId, opts);
    if (stopped) return;
    timer = setTimeout(tick, cfg.BEACON_MS ?? 30000);
  }

  /* Fire immediately: a viewer who reads the page for twenty seconds and
   * leaves still counted as an audience, which is the point. */
  tick();

  return {
    sessionId,
    stop() {
      stopped = true;
      clearTimeout(timer);
    },
  };
}
