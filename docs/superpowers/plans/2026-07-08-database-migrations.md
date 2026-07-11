# Database Migrations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create 10 PostgreSQL migration files (00002-00011) implementing the complete RoadPack v2 schema with Clerk auth, PostGIS, full RLS, and monthly-partitioned location history.

**Architecture:** One migration per table in FK-dependency order. All RLS policies use `requesting_user_id()` helper (reads Clerk JWT `sub` claim as TEXT, avoiding `auth.uid()` which casts to UUID and breaks with Clerk's string IDs). SECURITY DEFINER functions bypass RLS for cross-table lookups in policies. Edge Functions use service role to bypass RLS entirely.

**Tech Stack:** PostgreSQL 15+, PostGIS, Supabase CLI, Clerk JWT

## Global Constraints

- User IDs: TEXT, not UUID (Clerk IDs like `user_2xABC`)
- Auth helper: use `requesting_user_id()` in ALL RLS policies — NOT `auth.uid()` (UUID cast breaks Clerk IDs)
- RLS: enabled on every table, no exceptions
- SECURITY DEFINER: all cross-table RLS helper functions must use this to bypass RLS on referenced tables
- Service role: Edge Functions bypass RLS for cascade/admin operations
- File naming: `000NN_<name>.sql` in `backend/supabase/migrations/`
- Migration 00001 already exists (extensions). Do not modify it.
- Spec reference: `docs/superpowers/specs/2026-07-08-database-migrations-design.md`
- SQL style: one comment header per file, no inline comments except for non-obvious logic

## File Structure

```
backend/supabase/migrations/
  00001_enable_extensions.sql           # EXISTS — PostGIS, uuid-ossp, pg_cron
  00002_create_users.sql                # Task 1 — users table + requesting_user_id() helper
  00003_create_circles.sql              # Task 1 — circles + circle_members + RLS helper functions
  00004_create_emergency_contacts.sql   # Task 1 — emergency_contacts
  00005_create_location_history.sql     # Task 2 — partitioned table + partition function + spatial index
  00006_create_known_routes.sql         # Task 2 — known_routes + spatial indexes
  00007_create_incidents.sql            # Task 3 — incidents + incident_alerts
  00008_create_hospitals.sql            # Task 3 — hospitals + spatial index + public read
  00009_create_consents.sql             # Task 4 — consent ledger (DPDPA 2023)
  00010_create_devices.sql              # Task 4 — device registry
  00011_create_audit_log.sql            # Task 4 — audit_log + trigger function + triggers
```

---

### Task 1: Identity Layer (00002 + 00003 + 00004)

**Files:**
- Create: `backend/supabase/migrations/00002_create_users.sql`
- Create: `backend/supabase/migrations/00003_create_circles.sql`
- Create: `backend/supabase/migrations/00004_create_emergency_contacts.sql`

**Interfaces:**
- Consumes: `uuid-ossp` extension (from 00001)
- Produces:
  - `requesting_user_id() -> TEXT` — JWT auth helper used by ALL subsequent RLS policies
  - `get_user_circle_ids(uid TEXT) -> SETOF UUID` — returns circle IDs for a user
  - `is_circle_member(uid TEXT, cid UUID) -> BOOLEAN` — membership check
  - `is_circle_admin(uid TEXT, cid UUID) -> BOOLEAN` — admin role check
  - `shares_circle_with(viewer TEXT, target TEXT) -> BOOLEAN` — checks if two users share any circle
  - Tables: `users`, `circles`, `circle_members`, `emergency_contacts`

- [ ] **Step 1: Create 00002_create_users.sql**

Create `backend/supabase/migrations/00002_create_users.sql`:

```sql
-- RoadPack v2: users table + Clerk JWT auth helper

-- Extract Clerk user ID from JWT sub claim (TEXT, not UUID)
-- Supabase auth.uid() casts to UUID which breaks with Clerk string IDs
CREATE FUNCTION requesting_user_id() RETURNS TEXT AS $$
  SELECT COALESCE(
    NULLIF(current_setting('request.jwt.claim.sub', true), ''),
    (current_setting('request.jwt.claims', true)::jsonb ->> 'sub')
  )
$$ LANGUAGE sql STABLE;

CREATE TABLE users (
    id                TEXT PRIMARY KEY,
    phone             VARCHAR(15) UNIQUE NOT NULL,
    name              VARCHAR(100) NOT NULL,
    date_of_birth     DATE NOT NULL,
    language          VARCHAR(5) DEFAULT 'en',
    blood_group       VARCHAR(5),
    medical_notes     TEXT,
    vehicle_type      VARCHAR(20),
    vehicle_reg       VARCHAR(20),
    phone_mount       VARCHAR(20),
    crash_sensitivity VARCHAR(10) DEFAULT 'medium',
    is_minor          BOOLEAN GENERATED ALWAYS AS (date_of_birth > CURRENT_DATE - INTERVAL '18 years') STORED,
    created_at        TIMESTAMPTZ DEFAULT now(),
    last_seen_at      TIMESTAMPTZ
);

ALTER TABLE users ENABLE ROW LEVEL SECURITY;

CREATE POLICY users_select ON users FOR SELECT
  USING (requesting_user_id() = id);

CREATE POLICY users_insert ON users FOR INSERT
  WITH CHECK (requesting_user_id() = id);

CREATE POLICY users_update ON users FOR UPDATE
  USING (requesting_user_id() = id);

CREATE POLICY users_delete ON users FOR DELETE
  USING (requesting_user_id() = id);
```

- [ ] **Step 2: Create 00003_create_circles.sql**

Create `backend/supabase/migrations/00003_create_circles.sql`:

```sql
-- RoadPack v2: circles, circle_members, SECURITY DEFINER helper functions, RLS

CREATE TABLE circles (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name         VARCHAR(100) NOT NULL,
    type         VARCHAR(20) NOT NULL CHECK (type IN ('family','friends','commute','convoy')),
    created_by   TEXT REFERENCES users(id),
    invite_code  VARCHAR(12) UNIQUE,
    max_members  INT,
    settings     JSONB DEFAULT '{}',
    created_at   TIMESTAMPTZ DEFAULT now(),
    expires_at   TIMESTAMPTZ
);

CREATE TABLE circle_members (
    circle_id    UUID REFERENCES circles(id) ON DELETE CASCADE,
    user_id      TEXT REFERENCES users(id) ON DELETE CASCADE,
    role         VARCHAR(20) NOT NULL CHECK (role IN ('admin','member','observer')),
    permissions  JSONB DEFAULT '{}',
    accepted_at  TIMESTAMPTZ,
    joined_at    TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (circle_id, user_id)
);

CREATE INDEX idx_circle_members_user ON circle_members(user_id);

-- SECURITY DEFINER helpers: bypass RLS to avoid recursive policy evaluation

CREATE FUNCTION get_user_circle_ids(uid TEXT)
RETURNS SETOF UUID AS $$
  SELECT circle_id FROM circle_members WHERE user_id = uid
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE FUNCTION is_circle_member(uid TEXT, cid UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (SELECT 1 FROM circle_members WHERE user_id = uid AND circle_id = cid)
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE FUNCTION is_circle_admin(uid TEXT, cid UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (SELECT 1 FROM circle_members WHERE user_id = uid AND circle_id = cid AND role = 'admin')
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE FUNCTION shares_circle_with(viewer TEXT, target TEXT)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM circle_members cm1
    JOIN circle_members cm2 ON cm1.circle_id = cm2.circle_id
    WHERE cm1.user_id = viewer AND cm2.user_id = target
  )
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Circles RLS

ALTER TABLE circles ENABLE ROW LEVEL SECURITY;

CREATE POLICY circles_select ON circles FOR SELECT
  USING (id IN (SELECT get_user_circle_ids(requesting_user_id())));

CREATE POLICY circles_insert ON circles FOR INSERT
  WITH CHECK (requesting_user_id() IS NOT NULL);

CREATE POLICY circles_update ON circles FOR UPDATE
  USING (is_circle_admin(requesting_user_id(), id));

CREATE POLICY circles_delete ON circles FOR DELETE
  USING (is_circle_admin(requesting_user_id(), id));

-- Circle Members RLS

ALTER TABLE circle_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY circle_members_select ON circle_members FOR SELECT
  USING (circle_id IN (SELECT get_user_circle_ids(requesting_user_id())));

CREATE POLICY circle_members_insert ON circle_members FOR INSERT
  WITH CHECK (
    user_id = requesting_user_id()
    OR is_circle_admin(requesting_user_id(), circle_id)
  );

CREATE POLICY circle_members_update ON circle_members FOR UPDATE
  USING (user_id = requesting_user_id());

CREATE POLICY circle_members_delete ON circle_members FOR DELETE
  USING (
    user_id = requesting_user_id()
    OR is_circle_admin(requesting_user_id(), circle_id)
  );
```

- [ ] **Step 3: Create 00004_create_emergency_contacts.sql**

Create `backend/supabase/migrations/00004_create_emergency_contacts.sql`:

```sql
-- RoadPack v2: emergency_contacts

CREATE TABLE emergency_contacts (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id      TEXT REFERENCES users(id) ON DELETE CASCADE,
    name         VARCHAR(100) NOT NULL,
    phone        VARCHAR(15) NOT NULL,
    relationship VARCHAR(30),
    priority     INT NOT NULL,
    alert_method VARCHAR(20)[] DEFAULT '{push,sms,call}',
    notified_at  TIMESTAMPTZ,
    opted_out    BOOLEAN DEFAULT false,
    is_app_user  BOOLEAN DEFAULT false,
    app_user_id  TEXT REFERENCES users(id),
    created_at   TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_emergency_contacts_user ON emergency_contacts(user_id);

ALTER TABLE emergency_contacts ENABLE ROW LEVEL SECURITY;

CREATE POLICY emergency_contacts_select ON emergency_contacts FOR SELECT
  USING (user_id = requesting_user_id());

CREATE POLICY emergency_contacts_insert ON emergency_contacts FOR INSERT
  WITH CHECK (user_id = requesting_user_id());

CREATE POLICY emergency_contacts_update ON emergency_contacts FOR UPDATE
  USING (user_id = requesting_user_id());

CREATE POLICY emergency_contacts_delete ON emergency_contacts FOR DELETE
  USING (user_id = requesting_user_id());
```

- [ ] **Step 4: Verify migrations apply**

Run from project root:

```bash
cd backend && npx supabase migration list
```

Expected: all four migrations listed (00001-00004). If Docker Desktop is running, also run:

```bash
npx supabase db reset
```

Expected: clean output, no errors. All tables created.

- [ ] **Step 5: Commit**

```bash
git add backend/supabase/migrations/00002_create_users.sql backend/supabase/migrations/00003_create_circles.sql backend/supabase/migrations/00004_create_emergency_contacts.sql
git commit -m "feat(db): add identity layer migrations (users, circles, emergency contacts)

- requesting_user_id() helper for Clerk JWT auth (TEXT, not UUID)
- SECURITY DEFINER helpers: get_user_circle_ids, is_circle_member, is_circle_admin, shares_circle_with
- Full RLS on all three tables"
```

---

### Task 2: Geospatial Layer (00005 + 00006)

**Files:**
- Create: `backend/supabase/migrations/00005_create_location_history.sql`
- Create: `backend/supabase/migrations/00006_create_known_routes.sql`

**Interfaces:**
- Consumes: `users` table, `circle_members` table, `circles` table, `requesting_user_id()`, PostGIS extension (from 00001)
- Produces:
  - `can_view_location(viewer TEXT, target TEXT) -> BOOLEAN` — circle-aware location visibility check
  - `create_location_partitions(months_ahead INT) -> void` — creates monthly partitions
  - Tables: `location_history` (partitioned), `known_routes`

- [ ] **Step 1: Create 00005_create_location_history.sql**

Create `backend/supabase/migrations/00005_create_location_history.sql`:

```sql
-- RoadPack v2: location_history (monthly partitioned) + location visibility helper

-- Check if viewer can see target's location via shared circle with location_sharing enabled
CREATE FUNCTION can_view_location(viewer TEXT, target TEXT)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM circle_members cm1
    JOIN circle_members cm2 ON cm1.circle_id = cm2.circle_id
    JOIN circles c ON c.id = cm1.circle_id
    WHERE cm1.user_id = viewer
      AND cm2.user_id = target
      AND COALESCE((c.settings->>'location_sharing')::BOOLEAN, true)
  )
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE TABLE location_history (
    id            BIGSERIAL,
    user_id       TEXT NOT NULL,
    point         GEOGRAPHY(POINT, 4326) NOT NULL,
    speed         REAL,
    heading       REAL,
    accuracy      REAL,
    altitude      REAL,
    battery_level SMALLINT,
    activity      VARCHAR(20),
    source        VARCHAR(10),
    recorded_at   TIMESTAMPTZ NOT NULL,
    synced_at     TIMESTAMPTZ,
    PRIMARY KEY (id, recorded_at)
) PARTITION BY RANGE (recorded_at);

CREATE INDEX idx_location_history_user_time ON location_history(user_id, recorded_at DESC);
CREATE INDEX idx_location_history_point ON location_history USING GIST (point);

CREATE FUNCTION create_location_partitions(months_ahead INT DEFAULT 3)
RETURNS void AS $$
DECLARE
    start_date DATE;
    end_date DATE;
    partition_name TEXT;
BEGIN
    FOR i IN 0..months_ahead LOOP
        start_date := date_trunc('month', CURRENT_DATE + (i || ' months')::INTERVAL);
        end_date := start_date + INTERVAL '1 month';
        partition_name := 'location_history_' || to_char(start_date, 'YYYY_MM');
        IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relname = partition_name) THEN
            EXECUTE format(
                'CREATE TABLE %I PARTITION OF location_history FOR VALUES FROM (%L) TO (%L)',
                partition_name, start_date, end_date
            );
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

SELECT create_location_partitions(3);

ALTER TABLE location_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY location_history_select ON location_history FOR SELECT
  USING (
    user_id = requesting_user_id()
    OR can_view_location(requesting_user_id(), user_id)
  );

CREATE POLICY location_history_insert ON location_history FOR INSERT
  WITH CHECK (user_id = requesting_user_id());

-- No UPDATE policy: append-only by design
-- DELETE for retention cleanup only
CREATE POLICY location_history_delete ON location_history FOR DELETE
  USING (user_id = requesting_user_id());
```

- [ ] **Step 2: Create 00006_create_known_routes.sql**

Create `backend/supabase/migrations/00006_create_known_routes.sql`:

```sql
-- RoadPack v2: known_routes (learned commute patterns)

CREATE TABLE known_routes (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id          TEXT REFERENCES users(id) ON DELETE CASCADE,
    name             VARCHAR(100),
    origin           GEOGRAPHY(POINT, 4326),
    destination      GEOGRAPHY(POINT, 4326),
    route_geometry   GEOGRAPHY(LINESTRING, 4326),
    typical_start    TIME,
    typical_duration INTERVAL,
    days_active      INT[],
    confidence       REAL DEFAULT 0,
    repetition_count INT DEFAULT 0,
    last_traveled    TIMESTAMPTZ,
    created_at       TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_known_routes_user ON known_routes(user_id);

ALTER TABLE known_routes ENABLE ROW LEVEL SECURITY;

CREATE POLICY known_routes_select ON known_routes FOR SELECT
  USING (user_id = requesting_user_id());

CREATE POLICY known_routes_insert ON known_routes FOR INSERT
  WITH CHECK (user_id = requesting_user_id());

CREATE POLICY known_routes_update ON known_routes FOR UPDATE
  USING (user_id = requesting_user_id());

CREATE POLICY known_routes_delete ON known_routes FOR DELETE
  USING (user_id = requesting_user_id());
```

- [ ] **Step 3: Verify migrations apply**

```bash
cd backend && npx supabase migration list
```

Expected: migrations 00001-00006 all listed. If Docker available:

```bash
npx supabase db reset
```

Expected: clean reset, partition tables `location_history_YYYY_MM` created for current + 3 months.

- [ ] **Step 4: Commit**

```bash
git add backend/supabase/migrations/00005_create_location_history.sql backend/supabase/migrations/00006_create_known_routes.sql
git commit -m "feat(db): add geospatial layer migrations (location history, known routes)

- Monthly-partitioned location_history with create_location_partitions()
- can_view_location() SECURITY DEFINER helper for circle-aware visibility
- GIST spatial indexes on geography columns
- Append-only location_history (no UPDATE policy)"
```

---

### Task 3: Safety Layer (00007 + 00008)

**Files:**
- Create: `backend/supabase/migrations/00007_create_incidents.sql`
- Create: `backend/supabase/migrations/00008_create_hospitals.sql`

**Interfaces:**
- Consumes: `users` table, `incidents` table (self-reference for alerts), `emergency_contacts` table, `shares_circle_with()`, `requesting_user_id()`
- Produces:
  - `get_user_as_contact_ids(uid TEXT) -> SETOF UUID` — finds emergency_contact rows where user is the app_user
  - Tables: `incidents`, `incident_alerts`, `hospitals`

- [ ] **Step 1: Create 00007_create_incidents.sql**

Create `backend/supabase/migrations/00007_create_incidents.sql`:

```sql
-- RoadPack v2: incidents + incident_alerts

CREATE TABLE incidents (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id          TEXT REFERENCES users(id),
    type             VARCHAR(20) NOT NULL CHECK (type IN ('crash_detected','sos','inactivity','non_arrival','lost_contact')),
    severity         VARCHAR(10),
    confidence       REAL,
    location         GEOGRAPHY(POINT, 4326),
    speed_at_event   REAL,
    sensor_data      JSONB,
    status           VARCHAR(20) NOT NULL DEFAULT 'detected' CHECK (status IN ('detected','countdown','cancelled','dispatched','acknowledged','escalated','resolved')),
    cancelled_reason VARCHAR(50),
    media            JSONB,
    created_at       TIMESTAMPTZ DEFAULT now(),
    first_ack_at     TIMESTAMPTZ,
    resolved_at      TIMESTAMPTZ
);

CREATE INDEX idx_incidents_user ON incidents(user_id);
CREATE INDEX idx_incidents_status ON incidents(status) WHERE status NOT IN ('cancelled','resolved');

CREATE TABLE incident_alerts (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    incident_id     UUID REFERENCES incidents(id) ON DELETE CASCADE,
    contact_id      UUID,
    channel         VARCHAR(10) NOT NULL CHECK (channel IN ('push','sms','call','whatsapp')),
    status          VARCHAR(20) NOT NULL DEFAULT 'queued' CHECK (status IN ('queued','sent','delivered','read','failed')),
    sent_at         TIMESTAMPTZ,
    delivered_at    TIMESTAMPTZ,
    acknowledged_at TIMESTAMPTZ,
    ack_method      VARCHAR(10),
    error           TEXT
);

CREATE INDEX idx_incident_alerts_incident ON incident_alerts(incident_id);

-- Helper: find emergency_contact IDs where this user is the linked app user
CREATE FUNCTION get_user_as_contact_ids(uid TEXT)
RETURNS SETOF UUID AS $$
  SELECT id FROM emergency_contacts WHERE app_user_id = uid
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Incidents RLS: own + circle members can view

ALTER TABLE incidents ENABLE ROW LEVEL SECURITY;

CREATE POLICY incidents_select ON incidents FOR SELECT
  USING (
    user_id = requesting_user_id()
    OR shares_circle_with(requesting_user_id(), user_id)
  );

CREATE POLICY incidents_insert ON incidents FOR INSERT
  WITH CHECK (user_id = requesting_user_id());

CREATE POLICY incidents_update ON incidents FOR UPDATE
  USING (user_id = requesting_user_id());

-- No DELETE: incidents are permanent records

-- Incident Alerts RLS: user sees alerts for own incidents or where they are the contact

ALTER TABLE incident_alerts ENABLE ROW LEVEL SECURITY;

CREATE POLICY incident_alerts_select ON incident_alerts FOR SELECT
  USING (
    incident_id IN (SELECT id FROM incidents WHERE user_id = requesting_user_id())
    OR contact_id IN (SELECT get_user_as_contact_ids(requesting_user_id()))
  );

-- INSERT/UPDATE/DELETE: service role only (Edge Functions manage alert lifecycle)
```

- [ ] **Step 2: Create 00008_create_hospitals.sql**

Create `backend/supabase/migrations/00008_create_hospitals.sql`:

```sql
-- RoadPack v2: hospitals (seeded from government data, public read)

CREATE TABLE hospitals (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name          VARCHAR(200) NOT NULL,
    location      GEOGRAPHY(POINT, 4326),
    address       TEXT,
    phone         VARCHAR(15)[],
    type          VARCHAR(30) CHECK (type IN ('phc','chc','district','medical_college','private')),
    trauma_level  VARCHAR(10),
    has_emergency BOOLEAN DEFAULT true,
    state         VARCHAR(50),
    district      VARCHAR(50),
    verified_at   TIMESTAMPTZ,
    flag_count    INT DEFAULT 0,
    source        VARCHAR(50)
);

CREATE INDEX idx_hospitals_location ON hospitals USING GIST (location);

ALTER TABLE hospitals ENABLE ROW LEVEL SECURITY;

-- Any authenticated user can read hospitals
CREATE POLICY hospitals_select ON hospitals FOR SELECT
  USING (requesting_user_id() IS NOT NULL);

-- INSERT/UPDATE/DELETE: service role only (admin seeding + community flagging via Edge Functions)
```

- [ ] **Step 3: Verify migrations apply**

```bash
cd backend && npx supabase migration list
```

Expected: migrations 00001-00008 listed. If Docker available:

```bash
npx supabase db reset
```

Expected: clean reset, all tables including incidents/incident_alerts/hospitals created.

- [ ] **Step 4: Commit**

```bash
git add backend/supabase/migrations/00007_create_incidents.sql backend/supabase/migrations/00008_create_hospitals.sql
git commit -m "feat(db): add safety layer migrations (incidents, hospitals)

- incidents + incident_alerts with status lifecycle constraints
- Circle-aware incident visibility via shares_circle_with()
- get_user_as_contact_ids() for alert recipient visibility
- hospitals with GIST spatial index, public read for authenticated users
- Partial index on active incident statuses"
```

---

### Task 4: Compliance & Operations (00009 + 00010 + 00011)

**Files:**
- Create: `backend/supabase/migrations/00009_create_consents.sql`
- Create: `backend/supabase/migrations/00010_create_devices.sql`
- Create: `backend/supabase/migrations/00011_create_audit_log.sql`

**Interfaces:**
- Consumes: `users` table, `circle_members` table, `consents` table, `requesting_user_id()`
- Produces:
  - `log_audit_event() -> TRIGGER` — generic audit trigger function (SECURITY DEFINER)
  - Triggers on: `circle_members` (INSERT/DELETE), `consents` (INSERT/UPDATE)
  - Tables: `consents`, `devices`, `audit_log`

- [ ] **Step 1: Create 00009_create_consents.sql**

Create `backend/supabase/migrations/00009_create_consents.sql`:

```sql
-- RoadPack v2: consent ledger (DPDPA 2023 compliance)

CREATE TABLE consents (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id       TEXT REFERENCES users(id) ON DELETE CASCADE,
    consent_type  VARCHAR(40) NOT NULL CHECK (consent_type IN ('tracking','data_sharing_anon','sensor_upload','parental','institutional_circle','audio_capture')),
    granted_by    TEXT REFERENCES users(id),
    method        VARCHAR(20),
    granted_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at    TIMESTAMPTZ,
    version       VARCHAR(10)
);

CREATE INDEX idx_consents_user ON consents(user_id);

ALTER TABLE consents ENABLE ROW LEVEL SECURITY;

CREATE POLICY consents_select ON consents FOR SELECT
  USING (user_id = requesting_user_id());

CREATE POLICY consents_insert ON consents FOR INSERT
  WITH CHECK (user_id = requesting_user_id());

-- UPDATE: own rows only (for revoking via revoked_at)
CREATE POLICY consents_update ON consents FOR UPDATE
  USING (user_id = requesting_user_id());

-- No DELETE: consent history is permanent (audit trail)
```

- [ ] **Step 2: Create 00010_create_devices.sql**

Create `backend/supabase/migrations/00010_create_devices.sql`:

```sql
-- RoadPack v2: device registry (FCM tokens, OEM battery optimization tracking)

CREATE TABLE devices (
    id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id              TEXT REFERENCES users(id) ON DELETE CASCADE,
    fcm_token            TEXT,
    oem                  VARCHAR(30),
    os_version           VARCHAR(20),
    app_version          VARCHAR(20),
    battery_opt_disabled BOOLEAN DEFAULT false,
    last_heartbeat       TIMESTAMPTZ,
    created_at           TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_devices_user ON devices(user_id);
CREATE INDEX idx_devices_heartbeat ON devices(last_heartbeat) WHERE last_heartbeat IS NOT NULL;

ALTER TABLE devices ENABLE ROW LEVEL SECURITY;

CREATE POLICY devices_select ON devices FOR SELECT
  USING (user_id = requesting_user_id());

CREATE POLICY devices_insert ON devices FOR INSERT
  WITH CHECK (user_id = requesting_user_id());

CREATE POLICY devices_update ON devices FOR UPDATE
  USING (user_id = requesting_user_id());

CREATE POLICY devices_delete ON devices FOR DELETE
  USING (user_id = requesting_user_id());
```

- [ ] **Step 3: Create 00011_create_audit_log.sql**

Create `backend/supabase/migrations/00011_create_audit_log.sql`:

```sql
-- RoadPack v2: audit_log + generic trigger function + trigger attachments

CREATE TABLE audit_log (
    id          BIGSERIAL PRIMARY KEY,
    actor_id    TEXT,
    subject_id  TEXT,
    action      VARCHAR(50) NOT NULL,
    detail      JSONB DEFAULT '{}',
    created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_audit_log_actor ON audit_log(actor_id);
CREATE INDEX idx_audit_log_subject ON audit_log(subject_id);

-- Generic audit trigger: logs old/new row state with action name from TG_ARGV[0]
CREATE FUNCTION log_audit_event()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_log (actor_id, subject_id, action, detail)
    VALUES (
        requesting_user_id(),
        COALESCE(NEW.user_id, OLD.user_id),
        TG_ARGV[0],
        jsonb_build_object('old', to_jsonb(OLD), 'new', to_jsonb(NEW))
    );
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Attach audit triggers to security-sensitive tables

CREATE TRIGGER audit_circle_members_insert
  AFTER INSERT ON circle_members
  FOR EACH ROW EXECUTE FUNCTION log_audit_event('circle_member_added');

CREATE TRIGGER audit_circle_members_delete
  AFTER DELETE ON circle_members
  FOR EACH ROW EXECUTE FUNCTION log_audit_event('circle_member_removed');

CREATE TRIGGER audit_consents_insert
  AFTER INSERT ON consents
  FOR EACH ROW EXECUTE FUNCTION log_audit_event('consent_granted');

CREATE TRIGGER audit_consents_update
  AFTER UPDATE ON consents
  FOR EACH ROW EXECUTE FUNCTION log_audit_event('consent_updated');

-- Audit log RLS: users see only events where they are the actor

ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY audit_log_select ON audit_log FOR SELECT
  USING (actor_id = requesting_user_id());

-- INSERT: via SECURITY DEFINER trigger only; no direct user inserts
-- No UPDATE or DELETE: audit trail is immutable
```

- [ ] **Step 4: Verify all migrations apply**

```bash
cd backend && npx supabase migration list
```

Expected: all 11 migrations (00001-00011) listed. If Docker available:

```bash
npx supabase db reset
```

Expected: clean reset, all tables + functions + triggers + partitions created. Verify trigger attachment:

```bash
npx supabase db reset 2>&1 | tail -5
```

Should show no errors.

- [ ] **Step 5: Commit**

```bash
git add backend/supabase/migrations/00009_create_consents.sql backend/supabase/migrations/00010_create_devices.sql backend/supabase/migrations/00011_create_audit_log.sql
git commit -m "feat(db): add compliance and operations migrations (consents, devices, audit)

- DPDPA 2023 consent ledger with consent_type constraints
- Device registry with heartbeat tracking for lost-contact detection
- Audit log with SECURITY DEFINER trigger function
- Triggers on circle_members (join/leave) and consents (grant/update)
- Immutable audit trail: no UPDATE or DELETE policies"
```
