-- Pack Mode Step 1 gate: route-relative positioning must survive geometry that
-- revisits its own vicinity. If chainage projection is wrong on a hairpin or a
-- grade-separated crossing, the "Ravi is 4.2 km behind on route" primitive does
-- not exist and nothing built on top of it is worth building.
--
-- Run: bash backend/supabase/tests/run.sh
--
-- Oracle: every route here is CONSTRUCTED by walking geodesic steps with
-- ST_Project, so the true chainage of any vertex is known independently of the
-- function under test -- it is the sum of the step lengths that built it. Each
-- test displaces a rider from a known vertex and asserts the projection
-- recovers that vertex's chainage.

BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(37);

-- ---------------------------------------------------------------------------
-- Geometry builders
-- ---------------------------------------------------------------------------

-- Walks a geodesic polyline from p0. legs is a JSON array of
-- {"az": degrees, "len": metres, "n": vertices in the leg}.
CREATE FUNCTION tst_walk(p0 GEOGRAPHY, legs JSONB)
RETURNS GEOGRAPHY LANGUAGE plpgsql AS $$
DECLARE
  pts GEOMETRY[];
  cur GEOGRAPHY := p0;
  leg JSONB;
  i INT; n INT; len DOUBLE PRECISION; az DOUBLE PRECISION;
BEGIN
  pts := ARRAY[cur::geometry];
  FOR leg IN SELECT value FROM jsonb_array_elements(legs) LOOP
    n   := (leg->>'n')::INT;
    len := (leg->>'len')::DOUBLE PRECISION;
    az  := (leg->>'az')::DOUBLE PRECISION;
    FOR i IN 1..n LOOP
      cur := ST_Project(cur, len / n, radians(az));
      pts := pts || cur::geometry;
    END LOOP;
  END LOOP;
  RETURN ST_MakeLine(pts)::geography;
END $$;

CREATE FUNCTION tst_ride(p_leader TEXT, p_route GEOGRAPHY, p_token TEXT)
RETURNS UUID LANGUAGE sql AS $$
  INSERT INTO pack_rides (leader_id, destination, route_line, route_cumdist,
                          route_length_m, route_source, share_token,
                          share_expires_at, status, started_at)
  SELECT p_leader,
         ST_EndPoint(p_route::geometry)::geography,
         p_route,
         c,
         c[array_length(c, 1)],
         'test',
         p_token,
         now() + INTERVAL '6 hours',
         'active',
         now()
  FROM (SELECT fn_pack_build_cumdist(p_route) AS c) x
  RETURNING id
$$;

-- Chainage of vertex k, straight from the construction.
CREATE FUNCTION tst_vertex_m(p_ride UUID, k INT)
RETURNS DOUBLE PRECISION LANGUAGE sql AS $$
  SELECT route_cumdist[k] FROM pack_rides WHERE id = p_ride
$$;

CREATE FUNCTION tst_vertex(p_ride UUID, k INT)
RETURNS GEOGRAPHY LANGUAGE sql AS $$
  SELECT ST_PointN(route_line::geometry, k)::geography FROM pack_rides WHERE id = p_ride
$$;

-- Places a member at a known chainage as of `age` ago, so the next projection
-- runs against a controlled window.
CREATE FUNCTION tst_seed(p_ride UUID, p_user TEXT,
                         p_chainage DOUBLE PRECISION, p_age INTERVAL)
RETURNS VOID LANGUAGE sql AS $$
  UPDATE pack_ride_members
     SET chainage_m = p_chainage, chainage_at = now() - p_age, off_route = false
   WHERE ride_id = p_ride AND user_id = p_user
$$;

-- Whole-line search, i.e. the projection with the window removed. Used to
-- demonstrate what the window is actually buying.
CREATE FUNCTION tst_unwindowed(p_ride UUID, p_pos GEOGRAPHY)
RETURNS DOUBLE PRECISION LANGUAGE sql AS $$
  SELECT s.chainage_m
    FROM pack_rides r,
         LATERAL fn_pack_project_on_span(r.route_line, r.route_cumdist, p_pos,
                                         0, r.route_length_m) s
   WHERE r.id = p_ride
$$;

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------

INSERT INTO users (id, phone, name) VALUES
  ('user_leader', '+919000000001', 'Leader'),
  ('user_ravi',   '+919000000002', 'Ravi'),
  ('user_out',    '+919000000003', 'Outsider');

-- Origin near Angamaly, Kerala. The coordinates only pick a neighbourhood on
-- the spheroid; every distance below is constructed, not measured off a map.
CREATE TEMP TABLE tst_env AS
SELECT ST_SetSRID(ST_MakePoint(76.3860, 10.1960), 4326)::geography AS p0;

-- ===========================================================================
-- A. Cumulative distance array (TRD 4.2)
-- ===========================================================================

CREATE TEMP TABLE t_straight AS
SELECT tst_ride('user_leader',
         tst_walk((SELECT p0 FROM tst_env),
                  '[{"az": 90, "len": 10000, "n": 20}]'::jsonb),
         'tok_straight') AS ride_id;

SELECT is(
  (SELECT array_length(route_cumdist, 1) FROM pack_rides
    WHERE id = (SELECT ride_id FROM t_straight)),
  (SELECT ST_NPoints(route_line::geometry) FROM pack_rides
    WHERE id = (SELECT ride_id FROM t_straight)),
  'cumdist has exactly one entry per route vertex');

SELECT is(
  (SELECT route_cumdist[1] FROM pack_rides
    WHERE id = (SELECT ride_id FROM t_straight)),
  0::DOUBLE PRECISION,
  'cumdist starts at zero');

SELECT ok(
  abs((SELECT route_length_m FROM pack_rides
        WHERE id = (SELECT ride_id FROM t_straight)) - 10000) < 1,
  'a route built from 20 x 500 m geodesic steps measures 10 km within 1 m');

SELECT throws_ok(
  format($q$UPDATE pack_rides SET route_cumdist = ARRAY[0, 1, 2]::float8[]
              WHERE id = %L$q$, (SELECT ride_id FROM t_straight)),
  'route_cumdist length (3) must equal ST_NPoints(route_line) (21)',
  'a cumdist array that disagrees with the route is rejected, not stored');

-- ===========================================================================
-- B. Straight road -- baseline accuracy and the off-route test (TRD 4.2, 4.5)
-- ===========================================================================

INSERT INTO pack_ride_members (ride_id, user_id, role)
SELECT ride_id, 'user_ravi', 'rider' FROM t_straight;

-- Vertex 7 sits at 3000 m by construction (6 steps x 500 m).
SELECT ok(
  abs((SELECT chainage_m FROM fn_pack_project_member(
        (SELECT ride_id FROM t_straight), 'user_ravi',
        tst_vertex((SELECT ride_id FROM t_straight), 7))) - 3000) < 2,
  'first fix on a route vertex recovers that vertex chainage within 2 m');

-- 200 m further on, 10 s later.
SELECT tst_seed((SELECT ride_id FROM t_straight), 'user_ravi', 3000, INTERVAL '10 seconds');
SELECT ok(
  abs((SELECT chainage_m FROM fn_pack_project_member(
        (SELECT ride_id FROM t_straight), 'user_ravi',
        ST_Project(tst_vertex((SELECT ride_id FROM t_straight), 7), 200, radians(90))))
      - 3200) < 3,
  'a mid-segment fix interpolates chainage within 3 m');

-- 100 m off the carriageway: inside the 150 m default, still on route.
SELECT tst_seed((SELECT ride_id FROM t_straight), 'user_ravi', 3000, INTERVAL '10 seconds');
SELECT is(
  (SELECT off_route FROM fn_pack_project_member(
     (SELECT ride_id FROM t_straight), 'user_ravi',
     ST_Project(tst_vertex((SELECT ride_id FROM t_straight), 7), 100, radians(0)))),
  false,
  'a fix 100 m off the line is within the default threshold and stays on route');

-- 300 m off: genuinely off route.
SELECT tst_seed((SELECT ride_id FROM t_straight), 'user_ravi', 3000, INTERVAL '10 seconds');
SELECT is(
  (SELECT off_route FROM fn_pack_project_member(
     (SELECT ride_id FROM t_straight), 'user_ravi',
     ST_Project(tst_vertex((SELECT ride_id FROM t_straight), 7), 300, radians(0)))),
  true,
  'a fix 300 m off the line is flagged off route');

SELECT ok(
  abs((SELECT chainage_m FROM pack_ride_members
        WHERE ride_id = (SELECT ride_id FROM t_straight)
          AND user_id = 'user_ravi') - 3000) < 5,
  'an off-route fix does not move chainage');

-- ===========================================================================
-- C. Hairpin -- the case the window exists for (TRD 4.3)
--
-- Two anti-parallel legs 40 m apart. Western Ghats routes are dense with
-- these. A rider on the return leg is physically 40 m from a stretch of the
-- outbound leg that is over a kilometre away in chainage, so a nearest-point
-- search over the whole line is a coin flip that GPS error decides.
-- ===========================================================================

CREATE TEMP TABLE t_hairpin AS
SELECT tst_ride('user_leader',
         tst_walk((SELECT p0 FROM tst_env),
           '[{"az": 90,  "len": 2000, "n": 20},
             {"az": 0,   "len": 40,   "n": 2},
             {"az": 270, "len": 2000, "n": 20}]'::jsonb),
         'tok_hairpin') AS ride_id;

INSERT INTO pack_ride_members (ride_id, user_id, role)
SELECT ride_id, 'user_ravi', 'rider' FROM t_hairpin;

-- Vertices: 1 origin, 2..21 outbound (0..2000 m), 22..23 transition (2040 m),
-- 24..43 return leg. Vertex 28 is 500 m into the return leg.
CREATE TEMP TABLE t_hp AS
SELECT tst_vertex_m((SELECT ride_id FROM t_hairpin), 28) AS true_m,
       tst_vertex((SELECT ride_id FROM t_hairpin), 28)   AS true_pt;

SELECT ok((SELECT true_m FROM t_hp) BETWEEN 2500 AND 2600,
  'the return-leg test vertex sits ~500 m into the return leg');

-- An exact fix on the return leg is unambiguous even without a window.
SELECT ok(
  abs((SELECT chainage_m FROM fn_pack_project_member(
        (SELECT ride_id FROM t_hairpin), 'user_ravi',
        (SELECT true_pt FROM t_hp))) - (SELECT true_m FROM t_hp)) < 15,
  'hairpin: an exact fix on the return leg projects onto the return leg');

-- The realistic case: 25 m of GPS error toward the outbound leg, which is
-- 40 m away. The fix is now nearer the outbound leg than the return leg.
CREATE TEMP TABLE t_hp_bad AS
SELECT ST_Project((SELECT true_pt FROM t_hp), 25, radians(180)) AS pt;

SELECT ok(
  tst_unwindowed((SELECT ride_id FROM t_hairpin), (SELECT pt FROM t_hp_bad))
    < (SELECT true_m FROM t_hp) - 500,
  'hairpin: an unwindowed search snaps a jittered fix onto the WRONG leg -- the failure the window exists to prevent');

-- Same fix, but the member was 40 m back 5 s ago. No rider covers the
-- kilometre between the legs in 5 s.
SELECT tst_seed((SELECT ride_id FROM t_hairpin), 'user_ravi',
                (SELECT true_m FROM t_hp) - 40, INTERVAL '5 seconds');

SELECT is(
  (SELECT windowed FROM fn_pack_project_member(
     (SELECT ride_id FROM t_hairpin), 'user_ravi', (SELECT pt FROM t_hp_bad))),
  true,
  'hairpin: a 5 s old prior fix is fresh enough to window the search');

SELECT ok(
  abs((SELECT chainage_m FROM pack_ride_members
        WHERE ride_id = (SELECT ride_id FROM t_hairpin) AND user_id = 'user_ravi')
      - (SELECT true_m FROM t_hp)) < 60,
  'hairpin GATE: the windowed search holds the jittered fix on the correct leg');

-- Regression pin for the tunable change. The TRD specified a fixed +/-2 km
-- window. This hairpin's legs are ~1 km apart in chainage, so a 2 km window
-- contains both of them and admits exactly the ambiguity it was introduced to
-- remove. The window has to be kinematic, not constant.
SELECT ok(
  (SELECT s.chainage_m
     FROM pack_rides r,
          LATERAL fn_pack_project_on_span(r.route_line, r.route_cumdist,
            (SELECT pt FROM t_hp_bad),
            (SELECT true_m FROM t_hp) - 40 - 2000,
            (SELECT true_m FROM t_hp) - 40 + 2000) s
    WHERE r.id = (SELECT ride_id FROM t_hairpin))
   < (SELECT true_m FROM t_hp) - 500,
  'hairpin: a fixed +/-2 km window lands on the wrong leg too -- it is wide enough to contain both');

-- ===========================================================================
-- D. Grade-separated crossing -- the cloverleaf failure mode
--
-- A route that crosses over itself is zero metres from itself in 2-D and
-- 1.8 km apart in chainage. This is the case a fixed +/-2 km window cannot
-- resolve, because it contains both sides of the crossing.
--
-- Legs: 1000 m east, 300 m north, 600 m west, 600 m south. The last leg
-- crosses the first at 400 m east of origin: chainage 400 on the way out,
-- chainage 2200 on the way back.
-- ===========================================================================

CREATE TEMP TABLE t_cross AS
SELECT tst_ride('user_leader',
         tst_walk((SELECT p0 FROM tst_env),
           '[{"az": 90,  "len": 1000, "n": 10},
             {"az": 0,   "len": 300,  "n": 3},
             {"az": 270, "len": 600,  "n": 6},
             {"az": 180, "len": 600,  "n": 6}]'::jsonb),
         'tok_cross') AS ride_id;

INSERT INTO pack_ride_members (ride_id, user_id, role)
SELECT ride_id, 'user_ravi', 'rider' FROM t_cross;

-- Vertex 23 is the crossing point on the final leg: chainage 2200.
CREATE TEMP TABLE t_cr AS
SELECT tst_vertex_m((SELECT ride_id FROM t_cross), 23) AS true_m,
       tst_vertex((SELECT ride_id FROM t_cross), 23)   AS true_pt;

SELECT ok(abs((SELECT true_m FROM t_cr) - 2200) < 5,
  'the crossing vertex sits at 2200 m, 1.8 km along from where the route first passed here');

SELECT ok(
  (SELECT ST_Distance(true_pt,
     ST_LineSubstring(
       (SELECT route_line::geometry FROM pack_rides WHERE id = (SELECT ride_id FROM t_cross)),
       0, 0.2)::geography) FROM t_cr) < 5,
  'the two passes are within 5 m of each other on the ground -- grade separation is invisible in 2-D');

-- 10 m of error along the outbound leg's bearing puts the fix nearer the
-- outbound leg than the return leg.
SELECT ok(
  tst_unwindowed((SELECT ride_id FROM t_cross),
                 ST_Project((SELECT true_pt FROM t_cr), 10, radians(90))) < 1000,
  'crossing: an unwindowed search puts the rider 1.8 km back, on the leg they rode 40 minutes ago');

SELECT tst_seed((SELECT ride_id FROM t_cross), 'user_ravi',
                (SELECT true_m FROM t_cr) - 40, INTERVAL '5 seconds');

SELECT ok(
  abs((SELECT chainage_m FROM fn_pack_project_member(
        (SELECT ride_id FROM t_cross), 'user_ravi',
        ST_Project((SELECT true_pt FROM t_cr), 10, radians(90))))
      - (SELECT true_m FROM t_cr)) < 60,
  'crossing GATE: the windowed search keeps the rider on the leg they are actually on');

-- ===========================================================================
-- E. Out-and-back -- same ambiguity, but far apart in chainage
-- ===========================================================================

CREATE TEMP TABLE t_oab AS
SELECT tst_ride('user_leader',
         tst_walk((SELECT p0 FROM tst_env),
           '[{"az": 90,  "len": 5000, "n": 25},
             {"az": 0,   "len": 30,   "n": 2},
             {"az": 270, "len": 5000, "n": 25}]'::jsonb),
         'tok_oab') AS ride_id;

INSERT INTO pack_ride_members (ride_id, user_id, role)
SELECT ride_id, 'user_ravi', 'rider' FROM t_oab;

SELECT tst_seed((SELECT ride_id FROM t_oab), 'user_ravi',
                tst_vertex_m((SELECT ride_id FROM t_oab), 42) - 40,
                INTERVAL '5 seconds');

SELECT ok(
  abs((SELECT chainage_m FROM fn_pack_project_member(
        (SELECT ride_id FROM t_oab), 'user_ravi',
        tst_vertex((SELECT ride_id FROM t_oab), 42)))
      - tst_vertex_m((SELECT ride_id FROM t_oab), 42)) < 20,
  'out-and-back: the return leg does not project onto the outbound leg 30 m away');

-- ===========================================================================
-- F. Re-acquisition after a signal gap (TRD 4.2 step 1)
-- ===========================================================================

SELECT tst_seed((SELECT ride_id FROM t_straight), 'user_ravi', 200, INTERVAL '10 minutes');

SELECT is(
  (SELECT windowed FROM fn_pack_project_member(
     (SELECT ride_id FROM t_straight), 'user_ravi',
     tst_vertex((SELECT ride_id FROM t_straight), 15))),
  false,
  'a fix older than the stale threshold is treated as a first fix, not windowed');

SELECT ok(
  abs((SELECT chainage_m FROM pack_ride_members
        WHERE ride_id = (SELECT ride_id FROM t_straight) AND user_id = 'user_ravi')
      - 7000) < 5,
  're-acquisition after a signal gap recovers the true chainage 6.8 km from the stale one');

-- ===========================================================================
-- G. Time gap from breadcrumbs (TRD 4.4)
-- ===========================================================================

SELECT fn_pack_record_breadcrumb((SELECT ride_id FROM t_straight), 3000, now() - INTERVAL '7 minutes');
SELECT fn_pack_record_breadcrumb((SELECT ride_id FROM t_straight), 5000, now() - INTERVAL '4 minutes');
SELECT fn_pack_record_breadcrumb((SELECT ride_id FROM t_straight), 7000, now() - INTERVAL '1 minute');

SELECT ok(
  abs(EXTRACT(EPOCH FROM fn_pack_time_gap((SELECT ride_id FROM t_straight), 3050)) - 420) < 2,
  'time gap resolves to the nearest breadcrumb by chainage, not by time');

SELECT is(
  fn_pack_time_gap((SELECT ride_id FROM t_hairpin), 1000),
  NULL,
  'time gap is NULL before any breadcrumb exists, so callers can mark it estimated');

SELECT lives_ok(
  format($q$SELECT fn_pack_record_breadcrumb(%L, 3000, now())$q$,
         (SELECT ride_id FROM t_straight)),
  'a stopped leader re-reporting the same chainage does not error');

SELECT is(
  (SELECT count(*)::BIGINT FROM pack_ride_breadcrumbs
    WHERE ride_id = (SELECT ride_id FROM t_straight)),
  3::BIGINT,
  'breadcrumbs are deduplicated on chainage, so a stopped leader does not accumulate rows');

-- ===========================================================================
-- H. Gap suppression (TRD 4.5)
-- ===========================================================================

INSERT INTO pack_ride_members (ride_id, user_id, role)
SELECT ride_id, 'user_leader', 'leader' FROM t_straight;

SELECT tst_seed((SELECT ride_id FROM t_straight), 'user_leader', 9000, INTERVAL '0 seconds');
SELECT tst_seed((SELECT ride_id FROM t_straight), 'user_ravi',   7000, INTERVAL '0 seconds');

SELECT is(
  (SELECT display_state FROM fn_pack_member_gaps((SELECT ride_id FROM t_straight))
    WHERE user_id = 'user_ravi'),
  'ok',
  'a fresh on-route member with breadcrumbs shows a real gap');

SELECT ok(
  abs((SELECT gap_m FROM fn_pack_member_gaps((SELECT ride_id FROM t_straight))
        WHERE user_id = 'user_ravi') + 2000) < 1,
  'gap is signed against the furthest-along member: 2 km behind reads as -2000');

SELECT tst_seed((SELECT ride_id FROM t_straight), 'user_ravi', 7000, INTERVAL '5 minutes');

SELECT is(
  (SELECT display_state FROM fn_pack_member_gaps((SELECT ride_id FROM t_straight))
    WHERE user_id = 'user_ravi'),
  'stale',
  'a fix older than the stale threshold suppresses the gap into "last seen"');

UPDATE pack_ride_members
   SET off_route = true,
       off_route_dist_m = 400,
       last_position = ST_Project(tst_vertex((SELECT ride_id FROM t_straight), 15), 400, radians(0))
 WHERE ride_id = (SELECT ride_id FROM t_straight) AND user_id = 'user_ravi';

SELECT is(
  (SELECT display_state FROM fn_pack_member_gaps((SELECT ride_id FROM t_straight))
    WHERE user_id = 'user_ravi'),
  'off_route',
  'off route outranks stale: the pack needs the more actionable fact first');

SELECT is(
  (SELECT gap_m FROM fn_pack_member_gaps((SELECT ride_id FROM t_straight))
    WHERE user_id = 'user_ravi'),
  NULL,
  'no route-relative gap is published for a member who is off the route');

SELECT ok(
  abs((SELECT straight_m FROM fn_pack_member_gaps((SELECT ride_id FROM t_straight))
        WHERE user_id = 'user_ravi') - 400) < 5,
  'an off-route member is described by straight-line distance instead');

INSERT INTO pack_ride_members (ride_id, user_id, role)
SELECT ride_id, 'user_out', 'rider' FROM t_straight;

SELECT is(
  (SELECT display_state FROM fn_pack_member_gaps((SELECT ride_id FROM t_straight))
    WHERE user_id = 'user_out'),
  'locating',
  'a member with no fix yet shows "locating", never a fabricated gap');

SELECT is(
  (SELECT display_state FROM fn_pack_member_gaps((SELECT ride_id FROM t_hairpin))
    WHERE user_id = 'user_ravi'),
  'estimated',
  'a gap with no breadcrumb behind it is marked estimated rather than published as fact');

-- ===========================================================================
-- I. RLS (TRD 3.3)
--
-- The TRD writes the member-visibility policy as an EXISTS over
-- pack_ride_members inside a policy ON pack_ride_members. Evaluating that
-- policy requires reading the table, which requires evaluating the policy.
-- These tests keep the SECURITY DEFINER break in place.
-- ===========================================================================

GRANT SELECT, INSERT, UPDATE, DELETE
  ON pack_rides, pack_ride_members, pack_ride_breadcrumbs TO authenticated;
GRANT SELECT ON t_straight, t_hairpin TO authenticated;

SET LOCAL request.jwt.claim.sub = 'user_ravi';
SET LOCAL ROLE authenticated;

SELECT is(
  (SELECT count(*)::BIGINT FROM pack_rides WHERE id = (SELECT ride_id FROM t_straight)),
  1::BIGINT,
  'a member can read their own ride without the policy recursing');

SELECT is(
  (SELECT count(*)::BIGINT FROM pack_ride_members
    WHERE ride_id = (SELECT ride_id FROM t_straight) AND user_id = 'user_leader'),
  1::BIGINT,
  'members of the same ride can see each other');

RESET ROLE;
SET LOCAL request.jwt.claim.sub = 'user_out';
SET LOCAL ROLE authenticated;

SELECT is(
  (SELECT count(*)::BIGINT FROM pack_rides WHERE id = (SELECT ride_id FROM t_hairpin)),
  0::BIGINT,
  'a non-member cannot see a ride they were never in');

RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
