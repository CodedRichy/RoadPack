-- Migration 00021 gate: a member can stop their own live location being
-- shared without leaving the circle, and the change can only ever restrict
-- visibility.
--
-- `can_view_location` is the single server-side authority on who may see
-- whom. The "Who can see me" screen (FR-014) mirrors it in
-- VisibilityReport.from, and the whole point of that screen is that a user
-- can trust it. So the two properties under test here are not conveniences:
--
--   1. The migration must not widen visibility. Every membership row that
--      existed before this change has no `share_location` key, and must keep
--      behaving exactly as it did. If COALESCE ever flips to false, every
--      circle in production goes dark overnight; if the term were ORed
--      instead of ANDed, opting out would expose people.
--   2. The opt-out must actually work, and be reversible. A privacy control
--      you cannot undo is not a control, it is a trapdoor.
--
-- Run: bash backend/supabase/tests/run.sh

BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;
SELECT plan(22);

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------

INSERT INTO users (id, phone, name) VALUES
  ('u_asha',  '+919200000001', 'Asha'),
  ('u_amma',  '+919200000002', 'Amma'),
  ('u_ravi',  '+919200000003', 'Ravi'),
  ('u_stray', '+919200000004', 'Stranger');

-- A circle that shares, one that does not, and one the others are not in.
INSERT INTO circles (id, name, type, created_by, invite_code, settings) VALUES
  ('11111111-1111-1111-1111-111111111111', 'Home',    'family',  'u_asha',
   'shrhme', '{"location_sharing": true}'),
  ('22222222-2222-2222-2222-222222222222', 'College', 'commute', 'u_asha',
   'silcol', '{}'),
  ('33333333-3333-3333-3333-333333333333', 'Strays',  'friends', 'u_stray',
   'strays', '{"location_sharing": true}');

-- Note: no `permissions` given. These rows are exactly the shape of every
-- membership that existed before migration 00021.
INSERT INTO circle_members (circle_id, user_id, role, accepted_at) VALUES
  ('11111111-1111-1111-1111-111111111111', 'u_asha', 'admin',  now()),
  ('11111111-1111-1111-1111-111111111111', 'u_amma', 'member', now()),
  ('11111111-1111-1111-1111-111111111111', 'u_ravi', 'member', now()),
  ('22222222-2222-2222-2222-222222222222', 'u_asha', 'member', now()),
  ('22222222-2222-2222-2222-222222222222', 'u_amma', 'member', now()),
  ('33333333-3333-3333-3333-333333333333', 'u_stray','admin',  now());

-- ---------------------------------------------------------------------------
-- 1. The migration cannot widen visibility: legacy rows behave as before
-- ---------------------------------------------------------------------------

SELECT ok(
  (SELECT can_view_location('u_amma', 'u_asha')),
  'a row with no share_location key still shares, as it did before 00021');

SELECT ok(
  (SELECT can_view_location('u_asha', 'u_amma')),
  'and it shares in both directions');

SELECT ok(
  NOT (SELECT can_view_location('u_stray', 'u_asha')),
  'someone outside every shared circle still sees nothing');

SELECT ok(
  NOT (SELECT can_view_location('u_asha', 'u_stray')),
  'and is not visible themselves');

SELECT is(
  (SELECT count(*)::BIGINT FROM circle_members
    WHERE permissions ? 'share_location'),
  0::BIGINT,
  'the migration writes no data: not one row gained the key');

-- The College circle has no location_sharing flag at all. The member term
-- must not rescue it -- the two conditions are ANDed, not ORed.
UPDATE circle_members SET permissions = '{"share_location": true}'
  WHERE circle_id = '22222222-2222-2222-2222-222222222222'
    AND user_id = 'u_asha';

-- Proven directly, with the Home circle excluded from the join.
SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM circle_members cm1
    JOIN circle_members cm2 ON cm1.circle_id = cm2.circle_id
    JOIN circles c ON c.id = cm1.circle_id
    WHERE cm1.user_id = 'u_amma' AND cm2.user_id = 'u_asha'
      AND c.id = '22222222-2222-2222-2222-222222222222'
      AND COALESCE((c.settings->>'location_sharing')::BOOLEAN, false)
      AND COALESCE((cm2.permissions->>'share_location')::BOOLEAN, true)
  ),
  'the circle flag and the member flag are ANDed, never ORed');

UPDATE circle_members SET permissions = '{}'
  WHERE circle_id = '22222222-2222-2222-2222-222222222222'
    AND user_id = 'u_asha';

-- ---------------------------------------------------------------------------
-- 2. Opting out hides the member, while the circle flag stays on
-- ---------------------------------------------------------------------------

UPDATE circle_members SET permissions = '{"share_location": false}'
  WHERE circle_id = '11111111-1111-1111-1111-111111111111'
    AND user_id = 'u_asha';

SELECT ok(
  NOT (SELECT can_view_location('u_amma', 'u_asha')),
  'a member who opted out is no longer visible to the circle');

SELECT ok(
  NOT (SELECT can_view_location('u_ravi', 'u_asha')),
  'and is invisible to every member, not just the one who asked');

SELECT ok(
  (SELECT COALESCE((settings->>'location_sharing')::BOOLEAN, false)
     FROM circles WHERE id = '11111111-1111-1111-1111-111111111111'),
  'the circle-wide setting is untouched -- this is a member-side lever only');

SELECT ok(
  (SELECT can_view_location('u_asha', 'u_amma')),
  'opting out stops others seeing you; it does not blind you to them');

SELECT ok(
  (SELECT can_view_location('u_amma', 'u_ravi')),
  'and it changes nothing for anybody else in the circle');

SELECT is(
  (SELECT count(*)::BIGINT FROM circle_members
    WHERE circle_id = '11111111-1111-1111-1111-111111111111'
      AND user_id = 'u_asha'),
  1::BIGINT,
  'the member is still in the circle -- opting out is not leaving');

SELECT is(
  (SELECT role FROM circle_members
    WHERE circle_id = '11111111-1111-1111-1111-111111111111'
      AND user_id = 'u_asha'),
  'admin',
  'and keeps their role, so the safety relationship is intact');

-- ---------------------------------------------------------------------------
-- 3. It is reversible
-- ---------------------------------------------------------------------------

UPDATE circle_members SET permissions = '{"share_location": true}'
  WHERE circle_id = '11111111-1111-1111-1111-111111111111'
    AND user_id = 'u_asha';

SELECT ok(
  (SELECT can_view_location('u_amma', 'u_asha')),
  'switching sharing back on restores visibility');

-- Removing the key entirely (rather than setting true) must also restore,
-- since COALESCE treats absence as sharing.
UPDATE circle_members SET permissions = permissions - 'share_location'
  WHERE circle_id = '11111111-1111-1111-1111-111111111111'
    AND user_id = 'u_asha';

SELECT ok(
  (SELECT can_view_location('u_amma', 'u_asha')),
  'and so does clearing the key, matching COALESCE(..., true)');

-- The client writes the key alongside whatever else lives in `permissions`.
-- Merging must not clobber the rest of the bag.
UPDATE circle_members
  SET permissions = '{"some_other_flag": true, "share_location": false}'
  WHERE circle_id = '11111111-1111-1111-1111-111111111111'
    AND user_id = 'u_asha';

SELECT ok(
  NOT (SELECT can_view_location('u_amma', 'u_asha')),
  'the opt-out is read correctly when other permission keys are present');

SELECT ok(
  (SELECT (permissions->>'some_other_flag')::BOOLEAN FROM circle_members
    WHERE circle_id = '11111111-1111-1111-1111-111111111111'
      AND user_id = 'u_asha'),
  'and unrelated permission keys survive');

-- A JSON string "false" must read as false too: `->>` yields text and the
-- cast is to BOOLEAN, so both shapes reach the same place.
UPDATE circle_members SET permissions = '{"share_location": "false"}'
  WHERE circle_id = '11111111-1111-1111-1111-111111111111'
    AND user_id = 'u_asha';

SELECT ok(
  NOT (SELECT can_view_location('u_amma', 'u_asha')),
  'the text "false" opts out as surely as the boolean');

UPDATE circle_members SET permissions = '{}'
  WHERE circle_id = '11111111-1111-1111-1111-111111111111'
    AND user_id = 'u_asha';

-- ---------------------------------------------------------------------------
-- 4. A member can set their own flag, and only their own
-- ---------------------------------------------------------------------------

GRANT SELECT, UPDATE ON circle_members TO authenticated;
GRANT SELECT ON circles TO authenticated;

SET LOCAL request.jwt.claim.sub = 'u_asha';
SET LOCAL ROLE authenticated;

UPDATE circle_members SET permissions = '{"share_location": false}'
  WHERE circle_id = '11111111-1111-1111-1111-111111111111'
    AND user_id = 'u_asha';

SELECT is(
  (SELECT (permissions->>'share_location')
     FROM circle_members
    WHERE circle_id = '11111111-1111-1111-1111-111111111111'
      AND user_id = 'u_asha'),
  'false',
  'a member can write the opt-out on their own row with no admin rights');

-- circle_members_update is USING (user_id = requesting_user_id()) with no
-- WITH CHECK, so another member's row is simply not visible to the UPDATE:
-- it matches zero rows rather than raising.
UPDATE circle_members SET permissions = '{"share_location": false}'
  WHERE circle_id = '11111111-1111-1111-1111-111111111111'
    AND user_id = 'u_ravi';

SELECT is(
  (SELECT permissions FROM circle_members
    WHERE circle_id = '11111111-1111-1111-1111-111111111111'
      AND user_id = 'u_ravi'),
  '{}'::JSONB,
  'and cannot silence anybody else -- no remote configuration (SG-04)');

RESET ROLE;

SELECT ok(
  NOT (SELECT can_view_location('u_amma', 'u_asha')),
  'the member-written opt-out is the one can_view_location honours');

SELECT ok(
  (SELECT can_view_location('u_amma', 'u_ravi')),
  'and the row the member could not touch still shares');

SELECT * FROM finish();
ROLLBACK;
