# RoadPack v2 — Database Migrations Design

**Date:** 2026-07-08
**Status:** Approved
**Scope:** All PostgreSQL + PostGIS tables, RLS policies, indexes, helper functions, audit triggers

---

## Decisions

| Decision | Choice |
|---|---|
| RLS strategy | Full RLS from day one |
| Partitioning | Monthly partitions for location_history |
| Migration split | One migration file per table |
| Auth provider | Clerk (JWT integrated with Supabase) |
| User ID type | TEXT (Clerk IDs are strings like `user_2x...`) |

---

## 1. Migration File Structure

```
backend/supabase/migrations/
  00001_enable_extensions.sql           # EXISTS — PostGIS, uuid-ossp, pg_cron
  00002_create_users.sql                # users + RLS helper functions
  00003_create_circles.sql              # circles + circle_members + RLS
  00004_create_emergency_contacts.sql   # emergency_contacts + RLS
  00005_create_location_history.sql     # partitioned + spatial index + RLS
  00006_create_known_routes.sql         # known_routes + spatial index + RLS
  00007_create_incidents.sql            # incidents + incident_alerts + RLS
  00008_create_hospitals.sql            # hospitals + spatial index + public read RLS
  00009_create_consents.sql             # consent ledger + RLS
  00010_create_devices.sql              # devices + RLS
  00011_create_audit_log.sql            # audit_log + RLS + trigger function
```

Migration 00001 already exists. Migrations 00002-00011 to be created. FK dependency order is respected (users first, then referencing tables).

### Auth Architecture: Clerk + Supabase

Clerk handles all authentication (OTP, sessions, user management). Supabase is configured to accept Clerk JWTs by setting Clerk's JWT signing key as Supabase's custom JWT secret. This means:

- `auth.uid()::TEXT` in RLS policies returns the Clerk user ID
- All `user_id` / `id` columns referencing users are TEXT (Clerk IDs are strings like `user_2x...`)
- All FK references to `users(id)` use TEXT
- Clerk webhook syncs profile data to the `users` table on signup/update
- Edge Functions use service role for cascade operations (bypass RLS)
- No Supabase Auth dependency in the client app

---

## 2. Table Schemas

All schemas follow PRD Section 12 with Clerk-adapted ID types. Additions noted with `-- NEW`.

### 00002 — users

```sql
CREATE TABLE users (
    id                TEXT PRIMARY KEY,  -- Clerk user ID
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
```

RLS helper functions are created in migration 00003 (after `circle_members` exists):

```sql
-- Returns all circle_ids a user belongs to
CREATE FUNCTION get_user_circle_ids(uid TEXT)
RETURNS SETOF UUID AS $$
  SELECT circle_id FROM circle_members WHERE user_id = uid
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Boolean check for circle membership
CREATE FUNCTION is_circle_member(uid TEXT, cid UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (SELECT 1 FROM circle_members WHERE user_id = uid AND circle_id = cid)
$$ LANGUAGE sql SECURITY DEFINER STABLE;
```

Users RLS policies that need circle helpers (e.g., location_history visibility) are added in later migrations after these functions exist.

### 00003 — circles + circle_members

```sql
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
```

### 00004 — emergency_contacts

```sql
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
```

### 00005 — location_history (monthly partitioned)

```sql
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
```

Partition creation function:

```sql
-- Creates monthly partitions for N months ahead
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

-- Create initial partitions (current month + 3 ahead)
SELECT create_location_partitions(3);
```

### 00006 — known_routes

```sql
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
```

### 00007 — incidents + incident_alerts

```sql
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
```

### 00008 — hospitals

```sql
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
```

### 00009 — consents

```sql
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
```

### 00010 — devices

```sql
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
```

### 00011 — audit_log + trigger

```sql
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

-- Generic audit trigger function
CREATE FUNCTION log_audit_event()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_log (actor_id, subject_id, action, detail)
    VALUES (
        auth.uid()::TEXT,
        COALESCE(NEW.user_id, OLD.user_id),
        TG_ARGV[0],
        jsonb_build_object('old', to_jsonb(OLD), 'new', to_jsonb(NEW))
    );
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

Audit triggers attached to: `circle_members` (INSERT/DELETE), `consents` (INSERT/UPDATE).

---

## 3. RLS Policy Summary

| Table | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| users | Own row | Authenticated (self) | Own row | Own row |
| circles | Circle member | Authenticated | Circle admin | Circle admin |
| circle_members | Same circle member | Circle admin or self-accept | Own membership | Own (leave) or admin |
| emergency_contacts | Own | Own | Own | Own |
| location_history | Own + location-sharing circle members | Own | None (append-only) | Own (retention) |
| known_routes | Own | Own | Own | Own |
| incidents | Own + circle members | Own | Own (cancel/resolve) | None |
| incident_alerts | Own incident or contact is self | Service role | Service role | None |
| hospitals | All authenticated | Service role | Service role | Service role |
| consents | Own | Own | Own (revoke only) | None |
| devices | Own | Own | Own | Own |
| audit_log | Own (actor_id) | Service role + trigger | None | None |

All Edge Functions use service role (bypasses RLS) for cascade operations.

Circle-based visibility uses `get_user_circle_ids(auth.uid())` helper.

`location_history` SELECT policy checks circle membership AND that the circle's permissions allow location sharing (via circle_members.permissions JSONB or circles.settings JSONB).

---

## 4. Operational Notes

- **Partition maintenance:** `create_location_partitions()` should be called monthly via pg_cron or an Edge Function cron
- **Retention:** A scheduled job deletes location_history rows older than the user's configured retention (default 7 days, stored in user preferences or a config table)
- **is_minor computed column:** Re-evaluates on read; users crossing the 18-year threshold automatically transition
- **Medical notes encryption:** Application-layer encryption before INSERT; the database stores ciphertext
- **Idempotent incident packets:** `incidents.id` is client-generated UUID, allowing upsert for retry resilience over 2G
