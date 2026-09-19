-- RoadPack: pack tick support (Pack Mode steps 3 and 5)
-- TRD: docs/trd/roadpack-pack-mode-trd.md sections 5.2, 5.3, 6.2, 7.2, 8.1, 8.4
-- PRD: PM-40, PM-41, PM-42, PM-44, PM-53, PM-70..PM-74
--
-- Everything the 5 s `pack-tick` edge function needs, plus the crash-detection
-- integration seam. Two deliberate architectural choices run through this file:
--
--   1. The tick payload and the public snapshot are BUILT IN THE DATABASE, not
--      in the edge function. The snapshot is anonymous-readable, so its
--      coarsening and its exclusion of user ids are a correctness property, not
--      a rendering detail. Building it here means there is exactly one place
--      where precise data could leak, and it is covered by SQL tests.
--   2. The `possible_incident` status is written by a trigger on `incidents`
--      whose entire body sits inside an exception handler. Every writer of the
--      incidents table -- edge function, app, cron -- gets the pack behaviour,
--      and no pack bug can abort an incident write. See section 6.

-- ---------------------------------------------------------------------------
-- 1. Ride-level tunables
-- ---------------------------------------------------------------------------

-- Thresholds are ride columns, never constants. The false-positive rate of
-- `unexplained_stop` is the design risk in TRD 5.2: a flag the pack learns to
-- ignore is worse than no flag. So the default is deliberately long (15 min --
-- longer than a tea stop is unusual, shorter than a puncture repair), and it
-- is tunable per ride so field data can move it without a migration.
ALTER TABLE pack_rides
  ADD COLUMN unexplained_stop_threshold_s INTEGER NOT NULL DEFAULT 900,
  -- Distinct from stale_threshold_s (90 s, which only greys the dot).
  -- `unreachable` is a claim about the rider, not about the pixel, so it costs
  -- more evidence.
  ADD COLUMN unreachable_threshold_s      INTEGER NOT NULL DEFAULT 300,
  -- How far chainage must move before a member counts as moving. Must exceed
  -- GPS jitter at a standstill or every parked rider looks like they are
  -- crawling forward and never trips the stop threshold.
  ADD COLUMN stationary_epsilon_m         DOUBLE PRECISION NOT NULL DEFAULT 75,
  -- Public snapshot coarsening (TRD 7.2 / PM-53).
  ADD COLUMN snapshot_precision_m         DOUBLE PRECISION NOT NULL DEFAULT 50,
  -- Cached encoded polyline. The route is frozen at creation, so encoding it
  -- 4,320 times per ride would be pure waste.
  ADD COLUMN route_polyline               TEXT,
  ADD COLUMN last_tick_at                 TIMESTAMPTZ;

ALTER TABLE pack_rides
  ADD CONSTRAINT pack_rides_stop_threshold_positive
    CHECK (unexplained_stop_threshold_s > 0),
  ADD CONSTRAINT pack_rides_unreachable_threshold_positive
    CHECK (unreachable_threshold_s > 0),
  ADD CONSTRAINT pack_rides_stationary_eps_positive
    CHECK (stationary_epsilon_m > 0),
  -- A "coarsened" position that is not actually coarsened is the PM-53
  -- failure. Make it unrepresentable rather than merely discouraged.
  ADD CONSTRAINT pack_rides_snapshot_precision_floor
    CHECK (snapshot_precision_m >= 50);

-- ---------------------------------------------------------------------------
-- 2. Stationarity tracking
-- ---------------------------------------------------------------------------

-- `unexplained_stop` needs "how long has this member not moved", which nothing
-- currently records. Deriving it from location_history would mean a scan per
-- member per tick; carrying it on the member row makes it O(1).
ALTER TABLE pack_ride_members
  ADD COLUMN stationary_since      TIMESTAMPTZ,
  ADD COLUMN last_moved_chainage_m DOUBLE PRECISION;

-- ---------------------------------------------------------------------------
-- 2a. Stable anonymous member identity
-- ---------------------------------------------------------------------------
--
-- The snapshot carries no user id (PM-53), which left an anonymous viewer with
-- nothing to key a map marker on but the display name and the array position.
-- Two riders called Ravi then swap markers whenever the array reorders, and a
-- marker that silently becomes a different person is precisely the
-- confidently-wrong readout the honesty rules exist to prevent.
--
-- A random per-member value rather than an HMAC of (ride_id, user_id): an HMAC
-- is only opaque while its key is, and it is stable ACROSS rides, so the same
-- rider in two public rides is linkable by anyone who saw both. A per-member
-- random is meaningless outside the ride by construction, with no key to leak.
ALTER TABLE pack_ride_members ADD COLUMN member_key TEXT;

UPDATE pack_ride_members
   SET member_key = translate(encode(gen_random_bytes(9), 'base64'), '+/=', '-_')
 WHERE member_key IS NULL;

ALTER TABLE pack_ride_members
  ALTER COLUMN member_key SET DEFAULT
    translate(encode(gen_random_bytes(9), 'base64'), '+/=', '-_'),
  ALTER COLUMN member_key SET NOT NULL,
  ADD CONSTRAINT pack_members_key_unique UNIQUE (ride_id, member_key);

-- Rejoining after leaving keeps the same key: fn_pack_join_ride upserts the
-- existing row (00018), so the marker a viewer was watching survives a rider's
-- phone dying and coming back. Only a genuinely new membership gets a new key.

-- Maintained by trigger rather than inside fn_pack_project_member so that it
-- holds for EVERY writer of the member row, including a future ingest path
-- that does not go through that function.
CREATE FUNCTION fn_pack_track_stationary() RETURNS TRIGGER AS $fn$
DECLARE
  v_eps DOUBLE PRECISION;
BEGIN
  IF NEW.chainage_m IS NULL THEN
    NEW.stationary_since      := NULL;
    NEW.last_moved_chainage_m := NULL;
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.last_moved_chainage_m IS NOT NULL THEN
    SELECT stationary_epsilon_m INTO v_eps FROM pack_rides WHERE id = NEW.ride_id;
    IF abs(NEW.chainage_m - OLD.last_moved_chainage_m) < COALESCE(v_eps, 75) THEN
      -- Still inside the standstill bubble: the clock keeps running.
      NEW.stationary_since      := OLD.stationary_since;
      NEW.last_moved_chainage_m := OLD.last_moved_chainage_m;
      RETURN NEW;
    END IF;
  END IF;

  NEW.last_moved_chainage_m := NEW.chainage_m;
  NEW.stationary_since      := COALESCE(NEW.chainage_at, now());
  RETURN NEW;
END;
$fn$ LANGUAGE plpgsql;

CREATE TRIGGER trg_pack_track_stationary
  BEFORE INSERT OR UPDATE OF chainage_m, chainage_at ON pack_ride_members
  FOR EACH ROW EXECUTE FUNCTION fn_pack_track_stationary();

-- ---------------------------------------------------------------------------
-- 3. Automatic status evaluation (TRD 5.2, 5.3)
-- ---------------------------------------------------------------------------

-- Evaluated once per ride per tick. Returns the number of member rows changed.
--
-- Precedence (TRD 5.3), highest first:
--   possible_incident > unreachable > unexplained_stop > manual status > riding
--
-- `possible_incident` is never touched here. It is written and cleared only by
-- the incident path (section 6) -- an automatic evaluator that could clear a
-- crash flag because a rider started moving again is exactly the bug that
-- makes a safety feature untrustworthy.
--
-- A manual status suppresses `unexplained_stop` by design: a rider who said
-- "refueling" has explained the stop, which is the whole meaning of the word
-- unexplained.
CREATE FUNCTION fn_pack_auto_status(
  p_ride_id UUID,
  p_now     TIMESTAMPTZ DEFAULT now()
) RETURNS INTEGER AS $fn$
DECLARE
  v_changed INTEGER;
BEGIN
  WITH r AS (SELECT * FROM pack_rides WHERE id = p_ride_id),
  ev AS (
    SELECT
      m.id,
      m.status_code,
      m.status_auto,
      -- No fix at all, for longer than the threshold, counts as unreachable
      -- too: a rider whose phone never reported since joining is not "still
      -- locating" twenty minutes in.
      (COALESCE(m.chainage_at, m.joined_at)
         < p_now - make_interval(secs => r.unreachable_threshold_s))
        AS unreachable_cond,
      (m.chainage_at IS NOT NULL
        AND m.chainage_at >= p_now - make_interval(secs => r.unreachable_threshold_s)
        AND NOT m.off_route
        AND m.stationary_since IS NOT NULL
        AND m.stationary_since
              < p_now - make_interval(secs => r.unexplained_stop_threshold_s))
        AS stop_cond
    FROM pack_ride_members m, r
    WHERE m.ride_id = p_ride_id AND m.left_at IS NULL
  ),
  target AS (
    SELECT id,
      CASE
        WHEN status_code = 'possible_incident' THEN NULL
        WHEN unreachable_cond THEN 'unreachable'
        -- An automatic flag may be upgraded or replaced by another automatic
        -- flag; a manual status is only ever displaced from 'riding'.
        WHEN stop_cond AND (status_code = 'riding'
                            OR (status_auto AND status_code IN ('unexplained_stop','unreachable')))
             THEN 'unexplained_stop'
        WHEN status_auto AND status_code IN ('unexplained_stop','unreachable')
             THEN 'riding'
        ELSE NULL
      END AS want
    FROM ev
  ),
  upd AS (
    UPDATE pack_ride_members m
       SET status_code = t.want::VARCHAR(20),
           status_auto = (t.want <> 'riding'),
           status_at   = p_now,
           status_note = NULL
      FROM target t
     WHERE m.id = t.id
       AND t.want IS NOT NULL
       AND m.status_code IS DISTINCT FROM t.want::VARCHAR(20)
    RETURNING m.id
  )
  SELECT count(*)::INTEGER INTO v_changed FROM upd;

  RETURN v_changed;
END;
$fn$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- 4. Polyline encoding (TRD 7.2)
-- ---------------------------------------------------------------------------

CREATE FUNCTION fn_pack_encode_varint(p_v INTEGER) RETURNS TEXT AS $fn$
DECLARE
  u     INTEGER;
  v_out TEXT := '';
BEGIN
  IF p_v < 0 THEN u := ~(p_v << 1); ELSE u := p_v << 1; END IF;
  LOOP
    IF u >= 32 THEN
      v_out := v_out || chr(((u & 31) | 32) + 63);
      u := u >> 5;
    ELSE
      v_out := v_out || chr(u + 63);
      EXIT;
    END IF;
  END LOOP;
  RETURN v_out;
END;
$fn$ LANGUAGE plpgsql IMMUTABLE STRICT;

-- Google encoded polyline, precision 5. Done in SQL so the snapshot builder
-- has no reason to hand raw route geometry to anything outside the database.
CREATE FUNCTION fn_pack_encode_polyline(p_route GEOGRAPHY) RETURNS TEXT AS $fn$
DECLARE
  g    GEOMETRY := p_route::geometry;
  n    INTEGER  := ST_NPoints(p_route::geometry);
  i    INTEGER;
  plat INTEGER := 0;
  plng INTEGER := 0;
  clat INTEGER;
  clng INTEGER;
  v_out TEXT := '';
BEGIN
  FOR i IN 1..n LOOP
    clat := round(ST_Y(ST_PointN(g, i)) * 1e5)::INTEGER;
    clng := round(ST_X(ST_PointN(g, i)) * 1e5)::INTEGER;
    v_out := v_out || fn_pack_encode_varint(clat - plat)
                   || fn_pack_encode_varint(clng - plng);
    plat := clat;
    plng := clng;
  END LOOP;
  RETURN v_out;
END;
$fn$ LANGUAGE plpgsql IMMUTABLE STRICT;

-- ---------------------------------------------------------------------------
-- 4a. Viewer count (PM-55 / PM-73, TRD 8.2)
-- ---------------------------------------------------------------------------
--
-- "Riders see the viewer count" is the anti-abuse control the TRD leans on
-- hardest, and social pressure only works if the number is true. Nothing in
-- the snapshot path could produce one: viewers read a CDN object and never
-- touch the database, which is exactly why the design scales.
--
-- So the count comes from a beacon the viewer sends itself. Deliberate shape:
--   * one beacon per viewer session per ~30 s, against a 5 s snapshot poll, so
--     it adds a sixth of the request rate the viewer already generates;
--   * keyed on (ride_id, session_id) as an upsert, so a viewer who polls for
--     six hours occupies exactly one row;
--   * counted over a 90 s window, so a closed tab stops counting quickly;
--   * the share token is the only credential, and a revoked or expired ride
--     accepts no beacon -- the beacon surface is never wider than the snapshot
--     surface it describes.
--
-- Bounded-growth caveat: an attacker can mint session ids. Rows older than
-- 5 minutes are pruned on every call, so the ceiling is "beacons in 5 minutes"
-- rather than unbounded, and the count itself only ever looks at 90 s.

CREATE TABLE pack_ride_viewers (
    ride_id      UUID NOT NULL REFERENCES pack_rides(id) ON DELETE CASCADE,
    session_id   TEXT NOT NULL,
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (ride_id, session_id)
);

CREATE INDEX idx_pack_viewers_seen ON pack_ride_viewers(ride_id, last_seen_at);

-- No policies: only the SECURITY DEFINER beacon below writes here, and no
-- client reads it. The count reaches riders through the snapshot and the tick.
ALTER TABLE pack_ride_viewers ENABLE ROW LEVEL SECURITY;

-- Marks that beacon-capable viewers exist for this ride at all. Without it a
-- ride watched by six people using an older viewer build would publish
-- "viewer_count: 0", which is a fabricated audience number -- worse than none.
ALTER TABLE pack_rides ADD COLUMN viewer_beacons_seen BOOLEAN NOT NULL DEFAULT false;

CREATE FUNCTION fn_pack_viewer_count(p_ride_id UUID, p_now TIMESTAMPTZ DEFAULT now())
RETURNS INTEGER AS $fn$
  SELECT count(*)::INTEGER FROM pack_ride_viewers
   WHERE ride_id = p_ride_id AND last_seen_at > p_now - INTERVAL '90 seconds'
$fn$ LANGUAGE sql STABLE;

-- Called by the anonymous web viewer. Takes a share token, never a ride id, so
-- it cannot be used to enumerate rides; returns the live count so the viewer
-- can show the same number the riders see.
CREATE FUNCTION fn_pack_viewer_beacon(p_share_token TEXT, p_session_id TEXT)
RETURNS INTEGER AS $fn$
DECLARE
  v_ride pack_rides%ROWTYPE;
BEGIN
  IF p_session_id !~ '^[A-Za-z0-9_-]{8,64}$' THEN
    RAISE EXCEPTION 'invalid session id';
  END IF;

  SELECT * INTO v_ride FROM pack_rides
   WHERE share_token = p_share_token
     AND status = 'active'
     AND share_revoked_at IS NULL
     AND share_expires_at > now()
     AND expires_at > now();
  IF NOT FOUND THEN
    RAISE EXCEPTION 'invalid share link';
  END IF;

  DELETE FROM pack_ride_viewers
   WHERE ride_id = v_ride.id AND last_seen_at < now() - INTERVAL '5 minutes';

  INSERT INTO pack_ride_viewers (ride_id, session_id, last_seen_at)
  VALUES (v_ride.id, p_session_id, now())
  ON CONFLICT (ride_id, session_id) DO UPDATE SET last_seen_at = now();

  IF NOT v_ride.viewer_beacons_seen THEN
    UPDATE pack_rides SET viewer_beacons_seen = true WHERE id = v_ride.id;
  END IF;

  RETURN fn_pack_viewer_count(v_ride.id);
END;
$fn$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION fn_pack_viewer_beacon(TEXT, TEXT) TO PUBLIC;

-- ---------------------------------------------------------------------------
-- 5. Tick payload and public snapshot (TRD 6.2, 7.2)
-- ---------------------------------------------------------------------------

-- Snap a position to a grid of p_m metres and return [lat, lng].
--
-- Rounding decimal places would be wrong: 4 dp is ~11 m and 3 dp is ~111 m,
-- neither of which is 50, and the longitude error changes with latitude.
-- Snapping to an explicit metre grid gives a stated precision that is actually
-- true, which is what `precision_m` in the payload claims.
CREATE FUNCTION fn_pack_coarsen(p_pos GEOGRAPHY, p_m DOUBLE PRECISION)
RETURNS DOUBLE PRECISION[] AS $fn$
DECLARE
  lat  DOUBLE PRECISION := ST_Y(p_pos::geometry);
  lng  DOUBLE PRECISION := ST_X(p_pos::geometry);
  dlat DOUBLE PRECISION := p_m / 111320.0;
  dlng DOUBLE PRECISION;
BEGIN
  dlng := p_m / (111320.0 * GREATEST(cos(radians(lat)), 0.01));
  RETURN ARRAY[
    round((round(lat / dlat) * dlat)::NUMERIC, 6)::DOUBLE PRECISION,
    round((round(lng / dlng) * dlng)::NUMERIC, 6)::DOUBLE PRECISION
  ];
END;
$fn$ LANGUAGE plpgsql IMMUTABLE STRICT;

-- Shared member projection. p_public = true strips identity and coarsens.
--
-- Honesty rules are enforced here rather than in either renderer, so the app
-- and the anonymous viewer cannot disagree about when a number is trustworthy:
-- the gap is NULL whenever display_state is not 'ok' or 'estimated'.
CREATE FUNCTION fn_pack_member_payload(
  p_ride_id UUID,
  p_public  BOOLEAN,
  p_now     TIMESTAMPTZ DEFAULT now()
) RETURNS JSONB AS $fn$
  SELECT COALESCE(jsonb_agg(x ORDER BY x->>'display_name'), '[]'::jsonb)
  FROM (
    SELECT
      (CASE WHEN p_public THEN '{}'::jsonb
            ELSE jsonb_build_object('user_id', g.user_id) END)
      || jsonb_build_object(
        -- Opaque, stable for the life of the ride, meaningless outside it.
        -- The client keys markers on this, never on display_name or index.
        'member_key',   m.member_key,
        'display_name', COALESCE(u.name, 'Rider'),
        'role',         g.role,
        'chainage_m',   g.chainage_m,
        'position',
          CASE WHEN m.last_position IS NULL THEN NULL
               WHEN p_public THEN to_jsonb(fn_pack_coarsen(m.last_position, r.snapshot_precision_m))
               ELSE jsonb_build_array(
                      ST_Y(m.last_position::geometry),
                      ST_X(m.last_position::geometry)) END,
        'precision_m',
          CASE WHEN m.last_position IS NULL THEN NULL
               WHEN p_public THEN r.snapshot_precision_m
               ELSE NULL END,
        -- Suppression (TRD 4.5 / honesty rule 3): a number the pack would act
        -- on is emitted only when it is trustworthy.
        'gap_from_leader_m',
          CASE WHEN g.display_state IN ('ok','estimated') THEN g.gap_m END,
        'gap_from_leader_s',
          CASE WHEN g.display_state IN ('ok','estimated') THEN g.gap_s END,
        'gap_estimated',  g.gap_estimated,
        'display_state',  g.display_state,
        'status',         g.status_code,
        'status_auto',    g.status_auto,
        'stale',          g.stale,
        'off_route',      g.off_route,
        'off_route_m',    g.straight_m,
        'updated_at',     to_char(m.chainage_at AT TIME ZONE 'UTC',
                                  'YYYY-MM-DD"T"HH24:MI:SS"Z"')
      ) AS x
    FROM fn_pack_member_gaps(p_ride_id, p_now) g
    JOIN pack_ride_members m
      ON m.ride_id = p_ride_id AND m.user_id = g.user_id AND m.left_at IS NULL
    JOIN users u ON u.id = g.user_id
    CROSS JOIN (SELECT snapshot_precision_m FROM pack_rides WHERE id = p_ride_id) r
  ) s
$fn$ LANGUAGE sql STABLE;

-- Authenticated riders' payload: exact positions, user ids present. One
-- aggregated object for the whole ride -- TRD 6.2, the ~14x cost reduction
-- that makes the feature economically viable.
CREATE FUNCTION fn_pack_tick_state(p_ride_id UUID, p_now TIMESTAMPTZ DEFAULT now())
RETURNS JSONB AS $fn$
  SELECT jsonb_build_object(
    'ride_id',           r.id,
    'name',              r.name,
    'status',            r.status,
    'generated_at',      to_char(p_now AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'stale_threshold_s', r.stale_threshold_s,
    'route',             jsonb_build_object('length_m', r.route_length_m),
    -- Riders always see the audience, beacons or not (PM-73). An authenticated
    -- reader is entitled to know the count is zero.
    'viewer_count',      fn_pack_viewer_count(p_ride_id, p_now),
    'members',           fn_pack_member_payload(p_ride_id, false, p_now)
  )
  FROM pack_rides r WHERE r.id = p_ride_id
$fn$ LANGUAGE sql STABLE;

-- Public snapshot (TRD 7.2). Returns NULL when the ride must not be published
-- -- the caller deletes the object in that case.
--
-- Eligibility is re-checked HERE, at generation time, not only when the link
-- was created (TRD 8.1). A ride that ended, expired, or was revoked stops
-- being publishable the moment it happens, without anything else having to
-- remember to intervene.
CREATE FUNCTION fn_pack_snapshot(p_ride_id UUID, p_now TIMESTAMPTZ DEFAULT now())
RETURNS JSONB AS $fn$
DECLARE
  r    pack_rides%ROWTYPE;
  v_pl TEXT;
BEGIN
  SELECT * INTO r FROM pack_rides WHERE id = p_ride_id;
  IF NOT FOUND THEN RETURN NULL; END IF;
  IF r.status <> 'active' THEN RETURN NULL; END IF;
  IF r.share_revoked_at IS NOT NULL THEN RETURN NULL; END IF;
  IF r.share_expires_at <= p_now OR r.expires_at <= p_now THEN RETURN NULL; END IF;

  v_pl := r.route_polyline;
  IF v_pl IS NULL THEN
    v_pl := fn_pack_encode_polyline(r.route_line);
    UPDATE pack_rides SET route_polyline = v_pl WHERE id = r.id;
  END IF;

  RETURN jsonb_build_object(
    'ride_id',           r.id,
    'name',              r.name,
    'status',            r.status,
    'generated_at',      to_char(p_now AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    -- So the viewer greys a member on the same threshold the pack does,
    -- instead of inventing its own and disagreeing with the app.
    'stale_threshold_s', r.stale_threshold_s,
    'route',             jsonb_build_object('polyline', v_pl,
                                            'length_m', r.route_length_m),
    'members',           fn_pack_member_payload(p_ride_id, true, p_now)
  )
  -- Emitted only once a beacon-capable viewer has actually been seen on this
  -- ride. Absent means "not measurable here", which the viewer renders as
  -- nothing; a zero from a ride nobody is beaconing would be a fabricated
  -- audience number, and those are worse than no number at all.
  || CASE WHEN r.viewer_beacons_seen
          THEN jsonb_build_object('viewer_count', fn_pack_viewer_count(r.id, p_now))
          ELSE '{}'::jsonb END;
END;
$fn$ LANGUAGE plpgsql;

-- One call per tick: evaluate status, then build both payloads. Keeps the edge
-- function to a single round trip per ride.
CREATE FUNCTION fn_pack_tick(p_ride_id UUID, p_now TIMESTAMPTZ DEFAULT now())
RETURNS JSONB AS $fn$
DECLARE
  v_changed INTEGER;
  v_token   TEXT;
BEGIN
  v_changed := fn_pack_auto_status(p_ride_id, p_now);
  SELECT share_token INTO v_token FROM pack_rides WHERE id = p_ride_id;
  IF v_token IS NULL THEN RETURN NULL; END IF;

  UPDATE pack_rides SET last_tick_at = p_now WHERE id = p_ride_id;

  RETURN jsonb_build_object(
    'ride_id',        p_ride_id,
    'share_token',    v_token,
    'status_changed', v_changed,
    'tick',           fn_pack_tick_state(p_ride_id, p_now),
    'snapshot',       fn_pack_snapshot(p_ride_id, p_now)
  );
END;
$fn$ LANGUAGE plpgsql;

CREATE FUNCTION fn_pack_active_ride_ids() RETURNS SETOF UUID AS $fn$
  SELECT id FROM pack_rides WHERE status = 'active' AND expires_at > now()
$fn$ LANGUAGE sql STABLE;

-- Which of these Storage objects no longer correspond to a publishable ride
-- (TRD 8.4). The sweeper lists the bucket and asks; the answer scales with the
-- bucket, not with the ride table.
CREATE FUNCTION fn_pack_orphan_tokens(p_tokens TEXT[]) RETURNS TEXT[] AS $fn$
  SELECT COALESCE(array_agg(t), '{}'::TEXT[])
    FROM unnest(p_tokens) AS t
   WHERE NOT EXISTS (
     SELECT 1 FROM pack_rides r
      WHERE r.share_token = t
        AND r.status = 'active'
        AND r.share_revoked_at IS NULL
        AND r.share_expires_at > now()
        AND r.expires_at > now()
   )
$fn$ LANGUAGE sql STABLE;

-- Anonymous viewers read Storage, never these. Belt and braces.
REVOKE EXECUTE ON FUNCTION fn_pack_tick_state(UUID, TIMESTAMPTZ)   FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_pack_snapshot(UUID, TIMESTAMPTZ)     FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_pack_tick(UUID, TIMESTAMPTZ)         FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_pack_auto_status(UUID, TIMESTAMPTZ)  FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_pack_orphan_tokens(TEXT[])           FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_pack_viewer_count(UUID, TIMESTAMPTZ) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_pack_member_payload(UUID, BOOLEAN, TIMESTAMPTZ)
  FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- 6. The crash-detection seam (TRD 5.2, PM-40, PM-42)
-- ---------------------------------------------------------------------------
--
-- THE HIGHEST-SEVERITY CONSTRAINT IN THE PROJECT: nothing below may delay,
-- alter, or fail the emergency alert cascade.
--
-- Two independent mechanisms, deliberately:
--   * this trigger writes the TRUTH (the member row) and is unfailable;
--   * `incident-receive` fires the immediate PUSH, fire-and-forget, so the
--     pack is told inside the 30 s cancellable countdown rather than after the
--     cascade dispatches.
-- If the push path breaks, the next 5 s tick still carries the status. If the
-- trigger's inner logic breaks, the exception handler swallows it and the
-- incident write commits regardless. Neither can take the cascade down.

CREATE FUNCTION fn_pack_flag_incident(p_user_id TEXT, p_incident_id UUID)
RETURNS INTEGER AS $fn$
  WITH upd AS (
    UPDATE pack_ride_members m
       SET status_code = 'possible_incident',
           status_auto = true,
           status_at   = now(),
           status_note = NULL,
           incident_id = p_incident_id
      FROM pack_rides r
     WHERE m.ride_id = r.id
       AND m.user_id = p_user_id
       AND m.left_at IS NULL
       AND r.status  = 'active'
    RETURNING m.id
  )
  SELECT count(*)::INTEGER FROM upd
$fn$ LANGUAGE sql;

-- The rider pressed "I'M OKAY" (or the incident was resolved). Clear back to
-- riding; the next tick pushes the cancellation to the pack.
CREATE FUNCTION fn_pack_clear_incident(p_incident_id UUID) RETURNS INTEGER AS $fn$
  WITH upd AS (
    UPDATE pack_ride_members
       SET status_code = 'riding',
           status_auto = false,
           status_at   = now(),
           incident_id = NULL
     WHERE incident_id = p_incident_id
       AND status_code = 'possible_incident'
    RETURNING id
  )
  SELECT count(*)::INTEGER FROM upd
$fn$ LANGUAGE sql;

CREATE FUNCTION fn_pack_incident_sync() RETURNS TRIGGER AS $fn$
BEGIN
  -- Every statement in this body is inside the handler below. There is no
  -- path from a Pack Mode defect to a failed incident write.
  BEGIN
    IF TG_OP = 'INSERT' THEN
      IF NEW.type IN ('crash_detected', 'sos', 'inactivity')
         AND NEW.status NOT IN ('cancelled', 'resolved') THEN
        PERFORM fn_pack_flag_incident(NEW.user_id, NEW.id);
      END IF;
    ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
      IF NEW.status IN ('cancelled', 'resolved') THEN
        PERFORM fn_pack_clear_incident(NEW.id);
      END IF;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    -- Log and continue. A pack write that cannot happen is a degraded pack
    -- view; an incident write that cannot happen is a person nobody comes for.
    RAISE WARNING 'pack incident sync failed for incident % (%): %',
      NEW.id, TG_OP, SQLERRM;
  END;
  RETURN NEW;
END;
$fn$ LANGUAGE plpgsql;

CREATE TRIGGER trg_pack_incident_sync
  AFTER INSERT OR UPDATE OF status ON incidents
  FOR EACH ROW EXECUTE FUNCTION fn_pack_incident_sync();

REVOKE EXECUTE ON FUNCTION fn_pack_flag_incident(TEXT, UUID)  FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION fn_pack_clear_incident(UUID)       FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- 7. Storage bucket for public snapshots
-- ---------------------------------------------------------------------------

-- Guarded: the pgTAP runner applies migrations to a bare Postgres with no
-- `storage` schema, and a migration that only works against a full Supabase
-- stack is a migration the tests cannot run.
DO $do$
BEGIN
  IF to_regclass('storage.buckets') IS NOT NULL THEN
    INSERT INTO storage.buckets (id, name, public, file_size_limit)
    VALUES ('packs', 'packs', true, 1048576)
    ON CONFLICT (id) DO NOTHING;
  END IF;
END $do$;

-- ---------------------------------------------------------------------------
-- 8. Scheduling (TRD 6.2, 8.4)
-- ---------------------------------------------------------------------------

-- Same shape as escalation-check (00014): pg_cron -> pg_net -> edge function.
--
-- 5 s cadence needs pg_cron's interval syntax (1.5+). Falling back to one
-- minute rather than failing the migration: a slow pack view is a degraded
-- feature, a migration that will not apply is an outage.
DO $do$
BEGIN
  BEGIN
    PERFORM cron.schedule('pack-tick', '5 seconds', $j$SELECT net.http_post(
      url := current_setting('app.supabase_url') || '/functions/v1/pack-tick',
      body := '{}'::jsonb,
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || current_setting('app.service_role_key'),
        'Content-Type', 'application/json'
      )
    )$j$);
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'pg_cron sub-minute schedule unavailable (%), falling back to 1 min', SQLERRM;
    PERFORM cron.schedule('pack-tick', '* * * * *', $j$SELECT net.http_post(
      url := current_setting('app.supabase_url') || '/functions/v1/pack-tick',
      body := '{}'::jsonb,
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || current_setting('app.service_role_key'),
        'Content-Type', 'application/json'
      )
    )$j$);
  END;
END $do$;

-- Orphaned-snapshot sweep. fn_pack_sweep_expired() is already scheduled by
-- 00018; this is the Storage half of TRD 8.4, which the database cannot do
-- alone because it cannot list a bucket.
SELECT cron.schedule(
  'pack-snapshot-sweep',
  '*/5 * * * *',
  $j$SELECT net.http_post(
    url := current_setting('app.supabase_url') || '/functions/v1/pack-tick?sweep=1',
    body := '{"sweep":true}'::jsonb,
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || current_setting('app.service_role_key'),
      'Content-Type', 'application/json'
    )
  )$j$
);
