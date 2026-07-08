-- RoadPack v2: circles, circle_members, SECURITY DEFINER helper functions, RLS

CREATE TABLE circles (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name         VARCHAR(100) NOT NULL,
    type         VARCHAR(20) NOT NULL CHECK (type IN ('family','friends','commute','convoy')),
    created_by   TEXT REFERENCES users(id),
    invite_code  VARCHAR(12) UNIQUE,
    max_members  INT,
    settings     JSONB DEFAULT '{}',
    created_at   TIMESTAMPTZ DEFAULT now(),
    expires_at   TIMESTAMPTZ
);

CREATE TABLE circle_members (
    circle_id    UUID REFERENCES circles(id) ON DELETE CASCADE,
    user_id      TEXT REFERENCES users(id) ON DELETE CASCADE,
    role         VARCHAR(20) NOT NULL CHECK (role IN ('admin','member','observer')),
    permissions  JSONB DEFAULT '{}',
    accepted_at  TIMESTAMPTZ,
    joined_at    TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (circle_id, user_id)
);

CREATE INDEX idx_circle_members_user ON circle_members(user_id);

-- SECURITY DEFINER helpers: bypass RLS to avoid recursive policy evaluation

CREATE FUNCTION get_user_circle_ids(uid TEXT)
RETURNS SETOF UUID AS $$
  SELECT circle_id FROM circle_members WHERE user_id = uid
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;

CREATE FUNCTION is_circle_member(uid TEXT, cid UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (SELECT 1 FROM circle_members WHERE user_id = uid AND circle_id = cid)
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;

CREATE FUNCTION is_circle_admin(uid TEXT, cid UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (SELECT 1 FROM circle_members WHERE user_id = uid AND circle_id = cid AND role = 'admin')
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;

CREATE FUNCTION shares_circle_with(viewer TEXT, target TEXT)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM circle_members cm1
    JOIN circle_members cm2 ON cm1.circle_id = cm2.circle_id
    WHERE cm1.user_id = viewer AND cm2.user_id = target
  )
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;

-- Circles RLS

ALTER TABLE circles ENABLE ROW LEVEL SECURITY;

CREATE POLICY circles_select ON circles FOR SELECT
  USING (id IN (SELECT get_user_circle_ids(requesting_user_id())));

CREATE POLICY circles_insert ON circles FOR INSERT
  WITH CHECK (requesting_user_id() IS NOT NULL AND created_by = requesting_user_id());

CREATE POLICY circles_update ON circles FOR UPDATE
  USING (is_circle_admin(requesting_user_id(), id));

CREATE POLICY circles_delete ON circles FOR DELETE
  USING (is_circle_admin(requesting_user_id(), id));

-- Circle Members RLS

ALTER TABLE circle_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY circle_members_select ON circle_members FOR SELECT
  USING (circle_id IN (SELECT get_user_circle_ids(requesting_user_id())));

CREATE POLICY circle_members_insert ON circle_members FOR INSERT
  WITH CHECK (
    (user_id = requesting_user_id() AND role IN ('member', 'observer'))
    OR is_circle_admin(requesting_user_id(), circle_id)
  );

CREATE POLICY circle_members_update ON circle_members FOR UPDATE
  USING (user_id = requesting_user_id());

CREATE POLICY circle_members_delete ON circle_members FOR DELETE
  USING (
    user_id = requesting_user_id()
    OR is_circle_admin(requesting_user_id(), circle_id)
  );

-- Prevent members from self-promoting their role via UPDATE (no WITH CHECK exists
-- above, so a member could otherwise set their own role to 'admin')

CREATE FUNCTION prevent_role_self_promotion()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.role != OLD.role AND NOT is_circle_admin(requesting_user_id(), NEW.circle_id) THEN
    RAISE EXCEPTION 'Only circle admins can change member roles';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER check_role_change
  BEFORE UPDATE ON circle_members
  FOR EACH ROW EXECUTE FUNCTION prevent_role_self_promotion();
