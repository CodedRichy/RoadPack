-- Check if admin_uid is an admin of any circle that member_uid also belongs to
CREATE OR REPLACE FUNCTION is_admin_of_shared_circle(admin_uid TEXT, member_uid TEXT)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM circle_members cm1
    JOIN circle_members cm2 ON cm1.circle_id = cm2.circle_id
    WHERE cm1.user_id = admin_uid AND cm1.role = 'admin'
      AND cm2.user_id = member_uid
  )
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;
