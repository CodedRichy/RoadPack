/* Pack viewer entry point.
 *
 * Order of operations is the product decision here:
 *   1. read the token from the URL fragment
 *   2. start the snapshot poll IMMEDIATELY
 *   3. paint the roster and the chainage strip from the first JSON response
 *   4. only then start downloading MapLibre
 *   5. only after the map is interactive, and never as a gate, offer install
 *
 * Steps 3 and 4 are in that order on purpose. The map bundle is ~200 KB of
 * WebGL; the snapshot is a few KB. On 3G, a viewer who taps a WhatsApp link
 * gets the answer they came for -- who is where, how far apart -- seconds
 * before the basemap finishes arriving, and still gets it if it never does.
 */

import { config } from './config.js';
import {
  deriveSnapshot,
  formatAge,
  freshnessState,
  precisionNote,
} from './format.js';
import { startPolling, Outcome } from './snapshot.js';
import { PackMap } from './map.js';
import { startBeacon } from './beacon.js';
import { track } from './analytics.js';
import * as ui from './ui.js';

/* --- Token ---------------------------------------------------------------
 * The token lives in the FRAGMENT, never the query string (TRD 8.1): a
 * fragment is not sent to the server, so it stays out of access logs and out
 * of the Referer header of anything this page loads. Accepts `#t=<token>` and
 * a bare `#<token>`. */
function readToken() {
  const hash = (location.hash || '').replace(/^#/, '');
  if (!hash) return null;
  const params = new URLSearchParams(hash);
  const fromParam = params.get('t') || params.get('token');
  const raw = fromParam || hash;
  const token = decodeURIComponent(raw).trim();
  return /^[A-Za-z0-9_-]{16,128}$/.test(token) ? token : null;
}

const state = {
  token: null,
  lastRaw: null,      // last successful snapshot body
  lastFetchMs: null,  // when we last successfully fetched it
  transport: 'ok',    // ok | gone | offline | server | malformed
  ended: false,
  painted: false,
  mapInteractive: false,
  mapSettled: false,   // the map load attempt has resolved, one way or the other
  promptArmed: false,
  rosterSignature: '',
  packMap: null,
  poller: null,
  beacon: null,
};

/* --- Render -------------------------------------------------------------- */

function render() {
  if (!state.lastRaw) return;
  const now = Date.now();
  /* `config.STALE_THRESHOLD_S` is a FALLBACK, not the setting. The ride's own
   * `stale_threshold_s` comes down in the snapshot and wins inside
   * deriveSnapshot, so this page and the app always agree about who is
   * stale. */
  const snap = deriveSnapshot(state.lastRaw, {
    nowMs: now,
    staleThresholdS: config.STALE_THRESHOLD_S,
  });

  /* Freshness is the age of the DATA, not of the last request. A snapshot the
   * CDN keeps serving happily is still old data if the producer stopped
   * writing it, and a viewer must never read that as live. */
  let fresh = freshnessState(snap.generatedAgeSeconds, {
    warnS: config.SNAPSHOT_LAG_WARN_S,
    frozenS: config.SNAPSHOT_LAG_FROZEN_S,
  });
  if (state.transport !== 'ok' || state.ended) fresh = 'frozen';

  ui.renderHeader(snap);
  if (state.packMap?.ready) ui.renderMapHint(precisionNote(snap.members));
  ui.renderFreshness(fresh, snap.generatedAgeSeconds);
  ui.renderStrip(snap);

  /* Only rebuild the roster when something a viewer can see has changed --
   * a blind 1 Hz rebuild would steal focus from anyone tabbing through it. */
  const signature = snap.members
    .map((m) => [m.key, m.tone, m.shape, m.stale, m.stateLabel, m.gap.text, m.gap.sub].join('|'))
    .join('~');
  if (signature !== state.rosterSignature) {
    state.rosterSignature = signature;
    ui.renderRoster(snap, (key) => state.packMap?.focus(key));
  }

  renderBanner(snap, fresh);

  if (state.packMap) state.packMap.render(snap, {});

  if (!state.painted) {
    state.painted = true;
    ui.hideState();
    track('map_render', { members: snap.members.length });
    bootMap();
    armInstallPrompt();
  }
}

function renderBanner(snap, fresh) {
  /* Precedence, highest first. A possible incident outranks everything,
   * including the fact that the link is dead. */
  if (snap.incident) {
    ui.showBanner(
      'emergency',
      `${snap.incident.name}: possible incident`,
      'Detected automatically from the rider’s phone, not confirmed. ' +
        'RoadPack does not call for help on its own — in an emergency, call 112.',
    );
    return;
  }

  if (state.transport === 'gone') {
    ui.showBanner(
      'attention',
      'This link is no longer live',
      'The ride has ended, the link expired, or the leader revoked it. ' +
        `Everything below is frozen at ${formatAge(snap.generatedAgeSeconds)}.`,
    );
    return;
  }

  if (state.ended) {
    ui.showBanner(
      'notice',
      'Ride ended',
      `Final positions, from ${formatAge(snap.generatedAgeSeconds)}. Sharing has stopped.`,
    );
    return;
  }

  if (state.transport === 'offline') {
    ui.showBanner(
      'attention',
      'You are offline',
      `Showing the last update received, from ${formatAge(snap.generatedAgeSeconds)}. ` +
        'Nothing on this page is live right now.',
    );
    return;
  }

  if (state.transport === 'server' || state.transport === 'malformed') {
    ui.showBanner(
      'attention',
      'Cannot reach the pack right now',
      `Retrying. Showing the last update received, from ${formatAge(snap.generatedAgeSeconds)}.`,
    );
    return;
  }

  if (fresh === 'frozen') {
    ui.showBanner(
      'attention',
      'Updates have stopped',
      `The pack stopped reporting ${formatAge(snap.generatedAgeSeconds)}. ` +
        'Positions below are last-known, not current.',
    );
    return;
  }

  if (fresh === 'lagging') {
    ui.showBanner(
      'notice',
      'Running behind',
      `Last update ${formatAge(snap.generatedAgeSeconds)}.`,
    );
    return;
  }

  if (snap.anyStale) {
    const n = snap.members.filter((m) => m.stale).length;
    ui.showBanner(
      'notice',
      `${n} rider${n === 1 ? '' : 's'} out of contact`,
      'Their last known position is shown with its age. It is not current.',
    );
    return;
  }

  ui.hideBanner();
}

/* --- Poll results -------------------------------------------------------- */

function onResult(result) {
  switch (result.outcome) {
    case Outcome.OK:
      state.transport = 'ok';
      state.lastRaw = result.body;
      state.lastFetchMs = Date.now();
      /* Anything other than `active` means sharing is over. Keep the last
       * picture on screen, labelled, and stop pretending to poll. */
      if (result.body.status && result.body.status !== 'active') {
        state.ended = true;
        state.poller?.stop();
        /* Nobody is an audience for a ride that is over. */
        state.beacon?.stop();
        state.beacon = null;
      }
      render();
      return;

    case Outcome.GONE:
      state.transport = 'gone';
      state.beacon?.stop();
      state.beacon = null;
      if (state.lastRaw) {
        render();
      } else {
        ui.showState('gone', {
          title: 'This link is no longer live',
          body:
            'The ride has ended, the link expired, or the leader revoked it. ' +
            'RoadPack links stop working when the ride does — that is deliberate. ' +
            'Ask the ride leader for a new one.',
        });
      }
      return;

    case Outcome.OFFLINE:
      state.transport = 'offline';
      if (state.lastRaw) {
        render();
      } else {
        ui.showState('offline', {
          title: 'No connection',
          body:
            'This page needs a connection to show where the pack is. ' +
            'It will load as soon as you have signal.',
          spinner: true,
        });
      }
      return;

    default:
      state.transport = result.outcome === Outcome.MALFORMED ? 'malformed' : 'server';
      if (state.lastRaw) {
        render();
      } else if (result.consecutiveFailures > 2) {
        ui.showState('server', {
          title: 'Cannot load this pack',
          body: 'The pack data could not be read. Still retrying.',
          spinner: true,
        });
      }
  }
}

/* --- Map ----------------------------------------------------------------- */

async function bootMap() {
  state.packMap = new PackMap('map');
  const ok = await state.packMap.init({
    onInteractive: () => {
      state.mapInteractive = true;
      track('map_interactive');
    },
  });
  state.mapSettled = true;
  if (!ok) {
    state.packMap = null;
    document.getElementById('mapwrap').hidden = true;
    ui.renderMapHint('');
    track('map_unavailable');
    /* The map is the optional half of this page. Losing it is worth saying
     * out loud, but it is not worth losing the answer over -- the strip and
     * the roster carry ordering, gaps and staleness on their own. */
    ui.showBanner(
      'notice',
      'Map unavailable',
      'The background map could not load. Rider order, gaps and status below are unaffected.',
    );
    return;
  }
  render();
}

/* --- Conversion ---------------------------------------------------------- */

function armInstallPrompt() {
  if (state.promptArmed) return;
  state.promptArmed = true;

  const deadline = Date.now() + 30000;

  const fire = () => {
    /* Never before the value. The map must have rendered AND become
     * interactive; while it is still loading we wait rather than interrupting
     * it with an ask. The deadline stops a map that never finishes from
     * suppressing the prompt forever -- by then the roster and the strip have
     * carried the value on their own. */
    if (!state.painted) return;
    if (state.transport === 'gone') return;
    if (!state.mapSettled && Date.now() < deadline) {
      setTimeout(fire, 1500);
      return;
    }
    if (state.packMap && !state.mapInteractive && Date.now() < deadline) {
      setTimeout(fire, 1500);
      return;
    }
    const shown = ui.showInstall({
      onInstall: () => {
        track('store_redirect', { platform: platform() }, false);
        goToApp();
      },
      onDismiss: () => track('install_prompt_dismissed', {}, false),
    });
    if (shown) track('install_prompt_shown');
  };

  setTimeout(fire, config.INSTALL_PROMPT_DELAY_MS);
}

function platform() {
  const ua = navigator.userAgent || '';
  if (/android/i.test(ua)) return 'android';
  if (/iphone|ipad|ipod/i.test(ua)) return 'ios';
  return 'other';
}

/* Try the app first, in case it is already installed, then fall back to the
 * store. The Android store URL carries the token as an install referrer so a
 * newly installed rider claims their slot without re-pasting the link
 * (PM-54). That is a deliberate, documented exception to keeping the token
 * out of query strings -- see README "Token exposure in the return path". */
function goToApp() {
  const p = platform();
  const token = state.token;
  const deepLink = config.APP_SCHEME_URL + encodeURIComponent(token);

  let storeUrl = p === 'ios' ? config.APP_STORE_URL : config.PLAY_STORE_URL;
  if (p === 'android') {
    const referrer = encodeURIComponent(`pack_token=${token}`);
    storeUrl += `&referrer=${referrer}`;
  }

  let left = false;
  const onHide = () => {
    left = true;
  };
  document.addEventListener('visibilitychange', onHide, { once: true });

  location.href = deepLink;
  setTimeout(() => {
    document.removeEventListener('visibilitychange', onHide);
    if (!left && !document.hidden) location.href = storeUrl;
  }, 900);
}

/* --- Boot ---------------------------------------------------------------- */

function boot() {
  track('link_tap', { has_token: !!readToken() });

  const token = readToken();
  if (!token) {
    ui.showState('no-token', {
      title: 'No ride link',
      body:
        'This page shows a live RoadPack ride, and it needs the link the ride ' +
        'leader shared. Open the full link you were sent — including ' +
        'everything after the # — and the pack will load here.',
    });
    return;
  }
  state.token = token;

  ui.showState('loading', {
    title: 'Loading the pack',
    body: 'Finding everyone on the route.',
    spinner: true,
  });

  state.poller = startPolling(token, onResult);

  /* Report this tab as one viewer, so the riders' visible audience count
   * (PM-55) is a real number rather than a guess. Fire-and-forget in every
   * direction: if it is unconfigured, refused or offline, nothing here
   * changes, nothing is shown, and the map carries on. */
  try {
    state.beacon = startBeacon(token);
  } catch {
    state.beacon = null;
  }

  /* Ages advance whether or not new data arrives. Without this tick a member
   * who went quiet would keep reading "just now" for as long as the tab stays
   * open, which is precisely the failure the honesty rules exist to prevent. */
  setInterval(() => {
    if (state.lastRaw && !document.hidden) render();
  }, 1000);

  /* Theme: follows the OS, with a manual override for a rider who wants the
   * paper theme under direct sun regardless of what the phone thinks. */
  document.getElementById('themetoggle').addEventListener('click', () => {
    const root = document.documentElement;
    const now = root.getAttribute('data-theme');
    const next =
      now === 'sunlight' ? 'night' : now === 'night' ? 'sunlight' : 'sunlight';
    root.setAttribute('data-theme', next);
    state.packMap?.applyTheme();
  });

  window.addEventListener('resize', () => state.packMap?.resize());
}

boot();
