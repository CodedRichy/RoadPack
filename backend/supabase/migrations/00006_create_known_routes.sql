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
