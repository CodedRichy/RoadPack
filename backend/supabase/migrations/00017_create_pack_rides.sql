-- RoadPack: pack rides (Layer 4 -- group ride coordination)
-- TRD: docs/trd/roadpack-pack-mode-trd.md sections 3.1, 3.3, 4.2-4.6
--
-- Step 1 of the Pack Mode build order. Contains the schema, the RLS surface,
-- and the route-relative positioning primitives. No tick, no status writes
-- from crash detection, no viewer. Those are steps 3-5.

-- ---------------------------------------------------------------------------
-- 1. Tables
-- ---------------------------------------------------------------------------

CREATE TABLE pack_rides (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    circle_id        UUID REFERENCES circles(id) ON DELETE SET NULL,
    leader_id        TEXT NOT NULL REFERENCES users(id),
    name             VARCHAR(80),

    destination      GEOGRAPHY(POINT, 4326) NOT NULL,
    route_line       GEOGRAPHY(LINESTRING, 4326) NOT NULL,
    -- Cumulative geodesic distance (metres) at each vertex of route_line.
    -- 1-indexed to match ST_PointN. route_cumdist[1] = 0.
    -- Length MUST equal ST_NPoints(route_line) -- enforced by trigger below.
    route_cumdist    DOUBLE PRECISION[] NOT NULL,
    route_length_m   DOUBLE PRECISION NOT NULL,
    route_source     VARCHAR(20) NOT NULL,

    -- Positioning tunables (TRD 4.6). Ride-level, never constants: Indian
    -- divided highways with wide medians need a higher off-route threshold
    -- than dense urban grids, and the value must be calibrated from field
    -- traces rather than guessed once and frozen.
    --
    -- The search window is derived from elapsed time, not fixed at the TRD's
    -- +/-2 km. See fn_pack_project_member. window_fwd_m/window_back_m are the
    -- caps that apply after a long gap, not the window itself.
    off_route_threshold_m DOUBLE PRECISION NOT NULL DEFAULT 150,
    window_fwd_m          DOUBLE PRECISION NOT NULL DEFAULT 2000,
    window_back_m         DOUBLE PRECISION NOT NULL DEFAULT 500,
    -- Fastest a member is assumed to travel between fixes. 33.3 m/s = 120 km/h.
    max_speed_mps         DOUBLE PRECISION NOT NULL DEFAULT 33.3,
    -- Slack for GPS error at both ends of the window.
    window_jitter_m       DOUBLE PRECISION NOT NULL DEFAULT 75,
    stale_threshold_s     INTEGER          NOT NULL DEFAULT 90,

    share_token      TEXT UNIQUE NOT NULL,
    share_expires_at TIMESTAMPTZ NOT NULL,
    share_revoked_at TIMESTAMPTZ,

    status           VARCHAR(10) NOT NULL DEFAULT 'draft'
                     CHECK (status IN ('draft','active','ended')),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    started_at       TIMESTAMPTZ,
    ended_at         TIMESTAMPTZ,
    -- Hard stop; enforced by pg_cron sweep (TRD 8.4, wired in a later step).
    expires_at       TIMESTAMPTZ NOT NULL DEFAULT now() + INTERVAL '12 hours',

    CONSTRAINT pack_rides_route_length_positive CHECK (route_length_m > 0),
    CONSTRAINT pack_rides_window_nonneg CHECK (window_back_m >= 0 AND window_fwd_m >= 0),
    CONSTRAINT pack_rides_speed_positive CHECK (max_speed_mps > 0),
    CONSTRAINT pack_rides_jitter_nonneg CHECK (window_jitter_m >= 0),
    CONSTRAINT pack_rides_off_route_positive CHECK (off_route_threshold_m > 0)
);

CREATE INDEX idx_pack_rides_active ON pack_rides(status) WHERE status = 'active';
CREATE INDEX idx_pack_rides_leader ON pack_rides(leader_id);
CREATE INDEX idx_pack_rides_circle ON pack_rides(circle_id);
-- share_token is already backed by the UNIQUE constraint's index.

CREATE TABLE pack_ride_members (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ride_id          UUID NOT NULL REFERENCES pack_rides(id) ON DELETE CASCADE,
    user_id          TEXT NOT NULL REFERENCES users(id),
    role             VARCHAR(10) NOT NULL DEFAULT 'rider'
                     CHECK (role IN ('leader','sweep','rider')),

    joined_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    left_at          TIMESTAMPTZ,

    -- Linear referencing state
    chainage_m       DOUBLE PRECISION,
    chainage_at      TIMESTAMPTZ,
    last_position    GEOGRAPHY(POINT, 4326),
    off_route        BOOLEAN NOT NULL DEFAULT false,
    off_route_dist_m DOUBLE PRECISION,

    -- Status. Written manually by the member for the first block of values;
    -- the last three are automatic-only (TRD 5.2) and are rejected from the
    -- client write path by fn_pack_set_status, added in step 4.
    status_code      VARCHAR(20) NOT NULL DEFAULT 'riding'
                     CHECK (status_code IN (
                        'riding','refueling','break','wrong_turn','waiting',
                        'stopped','done',
                        'unexplained_stop','possible_incident','unreachable'
                     )),
    status_note      VARCHAR(140),
    status_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    status_auto      BOOLEAN NOT NULL DEFAULT false,
    incident_id      UUID REFERENCES incidents(id) ON DELETE SET NULL,

    UNIQUE (ride_id, user_id)
);

CREATE INDEX idx_pack_members_ride ON pack_ride_members(ride_id) WHERE left_at IS NULL;
CREATE INDEX idx_pack_members_user ON pack_ride_members(user_id);
CREATE INDEX idx_pack_members_incident ON pack_ride_members(incident_id)
  WHERE incident_id IS NOT NULL;

-- Leader breadcrumbs, for time-gap derivation (TRD 4.4). Keyed on chainage,
-- not time: the lookup is always "when was the leader at MY chainage", and
-- chainage as the key deduplicates a stopped leader automatically.
CREATE TABLE pack_ride_breadcrumbs (
    ride_id     UUID NOT NULL REFERENCES pack_rides(id) ON DELETE CASCADE,
    chainage_m  DOUBLE PRECISION NOT NULL,
    at          TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (ride_id, chainage_m)
);

-- ---------------------------------------------------------------------------
-- 2. route_cumdist integrity
-- ---------------------------------------------------------------------------

-- Builds the cumulative geodesic distance array for a route line.
-- Called once at ride creation. Converting ST_LineLocatePoint's 0-1 fraction
-- to metres by multiplying ST_Length is wrong on a route with variable-density
-- vertices, so the array is precomputed and interpolated instead (TRD 3.2).
CREATE FUNCTION fn_pack_build_cumdist(route GEOGRAPHY)
RETURNS DOUBLE PRECISION[] AS $$
  WITH g AS (SELECT route::geometry AS line),
  steps AS (
    SELECT i,
           CASE WHEN i = 1 THEN 0
                ELSE ST_Distance(
                       ST_PointN(g.line, i - 1)::geography,
                       ST_PointN(g.line, i)::geography)
           END AS d
    FROM g, generate_series(1, ST_NPoints(g.line)) AS i
  ),
  cum AS (SELECT i, SUM(d) OVER (ORDER BY i) AS c FROM steps)
  SELECT array_agg(c ORDER BY i) FROM cum
$$ LANGUAGE sql IMMUTABLE STRICT;

-- The whole algorithm assumes cumdist and the line agree. A mismatch would
-- silently produce confidently wrong chainage, so it is a constraint, not a
-- convention.
CREATE FUNCTION fn_pack_rides_validate() RETURNS TRIGGER AS $$
BEGIN
  IF array_length(NEW.route_cumdist, 1) IS DISTINCT FROM
     ST_NPoints(NEW.route_line::geometry) THEN
    RAISE EXCEPTION
      'route_cumdist length (%) must equal ST_NPoints(route_line) (%)',
      array_length(NEW.route_cumdist, 1),
      ST_NPoints(NEW.route_line::geometry);
  END IF;
  IF NEW.route_cumdist[1] <> 0 THEN
    RAISE EXCEPTION 'route_cumdist[1] must be 0, got %', NEW.route_cumdist[1];
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_pack_rides_validate
  BEFORE INSERT OR UPDATE OF route_line, route_cumdist ON pack_rides
  FOR EACH ROW EXECUTE FUNCTION fn_pack_rides_validate();

-- ---------------------------------------------------------------------------
-- 3. Route-relative positioning (TRD 4.2 - 4.5)
-- ---------------------------------------------------------------------------

-- Projects a position onto a windowed span of the route and returns absolute
-- chainage in metres plus the geodesic distance from the route.
--
-- Deviation from TRD 4.2, deliberate: the TRD windows with ST_LineSubstring
-- and converts fractions to metres. ST_LineSubstring fractions are planar 2-D
-- length fractions of a lon/lat linestring, where one degree of longitude is
-- worth cos(latitude) times one degree of latitude. Mixing those fractions
-- with a geodesic cumulative-distance array biases both the window bounds and
-- the resulting chainage on any route that changes bearing -- which is every
-- real route. Scanning the segments that the cumdist array already indexes
-- keeps every measurement geodesic and removes that error class entirely.
-- Cost is the same order: a windowed scan of a few hundred segments.
--
-- lo_m/hi_m bound the search by chainage. Pass 0/route_length_m for a
-- whole-line search (first fix, or re-acquisition after a stale gap).
CREATE FUNCTION fn_pack_project_on_span(
  route      GEOGRAPHY,
  cumdist    DOUBLE PRECISION[],
  pos        GEOGRAPHY,
  lo_m       DOUBLE PRECISION,
  hi_m       DOUBLE PRECISION
)
RETURNS TABLE (chainage_m DOUBLE PRECISION, dist_m DOUBLE PRECISION) AS $$
  WITH g AS (SELECT route::geometry AS line, pos::geometry AS p),
  seg AS (
    SELECT i,
           ST_MakeLine(ST_PointN(g.line, i), ST_PointN(g.line, i + 1)) AS s,
           cumdist[i] AS seg_start_m
    FROM g, generate_series(1, ST_NPoints(g.line) - 1) AS i
    -- Keep any segment that overlaps the window at all.
    WHERE cumdist[i + 1] >= lo_m AND cumdist[i] <= hi_m
  ),
  nearest AS (
    SELECT seg.i,
           seg.seg_start_m,
           seg.s,
           ST_Distance(seg.s::geography, pos) AS d
    FROM seg
    ORDER BY d
    LIMIT 1
  )
  -- Offset within the winning segment is measured geodesically from the
  -- segment's start vertex to the planar closest point. Over a segment of a
  -- few hundred metres the planar-vs-geodesic difference in WHERE the closest
  -- point falls is sub-centimetre; the distance itself is geodesic.
  SELECT
    LEAST(
      GREATEST(
        n.seg_start_m + ST_Distance(
          ST_StartPoint(n.s)::geography,
          ST_ClosestPoint(n.s, (SELECT p FROM g))::geography),
        lo_m),
      hi_m),
    n.d
  FROM nearest n
$$ LANGUAGE sql STABLE;

-- Per-position-update entry point. Windows the search around the member's
-- last known chainage, applies the off-route test, and writes the linear
-- referencing state.
--
-- Why the window is non-optional (TRD 4.3): an unwindowed nearest-point search
-- returns the nearest point on the ENTIRE line. On a hairpin, a cloverleaf, or
-- the return leg of an out-and-back, the projection jumps kilometres and the
-- displayed gap becomes confidently wrong. The tests for this function exist
-- to prove that claim, not to assume it.
--
-- Deviation from TRD 4.3, forced by the traces: the window is derived from
-- elapsed time, not fixed at +/-2 km. A Western Ghats hairpin puts its two
-- legs ~1 km apart in chainage and ~40 m apart on the ground, which a 2 km
-- window contains whole -- so the fixed window admits exactly the ambiguity it
-- was introduced to remove. The bound that actually holds is kinematic: a
-- rider cannot have travelled further than max_speed_mps x elapsed since the
-- last fix. At a 5 s tick that is a ~240 m corridor, which separates hairpin
-- legs and grade-separated crossings alike. window_fwd_m and window_back_m
-- remain as caps for long gaps.
--
-- Re-acquisition: if the windowed search finds nothing within the off-route
-- threshold, chainage is NOT moved. A member whose fix is older than
-- stale_threshold_s is treated as a first fix and searched against the whole
-- line, which is how a rider returns after a tunnel, an app restart, or a
-- dead battery without the window trapping them at a stale chainage forever.
CREATE FUNCTION fn_pack_project_member(
  p_ride_id UUID,
  p_user_id TEXT,
  p_pos     GEOGRAPHY,
  p_at      TIMESTAMPTZ DEFAULT now()
)
RETURNS TABLE (
  chainage_m       DOUBLE PRECISION,
  off_route        BOOLEAN,
  off_route_dist_m DOUBLE PRECISION,
  windowed         BOOLEAN
) AS $$
DECLARE
  r          pack_rides%ROWTYPE;
  m          pack_ride_members%ROWTYPE;
  v_lo       DOUBLE PRECISION;
  v_hi       DOUBLE PRECISION;
  v_windowed BOOLEAN;
  v_chain    DOUBLE PRECISION;
  v_dist     DOUBLE PRECISION;
  v_full     DOUBLE PRECISION;
  v_elapsed  DOUBLE PRECISION;
BEGIN
  SELECT * INTO r FROM pack_rides WHERE id = p_ride_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'pack ride % not found', p_ride_id;
  END IF;

  SELECT * INTO m FROM pack_ride_members
   WHERE ride_id = p_ride_id AND user_id = p_user_id AND left_at IS NULL;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'user % is not an active member of ride %', p_user_id, p_ride_id;
  END IF;

  -- Window only when there is a trustworthy prior fix.
  v_windowed := m.chainage_m IS NOT NULL
            AND m.chainage_at IS NOT NULL
            AND p_at - m.chainage_at <= make_interval(secs => r.stale_threshold_s);

  IF v_windowed THEN
    v_elapsed := GREATEST(0, EXTRACT(EPOCH FROM (p_at - m.chainage_at)));
    -- Backward travel along the route is rare and slow (a U-turn, a missed
    -- exit), so the rear bound is a quarter of the forward one.
    v_lo := GREATEST(0, m.chainage_m
              - LEAST(r.window_back_m,
                      0.25 * r.max_speed_mps * v_elapsed + r.window_jitter_m));
    v_hi := LEAST(r.route_length_m, m.chainage_m
              + LEAST(r.window_fwd_m,
                      r.max_speed_mps * v_elapsed + r.window_jitter_m));
  ELSE
    v_lo := 0;
    v_hi := r.route_length_m;
  END IF;

  SELECT s.chainage_m, s.dist_m INTO v_chain, v_dist
    FROM fn_pack_project_on_span(r.route_line, r.route_cumdist, p_pos, v_lo, v_hi) s;

  IF v_dist IS NOT NULL AND v_dist <= r.off_route_threshold_m THEN
    UPDATE pack_ride_members
       SET chainage_m       = v_chain,
           chainage_at      = p_at,
           last_position    = p_pos,
           off_route        = false,
           off_route_dist_m = v_dist
     WHERE id = m.id;

    RETURN QUERY SELECT v_chain, false, v_dist, v_windowed;
    RETURN;
  END IF;

  -- Outside the window's corridor. Distinguish "genuinely off the route" from
  -- "still on the route but somewhere the window cannot see" -- the second is
  -- not off-route, but it is also not a position we are willing to jump to,
  -- because that jump is exactly the hairpin failure the window exists to
  -- prevent. Chainage stays put until the fix goes stale and re-acquires.
  v_full := ST_Distance(p_pos, r.route_line);

  UPDATE pack_ride_members
     SET last_position    = p_pos,
         off_route        = (v_full > r.off_route_threshold_m),
         off_route_dist_m = v_full
   WHERE id = m.id;

  RETURN QUERY SELECT m.chainage_m, (v_full > r.off_route_threshold_m), v_full, v_windowed;
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- 4. Time gap from breadcrumbs (TRD 4.4)
-- ---------------------------------------------------------------------------

-- Records where the leader was and when. Chainage is the primary key, so a
-- stopped leader does not accumulate rows.
CREATE FUNCTION fn_pack_record_breadcrumb(
  p_ride_id UUID,
  p_chainage_m DOUBLE PRECISION,
  p_at TIMESTAMPTZ DEFAULT now()
) RETURNS VOID AS $$
  INSERT INTO pack_ride_breadcrumbs (ride_id, chainage_m, at)
  VALUES (p_ride_id, p_chainage_m, p_at)
  ON CONFLICT (ride_id, chainage_m) DO NOTHING
$$ LANGUAGE sql;

-- How long ago the leader passed the given chainage. Ground truth: it absorbs
-- real traffic, real road conditions, and real stops, because it measures how
-- long the leader actually took to cover that ground. One indexed lookup, no
-- external routing service.
--
-- Returns NULL when no breadcrumb exists yet (first ~2 km of a ride); callers
-- fall back to distance / trailing speed and mark the value as estimated.
CREATE FUNCTION fn_pack_time_gap(
  p_ride_id UUID,
  p_chainage_m DOUBLE PRECISION,
  p_now TIMESTAMPTZ DEFAULT now()
) RETURNS INTERVAL AS $$
  SELECT p_now - at
    FROM pack_ride_breadcrumbs
   WHERE ride_id = p_ride_id
   ORDER BY abs(chainage_m - p_chainage_m)
   LIMIT 1
$$ LANGUAGE sql STABLE;

-- ---------------------------------------------------------------------------
-- 5. Gap display with suppression (TRD 4.5)
-- ---------------------------------------------------------------------------

-- The gap is a number the rider will act on -- pull over and wait, or push on.
-- A wrong number is worse than no number, so every condition under which the
-- gap is not trustworthy resolves to a display state instead of a figure.
CREATE FUNCTION fn_pack_member_gaps(
  p_ride_id UUID,
  p_now TIMESTAMPTZ DEFAULT now()
)
RETURNS TABLE (
  user_id        TEXT,
  role           VARCHAR(10),
  chainage_m     DOUBLE PRECISION,
  gap_m          DOUBLE PRECISION,
  gap_s          DOUBLE PRECISION,
  gap_estimated  BOOLEAN,
  display_state  TEXT,
  status_code    VARCHAR(20),
  status_auto    BOOLEAN,
  off_route      BOOLEAN,
  straight_m     DOUBLE PRECISION,
  stale          BOOLEAN
) AS $$
  WITH r AS (SELECT * FROM pack_rides WHERE id = p_ride_id),
  lead AS (
    SELECT max(m.chainage_m) AS chainage_m
      FROM pack_ride_members m
     WHERE m.ride_id = p_ride_id AND m.left_at IS NULL AND NOT m.off_route
  )
  SELECT
    m.user_id,
    m.role,
    m.chainage_m,
    CASE WHEN m.off_route OR m.chainage_m IS NULL THEN NULL
         ELSE m.chainage_m - lead.chainage_m END,
    CASE WHEN m.off_route OR m.chainage_m IS NULL THEN NULL
         ELSE EXTRACT(EPOCH FROM fn_pack_time_gap(p_ride_id, m.chainage_m, p_now)) END,
    CASE WHEN m.off_route OR m.chainage_m IS NULL THEN false
         ELSE fn_pack_time_gap(p_ride_id, m.chainage_m, p_now) IS NULL END,
    -- Precedence matters: off-route beats stale beats locating. A rider who
    -- left the route and then lost signal is off-route first; that is the
    -- fact the pack needs.
    CASE
      WHEN m.off_route                     THEN 'off_route'
      WHEN m.chainage_m IS NULL            THEN 'locating'
      WHEN m.chainage_at IS NULL
        OR p_now - m.chainage_at > make_interval(secs => r.stale_threshold_s)
                                           THEN 'stale'
      WHEN fn_pack_time_gap(p_ride_id, m.chainage_m, p_now) IS NULL
                                           THEN 'estimated'
      ELSE 'ok'
    END,
    m.status_code,
    m.status_auto,
    m.off_route,
    CASE WHEN m.off_route
         THEN ST_Distance(m.last_position, r.route_line) END,
    m.chainage_at IS NULL
      OR p_now - m.chainage_at > make_interval(secs => r.stale_threshold_s)
  FROM pack_ride_members m, r, lead
  WHERE m.ride_id = p_ride_id AND m.left_at IS NULL
$$ LANGUAGE sql STABLE;

-- ---------------------------------------------------------------------------
-- 6. RLS (TRD 3.3)
-- ---------------------------------------------------------------------------

-- Membership lookup as SECURITY DEFINER. The TRD writes the member-visibility
-- policy as an EXISTS over pack_ride_members inside a policy ON
-- pack_ride_members, which recurses: evaluating the policy requires reading
-- the table, which requires evaluating the policy. A definer function breaks
-- the cycle, and it is the same shape the circles migration already uses.
CREATE FUNCTION is_pack_member(uid TEXT, rid UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM pack_ride_members
     WHERE ride_id = rid AND user_id = uid AND left_at IS NULL
  )
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;

CREATE FUNCTION is_pack_leader(uid TEXT, rid UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (SELECT 1 FROM pack_rides WHERE id = rid AND leader_id = uid)
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;

ALTER TABLE pack_rides            ENABLE ROW LEVEL SECURITY;
ALTER TABLE pack_ride_members     ENABLE ROW LEVEL SECURITY;
ALTER TABLE pack_ride_breadcrumbs ENABLE ROW LEVEL SECURITY;

-- Helper calls are wrapped in SELECT so they are evaluated once per query as
-- an InitPlan rather than once per row.
CREATE POLICY pack_rides_select ON pack_rides FOR SELECT
  USING (is_pack_member((SELECT requesting_user_id()), id));

CREATE POLICY pack_rides_insert ON pack_rides FOR INSERT
  WITH CHECK (leader_id = (SELECT requesting_user_id()));

CREATE POLICY pack_rides_update ON pack_rides FOR UPDATE
  USING (leader_id = (SELECT requesting_user_id()));

-- No DELETE policy: rides are ended, not deleted. The pg_cron sweep runs as
-- service role.

CREATE POLICY pack_members_select ON pack_ride_members FOR SELECT
  USING (is_pack_member((SELECT requesting_user_id()), ride_id));

CREATE POLICY pack_members_insert ON pack_ride_members FOR INSERT
  WITH CHECK (user_id = (SELECT requesting_user_id()));

-- A member may only ever write their own row.
CREATE POLICY pack_members_update ON pack_ride_members FOR UPDATE
  USING (user_id = (SELECT requesting_user_id()));

CREATE POLICY pack_members_delete ON pack_ride_members FOR DELETE
  USING (user_id = (SELECT requesting_user_id()));

CREATE POLICY pack_breadcrumbs_select ON pack_ride_breadcrumbs FOR SELECT
  USING (is_pack_member((SELECT requesting_user_id()), ride_id));

-- Breadcrumb writes are server-side only (the tick runs as service role).

-- Anonymous viewers never touch these tables. They read a pre-rendered
-- snapshot from Storage (TRD 7.2), so no policy here has to reason about
-- unauthenticated access and a policy bug cannot leak the live table.
