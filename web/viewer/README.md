# RoadPack pack viewer

The no-install web viewer for a Pack Mode ride. Someone taps a WhatsApp link on
a mid-range Android phone over 3G and sees where the pack is — no app, no
account, no sign-up wall. PM-50 through PM-55; TRD §7.

This is a P0 product surface, not a marketing page. It is the acquisition path.

## What it is

Static files. No build step, no framework, no runtime dependency to install.
`index.html` + 2 stylesheets + 9 ES modules, served from any static host.

```
index.html            markup skeleton; every element the UI touches already exists
css/tokens.css        Kilometre Stone palette ported from app_colors.dart, OKLCH
css/viewer.css        layout, markers, roster, chainage strip, states
js/config.js          every environment-specific value; override at runtime
js/main.js            boot order, poll results, banners, conversion
js/format.js          the honesty layer — pure functions, fully unit tested
js/snapshot.js        polling transport with classified failure outcomes
js/map.js             MapLibre, loaded lazily and treated as optional
js/ui.js              DOM rendering (textContent only; no innerHTML from payload)
js/polyline.js        encoded-polyline decoder with a plausibility guard
js/analytics.js       funnel events; never carries the share token
js/devfixtures.js     local-dev timestamp resolution, never runs in production
sample/*.json         fixtures for the live and ended states
test/format.test.mjs  28 tests, `node --test`, no dependencies
```

### Load order, and why it is that order

1. Read the share token from the URL **fragment**.
2. Start polling the snapshot **immediately**.
3. Paint the roster and the chainage strip from the first JSON response.
4. *Then* start downloading MapLibre.
5. Only once the map is interactive, and never as a gate, offer install.

Steps 3 and 4 are deliberately in that order. The map bundle is ~200 KB of
WebGL; the snapshot is a few KB. On 3G a viewer gets the answer they came for —
who is where, how far apart, who has gone quiet — seconds before the basemap
arrives, and still gets it if the basemap never arrives at all.

The **chainage strip** is what makes step 3 sufficient: the route flattened to a
rail with each rider ticked at their chainage. Pure DOM, zero network. When
tiles fail, ordering and gaps survive.

## Honesty rules

These are correctness requirements, not copy. They live in `js/format.js` and
each one has a test.

| Rule | Implementation |
|---|---|
| Never show a stale position as live | Stale when the server flag says so **or** the client ages `updated_at` past the threshold **or** the timestamp cannot be read at all. Unverifiable freshness renders as stale. |
| Never interpolate forward | Markers are moved with `setLngLat`, with `transition: none` forced in CSS. A marker jumps to a reported fix or does not move. |
| `unreachable` ≠ `stopped` | Different shape (ring vs square), different tone, different words. Distinct in greyscale — ~8% of Indian men have red-green CVD, so nothing here relies on hue. |
| Suppress the gap | Off route → "Off route" + straight-line distance. Stale → "last seen Xm ago". Not located → "Locating". Never a stale number. |
| Mark estimates | `gap_estimated: true` renders an `EST` chip with a tooltip explaining it was derived from average speed. |
| Emergency tier is reserved | Only a member flagged `possible_incident` reaches it. Off-route uses the attention tier, per CONTRACT.md. |
| Never imply dispatch | The incident banner and the footer both say RoadPack does not call for help on its own and does not replace 112. |

Every failure state is explicit: **404/403 →** link ended, expired, or revoked;
**network error →** "You are offline", last update labelled with its age;
**5xx/malformed →** "Cannot reach the pack right now", still retrying;
**`status != "active"` →** ride ended, polling stops, final positions labelled.
In each case the last known picture stays on screen, greyed, with its age
stated, and the map is desaturated so it cannot be misread as live. There is no
state that shows a blank map, and none that shows a stale map looking live.

## Local development

No toolchain. Any static server works; `file://` also works (fixtures are
loaded relatively).

```bash
cd web/viewer
python -m http.server 8080        # or: npx serve .
```

Then open a fixture — the token goes after the `#`:

```
http://localhost:8080/#t=demo-token-0123456789     # active ride, every state
http://localhost:8080/#t=ended-token-0123456789    # ended ride, frozen
http://localhost:8080/#t=missing-token-000000000   # 404 → dead-link state
http://localhost:8080/                             # no token → explain state
```

On `localhost` and `file://`, `config.USE_SAMPLES` flips on automatically and
snapshots are read from `./sample/<token>.json`. Fixture timestamps are
symbolic (`REPLACED_AT_LOAD`, `STALE_6M`) and are resolved at fetch time by
`js/devfixtures.js`, so the demo stays live while you work on it. **That
rewriting only ever happens against fixtures** — rewriting a real timestamp
would be precisely the dishonesty this page exists to prevent.

To see the offline and frozen states, use DevTools → Network → Offline. To see
the sunlight (paper) theme, use the ◐ button in the header or switch the OS to
light mode.

### Tests

```bash
cd web/viewer
npm test        # node --test test/format.test.mjs  → 28 passing
npm run check   # node --check on every module
```

No dependencies. `package.json` exists only to mark the modules as ESM for
Node; nothing is installed and nothing is bundled.

## Configuration

Everything environment-specific is in `js/config.js`. For a deploy-time
override without editing the file, define `window.ROADPACK_VIEWER_CONFIG`
before the module script in `index.html`:

```html
<script>
  window.ROADPACK_VIEWER_CONFIG = {
    SNAPSHOT_BASE: 'https://cdn.roadpack.in/packs',
    ANALYTICS_URL: 'https://api.roadpack.in/fn/viewer-events',
  };
</script>
```

Keys worth knowing: `SNAPSHOT_BASE`, `MAP_STYLE`, `PMTILES_URL`, `POLL_MS`,
`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `BEACON_MS`, `INSTALL_PROMPT_DELAY_MS`,
`PLAY_STORE_URL`, `APP_SCHEME_URL`, `ANALYTICS_URL`.

`STALE_THRESHOLD_S` is a fallback only. `stale_threshold_s` is a per-ride
column and arrives in every snapshot; that value wins outright, so this page
and the app can never disagree about who is stale. Changing it here does not
change a live ride.

### Viewer beacon (PM-55)

Riders see how many people are watching their link, and that control only
works because the number is true — so this page reports itself:

```
POST ${SUPABASE_URL}/rest/v1/rpc/fn_pack_viewer_beacon
{ "p_share_token": "<token>", "p_session_id": "<per-tab random>" }
```

Anonymous (the function is granted to `anon`; the anon key is publishable, not
a secret). Roughly every 30 s — a sixth of the poll rate — and paused while
the tab is hidden. The server upserts on `(ride_id, session_id)`, counts a 90 s
window, prunes at 5 minutes, and refuses a revoked, expired or unknown token.

The session id is a fresh per-tab random in `sessionStorage`, **never**
`localStorage`: it must not be stable across visits and identifies nobody.

Failure is silent by design — refused, offline, or unconfigured, the beacon
shows nothing, surfaces no error, and the map is untouched. This is telemetry
for an anti-abuse control, not a dependency. Leave `SUPABASE_URL` null and no
beacon is ever sent; the ride then carries no `viewer_count` at all, which is
the honest outcome of not measuring.

The count rendered in the header comes from the **snapshot**, never from this
call's return value — otherwise one viewer would see a private number the
riders cannot.

### Cache-key bucketing

The snapshot URL carries `?v=<floor(now / 5000)>`. Every viewer polling in the
same 5-second window requests the *same* URL, so a viral link collapses into
one origin fetch per bucket instead of one per viewer, while still never
serving data older than a tick. Keep `CACHE_BUCKET_MS === POLL_MS`.

Set a short `Cache-Control` on the snapshot objects (`max-age=5,
stale-while-revalidate=30` is a reasonable starting point).

## Swapping the tile source to R2 + PMTiles

MapLibre + OpenFreeMap is the default because the pricing of the commercial
options inverts exactly when success arrives: the same 500k-view moment costs
~$3,430 on Google and ~$2,250 on Mapbox, and $0 here. OpenFreeMap is
single-maintainer, so it is the convenience default and **not** the launch
answer. Provision R2 before public launch, not after.

The swap is two config values:

1. Build an India extract and upload it:
   ```bash
   pmtiles extract https://build.protomaps.com/20260801.pmtiles india.pmtiles \
     --bbox=68.0,6.5,97.5,35.7
   rclone copy india.pmtiles r2:roadpack-tiles/
   ```
   Serve it from an R2 bucket with a custom domain and CORS allowing `GET` and
   `Range` from the viewer's origin. Egress from R2 is free.

2. Point the viewer at it:
   ```js
   window.ROADPACK_VIEWER_CONFIG = {
     PMTILES_URL: 'https://tiles.roadpack.in/india.pmtiles',
     MAP_STYLE: './style/protomaps-light.json',   // sources use pmtiles://
   };
   ```

`js/map.js` registers the `pmtiles://` protocol whenever `PMTILES_URL` is set;
nothing else in the codebase knows where tiles come from. Vector glyphs and
sprites referenced by the style must also be self-hosted — a style that still
points at a third-party glyph host has not actually been de-risked.

### Vendoring MapLibre

`MAPLIBRE_JS` / `MAPLIBRE_CSS` point at a pinned jsDelivr build. Before public
launch, copy `maplibre-gl.js` and `maplibre-gl.css` into `./vendor/` and point
the config at the local copies, so the page has no third-party runtime
dependency and one fewer connection to open on 3G.

## Deployment

Copy the directory to any static host with HTTPS and a CDN. There is nothing to
build.

```bash
# Cloudflare Pages
npx wrangler pages deploy web/viewer --project-name roadpack-viewer
```

Required headers:

| Header | Value | Why |
|---|---|---|
| `Referrer-Policy` | `no-referrer` | Belt and braces around the fragment token |
| `X-Robots-Tag` | `noindex, nofollow` | A live location feed must never be indexable |
| `Content-Security-Policy` | see below | The page loads exactly two third-party origins |
| `Cache-Control` (page) | `max-age=300` | The shell changes rarely |
| `Cache-Control` (snapshots) | `max-age=5, stale-while-revalidate=30` | Set on the Storage objects, not here |

```
default-src 'self';
script-src 'self' https://cdn.jsdelivr.net;
style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net;
img-src 'self' data: blob: https://tiles.openfreemap.org;
connect-src 'self' https://*.supabase.co https://tiles.openfreemap.org;
worker-src blob:;
frame-ancestors 'none';
```

Tighten `script-src`/`style-src` to `'self'` once MapLibre is vendored, and
replace the OpenFreeMap origins with the R2 domain once tiles move.

The snapshot bucket needs CORS allowing `GET` from the viewer's origin.

## Conversion funnel

`link_tap` → `map_render` → `install_prompt_shown` → `store_redirect`, plus
`map_interactive`, `map_unavailable`, and `install_prompt_dismissed`. Events go
to `ANALYTICS_URL` via `sendBeacon`, batched, fire-and-forget; with no URL
configured they stay client-side.

`map_render` fires when the **first snapshot is painted**, which is the moment
value is delivered — not when tiles finish, which may be seconds later or never.
The two are separated so a slow basemap does not distort the funnel.

**The share token is never included in an event.** It is a live location
credential. Events carry the step name, a millisecond offset from page load, and
a random per-session id that is not persisted. No ride id, no names, no
coordinates.

### Token exposure in the return path

`Join` tries `roadpack://pack/join?t=<token>` first, in case the app is already
installed, and falls back to the store after ~900 ms. On Android the store URL
carries `&referrer=pack_token=<token>` so the Play Install Referrer API lets a
newly installed rider claim their slot without re-pasting the link (PM-54).

This is a deliberate, narrow exception to keeping the token out of query
strings, and it is worth naming: it puts a live location credential into Play's
referrer pipeline. It happens only on an explicit tap, never on page load. If
that trade is not acceptable, the alternative is a server-issued single-use
claim handle exchanged for the token — **that decision belongs to the backend
owner, not this page.** iOS has no referrer equivalent; the iOS path is a plain
store link today and needs a Universal Link or a deferred-deep-link service
before PM-54 is genuinely complete there.

## Accessibility and glare

Read outdoors, one-handed, at 320 px. Type scales with `clamp()` and never goes
below 13 px. Interactive controls are 48 px, gloved controls 64 px
(`AppSpace.gloveTarget`). The sunlight theme is *paper*, not a dimmer dark
theme: maximum luminance, no mid-greys, doubled strokes, no shadows. State is
carried by shape and by words as well as by colour. The freshness pill is a
`role="status"` live region, banners announce politely, and roster rows are
keyboard-operable.

## Payload

Consumed as specified in TRD §7.2, reconciled against what the `pack-tick`
producer actually emits (`backend/supabase/functions/pack-tick/snapshot.ts` and
`fn_pack_member_payload` in migration 00019). The viewer never enriches or
un-coarsens it; `precision_m` is surfaced to the viewer as a stated limit
rather than hidden.

Fields read beyond the §7.2 example, all optional, all handled when absent:

| Field | Use |
|---|---|
| `display_state` | Authoritative suppression state — `off_route` > `locating` > `stale` > `estimated` > `ok`. Honoured when present; the client may only promote a member to `stale`, never demote one. |
| `off_route_m` | Distance from the route for an off-route member. The only field read for this; no aliases are accepted. |
| `gap_estimated` | Renders the `EST` chip. |
| `role` | `leader` is called out in the state line. |
| `member_key` | **Marker and roster identity.** Opaque, stable for the life of the ride, unique within it (migration 00019). There is no name-or-index fallback: two riders sharing a first name would collide, and an index changes on every reorder, either of which turns a marker into a different person without anyone seeing it. A member with no key gets no marker; the roster still lists them. |
| `name` | Ride name. Falls back to "Pack ride" when null. |
| `stale_threshold_s` | Per-ride staleness threshold. Overrides `config.STALE_THRESHOLD_S` outright. |
| `viewer_count` | Rendered only when present — it appears once the ride has received a viewer beacon. Absent renders **nothing**; it is never substituted with 0, because the whole value of PM-55 is that the number is true. A real `0` (beaconed, nobody watching now) is a fact and is shown. |

`gap_from_leader_m` is read with the producer's sign convention: `chainage −
leader chainage`, so negative means behind. The page prints the direction in
words either way rather than relying on the sign.

`route.polyline` is precision 5, standard Google encoding — confirmed, not
inferred. `js/polyline.js` decodes at 5 only: there is no precision-6 retry and
no "does this look plausible, try the other one" fallback, because a decoder
that guesses its own input turns a producer bug into a subtly wrong map instead
of a visible one. Coordinates that land off the planet draw no route at all.
