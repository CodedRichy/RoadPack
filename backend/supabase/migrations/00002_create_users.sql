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
