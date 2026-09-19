-- RoadPack: flat projection of hospitals for the client (FR-111)
--
-- `hospitals.location` is a PostGIS geography. PostgREST cannot project
-- ST_X/ST_Y through a select, so a client asking for coordinates either gets
-- an opaque WKB blob it has to decode, or nothing. The bystander screen needs
-- plain lat/lng scalars to sort hospitals by distance, and it needs them on a
-- phone that may never have had a good network moment.
--
-- security_invoker = true is deliberate: the view must not become a way to
-- read the table with the view owner's rights. The caller's own RLS applies.

CREATE VIEW hospitals_flat WITH (security_invoker = true) AS
SELECT
  id,
  name,
  address,
  phone,
  type,
  trauma_level,
  has_emergency,
  state,
  district,
  verified_at,
  flag_count,
  source,
  ST_Y(location::geometry) AS lat,
  ST_X(location::geometry) AS lng
FROM hospitals;

COMMENT ON VIEW hospitals_flat IS
  'Hospitals with coordinates as lat/lng scalars for client consumption. '
  'Reference data only -- no user data passes through here.';

-- Anonymous read.
--
-- Bystander Mode (FR-007) is used by a stranger holding a crash victim''s
-- phone: not signed in, often no network, and in no position to authenticate.
-- The existing policy required an authenticated caller, which would have made
-- the nearest-hospital lookup fail in exactly the situation it exists for.
--
-- The exposure is bounded and acceptable: this table holds published facility
-- reference data -- name, address, public phone, coordinates -- and no user
-- data whatsoever. Writes remain service-role only.
DROP POLICY IF EXISTS hospitals_select ON hospitals;

CREATE POLICY hospitals_select ON hospitals FOR SELECT
  USING (true);

GRANT SELECT ON hospitals TO anon, authenticated;
GRANT SELECT ON hospitals_flat TO anon, authenticated;
