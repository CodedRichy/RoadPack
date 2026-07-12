# L1: Background Tracking & Commute Intelligence — Design Spec

**Date:** 2026-07-12
**Branch:** `feat/l1-tracking-commute`
**Scope:** Background location engine + commute intelligence (route learning, non-arrival alerts). Live map deferred to separate spec.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Activity recognition | OS APIs via flutter_background_geolocation | Battery-efficient, no custom sensor processing needed for Phase 1 |
| Route learning location | On-device (Drift SQLite) | Offline-first, privacy-preserving, no server dependency |
| Non-arrival detection | Server-driven (edge function + FCM push) | Catches the worst case: phone dead/offline |
| Location sync | Batch upload via FBG's HTTP sync service | Built-in retry, dedup, offline buffering |
| OEM battery | Heartbeat gap tracking + generic deviceSettings() prompt | Data-first: measure the problem before building per-OEM fixes |
| Architecture | FBG-Native (Approach A) | Purpose-built plugin handles OEM quirks; we build intelligence layer on top |

## 1. Background Location Engine

### 1.1 Duty Cycling State Machine

| State | GPS Interval | Accuracy | Battery | Trigger |
|-------|-------------|----------|---------|---------|
| Stationary | Off (geofence + motion) | ~500m | Negligible | No motion 5 min |
| Walking | 30s | ~50m | Low | Activity: on_foot |
| Commute | 5s | ~10m | Medium | Activity: in_vehicle on known route |
| SOS Active | 1s | ~3m | Maximum | Incident dispatched |

FBG's `Config` maps directly to these states. State transitions driven by FBG's `onActivityChange` callback + manual override for SOS.

### 1.2 FBG Configuration

```dart
BackgroundGeolocation.ready(Config(
  desiredAccuracy: Config.DESIRED_ACCURACY_HIGH,
  distanceFilter: 10,
  stopOnTerminate: false,
  startOnBoot: true,
  foregroundService: true,
  notification: Notification(
    title: 'RoadPack',
    text: 'Keeping you safe',
  ),
  // HTTP sync to Supabase
  url: '${supabaseUrl}/functions/v1/location-ingest',
  autoSync: true,
  batchSync: true,
  maxBatchSize: 50,
  headers: {'Authorization': 'Bearer {TOKEN}'},
  // Heartbeat
  heartbeatInterval: 900, // 15 min
  // Activity recognition
  activityRecognitionInterval: 10000,
  // Geofencing
  geofenceProximityRadius: 1000,
));
```

### 1.3 Heartbeat & Device Liveness

- FBG fires `onHeartbeat` every 15 min regardless of motion state
- Each heartbeat: POST to `location-ingest` with `is_heartbeat: true` flag
- Edge function updates `devices.last_heartbeat`
- `heartbeat-check` cron (every 5 min) detects gaps > 15 min during expected commute windows

### 1.4 Geofences

Auto-registered at:
- Known route origins (home) — exit triggers trip start
- Known route destinations (work/college) — enter triggers trip end

Geofence radius: 200m (configurable per-route).

## 2. Trip Detection State Machine

```
idle ──[motion + speed > 5km/h for 60s OR geofence exit]──> recording
                                                                 |
                                     [speed < 2km/h for 3 min   |   [distance < 500m
                                      OR geofence enter]        |    OR duration < 2 min]
                                                |               |           |
                                                v               |           v
                                           completed            |       discarded
                                                |               |
                                                v               |
                                             synced             |
                                                                |
                              idle <────────────────────────────-+
```

### 2.1 Trip Start Conditions
- Geofence exit at known origin, OR
- Sustained motion: speed > 5 km/h for > 60 seconds (prevents false starts from traffic jams, parking maneuvers)

### 2.2 Trip End Conditions
- Geofence enter at known destination, OR
- Speed < 2 km/h for > 3 minutes (parked/stopped)

### 2.3 Discard Rules
- Total distance < 500m (walked to mailbox)
- Duration < 2 min (moved car in parking lot)

### 2.4 Trip Data Captured
- Start time, end time
- Origin (lat, lng) — first stable position
- Destination (lat, lng) — last stable position
- Route geometry — encoded polyline from GPS trace
- Distance (meters) — sum of point-to-point distances
- Average speed, max speed
- Matched route ID (if matches a known route)

## 3. Route Learning (On-Device)

### 3.1 Algorithm

On trip completion:

1. **Cluster matching:** Search `route_candidates` for:
   - Origin within 500m of trip origin
   - Destination within 500m of trip destination
   - Start time within ±90 min of trip start

2. **If match found:**
   - Increment `trip_count`
   - Update centroid (rolling average of origin/destination)
   - Add day-of-week to `days_seen[]`
   - Update `typical_duration` (rolling average)
   - Update `typical_start` (rolling average)

3. **If no match:** Create new `route_candidates` row.

4. **Promotion threshold:** When `trip_count >= 3`:
   - Create `known_route` in local Drift DB
   - Sync to Supabase `known_routes` table
   - Register geofences at origin + destination
   - Calculate `confidence` = min(1.0, trip_count / 10)

### 3.2 Route Matching (for active trips)

During recording, check if current trip matches a known route:
- Origin within 500m of a known route's origin
- Time-of-day within known route's `typical_start ± 90 min`
- Day-of-week in known route's `days_active`

If matched: set `matched_route_id` on trip record. This enables non-arrival detection.

### 3.3 Manual Routes

Users can manually define routes (FR-041):
- Pick origin/destination on map (or from recent trips)
- Set schedule (days, typical start time)
- These bypass the 3-trip learning threshold

## 4. Non-Arrival Detection (Server-Side)

### 4.1 Detection Flow

**Edge function: `non-arrival-check`** (pg_cron every 2 min):

```
1. SELECT known_routes WHERE:
   - days_active includes current day-of-week
   - typical_start + typical_duration + delay_config < NOW
   - typical_start + typical_duration + delay_config + 30min > NOW
     (don't check routes from hours ago)
   - enabled = true

2. For each matching route:
   a. Check location_history for user's position near destination
      (within 500m, recorded in last 30 min)
   b. If NOT near destination AND no active incident for user:
      - Create incident (type: 'non_arrival', status: 'detected')
      - Send FCM high-priority data message:
        { type: 'check_in', incident_id, route_name, destination }
      - Insert cascade_jobs with delay_seconds: 300 (5 min grace)
```

### 4.2 User Response Flow

**Edge function: `check-in-response`**

User taps notification → app sends response to this function:

| Response | Action |
|----------|--------|
| "I'm fine" | Cancel incident. No circle alert. |
| "Running late" | Cancel incident. Optional: notify circle with calm "running late" message. Snooze 30 min. |
| "Need help" | Escalate immediately: dispatch full cascade (push → SMS → call). |
| No response (5 min) | `escalation-check` picks up: dispatch cascade to Family circle. |

### 4.3 Configuration

Per-user settings (stored in `users` table or dedicated config):
- `non_arrival_delay`: 10 / 15 (default) / 30 min
- `non_arrival_enabled`: boolean (default true)

Per-route override:
- `enabled`: boolean (some routes don't need monitoring)

## 5. Location Sync

### 5.1 Ingest Edge Function

**`location-ingest/index.ts`** — receives batch POSTs from FBG:

```typescript
// POST body (FBG format):
{
  location: [
    { timestamp, coords: { latitude, longitude, speed, heading, accuracy, altitude } },
    ...
  ]
}

// Actions:
// 1. Verify JWT (using _shared/jwt.ts)
// 2. Bulk insert into location_history
// 3. Update devices.last_heartbeat
// 4. Return 200 (FBG marks batch as synced)
```

### 5.2 Auth Token Refresh

FBG's `authorization` config handles token refresh:
```dart
Config(
  authorization: Authorization(
    strategy: Authorization.STRATEGY_JWT,
    accessToken: currentToken,
    refreshUrl: '${supabaseUrl}/functions/v1/token-refresh',
    refreshToken: refreshToken,
  ),
)
```

**Chosen approach:** Dynamically update FBG headers via `BackgroundGeolocation.setConfig()` when ClerkService refreshes the token. Listen to Clerk's `sessionTokenStream` and push new headers to FBG. No custom refresh endpoint needed.

### 5.3 Route Sync (Drift ↔ Supabase)

- **Up-sync:** On route promotion (3+ trips), insert into Supabase `known_routes`.
- **Down-sync:** On app foreground, pull `known_routes` from Supabase → merge into Drift. Handles manually-created routes.
- **Conflict resolution:** Server wins (higher trip count or manual creation takes precedence).

## 6. Local Database Schema (Drift)

### 6.1 Tables

```dart
class Trips extends Table {
  TextColumn get id => text()();  // UUID
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();
  RealColumn get originLat => real()();
  RealColumn get originLng => real()();
  RealColumn get destLat => real().nullable()();
  RealColumn get destLng => real().nullable()();
  RealColumn get distanceMeters => real().nullable()();
  TextColumn get routeGeometry => text().nullable()();  // encoded polyline
  TextColumn get state => text()();  // recording, completed, discarded, synced
  TextColumn get matchedRouteId => text().nullable()();
  
  @override
  Set<Column> get primaryKey => {id};
}

class RouteCandidates extends Table {
  TextColumn get id => text()();
  RealColumn get originLat => real()();
  RealColumn get originLng => real()();
  RealColumn get destLat => real()();
  RealColumn get destLng => real()();
  IntColumn get tripCount => integer().withDefault(const Constant(1))();
  TextColumn get daysSeen => text()();  // JSON array of day numbers [1,2,3,4,5]
  TextColumn get typicalStart => text().nullable()();  // HH:mm
  IntColumn get typicalDurationMin => integer().nullable()();
  DateTimeColumn get lastTripAt => dateTime()();
  
  @override
  Set<Column> get primaryKey => {id};
}

class KnownRoutesLocal extends Table {
  TextColumn get id => text()();  // matches Supabase known_routes.id
  TextColumn get name => text().nullable()();
  RealColumn get originLat => real()();
  RealColumn get originLng => real()();
  RealColumn get destLat => real()();
  RealColumn get destLng => real()();
  TextColumn get routeGeometry => text().nullable()();
  TextColumn get typicalStart => text().nullable()();  // HH:mm
  IntColumn get typicalDurationMin => integer().nullable()();
  TextColumn get daysActive => text()();  // JSON array [1,2,3,4,5]
  RealColumn get confidence => real().withDefault(const Constant(0))();
  IntColumn get repetitionCount => integer().withDefault(const Constant(0))();
  BoolColumn get nonArrivalEnabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastTraveled => dateTime().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  
  @override
  Set<Column> get primaryKey => {id};
}
```

## 7. Migration

**`00016_add_non_arrival_config.sql`:**

```sql
ALTER TABLE users ADD COLUMN non_arrival_delay_min INT DEFAULT 15;
ALTER TABLE users ADD COLUMN non_arrival_enabled BOOLEAN DEFAULT true;
ALTER TABLE known_routes ADD COLUMN non_arrival_enabled BOOLEAN DEFAULT true;
```

## 8. Edge Functions (New/Rewritten)

| Function | Trigger | Purpose |
|----------|---------|---------|
| `location-ingest` | FBG HTTP POST | Bulk insert locations, update heartbeat |
| `non-arrival-check` | pg_cron every 2 min | Detect overdue arrivals, send check-in push |
| `heartbeat-check` | pg_cron every 5 min | Detect lost contact during commutes |
| `check-in-response` | User POST | Handle "I'm fine" / "Running late" / "Need help" |

## 9. Flutter File Structure

```
app/lib/features/tracking/
  db/
    tracking_database.dart       -- Drift schema
    tracking_database.g.dart     -- generated
  models/
    trip.dart                    -- Freezed Trip model
    route_candidate.dart         -- Freezed RouteCandidate model  
    tracking_state.dart          -- enum: idle/recording/syncing
  services/
    tracking_service.dart        -- FBG lifecycle, config, state transitions
    trip_detector.dart           -- trip start/end state machine
    route_learner.dart           -- on-device clustering algorithm
  providers/
    tracking_provider.dart       -- exposes tracking state, active trip
    known_routes_provider.dart   -- Supabase ↔ Drift sync
    trip_history_provider.dart   -- completed trips list
  widgets/
    tracking_status_indicator.dart -- shows current tracking state in UI
  screens/
    routes_screen.dart           -- list known routes, enable/disable non-arrival
    trip_history_screen.dart     -- past trips
```

## 10. Testing Strategy

- **Unit tests:** Route learner algorithm (clustering, promotion threshold, centroid updates)
- **Unit tests:** Trip detector state machine (all transitions, discard rules)
- **Integration tests:** FBG mock → trip detection → route learning pipeline
- **Edge function tests:** non-arrival-check with mocked DB state
- **Manual testing:** Real rides with GPS recording, verify route learning after 3 trips

## 11. Privacy & Security

- Raw GPS never leaves device unless user has tracking enabled for a circle
- Synced `location_history` protected by RLS (user sees own + circle members with `location_sharing` enabled)
- Known routes are user-private (RLS: `user_id = requesting_user_id()`)
- Non-arrival alerts only notify Family circle (not friends/commute/convoy)
- "Running late" messages are opt-in and generic (no location shared)

## 12. Out of Scope (Deferred)

- Live map (separate spec)
- Custom per-OEM battery optimization instruction screens
- Offline map tiles / PMTiles
- Convoy mode (L4)
- Adaptive interval based on road geometry (FR-033)
- Battery attribution UI (FR-035)
- Academic calendar import (FR-045)
