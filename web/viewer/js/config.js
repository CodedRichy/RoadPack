/* Deployment configuration for the pack viewer.
 *
 * Everything environment-specific lives here so the rest of the code has no
 * hardcoded hosts. Values can also be overridden at runtime without a rebuild
 * by defining `window.ROADPACK_VIEWER_CONFIG` in a small inline <script> in
 * index.html -- that is how a staging deploy points at a staging bucket.
 */

const defaults = {
  /* Public base URL for snapshot objects. The viewer fetches
   * `${SNAPSHOT_BASE}/${share_token}.json`. Supabase Storage public bucket, or
   * whatever CDN fronts it. No trailing slash. */
  SNAPSHOT_BASE: 'https://REPLACE-ME.supabase.co/storage/v1/object/public/packs',

  /* MapLibre style. ONE string, deliberately.
   *
   * OpenFreeMap is the convenience default: no key, no per-load billing, and a
   * viral ride link is the intended outcome of this feature -- the same
   * 500k-view moment costs ~$3,430 on Google and ~$2,250 on Mapbox.
   *
   * OpenFreeMap is single-maintainer, so it is not the launch answer. The real
   * plan is a Protomaps PMTiles India extract on Cloudflare R2 (free egress,
   * ~$0.10/mo). Swapping is this one line plus the pmtiles protocol shim --
   * see README "Swapping the tile source". */
  MAP_STYLE: 'https://tiles.openfreemap.org/styles/liberty',

  /* PMTiles archive URL. Set this and MAP_STYLE is built locally against it
   * instead of hitting a hosted style. Leave null to use MAP_STYLE. */
  PMTILES_URL: null,

  /* MapLibre itself. Pinned exactly, loaded lazily -- the roster and the
   * chainage strip render from JSON before this bundle arrives, which is the
   * whole 3G time-to-first-render argument. Vendor these into ./vendor/ before
   * public launch so the page has no third-party runtime dependency; see
   * README "Vendoring MapLibre". */
  MAPLIBRE_JS: 'https://cdn.jsdelivr.net/npm/maplibre-gl@4.7.1/dist/maplibre-gl.js',
  MAPLIBRE_CSS: 'https://cdn.jsdelivr.net/npm/maplibre-gl@4.7.1/dist/maplibre-gl.css',
  PMTILES_JS: 'https://cdn.jsdelivr.net/npm/pmtiles@3.2.1/dist/pmtiles.js',

  /* Poll cadence. Matches the server tick (TRD 6). */
  POLL_MS: 5000,

  /* Cache-key bucket. Requests inside the same bucket share one CDN cache
   * entry, so N viewers of a viral link collapse into one origin fetch per
   * bucket instead of N. Keep equal to POLL_MS. */
  CACHE_BUCKET_MS: 5000,

  /* Client-side staleness FALLBACK ONLY. `stale_threshold_s` is a per-ride
   * column and the snapshot always carries it; that value wins outright. This
   * is used only for a payload that predates the field. Raising it here does
   * not change who is stale on a live ride, and must not be used to try. */
  STALE_THRESHOLD_S: 90,

  /* How old the whole snapshot may get before the page stops calling itself
   * live. Two missed polls. */
  SNAPSHOT_LAG_WARN_S: 12,
  SNAPSHOT_LAG_FROZEN_S: 30,

  /* Conversion (TRD 7.3). Value first, ask second: the prompt cannot appear
   * before the map has rendered, and never before this delay. */
  INSTALL_PROMPT_DELAY_MS: 9000,

  /* Return path. The deep link is tried first in case the app is already
   * installed; the store link carries the token as an Android install
   * referrer so a fresh install claims the slot without re-pasting the link
   * (PM-54). See README "Token exposure in the return path". */
  APP_SCHEME_URL: 'roadpack://pack/join?t=',
  PLAY_STORE_URL:
    'https://play.google.com/store/apps/details?id=com.roadpack.app',
  APP_STORE_URL: 'https://apps.apple.com/app/roadpack/id0000000000',

  /* --- Viewer beacon (PM-55 / PM-73) ------------------------------------
   * Riders can see how many people are watching the link. That number only
   * exists because viewers report themselves, so this page does.
   *
   * `POST ${SUPABASE_URL}/rest/v1/rpc/fn_pack_viewer_beacon` with
   * `{ share_token, session_id }`. Anonymous -- the function is granted to
   * anon and takes a share token, never a ride id, so it cannot enumerate
   * rides. The anon key is a publishable key, not a secret.
   *
   * Leave SUPABASE_URL null and no beacon is ever sent; the ride then shows
   * no viewer count at all, which is the honest outcome of not measuring.
   *
   * A beacon is telemetry for an anti-abuse control, not a dependency: it is
   * fire-and-forget, and it can never delay, break, or surface an error on
   * the map. See js/beacon.js. */
  SUPABASE_URL: null,
  SUPABASE_ANON_KEY: null,

  /* Beacon cadence. A sixth of the poll rate: the server counts a 90s window
   * and prunes at 5 min, so 30s keeps a viewer counted with two beacons of
   * headroom while costing one request per six polls. */
  BEACON_MS: 30000,

  /* Analytics sink. POST endpoint that accepts a JSON array of events, or
   * null to keep events client-side only (console in dev). The share token is
   * NEVER included in an event -- see js/analytics.js. */
  ANALYTICS_URL: null,

  /* Dev-only: read snapshots from ./sample/<token>.json instead of the CDN.
   * Enabled automatically for file:// and localhost. */
  USE_SAMPLES: null,
};

const overrides =
  (typeof window !== 'undefined' && window.ROADPACK_VIEWER_CONFIG) || {};

export const config = { ...defaults, ...overrides };

if (config.USE_SAMPLES === null && typeof location !== 'undefined') {
  config.USE_SAMPLES =
    location.protocol === 'file:' ||
    location.hostname === 'localhost' ||
    location.hostname === '127.0.0.1';
}

/** Where the snapshot for this token lives. */
export function snapshotUrl(token, nowMs = Date.now()) {
  const bucket = Math.floor(nowMs / config.CACHE_BUCKET_MS);
  const base = config.USE_SAMPLES ? './sample' : config.SNAPSHOT_BASE;
  return `${base}/${encodeURIComponent(token)}.json?v=${bucket}`;
}
