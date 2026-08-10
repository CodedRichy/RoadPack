# RoadPack Pack Mode — Technical Requirements Document

**Document Version:** 1.0
**Date:** August 10, 2026
**Author:** Praseeth / Claude
**Status:** Draft for Review
**Classification:** Internal
**Implements:** `docs/prd/roadpack-pack-mode-prd.md`

---

## 1. Overview

Pack Mode adds group ride coordination to RoadPack. This document specifies the data model, positioning algorithm, realtime transport, no-install web viewer, and the integration seam with the existing crash detection engine.

**Design stance:** Pack Mode introduces exactly one new subsystem — route-relative positioning. Everything else composes existing RoadPack infrastructure. Where a choice exists between building new and reusing, reuse wins, because the strategic value of Pack Mode is the loop, not the code.

### 1.1 What Already Exists

Verified against the repository, August 10, 2026:

| Asset | Location | Reuse |
|---|---|---|
| `CircleType.convoy` | `app/lib/features/circles/models/circle.dart:9` | Enum label only, no behavior. Pack rides attach to convoy circles. |
| `TrackingService` | `app/lib/features/tracking/services/tracking_service.dart` | Exposes `onActivityChanged`, `onSpeedUpdate`, geofence + heartbeat hooks. Position source for pack rides. |
| Crash detection engine | `app/lib/features/crash_detection/services/crash_detection_service.dart` | Source of automatic status (PM-40). |
| `incidents` table | `backend/supabase/migrations/00007_create_incidents.sql` | Already supports `crash_detected`, `inactivity`, with `severity`, `confidence`, `location`, `sensor_data`. **No schema change required.** |
| Alert cascade | `backend/supabase/functions/alert-cascade/` | Continues to run unmodified and in parallel with pack notification. |
| Channel abstraction | `AlertChannel` interface + FCM impl | Pack notifications reuse the push channel. |
| `location-ingest` | `backend/supabase/functions/location-ingest/` | Extended, not replaced, for pack position writes. |
| Drift local DB | `app/lib/` tracking feature | Offline queue for PM-61. |

### 1.2 What Is Genuinely New

1. `pack_rides` / `pack_ride_members` schema + linear-referencing helpers (migration `00017`)
2. A gap-computation RPC based on PostGIS linear referencing
3. A status field with an automatic-write path from crash detection
4. A public, no-install web viewer served as static snapshots

### 1.3 Non-Goals

- No new map SDK inside the Flutter app. The app keeps Google Maps Flutter. **The web viewer must not inherit it** (see §7).
- No routing service in the hot path. Route is resolved once, at ride creation.
- No map-matching service. See §4.1.

---

## 2. Architecture

```
Flutter app (rider)
  TrackingService ──► position batch ──► location-ingest (edge fn)
                                             │
  CrashDetectionService ──► incident ──► incident-receive (edge fn)
                                             │
                                             ▼
                                    Postgres + PostGIS
                                    pack_rides
                                    pack_ride_members
                                    fn_pack_project_member()
                                             │
                            ┌────────────────┴────────────────┐
                            ▼                                 ▼
                    pack-tick (edge fn, 5s)            alert-cascade
                    ├─ 1 aggregated Realtime broadcast   (UNCHANGED,
                    └─ snapshot JSON ──► Storage/CDN       parallel)
                            │
                            ▼
                    Web viewer (MapLibre, polls CDN, no auth)
```

**Two consumers, two transports, deliberately:**

- **Riders** (authenticated, few, need low latency) → single aggregated Realtime broadcast.
- **Viewers** (anonymous, potentially many, latency-tolerant) → CDN-cached JSON snapshot, polled.

The split exists because viewers are the uncapped population and holding a WebSocket per viewer is what breaks under a viral moment. See §6.2.

---

## 3. Data Model

### 3.1 Migration `00017_create_pack_rides.sql`

```sql
-- RoadPack: pack rides (Layer 4 — group ride coordination)

CREATE TABLE pack_rides (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    circle_id        UUID REFERENCES circles(id) ON DELETE SET NULL,
    leader_id        TEXT NOT NULL REFERENCES users(id),
    name             VARCHAR(80),

    destination      GEOGRAPHY(POINT, 4326) NOT NULL,
    route_line       GEOGRAPHY(LINESTRING, 4326) NOT NULL,
    -- cumulative geodesic distance (metres) at each vertex of route_line.
    -- length MUST equal ST_NPoints(route_line). See §4.2.
    route_cumdist    DOUBLE PRECISION[] NOT NULL,
    route_length_m   DOUBLE PRECISION NOT NULL,
    route_source     VARCHAR(20) NOT NULL,

    share_token      TEXT UNIQUE NOT NULL,
    share_expires_at TIMESTAMPTZ NOT NULL,
    share_revoked_at TIMESTAMPTZ,

    status           VARCHAR(10) NOT NULL DEFAULT 'draft'
                     CHECK (status IN ('draft','active','ended')),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    started_at       TIMESTAMPTZ,
    ended_at         TIMESTAMPTZ,
    -- hard stop; enforced by pg_cron sweep (§8.4)
    expires_at       TIMESTAMPTZ NOT NULL DEFAULT now() + INTERVAL '12 hours'
);

CREATE INDEX idx_pack_rides_active ON pack_rides(status) WHERE status = 'active';
CREATE INDEX idx_pack_rides_leader ON pack_rides(leader_id);
CREATE UNIQUE INDEX idx_pack_rides_token ON pack_rides(share_token);

CREATE TABLE pack_ride_members (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ride_id          UUID NOT NULL REFERENCES pack_rides(id) ON DELETE CASCADE,
    user_id          TEXT NOT NULL REFERENCES users(id),
    role             VARCHAR(10) NOT NULL DEFAULT 'rider'
                     CHECK (role IN ('leader','sweep','rider')),

    joined_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    left_at          TIMESTAMPTZ,

    -- linear referencing state
    chainage_m       DOUBLE PRECISION,
    chainage_at      TIMESTAMPTZ,
    last_position    GEOGRAPHY(POINT, 4326),
    off_route        BOOLEAN NOT NULL DEFAULT false,
    off_route_dist_m DOUBLE PRECISION,

    -- status
    status_code      VARCHAR(20) NOT NULL DEFAULT 'riding'
                     CHECK (status_code IN (
                        'riding','refueling','break','wrong_turn','waiting',
                        'stopped','done',
                        -- automatic only, never user-settable (§5.2)
                        'unexplained_stop','possible_incident','unreachable'
                     )),
    status_note      VARCHAR(140),
    status_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    status_auto      BOOLEAN NOT NULL DEFAULT false,
    incident_id      UUID REFERENCES incidents(id) ON DELETE SET NULL,

    UNIQUE (ride_id, user_id)
);

CREATE INDEX idx_pack_members_ride ON pack_ride_members(ride_id) WHERE left_at IS NULL;

-- leader breadcrumbs, for time-gap derivation (§4.4)
CREATE TABLE pack_ride_breadcrumbs (
    ride_id     UUID NOT NULL REFERENCES pack_rides(id) ON DELETE CASCADE,
    chainage_m  DOUBLE PRECISION NOT NULL,
    at          TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (ride_id, chainage_m)
);
```

### 3.2 Notes on Schema Decisions

- **`route_cumdist` as an array, not a computed value.** Converting `ST_LineLocatePoint`'s 0–1 fraction to metres by multiplying `ST_Length` is wrong on a route with variable-density vertices, and calling `ST_Length` per update is wasteful. Precompute once at ride creation and interpolate. Exact and free thereafter.
- **`incidents` is untouched.** Pack Mode reads incidents; it does not extend the type CHECK. This keeps the cascade path uncoupled from Pack Mode entirely, which is a hard requirement (PM-42).
- **`status_auto` is a separate flag, not a status prefix.** The UI must render automatic statuses distinctly (PM-43), and the value alone should not have to carry that meaning.
- **Breadcrumbs are keyed on chainage, not time.** The lookup is always "when was the leader at *my* chainage," so chainage is the natural key and it deduplicates a stopped leader automatically.
- **`share_expires_at` and `expires_at` are distinct.** A link can be revoked before the ride ends.

### 3.3 RLS

```sql
ALTER TABLE pack_rides         ENABLE ROW LEVEL SECURITY;
ALTER TABLE pack_ride_members  ENABLE ROW LEVEL SECURITY;
ALTER TABLE pack_ride_breadcrumbs ENABLE ROW LEVEL SECURITY;

-- members read their own rides
CREATE POLICY pack_rides_select ON pack_rides FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM pack_ride_members m
    WHERE m.ride_id = pack_rides.id
      AND m.user_id = auth.jwt() ->> 'sub'
      AND m.left_at IS NULL
  ));

CREATE POLICY pack_rides_insert ON pack_rides FOR INSERT
  WITH CHECK (leader_id = auth.jwt() ->> 'sub');

CREATE POLICY pack_rides_update ON pack_rides FOR UPDATE
  USING (leader_id = auth.jwt() ->> 'sub');

CREATE POLICY pack_members_select ON pack_ride_members FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM pack_ride_members me
    WHERE me.ride_id = pack_ride_members.ride_id
      AND me.user_id = auth.jwt() ->> 'sub'
      AND me.left_at IS NULL
  ));

-- a member may only ever write their own row
CREATE POLICY pack_members_update ON pack_ride_members FOR UPDATE
  USING (user_id = auth.jwt() ->> 'sub');
```

**Anonymous viewers never touch these tables.** They read a pre-rendered snapshot from Storage (§7.2). This is deliberate — it means no RLS policy has to reason about unauthenticated access, and a policy bug cannot leak the live table.

---

## 4. Route-Relative Positioning

The core algorithm and the only genuinely novel component.

### 4.1 Why Not Map Matching

HMM map matching (Valhalla, OSRM, Mapbox Map Matching, Google `snapToRoads`) answers *"which road was this GPS trace on?"* Pack Mode already knows the road — the ride shares one frozen route polyline. The question is only *"how far along that line is this rider?"*

Cost of solving it the expensive way, for one 10-rider 6-hour ride:

| Service | Pricing | Per convoy |
|---|---|---|
| Google `snapToRoads` | $10 CPM, 100 pts/req | **~$4.32 — rejected** |
| Mapbox Map Matching | 100k req/mo free, then $2/1k | ~$0.86 |
| OSRM public demo | 1 req/s, non-commercial | Unusable |
| Self-hosted Valhalla | ~$20/mo VPS | Viable but unnecessary |

**Decision: none of the above.** PostGIS linear referencing on the shared route, in-database, at zero marginal cost.

### 4.2 Chainage Computation

At ride creation:

```
route_cumdist[0] = 0
route_cumdist[i] = route_cumdist[i-1]
                 + ST_Distance(vertex[i-1]::geography, vertex[i]::geography)
route_length_m   = route_cumdist[n-1]
```

Per position update, `fn_pack_project_member(ride_id, user_id, pos)`:

1. **Window the search.** If the member has a prior `chainage_m`, restrict to a ±2 km substring:
   ```sql
   ST_LineSubstring(route_line::geometry,
                    GREATEST(0, (chainage_m - 2000) / route_length_m),
                    LEAST(1,  (chainage_m + 2000) / route_length_m))
   ```
   On first fix, search the whole line.
2. **Locate.** `ST_LineLocatePoint(window, pos)` → fraction within window → add the window's start offset → absolute `chainage_m`.
3. **Off-route test.** `ST_Distance(pos::geography, route_line)` > `off_route_threshold_m` → set `off_route = true`, **do not update `chainage_m`**, and suppress the gap downstream.
4. Write `chainage_m`, `chainage_at`, `last_position`.

### 4.3 Why the Window Is Non-Optional

Without it, `ST_LineLocatePoint` returns the *nearest* point on the entire line. On any route that revisits its own vicinity, the projection jumps kilometres and the displayed gap becomes confidently wrong:

- **Hairpins** — Western Ghats and Himalayan routes are dense with them
- **Cloverleaf interchanges** — inbound and outbound arms within metres
- **Out-and-back rides** — the return leg projects onto the outbound leg

The ±2 km window plus a monotonic-progress assumption removes the ambiguity. This is the single highest-risk piece of the algorithm and must be validated against a real Indian highway trace containing a cloverleaf **before any UI work begins**.

Parallel service lanes and flyovers are, by contrast, a non-problem: both project to nearly identical chainage on the same route line. They only matter for the off-route test, which is why the threshold is a tunable (§4.6).

### 4.4 Time Gap Without a Routing API

Distance gap is `chainage_self - chainage_other` (signed: positive = ahead of you).

Time gap uses the leader's breadcrumb trail:

```
time_gap = now() - (SELECT at FROM pack_ride_breadcrumbs
                    WHERE ride_id = $1
                    ORDER BY abs(chainage_m - $my_chainage) LIMIT 1)
```

This is ground truth. It absorbs actual traffic, actual road conditions, and actual stops, because it measures how long the leader really took to cover that ground. It costs one indexed lookup and no external service.

**Fallback:** before enough breadcrumbs accumulate (first ~2 km), derive time gap from distance gap and the member's trailing average speed, and mark it as estimated in the payload.

### 4.5 Suppression Rules (PM-23, PM-24)

The gap is **not displayed** when any of:

| Condition | Displayed state |
|---|---|
| `off_route = true` | `off route` + straight-line distance only |
| `now() - chainage_at > stale_threshold` | `last seen Xm ago` |
| member has no `chainage_m` yet | `locating` |
| time gap derived from fallback | number shown with explicit estimate marker |

Defaults: `off_route_threshold_m = 150`, `stale_threshold = 90s`.

Both are ride-level tunables, not constants. §4.6.

### 4.6 Tunables

`off_route_threshold_m` at 150 m is a starting hypothesis, not a validated value. Indian divided highways with wide medians and parallel service roads may require a higher value; dense urban grids may require lower. This must be exposed as configuration and calibrated from field traces, not guessed once and frozen.

---

## 5. Status System

### 5.1 Manual Status

Rider sets `status_code` + optional `status_note`. Writes the member row directly under RLS; the next `pack-tick` propagates it (≤5s).

UI constraint from PM-32: ≤2 taps, glove-operable, large hit targets. Statuses are a fixed enum specifically so the control can be a grid of large buttons rather than a text field.

`status_auto` is set `false`. Auto-clear to `riding` on sustained motion (PM-34).

### 5.2 Automatic Status — The Integration Seam

**This section is the reason Pack Mode is strategically defensible. It must not be descoped.**

Three automatic writers, none user-settable:

**`possible_incident` (PM-40)**

`incident-receive` already handles `crash_detected` from `CrashDetectionService`. Extend it with one additional step, guarded so it cannot affect the existing path:

```
on incident received (type = crash_detected | sos | inactivity):
    → existing behavior: persist incident, invoke alert-cascade   [UNCHANGED]
    → new: if user is in an active pack ride,
           set member.status_code   = 'possible_incident'
               member.status_auto   = true
               member.incident_id   = incident.id
           push to pack immediately
```

**Ordering requirement.** Pack notification fires on incident *receipt*, not on cascade completion. The existing crash flow includes a 30s user-cancellable countdown before the cascade dispatches. The pack must be told during that window — they are the nearest possible responders and are often minutes closer than any emergency contact.

**Isolation requirement (PM-42).** The pack write must not be able to fail, delay, or alter the cascade. Implement as a fire-and-forget side effect with its own error boundary. **A Pack Mode bug must never degrade emergency dispatch.** This is the highest-severity constraint in this document.

If the rider cancels the countdown ("I'M OKAY"), the pack status clears to `riding` and a cancellation notice is pushed.

**`unexplained_stop` (PM-41)**

Server-side, evaluated in `pack-tick`: member stationary beyond threshold, `status_code = 'riding'`, not `off_route`, not already flagged. Distinct from `possible_incident` — no impact was detected, only an unexplained absence of motion.

False-positive tolerance is the design risk here. If the pack learns to ignore this flag it is worse than not shipping it. Start conservative (long threshold), tune down with real data, and track the false-positive rate as a first-class metric.

**`unreachable` (PM-44)**

No position received beyond threshold. **Must be visually distinct from `stopped`** — a rider in a dead zone and a rider who has stopped moving are entirely different situations, and conflating them is exactly the failure mode §9 exists to prevent.

### 5.3 Status Precedence

When multiple conditions hold, highest wins:

```
possible_incident > unreachable > unexplained_stop > manual status > riding
```

---

## 6. Realtime and Cost

### 6.1 The Cost Trap

Supabase Realtime bills **1 message + 1 per receiving client**. Naive per-rider broadcast, 10 riders + 5 viewers, every 5s for 6h:

```
4,320 ticks × 10 riders × (1 + 15 recipients) = ~648,000 messages per ride
```

Free tier (2M msgs) = ~3 rides/month. Pro (5M, $25) = ~7 rides/month. That is not a product.

### 6.2 The Fix — One Server Tick, Two Transports

**`pack-tick` edge function, every 5s per active ride:**

1. Read all active members for the ride.
2. Compute gaps for every pairing (in-database, one query).
3. Evaluate automatic status conditions (§5.2).
4. Emit **one** aggregated Realtime broadcast containing all member states.
5. Write **one** snapshot JSON to Storage at `packs/{share_token}.json`.

```
4,320 ticks × (1 + 10 riders) = ~47,500 messages per ride
```

**~14× reduction**, and critically, **viewer count no longer affects Realtime cost at all** — viewers read the CDN.

The peak-connection cap ($10/1k concurrent) is what actually breaks during a viral moment, not message volume. Viewers never holding a WebSocket removes that ceiling entirely.

### 6.3 Position Ingest

Riders do not push individually to Realtime. Positions flow through the existing `location-ingest` path, batched by `flutter_background_geolocation`'s native batching — 10 fixes per ~30s POST rather than one request per fix. The radio tail, not the GPS chip, dominates battery (§10).

Position fidelity is therefore ~5s resolution with up to ~30s ingest latency, smoothed client-side. Acceptable: pack coordination decisions operate on minutes.

---

## 7. No-Install Web Viewer

PM-50 through PM-55. **This is the acquisition path — treat it as a P0 product surface, not a marketing page.**

### 7.1 Map Stack

The Flutter app keeps Google Maps Flutter. The web viewer must not.

| Option | Free tier | Overage | 500k-view moment |
|---|---|---|---|
| Google Maps JS | 10k loads | $7/1k | **~$3,430** |
| Mapbox GL JS | 50k loads | $5/1k | **~$2,250** |
| **MapLibre GL JS + OpenFreeMap** | Unlimited, no key | — | **$0** |

**Decision: MapLibre GL JS + OpenFreeMap**, with **Protomaps PMTiles on Cloudflare R2** as the fallback — free egress, ~$0.10/mo for an India extract, and switching is a single style-URL change.

Rationale: the pricing on the commercial options inverts exactly when success arrives. A viral ride link is the intended outcome of this feature, and the map bill must not scale with it.

**Risk:** OpenFreeMap is single-maintainer. R2 + PMTiles is the real plan; OpenFreeMap is the convenience default. Provision R2 before public launch, not after.

### 7.2 Serving

Viewer loads a static page and polls `packs/{share_token}.json` from Storage/CDN every 5s. No authentication, no database round trip, no WebSocket.

Snapshot payload:

```json
{
  "ride_id": "...",
  "status": "active",
  "generated_at": "2026-08-10T09:14:05Z",
  "route": { "polyline": "encoded", "length_m": 184320 },
  "members": [
    {
      "display_name": "Ravi",
      "chainage_m": 41200,
      "position": [10.0231, 76.3410],
      "precision_m": 50,
      "gap_from_leader_m": -4200,
      "gap_from_leader_s": 420,
      "status": "refueling",
      "status_auto": false,
      "stale": false,
      "off_route": false,
      "updated_at": "2026-08-10T09:14:02Z"
    }
  ]
}
```

**Privacy in the payload itself (PM-53):** the snapshot is generated for anonymous consumption, so positions are coarsened to ~50 m and no user IDs, phone numbers, or emergency-contact data appear. Authenticated riders receive exact positions over Realtime instead. The coarsening happens at generation time — an anonymous viewer never receives precise data that client code is trusted to hide.

### 7.3 Conversion Path

Value first, ask second (PM-52). The live pack renders immediately; the install prompt appears after the map is interactive, never as a gate. Instrument every transition: `link_tap → map_render → install_prompt_shown → store_redirect → install → slot_claimed`.

Deep-link the return path so a newly installed rider claims their slot without re-pasting the link.

---

## 8. Security and Privacy

### 8.1 Share Tokens

- 128-bit CSPRNG, URL-safe. Never sequential, never derived from ride ID.
- Carried in the URL **fragment** where feasible, so it stays out of server access logs and Referer headers.
- `share_expires_at` enforced server-side at snapshot generation, not only at link creation.
- Revocation (`share_revoked_at`) deletes the snapshot object from Storage — the CDN copy must be purged, not merely orphaned.

### 8.2 Anti-Abuse

Pack Mode creates a live location feed reachable by anyone holding a URL. Mitigations, all required for P0:

| Control | Requirement |
|---|---|
| Scoped lifetime | Sharing exists only while the ride is `active` (PM-70) |
| Hard TTL | 12h default ceiling regardless of ride state |
| Immediate revocation | Leaving a ride removes the member from the next snapshot (PM-72) |
| Visible audience | Riders see viewer count; social pressure is the most effective control available (PM-73) |
| No covert mode | A device in a ride always indicates it (PM-74) |
| Coarsened public precision | ~50 m for link viewers (§7.2) |

This inherits the v2 PRD's anti-stalking posture (SG-01..SG-08) and does not weaken it. **A feature that makes covert tracking easier is out of scope regardless of demand.**

### 8.3 Minors

Rides including members under 18 inherit existing DPDPA consent handling (PM-75). Where a minor is present, the public link path should be evaluated for restriction — flagged as an open question, §12.

### 8.4 Lifecycle Enforcement

Reuse the existing pg_cron infrastructure (already in place for `escalation-check`):

- Sweep `pack_rides` where `expires_at < now()` and `status = 'active'` → force `ended`, purge snapshots.
- Sweep orphaned snapshots in Storage with no corresponding active ride.

---

## 9. Offline Behaviour

PM-60 through PM-64. **The competitive moat, and the requirement most likely to be cut under delivery pressure. It should not be.**

Route research found ~85 km of continuous zero coverage on Gramphu–Losar, non-local prepaid SIM deactivation at the Ladakh border, and no coverage at any high pass. Every competitor assumes connectivity.

| Requirement | Implementation |
|---|---|
| Own navigation survives (PM-62) | Route polyline cached locally at ride start. No network needed for self-navigation. |
| Positions queue offline (PM-61) | Existing Drift offline queue. On reconnect, backfill the track rather than discarding. |
| Staleness surfaced (PM-60) | Client marks its own connectivity state; the map greys members past `stale_threshold`. **Never interpolate a position forward.** |
| Last-known persists (PM-63) | Member card shows last-known chainage + explicit timestamp, never a live-looking dot. |
| P2P proximity (PM-64) | Deferred. BLE-based nearby-member detection is the correct long-term answer for dead zones. |

**The cardinal rule:** a stale position the pack trusts is more dangerous than no position at all, because the pack makes wait/continue decisions on it. Staleness honesty ships before any visual polish.

---

## 10. Battery

| Source | Figure |
|---|---|
| `flutter_background_geolocation` adaptive, Redmi Note 12 (published benchmark) | ~5.5%/hr |
| Realistic Pack Mode load (5s fixes + batched network) | ~8–12%/hr |
| Same, with screen on and map visible | Roughly double |

A 6-hour ride at 10%/hr consumes ~60% — survivable, but only with batching. Mitigations:

- Native batch sync (10 fixes / ~30s) — the radio tail dominates, not the GPS chip
- Reduce fix rate when a member's gap is stable and large
- Screen-off is the default assumption; the map is a glance surface, not a persistent one

**Requirement:** instrument on target budget-Android hardware (Redmi/Realme class), not on a flagship. No vendor in this category publishes battery figures, so there is no external benchmark to rely on — measure it.

---

## 11. Testing

| Layer | Approach |
|---|---|
| **Chainage projection** | **Highest priority.** Recorded GPS traces over: a Western Ghats hairpin sequence, a cloverleaf interchange, an out-and-back route, and a divided highway with service lanes. Assert no chainage discontinuity exceeding physical plausibility. |
| Gap math | Unit tests with synthetic routes and known offsets, including at route start and end boundaries. |
| Suppression | Assert that off-route, stale, and pre-location states never emit a numeric gap. |
| Automatic status | **Assert cascade isolation:** an induced failure in the pack write must leave the emergency cascade completely unaffected. This is the critical test in the suite. |
| Realtime cost | Measure actual message counts against Supabase usage for one full simulated ride; verify the aggregate-tick model against the §6.2 arithmetic. |
| Web viewer | Cold link tap on a mid-range Android browser over 3G. Measure time-to-first-render — this is the conversion path. |
| Offline | Airplane-mode mid-ride: verify staleness surfaces within threshold, queue backfills correctly on reconnect, and no position is ever interpolated forward. |

Existing suite is 143 passing tests, 0 analyze issues. Pack Mode must not regress either.

---

## 12. Open Technical Questions

1. **Route source.** What provider resolves the destination to a route polyline at ride creation, and at what cost? Called once per ride, so unit economics are far better than per-fix services — but it is unresolved and blocks PM-02. Self-hosted Valhalla is the leading candidate.
2. **Off-route threshold.** 150 m is a hypothesis. Requires field calibration on Indian divided highways (§4.6).
3. **Realtime arithmetic.** §6.2 assumes 5 viewers per ride. Verify against actual Supabase usage on a real ride before committing to the tier.
4. **OpenFreeMap coverage quality** for rural Indian roads is unverified. Test before it becomes the default tile source.
5. **Snapshot write frequency vs. Storage cost.** 5s writes for a 6h ride is ~4,320 object writes per ride. Confirm this is bounded by request pricing, and consider a longer interval for viewers than for riders.
6. **Minor-in-ride public link.** Should the anonymous link path be disabled when any member is under 18? Policy question with a technical implementation (§8.3).
7. **Patent.** US12018949B2 review by counsel. Blocking for public launch, not for build.

---

## 13. Build Order

Sequenced so the riskiest unknown is retired first and nothing is built on an unvalidated foundation.

| Step | Deliverable | Gate |
|---|---|---|
| 1 | Migration `00017` + `fn_pack_project_member` + chainage tests | **Cloverleaf and hairpin traces pass before anything else is built.** |
| 2 | Ride lifecycle: create, join, start, end, leave + share token | Round-trip works end to end |
| 3 | `pack-tick` aggregate broadcast + gap display in-app | Message counts match §6.2 |
| 4 | Status enum, UI, and push propagation | Glove test, ≤2 taps |
| 5 | **Automatic status wiring from crash detection** | **Cascade isolation test passes** |
| 6 | Web viewer (MapLibre + snapshot) | Cold-link render on 3G under target latency |
| 7 | Offline behaviour + staleness honesty | Airplane-mode test passes |

Steps 1–4 are a working demo. **Step 5 is the product.** Steps 6–7 are what make the loop actually close and what competitors cannot follow.
