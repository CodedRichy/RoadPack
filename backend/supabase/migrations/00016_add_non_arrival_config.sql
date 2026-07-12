-- Non-arrival configuration columns

ALTER TABLE users ADD COLUMN IF NOT EXISTS non_arrival_delay_min INT DEFAULT 15;
ALTER TABLE users ADD COLUMN IF NOT EXISTS non_arrival_enabled BOOLEAN DEFAULT true;
ALTER TABLE known_routes ADD COLUMN IF NOT EXISTS non_arrival_enabled BOOLEAN DEFAULT true;

-- RPC: check if a user has a recent location near a destination point
CREATE OR REPLACE FUNCTION check_near_destination(
  uid UUID,
  dest_point GEOGRAPHY,
  radius_m DOUBLE PRECISION,
  since TIMESTAMPTZ
) RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM location_history
    WHERE user_id = uid
      AND recorded_at >= since
      AND ST_DWithin(point, dest_point, radius_m)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
