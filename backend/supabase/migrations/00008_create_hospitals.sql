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
