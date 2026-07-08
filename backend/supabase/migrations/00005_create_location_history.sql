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
      AND COALESCE((c.settings->>'location_sharing')::BOOLEAN, false)
  )
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;

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

-- Monthly partition maintenance via pg_cron
SELECT cron.schedule(
  'maintain-location-partitions',
  '0 0 1 * *',
  'SELECT create_location_partitions(3)'
);
