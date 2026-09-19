# RoadPack — Launch Readiness

**Date:** 2026-09-08
**Branch:** `feat/pack-mode-chainage`
**Status:** MVP feature-complete in software. Not launchable — see §3 and §4.

This document is the handoff. §1 says what exists, §2 how to verify it, §3 what a
human must do by hand, §4 what is blocked on parties outside engineering, and §5
what ships deliberately incomplete.

Read §4 first. Several items there are launch-blocking and none of them can be
closed by writing code.

---

## 1. What is built

| Area | Requirements | State |
|---|---|---|
| Identity, onboarding | FR-001, FR-004, FR-006 | Clerk phone/Google auth, onboarding, permissions walkthrough |
| Age gate, consent | FR-003 | Mechanism, hard gate and append-only record built. **Cannot track an under-18 user at all** — see §4.1 |
| Circles | FR-010…FR-015 | Create, invite, roles, leave-notifies |
| Who can see me | FR-014 | Mirrors `can_view_location` exactly; member-level opt-out (migration 00021) |
| Emergency profile | FR-020…FR-024 | 1–5 priority contacts, ICE card gated to active incident/commute, once-only listing notice |
| Tracking | FR-030…FR-036 | Background geolocation, trip detection, route learning. Start path gated on consent + profile completeness |
| Commute intelligence | FR-040…FR-044 | Learned + manual routes, non-arrival grace window (10/15/30, default 15), escalation, one-tap "running late" |
| Live map | FR-050, FR-053 | Member positions, entitlement-filtered, stale-honest. FR-052 partial — see §5.1 |
| SOS | FR-070, FR-071, FR-073 | Long-press, countdown, streaming |
| Crash detection | L2 | Accelerometer + gyroscope engine, countdown, server integration |
| Alert cascade | FR-100…FR-104 | Orchestration, retries, acknowledgement, terminal escalation. **Only the push channel actually sends** — see §4.4 |
| Bystander mode | FR-007, FR-091…FR-094, FR-110, FR-111 | No-signup public screen, 112 dial, Good Samaritan notice, first aid, gated ICE QR, offline hospital lookup |
| Pack Mode | PM-01…PM-75 | Route-relative chainage, ride lifecycle, `pack-tick` aggregate broadcast, status system, automatic status from crash detection, no-install web viewer |
| Localisation | FR-005 | EN / HI / ML — see §4.5 for review status |

### The two structurally important pieces

**Route-relative positioning** (`fn_pack_project_member`, migration 00017) is the
only genuinely novel subsystem. It answers "how far along this shared route is
each rider" using PostGIS linear referencing, in-database, at zero marginal cost
— rather than a per-fix map-matching service, which would cost roughly $4.32 per
10-rider ride on Google `snapToRoads`.

Its search window is **kinematic**, not the fixed ±2 km the TRD originally
specified: `LEAST(window_fwd_m, max_speed_mps × elapsed + jitter)`. A fixed
window cannot contain the true position when ingest is batched at ~30 s or
backfilled after a dead zone, so chainage would clamp to the window edge and the
displayed gap would freeze while still looking live. The TRD text was corrected
to match the shipped code.

**Cascade isolation** (TRD §5.2, PM-42) is the highest-severity constraint in the
project: a Pack Mode bug must never degrade emergency dispatch. The pack write on
the incident path is fire-and-forget behind its own error boundary, and
`cascade_isolation.test.ts` asserts that a pack write which throws, rejects, or
*hangs* leaves the cascade unaffected, that it never reaches the cascade
endpoint, that it carries no contact data, and — structurally, against the real
source — that production does not `await` it.

---

## 2. Verification

```bash
# Flutter
cd app && flutter analyze          # expect: No issues found!
cd app && flutter test             # expect: all pass
cd app && flutter build apk --debug

# Edge functions
deno test --allow-read --allow-env --allow-net \
  backend/supabase/functions/pack-tick/ \
  backend/supabase/tests/contact_notice_*.test.ts

# Database (requires Docker)
bash backend/supabase/tests/run.sh

# Web viewer
cd web/viewer && npm test && npm run check
```

At the time of writing: analyze clean, Flutter suite green, Deno suites green,
pgTAP suites green, viewer suite green, and the Android debug APK builds.

**The APK building is new.** Before this pass the Android app had never built:
`flutter_background_geolocation` declares its bundled native AARs with a relative
Maven path that Gradle resolves against the root project rather than the plugin,
so `tslocationmanager:3.+` was unresolvable. Fixed in `android/build.gradle.kts`.
Do not remove that repository block.

---

## 3. Manual prerequisites (engineering can do these, but they need accounts/keys)

### 3.1 Android
- **Google Maps API key.** Copy `app/android/google_maps_api.xml.example` to
  `app/android/app/src/main/res/values/google_maps_api.xml` and insert a real
  key. That file is gitignored — a Maps key in a public repo is billed to
  whoever finds it. Restrict the key to the package name and signing
  certificate. **Without it the map renders blank and logs nothing obvious.**
- **Firebase.** Add `app/android/app/google-services.json` and apply the
  `com.google.gms.google-services` Gradle plugin. Both are required together;
  adding the plugin without the file breaks the build. `Firebase.initializeApp`
  is already guarded, so the app boots without it — but push notifications, and
  therefore the entire alert cascade and the bystander entry point, do not work.
- **Release signing.** `android/app/build.gradle.kts` still signs release builds
  with the debug keystore. Replace before any distribution.
- **Deep links.** A custom `roadpack://pack` scheme is wired. The `https` intent
  filter is commented out pending a real host plus an `assetlinks.json` served
  from it.

### 3.2 iOS
Usage descriptions and background modes are in `Info.plist`. iOS is the secondary
platform; nothing on it has been run or tested on a device.

### 3.3 Supabase
- Apply migrations `00001` … `00021`.
- Create the **`packs` storage bucket** (public, JSON). Declared in
  `config.toml` for local use; the hosted project needs it created.
- Confirm `pg_cron` and `pg_net` are enabled — `pack-tick` is scheduled via
  `net.http_post`.
- Deploy all 15 edge functions. `config.toml` now declares each with
  `verify_jwt = false`; **this is deliberate and must not be "tightened"**. The
  platform gate validates *Supabase* JWTs, but this project authenticates with
  Clerk, so enabling it makes every function unreachable. Each function performs
  its own verification (Clerk JWT, webhook signature, or service-role bearer).
- Set secrets: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `CLERK_ISSUER_URL`,
  `CLERK_WEBHOOK_SECRET`, `SMS_WEBHOOK_SECRET`, `VOICE_WEBHOOK_SECRET`,
  `SMS_PROVIDER`, `VOICE_PROVIDER`, and the DLT variables in §4.2.

### 3.4 Web viewer
- Set `SUPABASE_URL` and `SUPABASE_ANON_KEY` in `web/viewer/js/config.js`. The
  viewer beacon is inert until they are set, so `viewer_count` never appears.
- Host statically. Confirm CORS allows the RPC from the viewer origin.
- **Revocation must purge the CDN copy**, not merely orphan it (TRD 8.1).
- Tile source is OpenFreeMap, which is single-maintainer. Provision Protomaps
  PMTiles on Cloudflare R2 before public launch; it is a one-line style-URL swap.

---

## 4. Blocked on parties outside engineering — launch-blocking

### 4.1 Verifiable parental consent (DPDPA C6) — legal
The mechanism, the hard gate and the append-only consent record are built. The
**verification method is not**, because what qualifies as "verifiable parental
consent" under the DPDPA is a question for counsel, not for engineering. The only
shipped `ParentalVerifier` is `UnavailableParentalVerifier`, which always
refuses — so this build writes no `parental` consent and **cannot track any
under-18 user at all**. That is deliberate: a dead end is correct until counsel
approves a method to drop into `parentalVerifierProvider`.
The consent wording (`kConsentWordingVersion = 'v1'`) also needs review before it
is stamped on real records.

### 4.2 DLT registration (TRAI) — telecom
No SMS can be delivered in India until entity, header and template registration
completes. Templates are structured so no code change is needed afterwards:
register the *unsubstituted* templates in `shared/templates/alert_templates.json`,
then set `DLT_ENTITY_ID`, `DLT_HEADER_ID`, and
`DLT_TEMPLATE_ID_CONTACT_LISTED_{EN,HI,ML}`.
Note the Hindi template has ~2 units of headroom inside its 2-segment budget
(Malayalam and Hindi are UCS-2, 67 characters per segment). A one-word copy edit
can push a safety SMS to three segments — `contact_notice_segments.test.ts`
exists to catch exactly that.

### 4.3 Google Play — policy
- Background location requires a prominent-disclosure declaration and review.
  The permission is declared in the manifest; **declaring it does not satisfy the
  policy.**
- Any SMS-related exception needed for the cascade must be applied for.

### 4.4 SMS and voice vendors — commercial
`_shared/channels.ts` implements **push (FCM) only**. The `sms` and `call`
channels throw `provider not yet implemented`. The cascade's escalation tiers
therefore cannot currently reach a feature-phone parent (the Observer role in
FR-011) or place a voice call. A vendor (Exotel, Twilio, MSG91) must be chosen
and implemented behind the existing `AlertChannel` interface.

### 4.5 Medical and content review
- **First-aid copy (FR-093)** is an engineering draft, deliberately minimal: do
  not move the casualty, do not remove the helmet, check breathing, control
  bleeding, keep warm. No airway, CPR, spinal or tourniquet technique. It needs
  sign-off from a qualified emergency physician; a "pending medical review"
  banner renders until then.
- **Hindi and Malayalam translations** need native-speaker review before launch.
  Keys the localisation pass flagged as uncertain are marked in the ARB metadata.
  A mistranslated instruction on an emergency screen is worse than an English one
  the reader can at least recognise as foreign.

### 4.6 Hospital data (FR-111)
Eight Ernakulam/Muvattupuzha facilities are seeded with `verified_at NULL` and
`source = 'pilot_seed_unverified'`. Coordinates are facility centroids, not
casualty entrances, and **no phone numbers are seeded** — a wrong number at a
crash costs more time than looking one up. A physical verification sweep is
required. The UI labels unverified rows as such; never present them otherwise.

### 4.7 Patent
US12018949B2 review by counsel (TRD §12.7). Blocking for public launch, not for
build.

---

## 5. Shipped deliberately incomplete

### 5.1 FR-052 offline base map
The route-buffer tile arithmetic, the tile store, and the cache-management UI are
real. **Offline base-map rendering is not.** `google_maps_flutter` draws its base
map inside the native Google SDK, which exposes no supported API to seed its tile
cache, and Google's tile endpoints may not be scraped or stored under Maps
Platform terms. `OfflineTileCache.servesBaseMapOffline` is `false` and the
limitation renders in the UI rather than hiding in a comment. Making this true
needs a self-hosted OSM/PMTiles source and a map widget that can render it.
Also: no `path_provider`, so the tile store is in-memory and does not survive a
restart.

### 5.2 Route resolution
`packRouteResolverProvider` returns a straight line from the current position,
tagged `route_source: 'provisional'`, because the routing provider question
(TRD §12.1, Valhalla the leading candidate) is unresolved. The tag marks which
rides predate a real router.

### 5.3 Other
- Lock-screen bystander presentation is Phase 2; Phase 1 ships the notification
  action.
- P2P/BLE proximity for dead zones (PM-64) deferred.
- Viewer beacon has no rate limit; the abuse ceiling is "beacons in 5 minutes".
  An edge rate limit is the documented follow-up.
- FR-045 holiday/weekend awareness out of scope.
- FR-114 crowd-flagging UI not built (`hospitals.flag_count` exists).

---

## 6. Field validation still required

These cannot be settled by testing and must be measured on real hardware and real
roads before the pilot:

- **Chainage against a real Indian highway trace containing a cloverleaf.** The
  synthetic hairpin and self-crossing gates pass, but the TRD calls a real trace
  mandatory and it is the highest-risk piece of the algorithm.
- **`off_route_threshold_m = 150` is a hypothesis**, not a validated value.
  Divided highways with wide medians may need more; dense urban grids less.
- **Battery on Snapdragon 680-class hardware** (FR-034 targets <5%/hr; Pack Mode
  realistically 8–12%/hr). Measure on a Redmi/Realme, not a flagship.
- **Crash-detection thresholds** are undertested on real devices.
- **`unexplained_stop` false-positive rate.** It starts deliberately conservative.
  If the pack learns to ignore the flag it is worse than not shipping it.
- **Per-OEM tracking survival** (FR-036) — battery-optimisation whitelisting on
  Xiaomi/Oppo/Vivo is the known fragility.
