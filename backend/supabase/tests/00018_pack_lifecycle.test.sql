-- Pack Mode Step 2 gate: the ride lifecycle round-trips end to end, and every
-- path that could leave a share link alive after a rider expects it dead is
-- closed. The share token is a live location feed reachable by anyone holding
-- the URL, so its lifetime is a safety property, not a session detail.
--
-- Run: bash backend/supabase/tests/run.sh

BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(34);

-- ---------------------------------------------------------------------------
-- Helpers and fixtures
-- ---------------------------------------------------------------------------

CREATE FUNCTION tstl_route() RETURNS GEOGRAPHY LANGUAGE plpgsql AS $$
DECLARE
  pts GEOMETRY[];
  cur GEOGRAPHY := ST_SetSRID(ST_MakePoint(76.3860, 10.1960), 4326)::geography;
  i INT;
BEGIN
  pts := ARRAY[cur::geometry];
  FOR i IN 1..20 LOOP
    cur := ST_Project(cur, 500, radians(90));
    pts := pts || cur::geometry;
  END LOOP;
  RETURN ST_MakeLine(pts)::geography;
END $$;

CREATE FUNCTION tstl_as(p_uid TEXT) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
  PERFORM set_config('request.jwt.claim.sub', p_uid, true);
END $$;

INSERT INTO users (id, phone, name) VALUES
  ('u_lead',  '+919100000001', 'Leader'),
  ('u_ravi',  '+919100000002', 'Ravi'),
  ('u_anju',  '+919100000003', 'Anju'),
  ('u_stray', '+919100000004', 'Stranger');

-- ===========================================================================
-- A. Create (PM-01, PM-02, PM-03)
-- ===========================================================================

SELECT tstl_as('u_lead');

CREATE TEMP TABLE r AS
SELECT (x).* FROM (SELECT fn_pack_create_ride(
          ST_SetSRID(ST_MakePoint(76.5, 10.2), 4326)::geography,
          tstl_route(), 'test', 'Sunday run') AS x) s;

SELECT is((SELECT status FROM r), 'draft'::VARCHAR(10),
  'a new ride starts as a draft, not broadcasting');

SELECT is((SELECT leader_id FROM r), 'u_lead',
  'the creator is the leader');

SELECT ok((SELECT route_length_m FROM r) BETWEEN 9999 AND 10001,
  'the route is frozen at creation with its cumulative distances precomputed');

SELECT is(
  (SELECT count(*)::BIGINT FROM pack_ride_members
    WHERE ride_id = (SELECT id FROM r) AND user_id = 'u_lead' AND role = 'leader'),
  1::BIGINT,
  'the leader is enrolled as a member by creation, not by a second call');

SELECT ok((SELECT length(share_token) FROM r) >= 22,
  'the share token carries at least 128 bits of entropy');

SELECT is(
  (SELECT share_token ~ '^[A-Za-z0-9_-]+$' FROM r), true,
  'the share token is URL-safe, so it survives being pasted into any messenger');

SELECT isnt((SELECT share_token FROM r), (SELECT id::TEXT FROM r),
  'the share token is not derived from the ride id');

SELECT is(
  (SELECT count(DISTINCT fn_pack_share_token())::BIGINT FROM generate_series(1, 200)),
  200::BIGINT,
  'tokens do not collide or run in sequence');

SELECT throws_ok(
  $q$SELECT fn_pack_create_ride(
       ST_SetSRID(ST_MakePoint(76.5, 10.2), 4326)::geography,
       ST_SetSRID(ST_MakePoint(76.4, 10.2), 4326)::geography, 'test')$q$,
  'route must have at least two vertices',
  'a ride cannot be created without a real route to project onto');

-- ===========================================================================
-- B. Join (PM-04)
-- ===========================================================================

SELECT tstl_as('u_ravi');

SELECT is(
  (SELECT role FROM fn_pack_join_ride((SELECT share_token FROM r))),
  'sweep'::VARCHAR(10),
  'the first rider to join a draft ride becomes the sweep by default');

SELECT tstl_as('u_anju');
SELECT lives_ok(
  format($q$SELECT fn_pack_join_ride(%L)$q$, (SELECT share_token FROM r)),
  'a second rider joins with the same link');

SELECT is(
  (SELECT role FROM pack_ride_members
    WHERE ride_id = (SELECT id FROM r) AND user_id = 'u_anju'),
  'sweep'::VARCHAR(10),
  'the sweep role follows the last rider to join, without the leader maintaining it');

SELECT is(
  (SELECT role FROM pack_ride_members
    WHERE ride_id = (SELECT id FROM r) AND user_id = 'u_ravi'),
  'rider'::VARCHAR(10),
  'the previous sweep is demoted, so exactly one rider holds the role');

SELECT throws_ok(
  $q$SELECT fn_pack_join_ride('not-a-real-token')$q$,
  'invalid share link',
  'a guessed token is rejected without revealing whether any ride exists');

-- ===========================================================================
-- C. Start (PM-05)
-- ===========================================================================

SELECT tstl_as('u_ravi');
SELECT throws_ok(
  format($q$SELECT fn_pack_start_ride(%L)$q$, (SELECT id FROM r)),
  'only the ride leader can start the ride',
  'a rider cannot start the ride out from under the leader');

SELECT tstl_as('u_lead');
SELECT is(
  (SELECT status FROM fn_pack_start_ride((SELECT id FROM r))),
  'active'::VARCHAR(10),
  'the leader starts the ride');

SELECT throws_like(
  format($q$SELECT fn_pack_start_ride(%L)$q$, (SELECT id FROM r)),
  '%is already active',
  'starting twice is an error, not a silent no-op that resets started_at');

SELECT throws_like(
  format($q$UPDATE pack_rides SET status = 'draft' WHERE id = %L$q$,
         (SELECT id FROM r)),
  '%cannot return to draft once active',
  'an active ride cannot be walked back to draft');

-- ===========================================================================
-- D. Leave (PM-06, PM-72)
-- ===========================================================================

SELECT tstl_as('u_ravi');
SELECT lives_ok(
  format($q$SELECT fn_pack_leave_ride(%L)$q$, (SELECT id FROM r)),
  'a rider can leave at any time');

SELECT is(
  (SELECT count(*)::BIGINT FROM fn_pack_member_gaps((SELECT id FROM r))
    WHERE user_id = 'u_ravi'),
  0::BIGINT,
  'leaving removes the rider from the published view immediately, not at the next tick');

SELECT throws_like(
  format($q$SELECT fn_pack_leave_ride(%L)$q$, (SELECT id FROM r)),
  '%is not an active member%',
  'leaving twice is an error rather than a silent success');

SELECT lives_ok(
  format($q$SELECT fn_pack_join_ride(%L)$q$, (SELECT share_token FROM r)),
  'a rider who left by accident can rejoin on the same link while the ride is live');

SELECT tstl_as('u_lead');
SELECT throws_ok(
  format($q$SELECT fn_pack_leave_ride(%L)$q$, (SELECT id FROM r)),
  'the ride leader cannot leave; end the ride instead',
  'the leader cannot abandon a ride whose live share link only they can revoke');

-- ===========================================================================
-- E. Revoke without ending (PM-55)
-- ===========================================================================

CREATE TEMP TABLE r2 AS
SELECT (x).* FROM (SELECT fn_pack_create_ride(
          ST_SetSRID(ST_MakePoint(76.5, 10.2), 4326)::geography,
          tstl_route(), 'test', 'Revoke test') AS x) s;

SELECT lives_ok(
  format($q$SELECT fn_pack_revoke_share(%L)$q$, (SELECT id FROM r2)),
  'the leader can revoke the link while the ride continues');

SELECT tstl_as('u_stray');
SELECT throws_ok(
  format($q$SELECT fn_pack_join_ride(%L)$q$, (SELECT share_token FROM r2)),
  'this share link has been revoked',
  'a revoked link admits no one, even though the ride is still live');

-- ===========================================================================
-- F. End (PM-07, PM-70, PM-71)
-- ===========================================================================

SELECT tstl_as('u_stray');
SELECT throws_ok(
  format($q$SELECT fn_pack_end_ride(%L)$q$, (SELECT id FROM r)),
  'only the ride leader can end the ride',
  'a non-member cannot end someone else''s ride');

SELECT tstl_as('u_lead');
SELECT ok(
  (SELECT share_revoked_at IS NOT NULL FROM fn_pack_end_ride((SELECT id FROM r))),
  'ending the ride revokes the share link in the same action -- a link never outlives its ride');

SELECT is(
  (SELECT count(*)::BIGINT FROM pack_ride_members
    WHERE ride_id = (SELECT id FROM r) AND left_at IS NULL),
  0::BIGINT,
  'ending the ride clears every member, so nobody keeps broadcasting into it');

SELECT tstl_as('u_stray');
SELECT throws_ok(
  format($q$SELECT fn_pack_join_ride(%L)$q$, (SELECT share_token FROM r)),
  'this ride has ended',
  'an ended ride cannot be rejoined');

-- ===========================================================================
-- G. Hard TTL sweep (TRD 8.4, PM-71)
-- ===========================================================================

SELECT tstl_as('u_lead');

CREATE TEMP TABLE r3 AS
SELECT (x).* FROM (SELECT fn_pack_create_ride(
          ST_SetSRID(ST_MakePoint(76.5, 10.2), 4326)::geography,
          tstl_route(), 'test', 'Forgotten ride') AS x) s;

SELECT fn_pack_start_ride((SELECT id FROM r3));

-- A ride the leader never ended. This is the common case, not the edge case.
UPDATE pack_rides
   SET expires_at = now() - INTERVAL '1 minute'
 WHERE id = (SELECT id FROM r3);

SELECT is(fn_pack_sweep_expired(), 1,
  'the sweep ends exactly the rides whose hard TTL has passed');

SELECT is(
  (SELECT status FROM pack_rides WHERE id = (SELECT id FROM r3)),
  'ended'::VARCHAR(10),
  'a forgotten ride stops broadcasting without any client being awake');

SELECT ok(
  (SELECT share_revoked_at IS NOT NULL FROM pack_rides WHERE id = (SELECT id FROM r3)),
  'the expired ride''s share link is revoked by the same sweep');

SELECT is(fn_pack_sweep_expired(), 0,
  'the sweep is idempotent and does not re-end rides it already ended');

-- A share link whose own TTL runs out on a ride that is still going.
CREATE TEMP TABLE r4 AS
SELECT (x).* FROM (SELECT fn_pack_create_ride(
          ST_SetSRID(ST_MakePoint(76.5, 10.2), 4326)::geography,
          tstl_route(), 'test', 'Long ride') AS x) s;

UPDATE pack_rides
   SET share_expires_at = now() - INTERVAL '1 minute'
 WHERE id = (SELECT id FROM r4);

SELECT fn_pack_sweep_expired();

SELECT ok(
  (SELECT status <> 'ended' AND share_revoked_at IS NOT NULL
     FROM pack_rides WHERE id = (SELECT id FROM r4)),
  'a link TTL expiring cuts off viewers without ending the ride the pack is on');

SELECT * FROM finish();
ROLLBACK;
