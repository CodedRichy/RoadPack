-- Pack Mode steps 3 and 5 gate: the tick's automatic status writers, the
-- aggregated payloads, the anonymous snapshot's privacy posture, and the
-- crash-detection seam.
--
-- The load-bearing test in this file is the cascade isolation test in section
-- E. If it fails, Pack Mode is capable of degrading emergency dispatch and
-- must not ship, no matter what else passes.
--
-- Run: bash backend/supabase/tests/run.sh

BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(67);

-- ---------------------------------------------------------------------------
-- Helpers and fixtures
-- ---------------------------------------------------------------------------

-- A 10 km due-east route from Muvattupuzha, built by walking geodesic steps,
-- so the true chainage of vertex k is known independently of the code.
CREATE FUNCTION tstt_route() RETURNS GEOGRAPHY LANGUAGE plpgsql AS $$
DECLARE
  pts GEOMETRY[];
  cur GEOGRAPHY := ST_SetSRID(ST_MakePoint(76.5760, 9.9800), 4326)::geography;
  i INT;
BEGIN
  pts := ARRAY[cur::geometry];
  FOR i IN 1..20 LOOP
    cur := ST_Project(cur, 500, radians(90));
    pts := pts || cur::geometry;
  END LOOP;
  RETURN ST_MakeLine(pts)::geography;
END $$;

-- The point on the route at a given chainage, for placing riders precisely.
CREATE FUNCTION tstt_at(p_ride UUID, p_m DOUBLE PRECISION)
RETURNS GEOGRAPHY LANGUAGE sql AS $$
  SELECT ST_LineInterpolatePoint(route_line::geometry,
           LEAST(1.0, GREATEST(0.0, p_m / route_length_m)))::geography
    FROM pack_rides WHERE id = p_ride
$$;

-- Place a member without going through fn_pack_project_member, so each test
-- states the exact state it is asserting on rather than depending on the
-- projector's behaviour.
CREATE FUNCTION tstt_place(
  p_ride UUID, p_uid TEXT, p_m DOUBLE PRECISION, p_at TIMESTAMPTZ)
RETURNS VOID LANGUAGE sql AS $$
  UPDATE pack_ride_members
     SET chainage_m = p_m, chainage_at = p_at, last_position = tstt_at(p_ride, p_m)
   WHERE ride_id = p_ride AND user_id = p_uid
$$;

CREATE FUNCTION tstt_status(p_ride UUID, p_uid TEXT) RETURNS TEXT LANGUAGE sql AS $$
  SELECT status_code::TEXT FROM pack_ride_members
   WHERE ride_id = p_ride AND user_id = p_uid
$$;

CREATE FUNCTION tstt_member(p_snap JSONB, p_name TEXT) RETURNS JSONB LANGUAGE sql AS $$
  SELECT m FROM jsonb_array_elements(p_snap -> 'members') m
   WHERE m ->> 'display_name' = p_name
$$;

INSERT INTO users (id, phone, name) VALUES
  ('u_t_lead', '+919200000001', 'Leader'),
  ('u_t_ravi', '+919200000002', 'Ravi'),
  ('u_t_anju', '+919200000003', 'Anju'),
  ('u_t_solo', '+919200000004', 'Solo');

CREATE FUNCTION tstt_as(p_uid TEXT) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN PERFORM set_config('request.jwt.claim.sub', p_uid, true); END $$;

SELECT tstt_as('u_t_lead');

CREATE TEMP TABLE r AS
SELECT (x).* FROM (SELECT fn_pack_create_ride(
          ST_SetSRID(ST_MakePoint(76.70, 9.98), 4326)::geography,
          tstt_route(), 'test', 'Tick ride') AS x) s;

SELECT tstt_as('u_t_ravi');
DO $do$ BEGIN PERFORM fn_pack_join_ride((SELECT share_token FROM r)); END $do$;
SELECT tstt_as('u_t_anju');
DO $do$ BEGIN PERFORM fn_pack_join_ride((SELECT share_token FROM r)); END $do$;
SELECT tstt_as('u_t_lead');
DO $do$ BEGIN PERFORM fn_pack_start_ride((SELECT id FROM r)); END $do$;

-- ===========================================================================
-- A. Stationarity tracking
-- ===========================================================================

SELECT tstt_place((SELECT id FROM r), 'u_t_lead', 6000, now() - INTERVAL '30 minutes');
SELECT tstt_place((SELECT id FROM r), 'u_t_ravi', 4000, now() - INTERVAL '30 minutes');

SELECT is(
  (SELECT stationary_since FROM pack_ride_members
    WHERE ride_id = (SELECT id FROM r) AND user_id = 'u_t_ravi'),
  now() - INTERVAL '30 minutes',
  'the stationary clock starts at the fix that placed the member');

-- A jitter-sized wobble is not movement.
SELECT tstt_place((SELECT id FROM r), 'u_t_ravi', 4030, now() - INTERVAL '20 minutes');

SELECT is(
  (SELECT stationary_since FROM pack_ride_members
    WHERE ride_id = (SELECT id FROM r) AND user_id = 'u_t_ravi'),
  now() - INTERVAL '30 minutes',
  'GPS jitter at a standstill does not reset the stationary clock');

-- Real movement does.
SELECT tstt_place((SELECT id FROM r), 'u_t_ravi', 4500, now() - INTERVAL '19 minutes');

SELECT is(
  (SELECT stationary_since FROM pack_ride_members
    WHERE ride_id = (SELECT id FROM r) AND user_id = 'u_t_ravi'),
  now() - INTERVAL '19 minutes',
  'movement past the epsilon restarts the stationary clock');

-- ===========================================================================
-- B. unexplained_stop (PM-41)
-- ===========================================================================

-- Ravi has not moved for 20 minutes but is still reporting.
SELECT tstt_place((SELECT id FROM r), 'u_t_ravi', 4500, now() - INTERVAL '20 minutes');
SELECT tstt_place((SELECT id FROM r), 'u_t_ravi', 4510, now() - INTERVAL '10 seconds');
SELECT tstt_place((SELECT id FROM r), 'u_t_lead', 6800, now() - INTERVAL '10 seconds');
SELECT tstt_place((SELECT id FROM r), 'u_t_anju', 5000, now() - INTERVAL '10 seconds');

SELECT is(fn_pack_auto_status((SELECT id FROM r)), 1,
  'the tick flags exactly the member who stopped without explaining it');

SELECT is(tstt_status((SELECT id FROM r), 'u_t_ravi'), 'unexplained_stop',
  'a rider stationary past the ride threshold while still reporting is flagged');

SELECT ok(
  (SELECT status_auto FROM pack_ride_members
    WHERE ride_id = (SELECT id FROM r) AND user_id = 'u_t_ravi'),
  'the flag is marked automatic, so the UI can distinguish it from a choice');

SELECT is(tstt_status((SELECT id FROM r), 'u_t_anju'), 'riding',
  'a moving member is not flagged');

SELECT is(fn_pack_auto_status((SELECT id FROM r)), 0,
  'the evaluation is idempotent -- a standing flag is not rewritten every tick');

-- Moving again clears it.
SELECT tstt_place((SELECT id FROM r), 'u_t_ravi', 5200, now());
DO $do$ BEGIN PERFORM fn_pack_auto_status((SELECT id FROM r)); END $do$;
SELECT is(tstt_status((SELECT id FROM r), 'u_t_ravi'), 'riding',
  'the flag clears itself when the rider moves again');

SELECT ok(
  NOT (SELECT status_auto FROM pack_ride_members
        WHERE ride_id = (SELECT id FROM r) AND user_id = 'u_t_ravi'),
  'clearing an automatic flag also clears the automatic marker');

-- A manual status explains the stop, which is the entire meaning of the word.
UPDATE pack_ride_members
   SET status_code = 'refueling', status_auto = false, status_at = now()
 WHERE ride_id = (SELECT id FROM r) AND user_id = 'u_t_anju';
SELECT tstt_place((SELECT id FROM r), 'u_t_anju', 5000, now() - INTERVAL '40 minutes');
SELECT tstt_place((SELECT id FROM r), 'u_t_anju', 5010, now());
DO $do$ BEGIN PERFORM fn_pack_auto_status((SELECT id FROM r)); END $do$;

SELECT is(tstt_status((SELECT id FROM r), 'u_t_anju'), 'refueling',
  'a member who explained their stop is never overwritten with unexplained_stop');

-- Off-route riders are not "stopped", they are lost; a different problem with
-- a different response.
UPDATE pack_ride_members
   SET status_code = 'riding', status_auto = false, off_route = true,
       off_route_dist_m = 400
 WHERE ride_id = (SELECT id FROM r) AND user_id = 'u_t_anju';
DO $do$ BEGIN PERFORM fn_pack_auto_status((SELECT id FROM r)); END $do$;

SELECT is(tstt_status((SELECT id FROM r), 'u_t_anju'), 'riding',
  'an off-route member is not flagged as an unexplained stop');

UPDATE pack_ride_members SET off_route = false, off_route_dist_m = NULL
 WHERE ride_id = (SELECT id FROM r) AND user_id = 'u_t_anju';

-- ===========================================================================
-- C. unreachable (PM-44) -- and its distinctness from a stop
-- ===========================================================================

-- Anju stops reporting entirely. She was moving when last heard from.
SELECT tstt_place((SELECT id FROM r), 'u_t_anju', 5000, now() - INTERVAL '31 minutes');
SELECT tstt_place((SELECT id FROM r), 'u_t_anju', 5600, now() - INTERVAL '30 minutes');
DO $do$ BEGIN PERFORM fn_pack_auto_status((SELECT id FROM r)); END $do$;

SELECT is(tstt_status((SELECT id FROM r), 'u_t_anju'), 'unreachable',
  'a member whose position stopped arriving is unreachable, not stopped');

-- Precedence: unreachable outranks unexplained_stop. A member who stopped and
-- THEN went silent is reported as silent, because that is the more alarming
-- and less certain of the two facts.
SELECT tstt_place((SELECT id FROM r), 'u_t_ravi', 5200, now() - INTERVAL '60 minutes');
DO $do$ BEGIN PERFORM fn_pack_auto_status((SELECT id FROM r)); END $do$;

SELECT is(tstt_status((SELECT id FROM r), 'u_t_ravi'), 'unreachable',
  'unreachable outranks unexplained_stop when both conditions hold');

SELECT ok(
  (SELECT unreachable_threshold_s > stale_threshold_s FROM r),
  'unreachable costs more evidence than merely going stale on the map');

-- Coming back on the air clears it.
SELECT tstt_place((SELECT id FROM r), 'u_t_anju', 6100, now());
SELECT tstt_place((SELECT id FROM r), 'u_t_ravi', 5300, now());
DO $do$ BEGIN PERFORM fn_pack_auto_status((SELECT id FROM r)); END $do$;
SELECT is(tstt_status((SELECT id FROM r), 'u_t_anju'), 'riding',
  'a member who comes back on the air is no longer unreachable');

-- ===========================================================================
-- D. The incident seam (PM-40)
-- ===========================================================================

CREATE TEMP TABLE inc AS
WITH ins AS (
  INSERT INTO incidents (user_id, type, status, location)
  VALUES ('u_t_ravi', 'crash_detected', 'dispatched',
          ST_SetSRID(ST_MakePoint(76.62, 9.98), 4326)::geography)
  RETURNING id)
SELECT id FROM ins;

SELECT is(tstt_status((SELECT id FROM r), 'u_t_ravi'), 'possible_incident',
  'an incident on a pack member flags the pack on receipt, not on dispatch');

SELECT is(
  (SELECT incident_id FROM pack_ride_members
    WHERE ride_id = (SELECT id FROM r) AND user_id = 'u_t_ravi'),
  (SELECT id FROM inc),
  'the member row carries the incident id, so the pack can open it');

-- Nothing the tick evaluates may clear a crash flag.
SELECT tstt_place((SELECT id FROM r), 'u_t_ravi', 5400, now());
DO $do$ BEGIN PERFORM fn_pack_auto_status((SELECT id FROM r)); END $do$;
SELECT is(tstt_status((SELECT id FROM r), 'u_t_ravi'), 'possible_incident',
  'the automatic evaluator never overwrites possible_incident, even on motion');

-- The rider presses "I'M OKAY" during the countdown.
UPDATE incidents SET status = 'cancelled', cancelled_reason = 'user_cancelled'
 WHERE id = (SELECT id FROM inc);

SELECT is(tstt_status((SELECT id FROM r), 'u_t_ravi'), 'riding',
  'cancelling the countdown clears the pack flag');

SELECT is(
  (SELECT incident_id FROM pack_ride_members
    WHERE ride_id = (SELECT id FROM r) AND user_id = 'u_t_ravi'),
  NULL::UUID,
  'a cancelled incident is unlinked from the member row');

-- A rider who is in no pack ride still files incidents normally.
INSERT INTO incidents (user_id, type, status) VALUES ('u_t_solo', 'sos', 'dispatched');
SELECT is(
  (SELECT count(*)::BIGINT FROM incidents WHERE user_id = 'u_t_solo'),
  1::BIGINT,
  'an incident from a rider in no pack ride is unaffected by the pack seam');

-- ===========================================================================
-- E. CASCADE ISOLATION -- the critical test (PM-42, TRD 11)
-- ===========================================================================
--
-- Induce a hard failure inside the pack write and prove the emergency path is
-- completely untouched: the incident row commits, its status is intact, and
-- the cascade job that alert-cascade keys on can still be created.

CREATE OR REPLACE FUNCTION fn_pack_flag_incident(p_user_id TEXT, p_incident_id UUID)
RETURNS INTEGER AS $$
BEGIN
  RAISE EXCEPTION 'induced pack mode failure';
END;
$$ LANGUAGE plpgsql;

CREATE TEMP TABLE inc2 AS
WITH ins AS (
  INSERT INTO incidents (user_id, type, status, severity, confidence, location)
  VALUES ('u_t_ravi', 'crash_detected', 'dispatched', 'high', 0.92,
          ST_SetSRID(ST_MakePoint(76.63, 9.98), 4326)::geography)
  RETURNING id)
SELECT id FROM ins;

SELECT is(
  (SELECT count(*)::BIGINT FROM incidents WHERE id = (SELECT id FROM inc2)),
  1::BIGINT,
  'CASCADE ISOLATION: a failing pack write does not abort the incident insert');

SELECT is(
  (SELECT status FROM incidents WHERE id = (SELECT id FROM inc2)),
  'dispatched'::VARCHAR(20),
  'CASCADE ISOLATION: the incident reaches the cascade with its status intact');

SELECT is(
  (SELECT severity FROM incidents WHERE id = (SELECT id FROM inc2)),
  'high'::VARCHAR(10),
  'CASCADE ISOLATION: no incident field is altered by the pack failure');

SELECT lives_ok(
  format('INSERT INTO cascade_jobs (incident_id) VALUES (%L)', (SELECT id FROM inc2)),
  'CASCADE ISOLATION: the cascade job still starts after a pack write failure');

SELECT is(tstt_status((SELECT id FROM r), 'u_t_ravi'), 'riding',
  'CASCADE ISOLATION: the cost of the failure is a degraded pack view, nothing more');

-- And the same on the cancel path.
CREATE OR REPLACE FUNCTION fn_pack_clear_incident(p_incident_id UUID)
RETURNS INTEGER AS $$
BEGIN
  RAISE EXCEPTION 'induced pack mode failure';
END;
$$ LANGUAGE plpgsql;

SELECT lives_ok(
  format('UPDATE incidents SET status = ''resolved'', resolved_at = now() WHERE id = %L',
         (SELECT id FROM inc2)),
  'CASCADE ISOLATION: a failing pack write does not block incident resolution');

SELECT is(
  (SELECT status FROM incidents WHERE id = (SELECT id FROM inc2)),
  'resolved'::VARCHAR(20),
  'CASCADE ISOLATION: the resolution commits regardless of the pack');

-- ===========================================================================
-- F. Snapshot privacy and coarsening (PM-53, TRD 7.2)
-- ===========================================================================

SELECT tstt_place((SELECT id FROM r), 'u_t_lead', 6000, now());
SELECT tstt_place((SELECT id FROM r), 'u_t_ravi', 4000, now());
SELECT tstt_place((SELECT id FROM r), 'u_t_anju', 5000, now());
UPDATE pack_ride_members SET status_code = 'riding', status_auto = false
 WHERE ride_id = (SELECT id FROM r);

CREATE TEMP TABLE snap AS SELECT fn_pack_snapshot((SELECT id FROM r)) AS j;

SELECT is(
  (SELECT count(*)::BIGINT FROM jsonb_array_elements(
     (SELECT j FROM snap) -> 'members') m WHERE m ? 'user_id'),
  0::BIGINT,
  'PM-53: no user id appears anywhere in the anonymous snapshot');

SELECT ok(
  (SELECT (j)::TEXT NOT LIKE '%9200000%' FROM snap),
  'PM-53: no phone number appears anywhere in the anonymous snapshot');

SELECT ok(
  (SELECT (j)::TEXT NOT LIKE '%u_t_%' FROM snap),
  'PM-53: the snapshot carries no internal identifiers at all');

SELECT is(
  (tstt_member((SELECT j FROM snap), 'Ravi') ->> 'precision_m')::DOUBLE PRECISION,
  50::DOUBLE PRECISION,
  'the snapshot states the precision it actually offers');

-- The coarsened point must genuinely differ from the exact one, and by no
-- more than the grid it claims. Coarsening at generation time is the whole
-- control: a viewer must never receive precise data it is trusted to hide.
SELECT ok(
  (SELECT ST_Distance(
     ST_SetSRID(ST_MakePoint(
       ((tstt_member(j, 'Ravi') -> 'position' ->> 1))::DOUBLE PRECISION,
       ((tstt_member(j, 'Ravi') -> 'position' ->> 0))::DOUBLE PRECISION), 4326)::geography,
     (SELECT last_position FROM pack_ride_members
       WHERE ride_id = (SELECT id FROM r) AND user_id = 'u_t_ravi')) <= 60
   FROM snap),
  'the coarsened position stays within the precision it advertises');

SELECT ok(
  (SELECT ST_Distance(
     ST_SetSRID(ST_MakePoint(
       ((tstt_member(j, 'Ravi') -> 'position' ->> 1))::DOUBLE PRECISION,
       ((tstt_member(j, 'Ravi') -> 'position' ->> 0))::DOUBLE PRECISION), 4326)::geography,
     (SELECT last_position FROM pack_ride_members
       WHERE ride_id = (SELECT id FROM r) AND user_id = 'u_t_ravi')) > 0
   FROM snap),
  'the coarsened position is not the exact position rounded to a prettier number');

-- Riders get the truth over Realtime; the CDN gets the coarsened copy.
SELECT ok(
  (SELECT jsonb_array_elements(
     fn_pack_tick_state((SELECT id FROM r)) -> 'members') ? 'user_id' LIMIT 1),
  'the authenticated tick payload does carry user ids, so the app can key on them');

SELECT is(
  (SELECT count(*)::BIGINT FROM jsonb_array_elements(
     fn_pack_tick_state((SELECT id FROM r)) -> 'members') m
    WHERE (m -> 'position' ->> 0)::DOUBLE PRECISION
          = ST_Y((SELECT last_position::geometry FROM pack_ride_members
                   WHERE ride_id = (SELECT id FROM r) AND user_id = 'u_t_ravi'))),
  1::BIGINT,
  'the authenticated tick payload carries exact positions, not coarsened ones');

-- ===========================================================================
-- G. Snapshot eligibility enforced at generation time (TRD 8.1)
-- ===========================================================================

SELECT ok((SELECT j IS NOT NULL FROM snap), 'an active, unrevoked ride publishes');

UPDATE pack_rides SET share_revoked_at = now() WHERE id = (SELECT id FROM r);
SELECT is(fn_pack_snapshot((SELECT id FROM r)), NULL::JSONB,
  'a revoked share link stops publishing at generation time, not just at creation');

UPDATE pack_rides SET share_revoked_at = NULL,
                      share_expires_at = now() - INTERVAL '1 minute'
 WHERE id = (SELECT id FROM r);
SELECT is(fn_pack_snapshot((SELECT id FROM r)), NULL::JSONB,
  'an expired share link stops publishing even while the ride is still running');

UPDATE pack_rides SET share_expires_at = now() + INTERVAL '6 hours'
 WHERE id = (SELECT id FROM r);

-- ===========================================================================
-- H. Honesty in the payload (TRD 4.5, section 9)
-- ===========================================================================

UPDATE pack_ride_members SET off_route = true, off_route_dist_m = 380
 WHERE ride_id = (SELECT id FROM r) AND user_id = 'u_t_anju';

SELECT is(
  tstt_member(fn_pack_snapshot((SELECT id FROM r)), 'Anju') -> 'gap_from_leader_m',
  'null'::jsonb,
  'an off-route member never carries a numeric gap');

SELECT ok(
  (tstt_member(fn_pack_snapshot((SELECT id FROM r)), 'Anju') ->> 'off_route_m')
    IS NOT NULL,
  'an off-route member carries straight-line distance instead, as the UI needs');

UPDATE pack_ride_members SET off_route = false, off_route_dist_m = NULL
 WHERE ride_id = (SELECT id FROM r) AND user_id = 'u_t_anju';
SELECT tstt_place((SELECT id FROM r), 'u_t_anju', 5000, now() - INTERVAL '5 minutes');

SELECT is(
  tstt_member(fn_pack_snapshot((SELECT id FROM r)), 'Anju') -> 'gap_from_leader_m',
  'null'::jsonb,
  'a stale member never carries a numeric gap either -- never show a stale gap as live');

SELECT is(
  tstt_member(fn_pack_snapshot((SELECT id FROM r)), 'Anju') ->> 'stale',
  'true',
  'staleness is stated explicitly rather than inferred from a missing number');

-- A member who left disappears from the next snapshot (PM-72).
SELECT tstt_as('u_t_anju');
DO $do$ BEGIN PERFORM fn_pack_leave_ride((SELECT id FROM r)); END $do$;
SELECT tstt_as('u_t_lead');

SELECT is(
  tstt_member(fn_pack_snapshot((SELECT id FROM r)), 'Anju'),
  NULL::JSONB,
  'PM-72: leaving the ride removes the member from the very next snapshot');

-- ===========================================================================
-- H2. Stable anonymous member identity
-- ===========================================================================

SELECT ok(
  (tstt_member(fn_pack_snapshot((SELECT id FROM r)), 'Ravi') ->> 'member_key')
    ~ '^[A-Za-z0-9_-]{8,}$',
  'every published member carries an opaque key the client can pin a marker to');

SELECT isnt(
  tstt_member(fn_pack_snapshot((SELECT id FROM r)), 'Ravi') ->> 'member_key',
  'u_t_ravi',
  'the member key is not the user id, and nothing in it points back to a person');

SELECT is(
  tstt_member(fn_pack_snapshot((SELECT id FROM r)), 'Ravi') ->> 'member_key',
  tstt_member(fn_pack_snapshot((SELECT id FROM r)), 'Ravi') ->> 'member_key',
  'the member key is stable across snapshots, so markers do not swap identity');

SELECT is(
  (SELECT count(DISTINCT member_key)::BIGINT FROM pack_ride_members
    WHERE ride_id = (SELECT id FROM r)),
  (SELECT count(*)::BIGINT FROM pack_ride_members WHERE ride_id = (SELECT id FROM r)),
  'member keys are unique within a ride even when two riders share a name');

-- ===========================================================================
-- H3. Viewer count (PM-55 / PM-73)
-- ===========================================================================

SELECT ok(
  NOT (fn_pack_snapshot((SELECT id FROM r)) ? 'viewer_count'),
  'a ride nobody has beaconed publishes no viewer count rather than a fake zero');

SELECT is(
  fn_pack_viewer_beacon((SELECT share_token FROM r), 'sess-aaaaaaaa'), 1,
  'a viewer beacon is accepted against a live share token and returns the count');

SELECT is(
  fn_pack_viewer_beacon((SELECT share_token FROM r), 'sess-bbbbbbbb'), 2,
  'a second viewer session is counted separately');

SELECT is(
  fn_pack_viewer_beacon((SELECT share_token FROM r), 'sess-aaaaaaaa'), 2,
  'a viewer polling for hours occupies one row, not one per beacon');

SELECT is(
  (fn_pack_snapshot((SELECT id FROM r)) ->> 'viewer_count')::INTEGER, 2,
  'PM-73: the count riders and viewers see is the real one');

UPDATE pack_ride_viewers SET last_seen_at = now() - INTERVAL '3 minutes'
 WHERE ride_id = (SELECT id FROM r) AND session_id = 'sess-bbbbbbbb';

SELECT is(fn_pack_viewer_count((SELECT id FROM r)), 1,
  'a closed tab stops counting within the beacon window');

SELECT throws_ok(
  format('SELECT fn_pack_viewer_beacon(%L, %L)', 'not-a-real-token', 'sess-cccccccc'),
  'invalid share link',
  'a beacon against an unknown token is refused, so the count cannot be inflated');

SELECT throws_ok(
  format('SELECT fn_pack_viewer_beacon(%L, %L)', (SELECT share_token FROM r), 'bad id!'),
  'invalid session id',
  'a malformed session id is refused rather than stored');

-- The beacon surface is never wider than the snapshot surface it describes.
UPDATE pack_rides SET share_revoked_at = now() WHERE id = (SELECT id FROM r);
SELECT throws_ok(
  format('SELECT fn_pack_viewer_beacon(%L, %L)', (SELECT share_token FROM r), 'sess-dddddddd'),
  'invalid share link',
  'a revoked ride accepts no beacon, exactly as it publishes no snapshot');
UPDATE pack_rides SET share_revoked_at = NULL WHERE id = (SELECT id FROM r);

-- ===========================================================================
-- H4. Ride-level fields the viewer needs
-- ===========================================================================

SELECT is(
  fn_pack_snapshot((SELECT id FROM r)) ->> 'name', 'Tick ride',
  'the snapshot names the ride, so a shared link is not an anonymous map');

SELECT is(
  (fn_pack_snapshot((SELECT id FROM r)) ->> 'stale_threshold_s')::INTEGER, 90,
  'the viewer greys members on the same threshold the pack does, not its own');

-- ===========================================================================
-- I. Polyline encoding
-- ===========================================================================

-- The reference vector from Google's encoded-polyline specification.
SELECT is(
  fn_pack_encode_polyline(ST_MakeLine(ARRAY[
    ST_SetSRID(ST_MakePoint(-120.2,   38.5),   4326),
    ST_SetSRID(ST_MakePoint(-120.95,  40.7),   4326),
    ST_SetSRID(ST_MakePoint(-126.453, 43.252), 4326)])::geography),
  '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
  'the polyline encoder matches the reference vector from the specification');

SELECT ok(
  (SELECT route_polyline IS NOT NULL FROM pack_rides WHERE id = (SELECT id FROM r)),
  'the encoded route is cached on first publish rather than re-encoded 4,320 times');

-- ===========================================================================
-- J. Orphaned snapshot sweep (TRD 8.4)
-- ===========================================================================

SELECT is(
  fn_pack_orphan_tokens(ARRAY[(SELECT share_token FROM r)]),
  '{}'::TEXT[],
  'a live ride''s snapshot is not swept');

SELECT is(
  fn_pack_orphan_tokens(ARRAY['no-such-token']),
  ARRAY['no-such-token'],
  'a snapshot with no ride behind it is swept');

UPDATE pack_rides SET share_revoked_at = now() WHERE id = (SELECT id FROM r);
SELECT is(
  fn_pack_orphan_tokens(ARRAY[(SELECT share_token FROM r)]),
  ARRAY[(SELECT share_token FROM r)],
  'a revoked ride''s snapshot object is swept, not merely left orphaned');

-- ===========================================================================
-- K. Scheduling
-- ===========================================================================

SELECT is(
  (SELECT count(*)::BIGINT FROM cron.job WHERE jobname = 'pack-tick'),
  1::BIGINT,
  'the tick is scheduled server-side and does not depend on a client being awake');

SELECT is(
  (SELECT count(*)::BIGINT FROM cron.job WHERE jobname = 'pack-snapshot-sweep'),
  1::BIGINT,
  'the orphaned-snapshot sweep is scheduled');

SELECT * FROM finish();
ROLLBACK;
