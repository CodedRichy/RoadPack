-- RoadPack: let a member stop sharing their own location without leaving the
-- circle (SG-04).
--
-- Until now the only lever a member had was to leave. Leaving is visible to the
-- whole circle and severs the safety relationship entirely -- so the only way
-- to stop being watched was to stop being protected. That is a bad trade to
-- force on someone, and it is exactly the trade an anti-stalking posture should
-- not require.
--
-- No new column or policy is needed. `circle_members.permissions` (JSONB)
-- already exists, and the `circle_members_update` policy already lets a member
-- write their own row; `prevent_membership_tampering` guards identity and role
-- but not this key. Only the visibility function changes.
--
-- COALESCE(..., true) is load-bearing: every existing row has no
-- `share_location` key and must keep behaving exactly as it does today. This
-- migration can only ever *restrict* visibility, never widen it.
--
-- Note the asymmetry with the circle-level flag, which COALESCEs to false. The
-- circle-level default is "not shared unless someone chose to share"; the
-- member-level default is "not additionally restricted unless the member chose
-- to restrict". Both defaults fail towards less exposure.

CREATE OR REPLACE FUNCTION can_view_location(viewer TEXT, target TEXT)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM circle_members cm1
    JOIN circle_members cm2 ON cm1.circle_id = cm2.circle_id
    JOIN circles c ON c.id = cm1.circle_id
    WHERE cm1.user_id = viewer
      AND cm2.user_id = target
      -- the circle shares at all
      AND COALESCE((c.settings->>'location_sharing')::BOOLEAN, false)
      -- and this member has not opted their own position out
      AND COALESCE((cm2.permissions->>'share_location')::BOOLEAN, true)
  )
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;

COMMENT ON FUNCTION can_view_location(TEXT, TEXT) IS
  'True when viewer may see target''s location: they share a circle, that '
  'circle has location_sharing enabled, and target has not set '
  'permissions.share_location = false on their own membership row. '
  'This function is the single server-side authority on location visibility; '
  'the client mirrors it in VisibilityReport.from and must never disagree.';
