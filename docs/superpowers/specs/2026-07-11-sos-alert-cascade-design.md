# SOS + Alert Cascade Design Spec

**Date:** 2026-07-11
**Status:** Draft
**PRD refs:** FR-070..075 (SOS), FR-100..104 (Cascade)
**Phase:** 1 (MVP)

---

## 1. Scope

**In scope:**
- Manual SOS trigger (long-press button, 5s countdown, incident creation)
- Server-side alert cascade (push + SMS + voice, per-contact sequential)
- Acknowledgment loop (app tap, SMS reply, IVR keypress)
- Terminal escalation (10 min no-ack rule)
- Incident resolution (victim or circle admin)
- Channel abstraction layer (mock SMS/voice for Phase 1, real FCM push)

**Out of scope (deferred):**
- Crash detection (Phase 2, separate spec)
- Inactivity/non-arrival detection (Phase 2)
- Bystander mode (Phase 2)
- Hospital finder (separate spec)
- Incident timeline UI beyond basic status
- Location streaming post-SOS (tracking feature)
- SMS uplink from victim's phone (Play policy complexity)
- WhatsApp channel (Phase 3)
- Hardware/voice triggers (Phase 4)

## 2. Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | Supabase Edge Functions + pg_cron, not BullMQ + Redis | Simpler deploy for Phase 1. Migrate to BullMQ when cascade volume demands it. |
| D2 | Mock SMS/voice channels first, real FCM push | MSG91 needs DLT registration (weeks). Exotel needs account. Channel abstraction lets us swap in real providers later. |
| D3 | 5-second countdown for SOS | PRD FR-071. Intent is explicit, shorter than crash detection's 30s. |
| D4 | No countdown on server | Client handles countdown. By the time the packet reaches the server, user already had 5s to cancel. Server dispatches immediately. |
| D5 | Single cascade invocation with delays | alert-cascade Edge Function runs ~60s total. Push at t=0, SMS at t=5s, voice at t=30s. Within Deno's 150s limit. |
| D6 | pg_cron for escalation + retry | 1-minute granularity. Catches cascade crashes (no alert rows after 60s) and no-ack escalation (10 min). |
| D7 | Snapshot location only | No continuous streaming post-SOS in Phase 1. Captured at dispatch time. |
| D8 | Max 3 active incidents per user | Rate limiting. Prevents abuse and stuck state. |

## 3. Architecture

```
Phone: SOS button -> 5s countdown -> incident packet (< 300 bytes)
  |
  v
incident-receive (Edge Function):
  validate JWT + payload -> insert incidents row -> fire alert-cascade
  |
  v
alert-cascade (Edge Function):
  per contact (ordered by priority):
    t=0s  -> FCM push (if is_app_user)
    t=5s  -> SMS (mock channel / MSG91)
    t=30s -> Voice call (mock channel / Exotel)
  |
  v
Webhook Edge Functions:
  sms-webhook  <- MSG91 delivery receipts + "OK" reply
  voice-webhook <- Exotel IVR keypress
  -> update incident_alerts rows
  |
  v
pg_cron (every minute):
  - escalation-check: dispatched + no ack + >10 min -> re-cascade next-priority contacts
  - cascade-retry: dispatched + zero alert rows + >60s -> re-invoke alert-cascade
  |
  v
Resolution:
  victim "I'm okay" OR circle admin resolves
  -> status = 'resolved', "all clear" push to all alerted contacts
```

## 4. Client Side (Flutter)

### 4.1 SOS State Machine

```
idle -> armed (long-press 2s) -> countdown (5s) -> dispatching -> active -> resolved
                                    |
                                    v
                                cancelled (user taps cancel)
```

Provider: `sosStateProvider` (Riverpod StateNotifier)

States:
- `idle` — default, SOS button visible
- `armed` — long-press detected, haptic fires, transitioning to countdown
- `countdown` — full-screen countdown with cancel button, alarm sound, vibration
- `dispatching` — capturing location, sending packet to server
- `active` — alerts sent, showing status screen
- `resolved` — user or admin resolved, showing confirmation

### 4.2 Incident Packet

Sent to `incident-receive` Edge Function. Designed for 2G (< 300 bytes):

```json
{
  "type": "sos",
  "lat": 9.9816,
  "lng": 76.2999,
  "speed": 42.5,
  "heading": 180,
  "ts": 1720684800,
  "battery": 67
}
```

User ID extracted from Clerk JWT on server side.

### 4.3 Widget Tree

| Widget | Purpose |
|--------|---------|
| `SosOverlay` | App-level overlay wrapping MaterialApp. Renders FAB on every screen. |
| `SosCountdownScreen` | Full-screen, over lock screen (Android full-screen intent). 5s countdown, large CANCEL button, alarm + vibration. |
| `SosActiveScreen` | Post-dispatch. Shows "Alerts sent", incident status, "I'm okay" resolve button. |
| `SosButton` | The FAB itself. Long-press 2s to arm. Visual feedback (color change, haptic). |

### 4.4 SOS Service

`SosService` — handles orchestration:
- Location capture (Geolocator, single high-accuracy fix, 10s timeout)
- HTTP POST to `incident-receive`
- Fallback: if location fails, send with last known location from cache + `location_stale: true`
- If HTTP fails: retry 2x with 5s backoff, then store locally for retry when connectivity returns

### 4.5 Alert Receiving (Contact Side)

When a contact receives a push notification:
- Rich notification with action buttons: "Acknowledge", "Call 112", "Call [Victim]"
- Tapping notification opens alert detail screen
- `AlertDetailScreen` shows: victim name, map with pin, timestamp, speed, nearest hospital, acknowledge button, call buttons
- Acknowledging calls `acknowledge-incident` Edge Function

### 4.6 Feature Folder Structure

```
app/lib/features/sos/
  models/
    sos_state.dart          # SosState enum + freezed state class
    incident.dart           # Incident model (matches DB schema)
    incident_alert.dart     # IncidentAlert model
  providers/
    sos_state_provider.dart # StateNotifier<SosState>
    incident_provider.dart  # Active incident data
  services/
    sos_service.dart        # Location capture, HTTP, retry
  screens/
    sos_countdown_screen.dart
    sos_active_screen.dart
  widgets/
    sos_button.dart         # The FAB
    sos_overlay.dart        # App-level overlay

app/lib/features/alerts/
  models/
    alert_notification.dart # Parsed push notification payload
  providers/
    alerts_provider.dart    # Incoming alerts for this user-as-contact
  screens/
    alert_detail_screen.dart
  services/
    alert_service.dart      # Acknowledge, resolve
  widgets/
    alert_card.dart         # Alert summary in list
```

## 5. Server Side (Supabase Edge Functions)

### 5.1 incident-receive

**Endpoint:** `POST /functions/v1/incident-receive`
**Auth:** Clerk JWT (Bearer token)

Steps:
1. Validate JWT, extract `user_id`
2. Validate payload: `type` must be `'sos'`, lat/lng within India bounds (-90..90, valid), timestamp not stale (> 5 min old), battery 0-100
3. Check rate limit: count active incidents for user (status not in `cancelled`, `resolved`). If >= 3, return 429.
4. Insert `incidents` row: `user_id`, `type: 'sos'`, `location: ST_Point(lng, lat, 4326)`, `speed_at_event`, `status: 'dispatched'`, `sensor_data: { heading, battery }`
5. Fetch emergency contacts: `SELECT * FROM emergency_contacts WHERE user_id = $1 AND opted_out = false ORDER BY priority`. If zero contacts: still create incident (for audit), return `{ incident_id, status: 'dispatched', warning: 'no_contacts' }`. Client shows "No emergency contacts configured" with link to add contacts. No cascade invoked.
6. Fetch user profile: `SELECT full_name, phone FROM users WHERE id = $1`
7. Insert `cascade_jobs` row: `incident_id`, `started_at: now()`
8. Invoke `alert-cascade` via fetch (fire-and-forget): `POST /functions/v1/alert-cascade` with `{ incident_id, contacts, user_profile, location }`
9. Return `{ incident_id, status: 'dispatched' }` (HTTP 201)

**Error responses:**
- 401: Invalid/missing JWT
- 422: Invalid payload
- 429: Too many active incidents
- 500: DB error

### 5.2 alert-cascade

**Endpoint:** `POST /functions/v1/alert-cascade`
**Auth:** Service role key (internal invocation only, not exposed to client)

Input:
```typescript
{
  incident_id: string
  contacts: EmergencyContact[]
  user_profile: { full_name: string, phone: string }
  location: { lat: number, lng: number, address?: string }
}
```

Steps per contact (sequential by priority):
1. **Check incident still active:** `SELECT status FROM incidents WHERE id = $1`. If cancelled/resolved, abort.
2. **Push (t=0s):** If `contact.is_app_user && contact.app_user_id`:
   - Insert `incident_alerts` row: `channel: 'push', status: 'queued'`
   - Send FCM notification to contact's device token (from `devices` table)
   - Update row: `status: 'sent'`, `sent_at: now()`
   - On failure: `status: 'failed'`, `error: <message>`
3. **SMS (t=+5s):** `await delay(5000)`
   - Re-check incident active + contact not already ack'd
   - Insert `incident_alerts` row: `channel: 'sms', status: 'queued'`
   - Call SMS channel (mock or MSG91): send alert text to `contact.phone`
   - Update status
4. **Voice (t=+30s):** `await delay(25000)` (30s from start, 25s after SMS)
   - Re-check incident active + contact not already ack'd
   - Insert `incident_alerts` row: `channel: 'call', status: 'queued'`
   - Call voice channel (mock or Exotel): TTS message + IVR to `contact.phone`
   - Update status
5. After all contacts processed: update `cascade_jobs.completed_at`

**Channel abstraction:**

```typescript
interface AlertChannel {
  send(payload: AlertPayload): Promise<ChannelResult>
}

interface AlertPayload {
  recipient_phone: string
  recipient_name: string
  victim_name: string
  victim_phone: string
  location: { lat: number, lng: number, address?: string }
  maps_link: string
  incident_id: string
}

interface ChannelResult {
  success: boolean
  provider_id?: string  // MSG91 request ID, Exotel call SID, etc.
  error?: string
}

// Implementations:
class FcmChannel implements AlertChannel { ... }
class MockSmsChannel implements AlertChannel { ... }  // logs to incident_alerts only
class MockVoiceChannel implements AlertChannel { ... } // logs to incident_alerts only
class Msg91Channel implements AlertChannel { ... }     // real, swap in later
class ExotelChannel implements AlertChannel { ... }    // real, swap in later
```

Channel selection via env var: `SMS_PROVIDER=mock|msg91`, `VOICE_PROVIDER=mock|exotel`

### 5.3 Alert Content Templates

**Push notification (FCM):**
```
Title: EMERGENCY ALERT - RoadPack
Body: [Name] may have been in an accident.
      Location: [Address]
      Tap to view details and acknowledge.
Data: { incident_id, lat, lng, victim_name, victim_phone }
```

**SMS (<=2 segments, ~300 chars):**
```
ROADPACK ALERT: [Name] accident at [Location]. Map: [shortURL]. Call 112. Call [Name]: [Number]. Reply OK.
```

**Voice TTS:**
```
This is an emergency alert from RoadPack. [Name] may have been in an accident at [location]. Press 1 to acknowledge. Press 2 to call 112.
```

### 5.4 sms-webhook

**Endpoint:** `POST /functions/v1/sms-webhook`
**Auth:** MSG91 webhook signature verification (or IP allowlist for mock)

Handles:
- **Delivery receipts:** Match `provider_id` to `incident_alerts` row, update `status: 'delivered'`, `delivered_at`
- **Inbound reply "OK":** Match sender phone to `emergency_contacts.phone`, find active `incident_alerts` for that contact, update `acknowledged_at`, `ack_method: 'sms'`
- Trigger ack broadcast (see Section 6)

### 5.5 voice-webhook

**Endpoint:** `POST /functions/v1/voice-webhook`
**Auth:** Exotel webhook signature verification

Handles:
- **Call status:** answered/unanswered/busy/failed -> update `incident_alerts.status`
- **IVR keypress "1":** Acknowledge. Update `acknowledged_at`, `ack_method: 'ivr'`
- **IVR keypress "2":** Connect to 112 (Exotel call transfer). Still counts as ack.
- Trigger ack broadcast

### 5.6 acknowledge-incident (new Edge Function)

**Endpoint:** `POST /functions/v1/acknowledge-incident`
**Auth:** Clerk JWT

Input: `{ incident_id: string }`

Steps:
1. Extract user_id from JWT
2. Find `incident_alerts` rows where contact matches this user (via `emergency_contacts.app_user_id`)
3. Update all matching rows: `acknowledged_at: now()`, `ack_method: 'app'`
4. If this is the first ack for this incident: update `incidents.first_ack_at`
5. Broadcast ack via Supabase Realtime on channel `incident:{incident_id}`
6. Return 200

## 6. Acknowledgment & Resolution

### 6.1 First Ack Broadcast

When any contact acknowledges (via any channel):
1. Set `incidents.first_ack_at` if null
2. Push notification to all circle members: "[Contact name] has seen the alert for [Victim name]"
3. Publish to Supabase Realtime channel `incident:{incident_id}`: `{ type: 'ack', contact_name, method, timestamp }`
4. Cancel pending (queued, not yet sent) channels for this specific contact. Do NOT cancel other contacts' cascades.

### 6.2 Incident Resolution

Two paths:
- **Victim resolves:** "I'm okay" button in `SosActiveScreen` -> `POST /functions/v1/resolve-incident` with `{ incident_id }`
- **Circle admin resolves:** Same endpoint, authorized if `is_circle_admin(user_id, any_circle_containing_victim)`

On resolve:
1. `incidents.status = 'resolved'`, `resolved_at = now()`
2. Push "all clear" notification to every contact who received an alert
3. Publish to Realtime channel: `{ type: 'resolved', resolved_by, timestamp }`
4. Cancel any pending cascade steps

### 6.3 resolve-incident (new Edge Function)

**Endpoint:** `POST /functions/v1/resolve-incident`
**Auth:** Clerk JWT

Steps:
1. Extract user_id
2. Fetch incident. Verify user is either the victim OR is admin of at least one circle that also contains the victim
3. Update `incidents.status = 'resolved'`, `resolved_at = now()`
4. Send "all clear" push to all contacts with `incident_alerts` rows for this incident
5. Return 200

## 7. Terminal Escalation

### 7.1 escalation-check (new Edge Function, invoked by pg_cron)

**Endpoint:** `POST /functions/v1/escalation-check`
**Auth:** Service role key
**Schedule:** Every minute via pg_cron

Query:
```sql
SELECT i.id, i.user_id, i.location, i.created_at
FROM incidents i
LEFT JOIN cascade_jobs cj ON cj.incident_id = i.id
WHERE i.status = 'dispatched'
  AND i.first_ack_at IS NULL
  AND i.created_at < now() - interval '10 minutes'
```

For each match:
1. Update `incidents.status = 'escalated'`
2. Fetch next-priority emergency contacts not yet in `incident_alerts` for this incident
3. If contacts exist: invoke `alert-cascade` with those contacts
4. Alert ALL circle members (not just ECs) via push: "[Name] emergency -- no contact has responded. Please check on them."
5. If already escalated AND `created_at < now() - interval '20 minutes'`: send final push to all: "Call 112 now. [Name] has not been reached." No further escalation.

### 7.2 cascade-retry (same function or separate)

In the same `escalation-check` run:
```sql
SELECT i.id FROM incidents i
LEFT JOIN incident_alerts ia ON ia.incident_id = i.id
WHERE i.status = 'dispatched'
  AND ia.id IS NULL
  AND i.created_at < now() - interval '1 minute'
```

For each: re-invoke `alert-cascade`. Increment `cascade_jobs.retry_count`. Give up after 3 retries (update incident status to `'failed'`, alert to error monitoring).

## 8. DB Changes

### 8.1 New Table: cascade_jobs

```sql
CREATE TABLE cascade_jobs (
    incident_id  UUID PRIMARY KEY REFERENCES incidents(id) ON DELETE CASCADE,
    started_at   TIMESTAMPTZ DEFAULT now(),
    completed_at TIMESTAMPTZ,
    retry_count  INT DEFAULT 0
);

ALTER TABLE cascade_jobs ENABLE ROW LEVEL SECURITY;
-- No client access. Service role only.
```

### 8.2 New pg_cron Job

```sql
SELECT cron.schedule(
  'escalation-check',
  '* * * * *',
  $$SELECT net.http_post(
    url := current_setting('app.supabase_url') || '/functions/v1/escalation-check',
    body := '{}'::jsonb,
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || current_setting('app.service_role_key'),
      'Content-Type', 'application/json'
    )
  )$$
);
```

### 8.3 New Edge Functions Summary

| Function | Auth | Trigger |
|----------|------|---------|
| `incident-receive` | Clerk JWT | Client POST |
| `alert-cascade` | Service role | Internal invocation |
| `sms-webhook` | Provider signature | MSG91 callback |
| `voice-webhook` | Provider signature | Exotel callback |
| `acknowledge-incident` | Clerk JWT | Client POST (contact) |
| `resolve-incident` | Clerk JWT | Client POST (victim/admin) |
| `escalation-check` | Service role | pg_cron every minute |

Existing stubs: `incident-receive`, `alert-cascade`, `sms-webhook`, `voice-webhook` (all return 501).
New functions: `acknowledge-incident`, `resolve-incident`, `escalation-check`.

## 9. Error Handling

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Phone loses connectivity during SOS | Incident packet never reaches server | Retry 2x with 5s backoff. Store locally, retry on reconnect. |
| incident-receive crashes | No incident created | Client retries. Idempotency: check for existing active SOS incident for user before inserting. |
| alert-cascade crashes mid-run | Some contacts alerted, some not | pg_cron cascade-retry detects missing alert rows, re-invokes. Idempotent: skip contacts already alerted. |
| FCM delivery fails | Contact doesn't get push | SMS fires at t=5s regardless. Voice at t=30s. Multi-channel redundancy. |
| SMS provider down | Contact doesn't get SMS | Channel failure logged. Voice still fires. Provider swap possible via env var. |
| Voice provider down | No voice call | Two channels already attempted. Terminal escalation catches if nobody acks. |
| All channels fail for all contacts | Nobody knows | Terminal escalation at 10 min alerts all circle members. 20 min: "Call 112" final push. Monitoring alerts on-call. |
| False SOS (accidental) | Contacts alarmed unnecessarily | 2s long-press + 5s countdown. User can cancel. User can resolve immediately after dispatch. |

## 10. Testing Strategy

- **Unit tests:** SOS state machine transitions, incident packet construction, alert content formatting
- **Integration tests:** incident-receive -> DB insertion, alert-cascade -> incident_alerts rows created, ack flow -> status updates
- **Mock channel tests:** Verify mock SMS/voice channels log correctly to incident_alerts
- **Escalation tests:** Simulate 10-min no-ack, verify re-cascade and circle alerts
- **Client tests:** SOS countdown timer, cancel flow, location capture fallback
- **E2E canary (post-launch):** Synthetic incident hourly through full cascade against test numbers (PRD requirement)

## 11. Future Integration Points

- **Crash detection (Phase 2):** Creates incident with `type: 'crash_detected'`, 30s countdown on device, then same `incident-receive` + `alert-cascade` pipeline
- **Inactivity detection (Phase 2):** Same pipeline, `type: 'inactivity'`
- **WhatsApp channel (Phase 3):** Add `WhatsAppChannel` implementing `AlertChannel`, add to cascade sequence parallel to SMS
- **BullMQ migration:** Replace delay-based cascade with proper job queue. Channel abstraction stays the same.
- **Location streaming:** Post-SOS continuous location updates to Supabase Realtime, visible to contacts on map
