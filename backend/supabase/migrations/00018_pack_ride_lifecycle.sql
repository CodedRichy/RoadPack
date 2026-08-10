-- RoadPack: pack ride lifecycle (Pack Mode step 2)
-- TRD: docs/trd/roadpack-pack-mode-trd.md sections 8.1, 8.2, 8.4
-- PRD: PM-01..PM-09, PM-70..PM-74
--
-- Create, join, start, end, leave, plus share-token issuance and the expiry
-- sweep. No tick, no status writes, no viewer -- those are steps 3-6.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---------------------------------------------------------------------------
-- 0. A leader can see their own ride before anyone joins it
-- ---------------------------------------------------------------------------

-- 00017 scoped visibility to members only, which leaves the leader unable to
-- read back the ride they just created (INSERT ... RETURNING is a read). The
-- leader is the one person whose right to see the ride is not in question.
DROP POLICY pack_rides_select ON pack_rides;
CREATE POLICY pack_rides_select ON pack_rides FOR SELECT
  USING (
    leader_id = (SELECT requesting_user_id())
    OR is_pack_member((SELECT requesting_user_id()), id)
  );

-- ---------------------------------------------------------------------------
-- 1. Share tokens (TRD 8.1)
-- ---------------------------------------------------------------------------

-- 128 bits from the CSPRNG, URL-safe, never sequential and never derived from
-- the ride id. The token is the only thing standing between a stranger and a
-- live location feed, so it is generated in the database rather than trusted
-- from a client.
CREATE FUNCTION fn_pack_share_token() RETURNS TEXT AS $$
  SELECT translate(encode(gen_random_bytes(16), 'base64'), '+/=', '-_')
$$ LANGUAGE sql VOLATILE;

-- ---------------------------------------------------------------------------
-- 2. Lifecycle state machine
-- ---------------------------------------------------------------------------

-- draft -> active -> ended, and draft -> ended. Nothing else. Without this a
-- bug that resurrects an ended ride also resurrects its share link, which is
-- a live location feed that the rider believes they switched off.
CREATE FUNCTION fn_pack_rides_transition() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = OLD.status THEN
    RETURN NEW;
  END IF;
  IF OLD.status = 'ended' THEN
    RAISE EXCEPTION 'pack ride % has ended and cannot return to %', OLD.id, NEW.status;
  END IF;
  IF OLD.status = 'active' AND NEW.status = 'draft' THEN
    RAISE EXCEPTION 'pack ride % cannot return to draft once active', OLD.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_pack_rides_transition
  BEFORE UPDATE OF status ON pack_rides
  FOR EACH ROW EXECUTE FUNCTION fn_pack_rides_transition();

-- ---------------------------------------------------------------------------
-- 3. Create (PM-01, PM-02, PM-03)
-- ---------------------------------------------------------------------------

-- The route is resolved and frozen by the caller and passed in whole. Which
-- provider resolves a destination to a polyline is still open (TRD 12.1,
-- self-hosted Valhalla leading); route_source records the provenance so the
-- decision can change without a schema change.
--
-- SECURITY INVOKER on purpose: the RLS policies already say a leader may
-- insert a ride they lead and a member may insert their own member row, so
-- this function needs no elevated privilege and gets none.
CREATE FUNCTION fn_pack_create_ride(
  p_destination  GEOGRAPHY,
  p_route_line   GEOGRAPHY,
  p_route_source VARCHAR(20),
  p_name         VARCHAR(80) DEFAULT NULL,
  p_circle_id    UUID DEFAULT NULL,
  p_ttl          INTERVAL DEFAULT INTERVAL '12 hours'
) RETURNS pack_rides AS $$
DECLARE
  v_uid  TEXT := requesting_user_id();
  v_ride pack_rides;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  IF ST_NPoints(p_route_line::geometry) < 2 THEN
    RAISE EXCEPTION 'route must have at least two vertices';
  END IF;
  IF p_circle_id IS NOT NULL AND NOT is_circle_member(v_uid, p_circle_id) THEN
    RAISE EXCEPTION 'user % is not a member of circle %', v_uid, p_circle_id;
  END IF;

  INSERT INTO pack_rides (
    circle_id, leader_id, name, destination, route_line, route_cumdist,
    route_length_m, route_source, share_token, share_expires_at,
    status, expires_at)
  SELECT p_circle_id, v_uid, p_name, p_destination, p_route_line, c,
         c[array_length(c, 1)], p_route_source, fn_pack_share_token(),
         now() + p_ttl, 'draft', now() + p_ttl
  FROM (SELECT fn_pack_build_cumdist(p_route_line) AS c) x
  RETURNING * INTO v_ride;

  INSERT INTO pack_ride_members (ride_id, user_id, role)
  VALUES (v_ride.id, v_uid, 'leader');

  RETURN v_ride;
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- 4. Join (PM-04)
-- ---------------------------------------------------------------------------

-- SECURITY DEFINER is unavoidable here: a rider holding a link is not yet a
-- member, so RLS correctly hides the ride from them. Every check the policies
-- would have made is made explicitly below, and the function takes a token,
-- never a ride id -- so it cannot be used to enumerate rides.
CREATE FUNCTION fn_pack_join_ride(p_share_token TEXT)
RETURNS pack_ride_members AS $$
DECLARE
  v_uid    TEXT := requesting_user_id();
  v_ride   pack_rides;
  v_member pack_ride_members;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  SELECT * INTO v_ride FROM pack_rides WHERE share_token = p_share_token;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'invalid share link';
  END IF;
  IF v_ride.status = 'ended' THEN
    RAISE EXCEPTION 'this ride has ended';
  END IF;
  IF v_ride.share_revoked_at IS NOT NULL THEN
    RAISE EXCEPTION 'this share link has been revoked';
  END IF;
  IF v_ride.share_expires_at <= now() OR v_ride.expires_at <= now() THEN
    RAISE EXCEPTION 'this share link has expired';
  END IF;

  -- Rejoining after leaving is allowed while the ride is live: a rider who
  -- left by accident, or whose phone died, should not need a new link.
  INSERT INTO pack_ride_members (ride_id, user_id, role)
  VALUES (v_ride.id, v_uid, 'rider')
  ON CONFLICT (ride_id, user_id) DO UPDATE
    SET left_at     = NULL,
        joined_at   = now(),
        status_code = 'riding',
        status_auto = false,
        status_at   = now()
  RETURNING * INTO v_member;

  -- Re-read: the default-sweep trigger fires after the insert, so RETURNING
  -- hands back a role the row no longer has. The caller gets the truth.
  SELECT * INTO v_member FROM pack_ride_members WHERE id = v_member.id;
  RETURN v_member;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Anonymous viewers must never reach this. They read a snapshot (TRD 7.2).
REVOKE EXECUTE ON FUNCTION fn_pack_join_ride(TEXT) FROM PUBLIC, anon;

-- ---------------------------------------------------------------------------
-- 5. Start / end (PM-05, PM-07)
-- ---------------------------------------------------------------------------

CREATE FUNCTION fn_pack_start_ride(p_ride_id UUID) RETURNS pack_rides AS $$
DECLARE
  v_uid  TEXT := requesting_user_id();
  v_ride pack_rides;
BEGIN
  SELECT * INTO v_ride FROM pack_rides WHERE id = p_ride_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'pack ride % not found', p_ride_id;
  END IF;
  IF v_ride.leader_id IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION 'only the ride leader can start the ride';
  END IF;
  IF v_ride.status <> 'draft' THEN
    RAISE EXCEPTION 'ride % is already %', p_ride_id, v_ride.status;
  END IF;

  UPDATE pack_rides
     SET status = 'active', started_at = now()
   WHERE id = p_ride_id
  RETURNING * INTO v_ride;
  RETURN v_ride;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Ending a ride revokes the share link in the same statement. The two are one
-- action, not two: a live link outliving the ride it describes is the exact
-- failure PM-70 and PM-71 exist to prevent. Purging the snapshot object from
-- Storage is the caller's remaining job (TRD 8.1) and lands with step 6.
CREATE FUNCTION fn_pack_end_ride(p_ride_id UUID) RETURNS pack_rides AS $$
DECLARE
  v_uid  TEXT := requesting_user_id();
  v_ride pack_rides;
BEGIN
  SELECT * INTO v_ride FROM pack_rides WHERE id = p_ride_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'pack ride % not found', p_ride_id;
  END IF;
  IF v_ride.leader_id IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION 'only the ride leader can end the ride';
  END IF;
  IF v_ride.status = 'ended' THEN
    RETURN v_ride;
  END IF;

  UPDATE pack_rides
     SET status           = 'ended',
         ended_at         = now(),
         share_revoked_at = COALESCE(share_revoked_at, now())
   WHERE id = p_ride_id
  RETURNING * INTO v_ride;

  UPDATE pack_ride_members
     SET left_at = COALESCE(left_at, now())
   WHERE ride_id = p_ride_id;

  RETURN v_ride;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Revoking the link without ending the ride (PM-55): the pack keeps riding,
-- anonymous viewers are cut off.
CREATE FUNCTION fn_pack_revoke_share(p_ride_id UUID) RETURNS pack_rides AS $$
DECLARE
  v_uid  TEXT := requesting_user_id();
  v_ride pack_rides;
BEGIN
  SELECT * INTO v_ride FROM pack_rides WHERE id = p_ride_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'pack ride % not found', p_ride_id;
  END IF;
  IF v_ride.leader_id IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION 'only the ride leader can revoke the share link';
  END IF;

  UPDATE pack_rides
     SET share_revoked_at = COALESCE(share_revoked_at, now())
   WHERE id = p_ride_id
  RETURNING * INTO v_ride;
  RETURN v_ride;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ---------------------------------------------------------------------------
-- 6. Leave (PM-06, PM-72)
-- ---------------------------------------------------------------------------

-- Setting left_at is the removal: every read path already filters on
-- left_at IS NULL, so the member disappears from the next tick and the next
-- snapshot rather than being tombstoned somewhere a bug could resurrect.
--
-- The leader cannot leave. A ride whose leader has walked away still has a
-- live share link and no one authorised to revoke it; ending the ride is the
-- honest action and is one call away.
CREATE FUNCTION fn_pack_leave_ride(p_ride_id UUID) RETURNS VOID AS $$
DECLARE
  v_uid TEXT := requesting_user_id();
BEGIN
  IF EXISTS (SELECT 1 FROM pack_rides WHERE id = p_ride_id AND leader_id = v_uid) THEN
    RAISE EXCEPTION 'the ride leader cannot leave; end the ride instead';
  END IF;

  UPDATE pack_ride_members
     SET left_at = now()
   WHERE ride_id = p_ride_id AND user_id = v_uid AND left_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'user % is not an active member of ride %', v_uid, p_ride_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ---------------------------------------------------------------------------
-- 7. Roles (PM-09)
-- ---------------------------------------------------------------------------

CREATE FUNCTION fn_pack_set_role(p_ride_id UUID, p_user_id TEXT, p_role VARCHAR(10))
RETURNS pack_ride_members AS $$
DECLARE
  v_uid    TEXT := requesting_user_id();
  v_member pack_ride_members;
BEGIN
  IF NOT is_pack_leader(v_uid, p_ride_id) THEN
    RAISE EXCEPTION 'only the ride leader can assign roles';
  END IF;
  IF p_role = 'leader' THEN
    RAISE EXCEPTION 'leadership transfer is not supported';
  END IF;
  IF p_user_id = (SELECT leader_id FROM pack_rides WHERE id = p_ride_id) THEN
    RAISE EXCEPTION 'the leader''s own role cannot be reassigned';
  END IF;

  UPDATE pack_ride_members
     SET role = p_role
   WHERE ride_id = p_ride_id AND user_id = p_user_id AND left_at IS NULL
  RETURNING * INTO v_member;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'user % is not an active member of ride %', p_user_id, p_ride_id;
  END IF;
  RETURN v_member;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Default sweep is the last rider to join, recomputed on each join so the
-- role follows reality without the leader having to maintain it.
CREATE FUNCTION fn_pack_assign_default_sweep() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.role <> 'rider' THEN
    RETURN NEW;
  END IF;
  UPDATE pack_ride_members
     SET role = 'rider'
   WHERE ride_id = NEW.ride_id AND role = 'sweep' AND id <> NEW.id;
  UPDATE pack_ride_members SET role = 'sweep' WHERE id = NEW.id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_pack_default_sweep
  AFTER INSERT ON pack_ride_members
  FOR EACH ROW EXECUTE FUNCTION fn_pack_assign_default_sweep();

-- ---------------------------------------------------------------------------
-- 8. Expiry sweep (TRD 8.4, PM-07, PM-71)
-- ---------------------------------------------------------------------------

-- The hard TTL is a safety property, not a cleanup nicety: it is what
-- guarantees a forgotten ride stops broadcasting a rider's location. It runs
-- server-side and does not depend on any client being awake to enforce it.
CREATE FUNCTION fn_pack_sweep_expired() RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER;
  v_ids   UUID[];
BEGIN
  WITH expired AS (
    UPDATE pack_rides
       SET status           = 'ended',
           ended_at         = COALESCE(ended_at, now()),
           share_revoked_at = COALESCE(share_revoked_at, now())
     WHERE status <> 'ended' AND expires_at <= now()
    RETURNING id
  )
  SELECT array_agg(id) INTO v_ids FROM expired;

  v_count := COALESCE(array_length(v_ids, 1), 0);

  UPDATE pack_ride_members
     SET left_at = COALESCE(left_at, now())
   WHERE ride_id = ANY(v_ids);

  -- Also revoke links whose own TTL ran out on a ride that is still going.
  UPDATE pack_rides
     SET share_revoked_at = now()
   WHERE status <> 'ended'
     AND share_revoked_at IS NULL
     AND share_expires_at <= now();

  RETURN v_count;
END;
$$ LANGUAGE plpgsql;

SELECT cron.schedule(
  'pack-sweep-expired',
  '*/5 * * * *',
  $$SELECT fn_pack_sweep_expired()$$
);
