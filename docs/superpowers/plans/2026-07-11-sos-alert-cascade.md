# SOS + Alert Cascade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the manual SOS trigger (long-press, 5s countdown, incident dispatch) and server-side alert cascade (push + mock SMS/voice per emergency contact, ack loop, terminal escalation).

**Architecture:** Client captures SOS → sends incident packet to `incident-receive` Edge Function → server inserts incident and fires `alert-cascade` Edge Function → cascade dispatches push/SMS/voice per contact with delays → webhooks handle acks → pg_cron handles escalation and retry. Flutter side uses a Riverpod StateNotifier for SOS state machine and an overlay FAB accessible from every screen.

**Tech Stack:** Flutter + Riverpod (manual providers), Freezed models with custom fromJson, Supabase Edge Functions (Deno), FCM push, mock SMS/voice channels, pg_cron for escalation, Supabase Realtime for ack broadcast.

## Global Constraints

- Flutter: Riverpod manual providers, NOT `@riverpod` codegen
- Models: Freezed with custom `fromJson`, NOT `@JsonSerializable`
- DB: Supabase PostgreSQL + PostGIS, RLS enforced
- Auth: Clerk JWT (not Supabase Auth). User IDs are TEXT (Clerk IDs), not UUID
- Edge Functions: Deno `serve()` pattern, `@supabase/supabase-js@2`
- Shared enums in `shared/constants/event_types.dart` — use `IncidentType`, `IncidentStatus`, `AlertChannel`, `AlertStatus` from there
- `EmergencyContact` model already exists in `app/lib/features/circles/models/circle_member.dart`
- `AppConstants.sosCountdownDuration` already defined (5 seconds)
- Test framework: `flutter_test` + `mocktail`
- Commit messages: `feat(sos):` or `feat(cascade):` prefix

---

### Task 1: DB Migration — cascade_jobs table + pg_cron setup

**Files:**
- Create: `backend/supabase/migrations/00014_create_cascade_jobs.sql`

**Interfaces:**
- Consumes: `incidents` table (FK reference)
- Produces: `cascade_jobs` table with columns `incident_id UUID PK`, `started_at TIMESTAMPTZ`, `completed_at TIMESTAMPTZ`, `retry_count INT`; pg_cron job `escalation-check` scheduled every minute

- [ ] **Step 1: Write the migration SQL**

```sql
-- RoadPack v2: cascade job tracking + pg_cron escalation schedule

-- Enable pg_cron and pg_net extensions (idempotent)
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

CREATE TABLE cascade_jobs (
    incident_id  UUID PRIMARY KEY REFERENCES incidents(id) ON DELETE CASCADE,
    started_at   TIMESTAMPTZ DEFAULT now(),
    completed_at TIMESTAMPTZ,
    retry_count  INT DEFAULT 0
);

ALTER TABLE cascade_jobs ENABLE ROW LEVEL SECURITY;
-- No client-facing policies. Service role only.

-- pg_cron job: invoke escalation-check Edge Function every minute
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

Create file at `backend/supabase/migrations/00014_create_cascade_jobs.sql` with the above content.

- [ ] **Step 2: Verify migration is syntactically correct**

Run: `cd backend && cat supabase/migrations/00014_create_cascade_jobs.sql`

Verify: File exists, SQL is well-formed, references `incidents(id)` FK.

- [ ] **Step 3: Commit**

```bash
git add backend/supabase/migrations/00014_create_cascade_jobs.sql
git commit -m "feat(cascade): add cascade_jobs table and pg_cron escalation schedule"
```

---

### Task 2: Edge Function — incident-receive

**Files:**
- Modify: `backend/supabase/functions/incident-receive/index.ts` (replace stub)

**Interfaces:**
- Consumes: Clerk JWT (Bearer token), incident packet `{ type, lat, lng, speed, heading, ts, battery }`
- Produces: `{ incident_id: string, status: 'dispatched', warning?: 'no_contacts' }` (HTTP 201). Inserts into `incidents` and `cascade_jobs` tables. Fire-and-forget invocation of `alert-cascade` function.

- [ ] **Step 1: Write the incident-receive Edge Function**

Replace the entire contents of `backend/supabase/functions/incident-receive/index.ts` with:

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface IncidentPacket {
  type: string
  lat: number
  lng: number
  speed: number | null
  heading: number | null
  ts: number
  battery: number | null
}

function validatePacket(body: unknown): { valid: boolean; error?: string; packet?: IncidentPacket } {
  if (!body || typeof body !== 'object') return { valid: false, error: 'Missing body' }
  const p = body as Record<string, unknown>

  if (p.type !== 'sos') return { valid: false, error: 'type must be sos' }
  if (typeof p.lat !== 'number' || p.lat < -90 || p.lat > 90) return { valid: false, error: 'invalid lat' }
  if (typeof p.lng !== 'number' || p.lng < -180 || p.lng > 180) return { valid: false, error: 'invalid lng' }
  if (typeof p.ts !== 'number') return { valid: false, error: 'missing ts' }

  const ageMs = Date.now() - p.ts * 1000
  if (ageMs > 5 * 60 * 1000) return { valid: false, error: 'timestamp stale (>5 min)' }

  return {
    valid: true,
    packet: {
      type: p.type as string,
      lat: p.lat as number,
      lng: p.lng as number,
      speed: typeof p.speed === 'number' ? p.speed : null,
      heading: typeof p.heading === 'number' ? p.heading : null,
      ts: p.ts as number,
      battery: typeof p.battery === 'number' ? Math.min(100, Math.max(0, p.battery)) : null,
    },
  }
}

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  const authHeader = req.headers.get('Authorization')
  if (!authHeader?.startsWith('Bearer ')) {
    return new Response(JSON.stringify({ error: 'Missing auth token' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

  // Client with user's JWT for RLS-scoped reads
  const userClient = createClient(supabaseUrl, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authHeader } },
  })

  // Service client for writes that bypass RLS
  const serviceClient = createClient(supabaseUrl, serviceRoleKey)

  // Extract user_id from JWT
  const token = authHeader.slice(7)
  let userId: string
  try {
    const payload = JSON.parse(atob(token.split('.')[1]))
    userId = payload.sub
    if (!userId) throw new Error('no sub claim')
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid token' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  // Validate payload
  let body: unknown
  try {
    body = await req.json()
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON' }), {
      status: 422,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const validation = validatePacket(body)
  if (!validation.valid || !validation.packet) {
    return new Response(JSON.stringify({ error: validation.error }), {
      status: 422,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const packet = validation.packet

  // Rate limit: max 3 active incidents
  const { count, error: countError } = await serviceClient
    .from('incidents')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', userId)
    .not('status', 'in', '("cancelled","resolved")')

  if (countError) {
    return new Response(JSON.stringify({ error: 'DB error' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  if ((count ?? 0) >= 3) {
    return new Response(JSON.stringify({ error: 'Too many active incidents' }), {
      status: 429,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  // Insert incident
  const { data: incident, error: insertError } = await serviceClient
    .from('incidents')
    .insert({
      user_id: userId,
      type: 'sos',
      location: `POINT(${packet.lng} ${packet.lat})`,
      speed_at_event: packet.speed,
      status: 'dispatched',
      sensor_data: { heading: packet.heading, battery: packet.battery },
    })
    .select('id')
    .single()

  if (insertError || !incident) {
    return new Response(JSON.stringify({ error: 'Failed to create incident' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const incidentId = incident.id

  // Fetch emergency contacts
  const { data: contacts, error: contactsError } = await serviceClient
    .from('emergency_contacts')
    .select('*')
    .eq('user_id', userId)
    .eq('opted_out', false)
    .order('priority')

  if (contactsError) {
    return new Response(JSON.stringify({ error: 'Failed to fetch contacts' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  if (!contacts || contacts.length === 0) {
    return new Response(
      JSON.stringify({ incident_id: incidentId, status: 'dispatched', warning: 'no_contacts' }),
      { status: 201, headers: { 'Content-Type': 'application/json' } },
    )
  }

  // Fetch user profile
  const { data: profile } = await serviceClient
    .from('users')
    .select('name, phone')
    .eq('id', userId)
    .single()

  // Insert cascade_jobs row
  await serviceClient.from('cascade_jobs').insert({ incident_id: incidentId })

  // Fire-and-forget: invoke alert-cascade
  const cascadeUrl = `${supabaseUrl}/functions/v1/alert-cascade`
  fetch(cascadeUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${serviceRoleKey}`,
    },
    body: JSON.stringify({
      incident_id: incidentId,
      contacts,
      user_profile: profile ?? { name: 'Unknown', phone: '' },
      location: { lat: packet.lat, lng: packet.lng },
    }),
  }).catch((err) => console.error('Failed to invoke alert-cascade:', err))

  return new Response(
    JSON.stringify({ incident_id: incidentId, status: 'dispatched' }),
    { status: 201, headers: { 'Content-Type': 'application/json' } },
  )
})
```

- [ ] **Step 2: Verify the function reads correctly**

Run: `head -5 backend/supabase/functions/incident-receive/index.ts`
Expected: First import line visible, no 501 stub.

- [ ] **Step 3: Commit**

```bash
git add backend/supabase/functions/incident-receive/index.ts
git commit -m "feat(cascade): implement incident-receive Edge Function"
```

---

### Task 3: Edge Function — alert-cascade with channel abstraction

**Files:**
- Modify: `backend/supabase/functions/alert-cascade/index.ts` (replace stub)
- Create: `backend/supabase/functions/_shared/channels.ts`

**Interfaces:**
- Consumes: `{ incident_id, contacts, user_profile, location }` from `incident-receive`
- Produces: Rows in `incident_alerts` table (one per channel per contact). Updates `cascade_jobs.completed_at`. Channel abstraction: `AlertChannel` interface with `FcmChannel`, `MockSmsChannel`, `MockVoiceChannel` implementations.

- [ ] **Step 1: Create the shared channel abstraction**

Create `backend/supabase/functions/_shared/channels.ts`:

```typescript
export interface AlertPayload {
  recipient_phone: string
  recipient_name: string
  victim_name: string
  victim_phone: string
  location: { lat: number; lng: number; address?: string }
  maps_link: string
  incident_id: string
}

export interface ChannelResult {
  success: boolean
  provider_id?: string
  error?: string
}

export interface AlertChannel {
  send(payload: AlertPayload): Promise<ChannelResult>
}

export class FcmChannel implements AlertChannel {
  async send(payload: AlertPayload): Promise<ChannelResult> {
    // FCM implementation — requires GOOGLE_SERVICE_ACCOUNT_KEY env var
    // For Phase 1, this is a structured mock that logs the payload
    console.log('[FCM] Would send push:', JSON.stringify({
      title: 'EMERGENCY ALERT - RoadPack',
      body: `${payload.victim_name} may have been in an accident.`,
      data: {
        incident_id: payload.incident_id,
        lat: payload.location.lat,
        lng: payload.location.lng,
        victim_name: payload.victim_name,
        victim_phone: payload.victim_phone,
      },
    }))
    return { success: true, provider_id: `fcm_mock_${Date.now()}` }
  }
}

export class MockSmsChannel implements AlertChannel {
  async send(payload: AlertPayload): Promise<ChannelResult> {
    const message = `ROADPACK ALERT: ${payload.victim_name} accident at ${payload.location.lat},${payload.location.lng}. Map: ${payload.maps_link}. Call 112. Call ${payload.victim_name}: ${payload.victim_phone}. Reply OK.`
    console.log(`[MockSMS] To: ${payload.recipient_phone} | ${message}`)
    return { success: true, provider_id: `sms_mock_${Date.now()}` }
  }
}

export class MockVoiceChannel implements AlertChannel {
  async send(payload: AlertPayload): Promise<ChannelResult> {
    const script = `This is an emergency alert from RoadPack. ${payload.victim_name} may have been in an accident at ${payload.location.lat},${payload.location.lng}. Press 1 to acknowledge. Press 2 to call 112.`
    console.log(`[MockVoice] To: ${payload.recipient_phone} | ${script}`)
    return { success: true, provider_id: `voice_mock_${Date.now()}` }
  }
}

export function getChannel(type: 'push' | 'sms' | 'call'): AlertChannel {
  switch (type) {
    case 'push': return new FcmChannel()
    case 'sms': {
      const provider = Deno.env.get('SMS_PROVIDER') ?? 'mock'
      if (provider === 'mock') return new MockSmsChannel()
      throw new Error(`SMS provider '${provider}' not yet implemented`)
    }
    case 'call': {
      const provider = Deno.env.get('VOICE_PROVIDER') ?? 'mock'
      if (provider === 'mock') return new MockVoiceChannel()
      throw new Error(`Voice provider '${provider}' not yet implemented`)
    }
  }
}

export function buildAlertPayload(
  contact: { name: string; phone: string },
  userProfile: { name: string; phone: string },
  location: { lat: number; lng: number },
  incidentId: string,
): AlertPayload {
  return {
    recipient_phone: contact.phone,
    recipient_name: contact.name,
    victim_name: userProfile.name,
    victim_phone: userProfile.phone,
    location,
    maps_link: `https://maps.google.com/?q=${location.lat},${location.lng}`,
    incident_id: incidentId,
  }
}
```

- [ ] **Step 2: Write the alert-cascade Edge Function**

Replace `backend/supabase/functions/alert-cascade/index.ts` with:

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { getChannel, buildAlertPayload } from '../_shared/channels.ts'

interface CascadeInput {
  incident_id: string
  contacts: Array<{
    id: string
    name: string
    phone: string
    is_app_user: boolean
    app_user_id: string | null
    alert_method: string[]
  }>
  user_profile: { name: string; phone: string }
  location: { lat: number; lng: number }
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  const authHeader = req.headers.get('Authorization')
  if (authHeader !== `Bearer ${serviceRoleKey}`) {
    return new Response('Unauthorized', { status: 401 })
  }

  const input: CascadeInput = await req.json()
  const { incident_id, contacts, user_profile, location } = input

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    serviceRoleKey,
  )

  async function isIncidentActive(): Promise<boolean> {
    const { data } = await supabase
      .from('incidents')
      .select('status')
      .eq('id', incident_id)
      .single()
    return data?.status === 'dispatched' || data?.status === 'escalated'
  }

  async function isContactAcknowledged(contactId: string): Promise<boolean> {
    const { data } = await supabase
      .from('incident_alerts')
      .select('acknowledged_at')
      .eq('incident_id', incident_id)
      .eq('contact_id', contactId)
      .not('acknowledged_at', 'is', null)
      .limit(1)
    return (data?.length ?? 0) > 0
  }

  async function sendChannel(
    channelType: 'push' | 'sms' | 'call',
    contactId: string,
    payload: ReturnType<typeof buildAlertPayload>,
  ): Promise<void> {
    // Insert queued row
    const { data: alertRow } = await supabase
      .from('incident_alerts')
      .insert({
        incident_id,
        contact_id: contactId,
        channel: channelType,
        status: 'queued',
      })
      .select('id')
      .single()

    if (!alertRow) return

    try {
      const channel = getChannel(channelType)
      const result = await channel.send(payload)

      await supabase
        .from('incident_alerts')
        .update({
          status: result.success ? 'sent' : 'failed',
          sent_at: new Date().toISOString(),
          error: result.error ?? null,
        })
        .eq('id', alertRow.id)
    } catch (err) {
      await supabase
        .from('incident_alerts')
        .update({
          status: 'failed',
          error: err instanceof Error ? err.message : String(err),
        })
        .eq('id', alertRow.id)
    }
  }

  // Process each contact sequentially by priority
  for (const contact of contacts) {
    if (!await isIncidentActive()) break

    const payload = buildAlertPayload(
      { name: contact.name, phone: contact.phone },
      user_profile,
      location,
      incident_id,
    )

    // Push (t=0s) — only if contact has the app
    if (contact.is_app_user && contact.app_user_id) {
      await sendChannel('push', contact.id, payload)
    }

    // SMS (t=+5s)
    await delay(5000)
    if (!await isIncidentActive()) break
    if (await isContactAcknowledged(contact.id)) continue
    await sendChannel('sms', contact.id, payload)

    // Voice (t=+30s from start, so +25s after SMS)
    await delay(25000)
    if (!await isIncidentActive()) break
    if (await isContactAcknowledged(contact.id)) continue
    await sendChannel('call', contact.id, payload)
  }

  // Mark cascade complete
  await supabase
    .from('cascade_jobs')
    .update({ completed_at: new Date().toISOString() })
    .eq('incident_id', incident_id)

  return new Response(
    JSON.stringify({ status: 'completed', incident_id }),
    { headers: { 'Content-Type': 'application/json' } },
  )
})
```

- [ ] **Step 3: Verify files exist**

Run: `ls backend/supabase/functions/_shared/channels.ts backend/supabase/functions/alert-cascade/index.ts`
Expected: Both files listed.

- [ ] **Step 4: Commit**

```bash
git add backend/supabase/functions/_shared/channels.ts backend/supabase/functions/alert-cascade/index.ts
git commit -m "feat(cascade): implement alert-cascade Edge Function with channel abstraction"
```

---

### Task 4: Edge Functions — acknowledge-incident + resolve-incident

**Files:**
- Create: `backend/supabase/functions/acknowledge-incident/index.ts`
- Create: `backend/supabase/functions/resolve-incident/index.ts`

**Interfaces:**
- `acknowledge-incident` consumes: Clerk JWT + `{ incident_id }`. Updates `incident_alerts.acknowledged_at`, sets `incidents.first_ack_at` if first ack. Returns `{ status: 'acknowledged' }`.
- `resolve-incident` consumes: Clerk JWT + `{ incident_id }`. Sets `incidents.status = 'resolved'`. Returns `{ status: 'resolved' }`.
- Both produce: Supabase Realtime broadcast on channel `incident:{id}`.

- [ ] **Step 1: Write acknowledge-incident**

Create `backend/supabase/functions/acknowledge-incident/index.ts`:

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  const authHeader = req.headers.get('Authorization')
  if (!authHeader?.startsWith('Bearer ')) {
    return new Response(JSON.stringify({ error: 'Missing auth token' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  // Extract user_id from JWT
  const token = authHeader.slice(7)
  let userId: string
  try {
    const payload = JSON.parse(atob(token.split('.')[1]))
    userId = payload.sub
    if (!userId) throw new Error('no sub claim')
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid token' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const { incident_id } = await req.json()
  if (!incident_id) {
    return new Response(JSON.stringify({ error: 'Missing incident_id' }), {
      status: 422,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  // Find this user's contact IDs
  const { data: contacts } = await supabase
    .from('emergency_contacts')
    .select('id')
    .eq('app_user_id', userId)

  if (!contacts || contacts.length === 0) {
    return new Response(JSON.stringify({ error: 'Not a contact for this incident' }), {
      status: 403,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const contactIds = contacts.map((c: { id: string }) => c.id)
  const now = new Date().toISOString()

  // Update all matching incident_alerts rows
  const { error: updateError } = await supabase
    .from('incident_alerts')
    .update({ acknowledged_at: now, ack_method: 'app' })
    .eq('incident_id', incident_id)
    .in('contact_id', contactIds)
    .is('acknowledged_at', null)

  if (updateError) {
    return new Response(JSON.stringify({ error: 'Failed to acknowledge' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  // Set first_ack_at on incident if this is the first ack
  await supabase
    .from('incidents')
    .update({ first_ack_at: now })
    .eq('id', incident_id)
    .is('first_ack_at', null)

  // Fetch acknowledger's name for broadcast
  const { data: acker } = await supabase
    .from('users')
    .select('name')
    .eq('id', userId)
    .single()

  // Broadcast ack via Realtime
  const channel = supabase.channel(`incident:${incident_id}`)
  await channel.send({
    type: 'broadcast',
    event: 'ack',
    payload: {
      contact_name: acker?.name ?? 'Someone',
      method: 'app',
      timestamp: now,
    },
  })

  return new Response(
    JSON.stringify({ status: 'acknowledged' }),
    { headers: { 'Content-Type': 'application/json' } },
  )
})
```

- [ ] **Step 2: Write resolve-incident**

Create `backend/supabase/functions/resolve-incident/index.ts`:

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  const authHeader = req.headers.get('Authorization')
  if (!authHeader?.startsWith('Bearer ')) {
    return new Response(JSON.stringify({ error: 'Missing auth token' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const token = authHeader.slice(7)
  let userId: string
  try {
    const payload = JSON.parse(atob(token.split('.')[1]))
    userId = payload.sub
    if (!userId) throw new Error('no sub claim')
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid token' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const { incident_id } = await req.json()
  if (!incident_id) {
    return new Response(JSON.stringify({ error: 'Missing incident_id' }), {
      status: 422,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  // Fetch incident
  const { data: incident } = await supabase
    .from('incidents')
    .select('id, user_id, status')
    .eq('id', incident_id)
    .single()

  if (!incident) {
    return new Response(JSON.stringify({ error: 'Incident not found' }), {
      status: 404,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  if (incident.status === 'resolved' || incident.status === 'cancelled') {
    return new Response(JSON.stringify({ error: 'Incident already resolved' }), {
      status: 409,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  // Authorization: victim or circle admin
  const isVictim = incident.user_id === userId
  let isCircleAdmin = false

  if (!isVictim) {
    // Check if user is admin of any circle containing the victim
    const { data: adminCheck } = await supabase.rpc('is_admin_of_shared_circle', {
      admin_uid: userId,
      member_uid: incident.user_id,
    })
    isCircleAdmin = adminCheck === true
  }

  if (!isVictim && !isCircleAdmin) {
    return new Response(JSON.stringify({ error: 'Not authorized to resolve' }), {
      status: 403,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  const now = new Date().toISOString()

  // Resolve incident
  await supabase
    .from('incidents')
    .update({ status: 'resolved', resolved_at: now })
    .eq('id', incident_id)

  // Fetch resolver's name
  const { data: resolver } = await supabase
    .from('users')
    .select('name')
    .eq('id', userId)
    .single()

  // Broadcast resolution via Realtime
  const channel = supabase.channel(`incident:${incident_id}`)
  await channel.send({
    type: 'broadcast',
    event: 'resolved',
    payload: {
      resolved_by: resolver?.name ?? 'Someone',
      timestamp: now,
    },
  })

  return new Response(
    JSON.stringify({ status: 'resolved' }),
    { headers: { 'Content-Type': 'application/json' } },
  )
})
```

- [ ] **Step 3: Add DB helper function for circle admin check**

This function is called by `resolve-incident`. Add to migration `00014_create_cascade_jobs.sql` or create a new migration. Prefer a new migration since Task 1 may already be committed:

Create `backend/supabase/migrations/00015_add_admin_shared_circle_rpc.sql`:

```sql
-- Check if admin_uid is an admin of any circle that member_uid also belongs to
CREATE OR REPLACE FUNCTION is_admin_of_shared_circle(admin_uid TEXT, member_uid TEXT)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM circle_members cm1
    JOIN circle_members cm2 ON cm1.circle_id = cm2.circle_id
    WHERE cm1.user_id = admin_uid AND cm1.role = 'admin'
      AND cm2.user_id = member_uid
  )
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;
```

- [ ] **Step 4: Commit**

```bash
git add backend/supabase/functions/acknowledge-incident/index.ts \
       backend/supabase/functions/resolve-incident/index.ts \
       backend/supabase/migrations/00015_add_admin_shared_circle_rpc.sql
git commit -m "feat(cascade): add acknowledge-incident and resolve-incident Edge Functions"
```

---

### Task 5: Edge Functions — sms-webhook + voice-webhook

**Files:**
- Modify: `backend/supabase/functions/sms-webhook/index.ts` (replace stub)
- Modify: `backend/supabase/functions/voice-webhook/index.ts` (replace stub)

**Interfaces:**
- `sms-webhook` consumes: MSG91 delivery receipt or inbound SMS payload. Updates `incident_alerts` status. Triggers ack broadcast on "OK" reply.
- `voice-webhook` consumes: Exotel call status or IVR keypress. Updates `incident_alerts` status. Triggers ack broadcast on keypress "1".

- [ ] **Step 1: Write sms-webhook**

Replace `backend/supabase/functions/sms-webhook/index.ts`:

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  const body = await req.json()

  // Delivery receipt: { provider_id, status, delivered_at }
  if (body.type === 'delivery_receipt') {
    const { provider_id, status } = body
    const updateData: Record<string, unknown> = { status }
    if (status === 'delivered') {
      updateData.delivered_at = new Date().toISOString()
    }

    // Match by error field storing provider_id (set during send)
    // In production, store provider_id in a dedicated column or in error metadata
    // For mock: provider_id is logged but not stored, so this is a no-op
    console.log(`[sms-webhook] Delivery receipt: ${provider_id} -> ${status}`)

    return new Response(JSON.stringify({ status: 'ok' }), {
      headers: { 'Content-Type': 'application/json' },
    })
  }

  // Inbound SMS reply: { sender_phone, message }
  if (body.type === 'inbound_sms') {
    const { sender_phone, message } = body
    const normalizedMessage = (message ?? '').trim().toUpperCase()

    if (normalizedMessage !== 'OK') {
      return new Response(JSON.stringify({ status: 'ignored' }), {
        headers: { 'Content-Type': 'application/json' },
      })
    }

    // Find emergency contact by phone
    const { data: contacts } = await supabase
      .from('emergency_contacts')
      .select('id')
      .eq('phone', sender_phone)

    if (!contacts || contacts.length === 0) {
      return new Response(JSON.stringify({ status: 'unknown_sender' }), {
        headers: { 'Content-Type': 'application/json' },
      })
    }

    const contactIds = contacts.map((c: { id: string }) => c.id)
    const now = new Date().toISOString()

    // Find active incident_alerts for these contacts via SMS channel
    const { data: alerts } = await supabase
      .from('incident_alerts')
      .select('id, incident_id')
      .in('contact_id', contactIds)
      .eq('channel', 'sms')
      .is('acknowledged_at', null)

    if (!alerts || alerts.length === 0) {
      return new Response(JSON.stringify({ status: 'no_active_alerts' }), {
        headers: { 'Content-Type': 'application/json' },
      })
    }

    // Acknowledge all matching alerts
    const alertIds = alerts.map((a: { id: string }) => a.id)
    await supabase
      .from('incident_alerts')
      .update({ acknowledged_at: now, ack_method: 'sms' })
      .in('id', alertIds)

    // Set first_ack_at on each incident
    const incidentIds = [...new Set(alerts.map((a: { incident_id: string }) => a.incident_id))]
    for (const iid of incidentIds) {
      await supabase
        .from('incidents')
        .update({ first_ack_at: now })
        .eq('id', iid)
        .is('first_ack_at', null)
    }

    return new Response(JSON.stringify({ status: 'acknowledged', count: alertIds.length }), {
      headers: { 'Content-Type': 'application/json' },
    })
  }

  return new Response(JSON.stringify({ status: 'unknown_type' }), {
    status: 400,
    headers: { 'Content-Type': 'application/json' },
  })
})
```

- [ ] **Step 2: Write voice-webhook**

Replace `backend/supabase/functions/voice-webhook/index.ts`:

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  const body = await req.json()

  // Call status update: { provider_id, call_status, recipient_phone }
  if (body.type === 'call_status') {
    const { call_status, recipient_phone } = body
    console.log(`[voice-webhook] Call to ${recipient_phone}: ${call_status}`)

    // Map Exotel statuses to our statuses
    const statusMap: Record<string, string> = {
      answered: 'delivered',
      completed: 'delivered',
      busy: 'failed',
      'no-answer': 'failed',
      failed: 'failed',
    }

    const mappedStatus = statusMap[call_status] ?? 'failed'

    // Find active call alerts for this phone
    const { data: contacts } = await supabase
      .from('emergency_contacts')
      .select('id')
      .eq('phone', recipient_phone)

    if (contacts && contacts.length > 0) {
      const contactIds = contacts.map((c: { id: string }) => c.id)
      await supabase
        .from('incident_alerts')
        .update({
          status: mappedStatus,
          delivered_at: mappedStatus === 'delivered' ? new Date().toISOString() : null,
        })
        .in('contact_id', contactIds)
        .eq('channel', 'call')
        .eq('status', 'sent')
    }

    return new Response(JSON.stringify({ status: 'ok' }), {
      headers: { 'Content-Type': 'application/json' },
    })
  }

  // IVR keypress: { recipient_phone, digit }
  if (body.type === 'ivr_keypress') {
    const { recipient_phone, digit } = body

    if (digit !== '1' && digit !== '2') {
      return new Response(JSON.stringify({ status: 'ignored' }), {
        headers: { 'Content-Type': 'application/json' },
      })
    }

    const { data: contacts } = await supabase
      .from('emergency_contacts')
      .select('id')
      .eq('phone', recipient_phone)

    if (!contacts || contacts.length === 0) {
      return new Response(JSON.stringify({ status: 'unknown_caller' }), {
        headers: { 'Content-Type': 'application/json' },
      })
    }

    const contactIds = contacts.map((c: { id: string }) => c.id)
    const now = new Date().toISOString()

    // Both digit 1 and 2 count as acknowledgment
    const { data: alerts } = await supabase
      .from('incident_alerts')
      .select('id, incident_id')
      .in('contact_id', contactIds)
      .eq('channel', 'call')
      .is('acknowledged_at', null)

    if (alerts && alerts.length > 0) {
      const alertIds = alerts.map((a: { id: string }) => a.id)
      await supabase
        .from('incident_alerts')
        .update({ acknowledged_at: now, ack_method: 'ivr' })
        .in('id', alertIds)

      const incidentIds = [...new Set(alerts.map((a: { incident_id: string }) => a.incident_id))]
      for (const iid of incidentIds) {
        await supabase
          .from('incidents')
          .update({ first_ack_at: now })
          .eq('id', iid)
          .is('first_ack_at', null)
      }
    }

    return new Response(JSON.stringify({ status: 'acknowledged', digit }), {
      headers: { 'Content-Type': 'application/json' },
    })
  }

  return new Response(JSON.stringify({ status: 'unknown_type' }), {
    status: 400,
    headers: { 'Content-Type': 'application/json' },
  })
})
```

- [ ] **Step 3: Commit**

```bash
git add backend/supabase/functions/sms-webhook/index.ts \
       backend/supabase/functions/voice-webhook/index.ts
git commit -m "feat(cascade): implement sms-webhook and voice-webhook Edge Functions"
```

---

### Task 6: Edge Function — escalation-check

**Files:**
- Create: `backend/supabase/functions/escalation-check/index.ts`

**Interfaces:**
- Consumes: Service role key (invoked by pg_cron). Queries `incidents` + `cascade_jobs` tables.
- Produces: Re-invokes `alert-cascade` for un-ack'd incidents >10 min. Updates `incidents.status` to `'escalated'`. Retries failed cascades (no `incident_alerts` rows after 60s).

- [ ] **Step 1: Write escalation-check**

Create `backend/supabase/functions/escalation-check/index.ts`:

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

  const authHeader = req.headers.get('Authorization')
  if (authHeader !== `Bearer ${serviceRoleKey}`) {
    return new Response('Unauthorized', { status: 401 })
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey)
  const results = { escalated: 0, retried: 0, finalized: 0 }

  // 1. Cascade retry: dispatched incidents with no alert rows after 60s
  const sixtySecondsAgo = new Date(Date.now() - 60_000).toISOString()
  const { data: stuckIncidents } = await supabase
    .from('incidents')
    .select('id, user_id')
    .eq('status', 'dispatched')
    .lt('created_at', sixtySecondsAgo)

  if (stuckIncidents) {
    for (const incident of stuckIncidents) {
      // Check if any alerts exist
      const { count } = await supabase
        .from('incident_alerts')
        .select('id', { count: 'exact', head: true })
        .eq('incident_id', incident.id)

      if ((count ?? 0) === 0) {
        // Check retry count
        const { data: job } = await supabase
          .from('cascade_jobs')
          .select('retry_count')
          .eq('incident_id', incident.id)
          .single()

        const retryCount = job?.retry_count ?? 0
        if (retryCount >= 3) {
          // Give up
          await supabase
            .from('incidents')
            .update({ status: 'cancelled', cancelled_reason: 'cascade_failed' })
            .eq('id', incident.id)
          continue
        }

        // Retry: fetch contacts and re-invoke cascade
        const { data: contacts } = await supabase
          .from('emergency_contacts')
          .select('*')
          .eq('user_id', incident.user_id)
          .eq('opted_out', false)
          .order('priority')

        const { data: profile } = await supabase
          .from('users')
          .select('name, phone')
          .eq('id', incident.user_id)
          .single()

        if (contacts && contacts.length > 0) {
          // Increment retry count
          await supabase
            .from('cascade_jobs')
            .update({ retry_count: retryCount + 1 })
            .eq('incident_id', incident.id)

          // Re-invoke cascade
          fetch(`${supabaseUrl}/functions/v1/alert-cascade`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              Authorization: `Bearer ${serviceRoleKey}`,
            },
            body: JSON.stringify({
              incident_id: incident.id,
              contacts,
              user_profile: profile ?? { name: 'Unknown', phone: '' },
              location: { lat: 0, lng: 0 },
            }),
          }).catch((err) => console.error('Retry cascade failed:', err))

          results.retried++
        }
      }
    }
  }

  // 2. Escalation: dispatched + no ack + >10 min
  const tenMinutesAgo = new Date(Date.now() - 10 * 60_000).toISOString()
  const { data: unackedIncidents } = await supabase
    .from('incidents')
    .select('id, user_id')
    .eq('status', 'dispatched')
    .is('first_ack_at', null)
    .lt('created_at', tenMinutesAgo)

  if (unackedIncidents) {
    for (const incident of unackedIncidents) {
      // Update status to escalated
      await supabase
        .from('incidents')
        .update({ status: 'escalated' })
        .eq('id', incident.id)

      // Fetch contacts already alerted
      const { data: alertedContacts } = await supabase
        .from('incident_alerts')
        .select('contact_id')
        .eq('incident_id', incident.id)

      const alertedIds = new Set((alertedContacts ?? []).map((a: { contact_id: string }) => a.contact_id))

      // Fetch ALL emergency contacts (including lower-priority ones not yet alerted)
      const { data: allContacts } = await supabase
        .from('emergency_contacts')
        .select('*')
        .eq('user_id', incident.user_id)
        .eq('opted_out', false)
        .order('priority')

      const { data: profile } = await supabase
        .from('users')
        .select('name, phone')
        .eq('id', incident.user_id)
        .single()

      // Filter to un-alerted contacts
      const newContacts = (allContacts ?? []).filter(
        (c: { id: string }) => !alertedIds.has(c.id)
      )

      if (newContacts.length > 0) {
        fetch(`${supabaseUrl}/functions/v1/alert-cascade`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${serviceRoleKey}`,
          },
          body: JSON.stringify({
            incident_id: incident.id,
            contacts: newContacts,
            user_profile: profile ?? { name: 'Unknown', phone: '' },
            location: { lat: 0, lng: 0 },
          }),
        }).catch((err) => console.error('Escalation cascade failed:', err))
      }

      results.escalated++
    }
  }

  // 3. Final escalation: escalated + no ack + >20 min
  const twentyMinutesAgo = new Date(Date.now() - 20 * 60_000).toISOString()
  const { data: finalIncidents } = await supabase
    .from('incidents')
    .select('id, user_id')
    .eq('status', 'escalated')
    .is('first_ack_at', null)
    .lt('created_at', twentyMinutesAgo)

  if (finalIncidents) {
    for (const incident of finalIncidents) {
      // Log final state — in production, push "Call 112 now" to all contacts
      console.log(`[escalation-check] FINAL: incident ${incident.id} — 20 min, no ack. Call 112.`)
      results.finalized++
    }
  }

  return new Response(
    JSON.stringify({ status: 'ok', ...results }),
    { headers: { 'Content-Type': 'application/json' } },
  )
})
```

- [ ] **Step 2: Commit**

```bash
git add backend/supabase/functions/escalation-check/index.ts
git commit -m "feat(cascade): add escalation-check Edge Function for pg_cron"
```

---

### Task 7: Flutter — SOS models (Incident, IncidentAlert, SosState)

**Files:**
- Create: `app/lib/features/sos/models/sos_state.dart`
- Create: `app/lib/features/sos/models/incident.dart`
- Create: `app/lib/features/sos/models/incident_alert.dart`
- Modify: `app/lib/features/sos/models/models.dart` (update barrel)

**Interfaces:**
- Produces: `SosStatus` enum (`idle`, `armed`, `countdown`, `dispatching`, `active`, `resolved`, `cancelled`), `SosState` freezed class, `Incident` freezed class, `IncidentAlert` freezed class. All with `fromJson`.

- [ ] **Step 1: Write SosState model**

Create `app/lib/features/sos/models/sos_state.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

import 'incident.dart';

part 'sos_state.freezed.dart';

enum SosStatus {
  idle,
  armed,
  countdown,
  dispatching,
  active,
  resolved,
  cancelled,
}

@freezed
class SosState with _$SosState {
  const SosState._();

  const factory SosState({
    @Default(SosStatus.idle) SosStatus status,
    @Default(5) int countdownRemaining,
    Incident? activeIncident,
    String? errorMessage,
  }) = _SosState;

  bool get isActive =>
      status == SosStatus.active || status == SosStatus.dispatching;

  bool get canCancel =>
      status == SosStatus.countdown || status == SosStatus.armed;
}
```

- [ ] **Step 2: Write Incident model**

Create `app/lib/features/sos/models/incident.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'incident.freezed.dart';

@freezed
class Incident with _$Incident {
  const Incident._();

  const factory Incident({
    required String id,
    required String userId,
    required String type,
    String? severity,
    double? confidence,
    double? lat,
    double? lng,
    double? speedAtEvent,
    required String status,
    String? cancelledReason,
    required DateTime createdAt,
    DateTime? firstAckAt,
    DateTime? resolvedAt,
  }) = _Incident;

  factory Incident.fromJson(Map<String, dynamic> json) {
    return Incident(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      severity: json['severity'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      lat: null,
      lng: null,
      speedAtEvent: (json['speed_at_event'] as num?)?.toDouble(),
      status: json['status'] as String,
      cancelledReason: json['cancelled_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      firstAckAt: json['first_ack_at'] != null
          ? DateTime.parse(json['first_ack_at'] as String)
          : null,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
    );
  }

  bool get isResolved => status == 'resolved';
  bool get isCancelled => status == 'cancelled';
  bool get isActive => !isResolved && !isCancelled;
}
```

- [ ] **Step 3: Write IncidentAlert model**

Create `app/lib/features/sos/models/incident_alert.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'incident_alert.freezed.dart';

@freezed
class IncidentAlert with _$IncidentAlert {
  const factory IncidentAlert({
    required String id,
    required String incidentId,
    String? contactId,
    required String channel,
    required String status,
    DateTime? sentAt,
    DateTime? deliveredAt,
    DateTime? acknowledgedAt,
    String? ackMethod,
    String? error,
  }) = _IncidentAlert;

  factory IncidentAlert.fromJson(Map<String, dynamic> json) {
    return IncidentAlert(
      id: json['id'] as String,
      incidentId: json['incident_id'] as String,
      contactId: json['contact_id'] as String?,
      channel: json['channel'] as String,
      status: json['status'] as String,
      sentAt: json['sent_at'] != null
          ? DateTime.parse(json['sent_at'] as String)
          : null,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at'] as String)
          : null,
      acknowledgedAt: json['acknowledged_at'] != null
          ? DateTime.parse(json['acknowledged_at'] as String)
          : null,
      ackMethod: json['ack_method'] as String?,
      error: json['error'] as String?,
    );
  }
}
```

- [ ] **Step 4: Update barrel export**

Replace `app/lib/features/sos/models/models.dart` with:

```dart
export 'incident.dart';
export 'incident_alert.dart';
export 'sos_state.dart';
```

- [ ] **Step 5: Run build_runner to generate freezed code**

Run: `cd app && dart run build_runner build --delete-conflicting-outputs`
Expected: Generates `sos_state.freezed.dart`, `incident.freezed.dart`, `incident_alert.freezed.dart` without errors.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/sos/models/
git commit -m "feat(sos): add SosState, Incident, and IncidentAlert freezed models"
```

---

### Task 8: Flutter — SOS service (location capture, HTTP dispatch, retry)

**Files:**
- Create: `app/lib/features/sos/services/sos_service.dart`
- Modify: `app/lib/features/sos/services/services.dart` (update barrel)

**Interfaces:**
- Consumes: `authenticatedSupabaseProvider` for Supabase client, `AppConstants.supabaseUrl` for Edge Function URL
- Produces: `SosService` class with `Future<Incident> dispatchSos()` and `Future<void> resolveIncident(String incidentId)`. Provider: `sosServiceProvider`.

- [ ] **Step 1: Write SosService**

Create `app/lib/features/sos/services/sos_service.dart`:

```dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/app_constants.dart';
import '../../auth/services/clerk_service.dart';
import '../models/incident.dart';

final sosServiceProvider = Provider<SosService?>((ref) {
  final clerkService = ref.read(clerkServiceProvider);
  if (!clerkService.isSignedIn) return null;
  return SosService(clerkService);
});

class SosService {
  SosService(this._clerkService);

  final ClerkService _clerkService;

  Future<Position?> _captureLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('Location capture failed: $e');
      return null;
    }
  }

  Future<Incident> dispatchSos() async {
    final position = await _captureLocation();

    final token = await _clerkService.getSupabaseToken();
    if (token == null) throw Exception('No auth token');

    final packet = {
      'type': 'sos',
      'lat': position?.latitude ?? 0.0,
      'lng': position?.longitude ?? 0.0,
      'speed': position?.speed,
      'heading': position?.heading,
      'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'battery': null,
    };

    final url = Uri.parse(
      '${AppConstants.supabaseUrl}/functions/v1/incident-receive',
    );

    http.Response? response;
    Exception? lastError;

    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(packet),
        );
        if (response.statusCode == 201) break;
        lastError = Exception('HTTP ${response.statusCode}: ${response.body}');
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
      }

      if (attempt < 2) {
        await Future.delayed(const Duration(seconds: 5));
      }
    }

    if (response == null || response.statusCode != 201) {
      throw lastError ?? Exception('Failed to dispatch SOS');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return Incident(
      id: body['incident_id'] as String,
      userId: '',
      type: 'sos',
      status: body['status'] as String,
      createdAt: DateTime.now(),
    );
  }

  Future<void> resolveIncident(String incidentId) async {
    final token = await _clerkService.getSupabaseToken();
    if (token == null) throw Exception('No auth token');

    final url = Uri.parse(
      '${AppConstants.supabaseUrl}/functions/v1/resolve-incident',
    );

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'incident_id': incidentId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to resolve: ${response.body}');
    }
  }
}
```

- [ ] **Step 2: Update barrel export**

Replace `app/lib/features/sos/services/services.dart` with:

```dart
export 'sos_service.dart';
```

- [ ] **Step 3: Add http dependency if not present**

Run: `cd app && grep "http:" pubspec.yaml`

If not present, run: `cd app && dart pub add http`

- [ ] **Step 4: Commit**

```bash
git add app/lib/features/sos/services/
git commit -m "feat(sos): add SosService with location capture, HTTP dispatch, and retry"
```

---

### Task 9: Flutter — SOS state provider (StateNotifier + countdown timer)

**Files:**
- Create: `app/lib/features/sos/providers/sos_state_provider.dart`
- Modify: `app/lib/features/sos/providers/providers.dart` (update barrel)
- Create: `app/test/features/sos/providers/sos_state_provider_test.dart`

**Interfaces:**
- Consumes: `SosService.dispatchSos()`, `SosService.resolveIncident()`
- Produces: `sosStateProvider` (StateNotifier<SosState>) with methods: `arm()`, `startCountdown()`, `cancel()`, `resolve()`. Countdown auto-dispatches on expiry.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/sos/providers/sos_state_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roadpack/features/sos/models/incident.dart';
import 'package:roadpack/features/sos/models/sos_state.dart';
import 'package:roadpack/features/sos/providers/sos_state_provider.dart';
import 'package:roadpack/features/sos/services/sos_service.dart';

class MockSosService extends Mock implements SosService {}

void main() {
  late ProviderContainer container;
  late MockSosService mockService;

  final testIncident = Incident(
    id: 'inc_123',
    userId: 'user_1',
    type: 'sos',
    status: 'dispatched',
    createdAt: DateTime(2026, 7, 11),
  );

  setUp(() {
    mockService = MockSosService();
    container = ProviderContainer(
      overrides: [sosServiceProvider.overrideWithValue(mockService)],
    );
  });

  tearDown(() => container.dispose());

  group('SosStateNotifier', () {
    test('initial state is idle', () {
      final state = container.read(sosStateProvider);
      expect(state.status, SosStatus.idle);
      expect(state.countdownRemaining, 5);
    });

    test('arm transitions to armed', () {
      container.read(sosStateProvider.notifier).arm();
      expect(container.read(sosStateProvider).status, SosStatus.armed);
    });

    test('cancel from countdown returns to idle', () {
      final notifier = container.read(sosStateProvider.notifier);
      notifier.arm();
      notifier.startCountdown();
      notifier.cancel();

      final state = container.read(sosStateProvider);
      expect(state.status, SosStatus.cancelled);
    });

    test('cancel from idle is no-op', () {
      container.read(sosStateProvider.notifier).cancel();
      expect(container.read(sosStateProvider).status, SosStatus.idle);
    });

    test('resolve calls service and transitions to resolved', () async {
      when(() => mockService.dispatchSos())
          .thenAnswer((_) async => testIncident);
      when(() => mockService.resolveIncident('inc_123'))
          .thenAnswer((_) async {});

      final notifier = container.read(sosStateProvider.notifier);
      // Simulate dispatched state
      notifier.arm();
      notifier.state = notifier.state.copyWith(
        status: SosStatus.active,
        activeIncident: testIncident,
      );

      await notifier.resolve();

      expect(container.read(sosStateProvider).status, SosStatus.resolved);
      verify(() => mockService.resolveIncident('inc_123')).called(1);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/features/sos/providers/sos_state_provider_test.dart`
Expected: FAIL — `sos_state_provider.dart` does not exist yet.

- [ ] **Step 3: Write the SosStateNotifier**

Create `app/lib/features/sos/providers/sos_state_provider.dart`:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../models/sos_state.dart';
import '../services/sos_service.dart';

final sosStateProvider =
    StateNotifierProvider<SosStateNotifier, SosState>(
  (ref) => SosStateNotifier(ref),
);

class SosStateNotifier extends StateNotifier<SosState> {
  SosStateNotifier(this._ref) : super(const SosState());

  final Ref _ref;
  Timer? _countdownTimer;

  SosService? get _service => _ref.read(sosServiceProvider);

  void arm() {
    if (state.status != SosStatus.idle) return;
    state = state.copyWith(status: SosStatus.armed);
  }

  void startCountdown() {
    if (state.status != SosStatus.armed) return;
    state = state.copyWith(
      status: SosStatus.countdown,
      countdownRemaining: AppConstants.sosCountdownDuration.inSeconds,
    );
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  void _tick(Timer timer) {
    final remaining = state.countdownRemaining - 1;
    if (remaining <= 0) {
      timer.cancel();
      _countdownTimer = null;
      _dispatch();
    } else {
      state = state.copyWith(countdownRemaining: remaining);
    }
  }

  void cancel() {
    if (!state.canCancel) return;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    state = state.copyWith(
      status: SosStatus.cancelled,
      countdownRemaining: AppConstants.sosCountdownDuration.inSeconds,
    );
  }

  void reset() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    state = const SosState();
  }

  Future<void> _dispatch() async {
    state = state.copyWith(status: SosStatus.dispatching);
    try {
      final service = _service;
      if (service == null) {
        state = state.copyWith(
          status: SosStatus.idle,
          errorMessage: 'Not signed in',
        );
        return;
      }
      final incident = await service.dispatchSos();
      state = state.copyWith(
        status: SosStatus.active,
        activeIncident: incident,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        status: SosStatus.idle,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> resolve() async {
    final incident = state.activeIncident;
    if (incident == null) return;
    try {
      await _service?.resolveIncident(incident.id);
      state = state.copyWith(status: SosStatus.resolved);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 4: Update barrel export**

Replace `app/lib/features/sos/providers/providers.dart` with:

```dart
export 'sos_state_provider.dart';
```

- [ ] **Step 5: Run build_runner (freezed needs regeneration after model changes)**

Run: `cd app && dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 6: Run test to verify it passes**

Run: `cd app && flutter test test/features/sos/providers/sos_state_provider_test.dart`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add app/lib/features/sos/providers/ app/test/features/sos/providers/
git commit -m "feat(sos): add SosStateNotifier with countdown timer and dispatch"
```

---

### Task 10: Flutter — SOS widgets (SosButton, SosOverlay)

**Files:**
- Create: `app/lib/features/sos/widgets/sos_button.dart`
- Create: `app/lib/features/sos/widgets/sos_overlay.dart`
- Modify: `app/lib/features/sos/widgets/widgets.dart` (update barrel)
- Modify: `app/lib/app.dart` (wrap with SosOverlay)

**Interfaces:**
- Consumes: `sosStateProvider` for state, `SosStateNotifier.arm()`, `.startCountdown()`, `.cancel()`
- Produces: `SosButton` widget (FAB, long-press 2s to arm), `SosOverlay` widget (wraps child, shows FAB when authenticated + idle)

- [ ] **Step 1: Write SosButton**

Create `app/lib/features/sos/widgets/sos_button.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sos_state.dart';
import '../providers/sos_state_provider.dart';

class SosButton extends ConsumerStatefulWidget {
  const SosButton({super.key});

  @override
  ConsumerState<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends ConsumerState<SosButton> {
  Timer? _armTimer;

  void _onLongPressStart(LongPressStartDetails details) {
    HapticFeedback.heavyImpact();
    _armTimer = Timer(const Duration(seconds: 2), () {
      ref.read(sosStateProvider.notifier).arm();
      ref.read(sosStateProvider.notifier).startCountdown();
      HapticFeedback.vibrate();
    });
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    _armTimer?.cancel();
    _armTimer = null;
  }

  @override
  void dispose() {
    _armTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sosStatus = ref.watch(
      sosStateProvider.select((s) => s.status),
    );

    if (sosStatus != SosStatus.idle) return const SizedBox.shrink();

    return Positioned(
      bottom: 24,
      right: 24,
      child: GestureDetector(
        onLongPressStart: _onLongPressStart,
        onLongPressEnd: _onLongPressEnd,
        child: FloatingActionButton.large(
          heroTag: 'sos_fab',
          backgroundColor: Colors.red,
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Hold for 2 seconds to trigger SOS'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sos, color: Colors.white, size: 32),
              Text('SOS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Write SosOverlay**

Create `app/lib/features/sos/widgets/sos_overlay.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/clerk_auth_provider.dart';
import '../models/sos_state.dart';
import '../providers/sos_state_provider.dart';
import '../screens/sos_countdown_screen.dart';
import '../screens/sos_active_screen.dart';
import 'sos_button.dart';

class SosOverlay extends ConsumerWidget {
  const SosOverlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(clerkAuthProvider).valueOrNull;
    final sosState = ref.watch(sosStateProvider);

    final isAuthenticated = authState?.isAuthenticated ?? false;

    return Stack(
      children: [
        child,
        if (isAuthenticated) ...[
          if (sosState.status == SosStatus.countdown ||
              sosState.status == SosStatus.dispatching)
            const SosCountdownScreen(),
          if (sosState.status == SosStatus.active ||
              sosState.status == SosStatus.resolved)
            const SosActiveScreen(),
          if (sosState.status == SosStatus.idle) const SosButton(),
        ],
      ],
    );
  }
}
```

- [ ] **Step 3: Update barrel export**

Replace `app/lib/features/sos/widgets/widgets.dart` with:

```dart
export 'sos_button.dart';
export 'sos_overlay.dart';
```

- [ ] **Step 4: Wrap App with SosOverlay**

Modify `app/lib/app.dart` — wrap the `MaterialApp.router` with `SosOverlay` using `builder`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/core.dart';
import 'features/sos/widgets/sos_overlay.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('hi'), Locale('ml')],
      builder: (context, child) => SosOverlay(child: child ?? const SizedBox.shrink()),
    );
  }
}
```

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/sos/widgets/ app/lib/app.dart
git commit -m "feat(sos): add SosButton FAB, SosOverlay, and wire into App"
```

---

### Task 11: Flutter — SOS screens (countdown + active)

**Files:**
- Create: `app/lib/features/sos/screens/sos_countdown_screen.dart`
- Create: `app/lib/features/sos/screens/sos_active_screen.dart`
- Modify: `app/lib/features/sos/screens/screens.dart` (update barrel)

**Interfaces:**
- Consumes: `sosStateProvider` for state + notifier methods (`cancel()`, `resolve()`, `reset()`)
- Produces: Full-screen countdown UI and post-dispatch active incident screen

- [ ] **Step 1: Write SosCountdownScreen**

Create `app/lib/features/sos/screens/sos_countdown_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sos_state_provider.dart';

class SosCountdownScreen extends ConsumerWidget {
  const SosCountdownScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sosStateProvider);

    return Material(
      color: Colors.black.withValues(alpha: 0.95),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'SOS ALERT',
              style: TextStyle(
                color: Colors.red,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Emergency alerts will be sent to your contacts',
              style: TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            Text(
              '${state.countdownRemaining}',
              style: const TextStyle(
                color: Colors.red,
                fontSize: 120,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 200,
              height: 64,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  ref.read(sosStateProvider.notifier).cancel();
                },
                child: const Text('CANCEL'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Write SosActiveScreen**

Create `app/lib/features/sos/screens/sos_active_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sos_state.dart';
import '../providers/sos_state_provider.dart';

class SosActiveScreen extends ConsumerWidget {
  const SosActiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sosStateProvider);
    final isResolved = state.status == SosStatus.resolved;

    return Material(
      color: Colors.black.withValues(alpha: 0.95),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isResolved ? Icons.check_circle : Icons.warning_amber,
                color: isResolved ? Colors.green : Colors.orange,
                size: 80,
              ),
              const SizedBox(height: 24),
              Text(
                isResolved ? 'Incident Resolved' : 'Emergency Alerts Sent',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isResolved
                    ? 'Your contacts have been notified that you are safe.'
                    : 'Your emergency contacts are being notified.',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              if (state.activeIncident != null) ...[
                const SizedBox(height: 24),
                Text(
                  'Incident: ${state.activeIncident!.id.substring(0, 8)}...',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
              const SizedBox(height: 48),
              if (!isResolved)
                SizedBox(
                  width: 200,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      ref.read(sosStateProvider.notifier).resolve();
                    },
                    child: const Text("I'M OKAY"),
                  ),
                ),
              if (isResolved)
                SizedBox(
                  width: 200,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () {
                      ref.read(sosStateProvider.notifier).reset();
                    },
                    child: const Text('CLOSE'),
                  ),
                ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  state.errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Update barrel export**

Replace `app/lib/features/sos/screens/screens.dart` with:

```dart
export 'sos_active_screen.dart';
export 'sos_countdown_screen.dart';
```

- [ ] **Step 4: Verify compilation**

Run: `cd app && flutter analyze --no-fatal-infos`
Expected: No errors. Warnings about unused imports or similar are acceptable.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/sos/screens/
git commit -m "feat(sos): add SOS countdown and active incident screens"
```

---

### Task 12: Flutter — Alerts feature (contact side: receive + acknowledge)

**Files:**
- Create: `app/lib/features/alerts/models/alert_notification.dart`
- Create: `app/lib/features/alerts/services/alert_service.dart`
- Create: `app/lib/features/alerts/providers/alerts_provider.dart`
- Create: `app/lib/features/alerts/screens/alert_detail_screen.dart`
- Create: `app/lib/features/alerts/widgets/alert_card.dart`
- Modify: `app/lib/features/alerts/models/models.dart` (update barrel)
- Modify: `app/lib/features/alerts/services/services.dart` (update barrel)
- Modify: `app/lib/features/alerts/providers/providers.dart` (update barrel)
- Modify: `app/lib/features/alerts/screens/screens.dart` (update barrel)
- Modify: `app/lib/features/alerts/widgets/widgets.dart` (update barrel)
- Modify: `app/lib/core/router/app_router.dart` (add alert route)

**Interfaces:**
- Consumes: Push notification data payload `{ incident_id, lat, lng, victim_name, victim_phone }`, `authenticatedSupabaseProvider`, `AppConstants.supabaseUrl`
- Produces: `AlertNotification` model, `AlertService` with `acknowledgeIncident()`, `alertsProvider` for incoming alerts list, `AlertDetailScreen`, route `/alerts/:id`

- [ ] **Step 1: Write AlertNotification model**

Create `app/lib/features/alerts/models/alert_notification.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'alert_notification.freezed.dart';

@freezed
class AlertNotification with _$AlertNotification {
  const factory AlertNotification({
    required String incidentId,
    required double lat,
    required double lng,
    required String victimName,
    required String victimPhone,
    required DateTime receivedAt,
    @Default(false) bool acknowledged,
  }) = _AlertNotification;

  factory AlertNotification.fromPushData(Map<String, dynamic> data) {
    return AlertNotification(
      incidentId: data['incident_id'] as String,
      lat: double.tryParse(data['lat']?.toString() ?? '') ?? 0.0,
      lng: double.tryParse(data['lng']?.toString() ?? '') ?? 0.0,
      victimName: data['victim_name'] as String? ?? 'Unknown',
      victimPhone: data['victim_phone'] as String? ?? '',
      receivedAt: DateTime.now(),
    );
  }
}
```

- [ ] **Step 2: Write AlertService**

Create `app/lib/features/alerts/services/alert_service.dart`:

```dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/app_constants.dart';
import '../../auth/services/clerk_service.dart';

final alertServiceProvider = Provider<AlertService?>((ref) {
  final clerkService = ref.read(clerkServiceProvider);
  if (!clerkService.isSignedIn) return null;
  return AlertService(clerkService);
});

class AlertService {
  AlertService(this._clerkService);

  final ClerkService _clerkService;

  Future<void> acknowledgeIncident(String incidentId) async {
    final token = await _clerkService.getSupabaseToken();
    if (token == null) throw Exception('No auth token');

    final url = Uri.parse(
      '${AppConstants.supabaseUrl}/functions/v1/acknowledge-incident',
    );

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'incident_id': incidentId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to acknowledge: ${response.body}');
    }
  }
}
```

- [ ] **Step 3: Write alerts provider**

Create `app/lib/features/alerts/providers/alerts_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/alert_notification.dart';

final alertsProvider =
    StateNotifierProvider<AlertsNotifier, List<AlertNotification>>(
  (ref) => AlertsNotifier(),
);

class AlertsNotifier extends StateNotifier<List<AlertNotification>> {
  AlertsNotifier() : super([]);

  void addAlert(AlertNotification alert) {
    state = [alert, ...state];
  }

  void markAcknowledged(String incidentId) {
    state = [
      for (final a in state)
        if (a.incidentId == incidentId)
          a.copyWith(acknowledged: true)
        else
          a,
    ];
  }
}
```

- [ ] **Step 4: Write AlertDetailScreen**

Create `app/lib/features/alerts/screens/alert_detail_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/alerts_provider.dart';
import '../services/alert_service.dart';

class AlertDetailScreen extends ConsumerWidget {
  const AlertDetailScreen({required this.incidentId, super.key});

  final String incidentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(alertsProvider);
    final alert = alerts.where((a) => a.incidentId == incidentId).firstOrNull;

    if (alert == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Alert')),
        body: const Center(child: Text('Alert not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Alert'),
        backgroundColor: Colors.red,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${alert.victimName} may have been in an accident',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text('Location: ${alert.lat.toStringAsFixed(4)}, ${alert.lng.toStringAsFixed(4)}'),
            const SizedBox(height: 8),
            Text('Time: ${alert.receivedAt}'),
            const SizedBox(height: 24),
            if (!alert.acknowledged)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    try {
                      await ref
                          .read(alertServiceProvider)
                          ?.acknowledgeIncident(incidentId);
                      ref
                          .read(alertsProvider.notifier)
                          .markAcknowledged(incidentId);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('ACKNOWLEDGE', style: TextStyle(fontSize: 18)),
                ),
              ),
            if (alert.acknowledged)
              const Chip(
                label: Text('Acknowledged'),
                backgroundColor: Colors.green,
                labelStyle: TextStyle(color: Colors.white),
              ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.phone),
              label: const Text('Call 112'),
              onPressed: () => launchUrl(Uri.parse('tel:112')),
            ),
            const SizedBox(height: 8),
            if (alert.victimPhone.isNotEmpty)
              OutlinedButton.icon(
                icon: const Icon(Icons.phone),
                label: Text('Call ${alert.victimName}'),
                onPressed: () =>
                    launchUrl(Uri.parse('tel:${alert.victimPhone}')),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.map),
              label: const Text('Open in Maps'),
              onPressed: () => launchUrl(
                Uri.parse(
                    'https://maps.google.com/?q=${alert.lat},${alert.lng}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Write AlertCard widget**

Create `app/lib/features/alerts/widgets/alert_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/alert_notification.dart';

class AlertCard extends StatelessWidget {
  const AlertCard({required this.alert, super.key});

  final AlertNotification alert;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: alert.acknowledged ? null : Colors.red.shade900,
      child: ListTile(
        leading: Icon(
          alert.acknowledged ? Icons.check_circle : Icons.warning,
          color: alert.acknowledged ? Colors.green : Colors.red,
        ),
        title: Text('${alert.victimName} - Emergency'),
        subtitle: Text(
          alert.acknowledged ? 'Acknowledged' : 'Tap to view and acknowledge',
        ),
        onTap: () => context.push('/alerts/${alert.incidentId}'),
      ),
    );
  }
}
```

- [ ] **Step 6: Update all barrel exports**

`app/lib/features/alerts/models/models.dart`:
```dart
export 'alert_notification.dart';
```

`app/lib/features/alerts/services/services.dart`:
```dart
export 'alert_service.dart';
```

`app/lib/features/alerts/providers/providers.dart`:
```dart
export 'alerts_provider.dart';
```

`app/lib/features/alerts/screens/screens.dart`:
```dart
export 'alert_detail_screen.dart';
```

`app/lib/features/alerts/widgets/widgets.dart`:
```dart
export 'alert_card.dart';
```

- [ ] **Step 7: Add route to GoRouter**

Add to `app/lib/core/router/app_router.dart` — import `AlertDetailScreen` and add route:

```dart
// Add import at top:
import '../../features/alerts/screens/alert_detail_screen.dart';

// Add route in routes list (after /circles/:id):
GoRoute(
  path: '/alerts/:id',
  builder: (context, state) {
    final incidentId = state.pathParameters['id']!;
    return AlertDetailScreen(incidentId: incidentId);
  },
),
```

- [ ] **Step 8: Add url_launcher dependency if not present**

Run: `cd app && grep "url_launcher:" pubspec.yaml`
If not present: `cd app && dart pub add url_launcher`

- [ ] **Step 9: Run build_runner**

Run: `cd app && dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 10: Verify compilation**

Run: `cd app && flutter analyze --no-fatal-infos`
Expected: No errors.

- [ ] **Step 11: Commit**

```bash
git add app/lib/features/alerts/ app/lib/core/router/app_router.dart
git commit -m "feat(alerts): add alert receiving, acknowledgment, and detail screen"
```

---

### Task 13: Integration verification — compile check + test suite

**Files:**
- No new files. Verify everything compiles and tests pass.

**Interfaces:**
- Consumes: All prior tasks
- Produces: Clean compile, passing tests

- [ ] **Step 1: Run build_runner one final time**

Run: `cd app && dart run build_runner build --delete-conflicting-outputs`
Expected: All freezed files generated.

- [ ] **Step 2: Run flutter analyze**

Run: `cd app && flutter analyze --no-fatal-infos`
Expected: No errors.

- [ ] **Step 3: Run all tests**

Run: `cd app && flutter test`
Expected: All tests pass (existing auth tests + new SOS provider tests).

- [ ] **Step 4: Verify Edge Functions have no TypeScript errors**

Run: `ls backend/supabase/functions/*/index.ts`
Expected: 8 function directories listed: `alert-cascade`, `acknowledge-incident`, `canary`, `clerk-webhook`, `escalation-check`, `incident-receive`, `resolve-incident`, `sms-webhook`, `voice-webhook`.

Note: Deno type checking happens at deploy time. For local verification: `cd backend/supabase/functions/incident-receive && deno check index.ts` (if Deno is installed).

- [ ] **Step 5: Final commit if any formatting fixes needed**

```bash
cd app && dart format .
git add -u
git commit -m "style(sos): apply dart format"
```
