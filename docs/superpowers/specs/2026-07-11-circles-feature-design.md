# RoadPack v2 -- Safety Circles Feature Design

**Date:** 2026-07-11
**Status:** Draft
**Scope:** Circle CRUD, invite flow, member/observer management, emergency contact auto-sync, alert cascade wiring, admin controls, anti-stalking by design

---

## Decisions

| Decision | Choice |
|---|---|
| Phase 1 scope | CRUD + invites + alert cascade wiring (no live location) |
| Architecture | Circle-centric: circles own social graph, EC table stays authoritative for alert routing |
| Observer storage | Observers stored in `emergency_contacts` with new `circle_id` FK (not in `circle_members`) |
| EC auto-sync | Family circle members auto-added as emergency contacts; other types require explicit promotion |
| Observer alerts | SMS only in Phase 1 (no voice call, no push) |
| Invite mechanism | 6-char alphanumeric code for app users; admin direct-add for observers |
| Location sharing | Not in circles -- separate tracking feature (L1). Anti-surveillance by design. |
| Minor consent | App-wide parental consent via existing `consents` table, not per-circle |
| Family circle limit | Max 1 family circle per user (enforced app-side) |

---

## 1. Architecture

Three layers:

1. **CircleRepository** -- Supabase CRUD for `circles`, `circle_members`, and EC sync operations. Uses authenticated Supabase client from auth feature. All queries go through RLS.
2. **CircleService** -- Business logic: create circle (auto-admin), generate invite code, join via code, manage members, auto-sync family members to `emergency_contacts`.
3. **Riverpod providers** -- `circlesProvider` (list of user's circles), `circleDetailProvider(circleId)` (members + observers + settings), `circleActionsProvider` (create/join/leave/manage state).

### Dependencies

| Package | Purpose |
|---|---|
| `supabase_flutter` | Already in pubspec -- Supabase client for all DB operations |
| `share_plus` | Share invite code via OS share sheet (already common in Flutter projects) |
| `freezed` | Already in pubspec -- immutable models |

No new external dependencies beyond `share_plus` if not already present.

### Provider Chain

```
authenticatedSupabaseProvider (from auth feature)
  -> circleRepositoryProvider (Supabase CRUD)
  -> circlesProvider (AsyncNotifier: all user circles)
  -> circleDetailProvider(circleId) (FamilyProvider: single circle + members + observers)
  -> circleActionsProvider (create/join/leave/manage)
```

### Data Flow: Alert Wiring

```
User creates family circle
  -> adds member (app user via invite code)
  -> CircleService auto-inserts emergency_contacts row
     (is_app_user=true, alert_method='{push,sms}', priority=sequential)
  -> Member removed from circle -> EC row auto-deleted

Admin adds observer (non-app user)
  -> Inserted directly into emergency_contacts with circle_id
     (is_app_user=false, alert_method='{sms}', priority=sequential)
  -> Observer removed -> EC row deleted

Non-family circles:
  -> No auto-EC creation
  -> UI offers "Mark as emergency contact" per member
  -> Explicit action creates/removes EC row
```

---

## 2. Circle Lifecycle

### Create Circle

- User picks type (family/friends/commute/convoy) and enters name
- App generates 6-char alphanumeric invite code (client-side `Random.secure()`, collision-checked via Supabase query)
- Creator auto-added to `circle_members` with role=admin
- Family type: app checks user doesn't already have a family circle (max 1, enforced app-side)
- Convoy type: user picks duration, sets `expires_at`
- Pre-filled name by type: "My Family", "Friends", "Commute Group", "Convoy"

### Join via Invite Code

1. User enters 6-char code in join screen
2. Supabase query: `SELECT * FROM circles WHERE invite_code = ? AND (expires_at IS NULL OR expires_at > now())`
3. Show circle preview: name, type, member count
4. On confirm: INSERT `circle_members` (role=member, accepted_at=now)
5. If family circle: auto-create bidirectional EC rows (joiner becomes EC of creator, creator becomes EC of joiner)
6. Redirect to circle detail screen

### Add Observer (Admin-Only)

1. Admin taps "Add Observer" in circle detail
2. Enters name + phone number
3. INSERT into `emergency_contacts`: user_id = circle creator's ID, name, phone, relationship (optional), circle_id = this circle, is_app_user = false, alert_method = '{sms}'
4. Observer appears in circle detail under "Observers" section

### Leave Circle

- Member deletes own `circle_members` row
- If family circle: corresponding EC rows auto-deleted (both directions)
- If last admin: promote longest-tenured member to admin; if sole member, delete circle (CASCADE removes all circle_members)

### Admin Actions

| Action | Effect |
|---|---|
| Promote to admin | UPDATE circle_members SET role='admin' (trigger validates requester is admin) |
| Demote to member | UPDATE circle_members SET role='member' |
| Remove member | DELETE circle_members row + associated EC rows if family |
| Remove observer | DELETE emergency_contacts row WHERE circle_id + phone match |
| Regenerate invite code | UPDATE circles SET invite_code = new_code |
| Delete circle | DELETE circles row (CASCADE removes all members + observer EC rows via circle_id) |

---

## 3. Emergency Contact Sync

### Family Circle Auto-Sync

When a member joins a family circle:
1. For each existing member M in the circle, create TWO EC rows:
   - Row 1: `user_id=M, app_user_id=new_member` (new member appears in M's emergency contact list)
   - Row 2: `user_id=new_member, app_user_id=M` (M appears in new member's emergency contact list)
2. EC rows created with:
   - `alert_method = '{push,sms}'` for app users
   - `priority` = next sequential number for that user's EC list
   - `is_app_user = true`, `app_user_id = <member's user id>`
   - `relationship` = NULL (user can set later)
   - `circle_id` = this family circle's ID

When a member leaves a family circle:
- Delete all EC rows WHERE `circle_id = this circle AND (user_id = leaving_user OR app_user_id = leaving_user)`

### Observer EC Creation

Observers are stored directly in `emergency_contacts`:
- `user_id` = the circle admin who added them (the person the observer watches over)
- `circle_id` = the circle they belong to
- `is_app_user = false`
- `alert_method = '{sms}'`
- `phone` = observer's phone number
- `opted_out = false`

### Non-Family EC Promotion

For friends/commute/convoy circles, members are NOT auto-added as EC. The UI shows a "Mark as emergency contact" toggle per member. This explicitly:
- Creates an EC row (same fields as family auto-sync, but `circle_id` = this non-family circle)
- Removes the EC row when toggled off

### Opted-Out Handling

- EC table has `opted_out BOOLEAN DEFAULT false`
- When auto-added as EC (family circle join), the target user sees a notification: "[Name] added you as an emergency contact via [Circle Name]"
- User can toggle opt-out in their circle settings
- Opted-out ECs are skipped by the cascade engine but NOT deleted (preserves the relationship for re-opt-in)

---

## 4. Database Migration

### Migration 00013: Add circle_id to emergency_contacts

```sql
ALTER TABLE emergency_contacts
  ADD COLUMN circle_id UUID REFERENCES circles(id) ON DELETE SET NULL;

CREATE INDEX idx_emergency_contacts_circle ON emergency_contacts(circle_id)
  WHERE circle_id IS NOT NULL;
```

`ON DELETE SET NULL` rather than CASCADE: if a circle is deleted, the EC relationship persists (user explicitly added this person as an emergency contact via the circle, deleting the circle shouldn't silently remove their safety net). The `circle_id` becomes NULL, indicating a manually-managed EC.

No other schema changes needed. Existing tables (`circles`, `circle_members`, `emergency_contacts`) cover all requirements.

---

## 5. UI Screens

### 5.1 Circles List Screen (`/circles`)

- Shows all user's circles as cards
- Each card: circle name, type icon (family=heart, friends=people, commute=route, convoy=motorcycle), member count, user's role badge (admin/member)
- FAB: "Create Circle" (bottom-right)
- Action bar: "Join Circle" button (top-right, enter code)
- Empty state: illustration + "Create your first Safety Circle" heading + "Your circles help ensure the right people are alerted when something happens on the road" + "Create Circle" CTA
- Pull-to-refresh

### 5.2 Circle Detail Screen (`/circles/:id`)

**Header section:**
- Circle name (editable by admin)
- Type badge + member count
- Invite code card: code displayed prominently, "Copy" + "Share" buttons

**Members section:**
- List of app-user members from `circle_members`
- Each tile: avatar (initials fallback), name, role badge, EC indicator (shield icon if this member is your emergency contact)
- Admin overflow menu per member: Promote/Demote, Remove, Mark as EC (non-family only)
- Member's own row: "Leave Circle" in overflow

**Observers section:**
- List from `emergency_contacts WHERE circle_id = this_circle AND is_app_user = false`
- Each tile: name, phone (masked: +91 ****1234), "SMS alerts" badge
- Admin: "Remove" option, "Add Observer" button at section bottom

**Admin-only settings:**
- Regenerate invite code
- Delete circle (with confirmation dialog)

### 5.3 Create Circle Screen (`/circles/new`)

- Type picker: 4 cards in a 2x2 grid
  - Family (heart icon): "Your closest people. Members are automatically added as emergency contacts."
  - Friends (people icon): "Friends who ride or commute. Add specific members as emergency contacts."
  - Commute (route icon): "Regular commute group."
  - Convoy (motorcycle icon): "Temporary group ride. Set a duration."
- Name field (pre-filled based on type, editable)
- Convoy only: duration picker (2h, 4h, 8h, 12h, 24h, custom)
- "Create" button -> creates circle -> navigates to detail screen with invite code prominently displayed + "Share this code with your circle members" prompt

### 5.4 Join Circle Screen (`/circles/join`)

- 6-char code input (reuses OTP-style widget pattern from auth feature: individual boxes, auto-advance)
- On code complete: auto-fetch circle preview (name, type, member count)
- Preview card + "Join" button
- Error states: "Invalid code", "Circle is full", "Circle has expired"

### Navigation

Circles added to main app navigation (bottom nav bar or drawer, following existing app shell pattern). Route structure:

| Path | Screen | Auth Required |
|---|---|---|
| `/circles` | Circles list | Yes + onboarded |
| `/circles/new` | Create circle | Yes + onboarded |
| `/circles/join` | Join via code | Yes + onboarded |
| `/circles/:id` | Circle detail | Yes + onboarded + member of circle |

---

## 6. Anti-Stalking Safeguards

Core principle: **circles define WHO gets alerted, never WHERE someone is.**

| Safeguard | Implementation |
|---|---|
| No location sharing in circles | Circles have zero access to location data. Location sharing is a separate feature with its own consent flow. |
| Observer transparency | When an admin adds an observer, all circle members see who the observers are. No hidden observers. |
| Leave freely | Any member can leave any circle at any time. No approval needed. Leaving auto-removes EC relationships. |
| No covert membership | Users can see all circles they belong to. No hidden circles. |
| EC opt-out | Auto-added emergency contacts can opt out without leaving the circle. |
| Admin accountability | All admin actions (remove member, add observer) are visible to all members via the member list. |

---

## 7. Error Handling

| Scenario | Handling |
|---|---|
| Invite code collision on create | Generate new code, retry (max 3 attempts). 6-char alphanumeric = 2.1B combinations. |
| Circle at max_members | Show "Circle is full" on join attempt. Invite code still valid. |
| Expired convoy circle | Reject joins with "This convoy has ended". Show "Expired" badge on list. Don't auto-delete. |
| Duplicate join attempt | Catch unique constraint error on (circle_id, user_id) PK. Show "You're already a member". |
| Last admin leaves | Promote longest-tenured member (earliest `joined_at`) to admin. If sole member, delete circle. |
| Observer phone already exists as EC | If EC row with same phone + same user_id exists, update it to add circle_id. Don't create duplicate. |
| Network error on CRUD | Riverpod AsyncValue handles loading/error states. Retry button on error. No optimistic mutations (Supabase latency is low enough). |
| Family circle limit exceeded | App-side check before showing create form. "You already have a family circle" with link to existing one. |
| Deleted user in circle | CASCADE on users table removes circle_members rows. If deleted user was sole admin, same promotion logic applies. |
| RLS violation | Supabase returns empty result / error. App shows generic "Something went wrong" + retry. |

---

## 8. File Structure

```
app/lib/features/circles/
  circles.dart                          # barrel export (exists)
  models/
    circle.dart                         # Circle freezed model
    circle_member.dart                  # CircleMember freezed model
    models.dart                         # barrel (exists)
  services/
    circle_repository.dart              # Supabase CRUD for circles, members, EC sync
    services.dart                       # barrel (exists)
  providers/
    circles_provider.dart               # AsyncNotifier: list of user's circles
    circle_detail_provider.dart         # Family provider: single circle + members + observers
    circle_actions_provider.dart        # State for create/join/leave/manage operations
    providers.dart                      # barrel (exists)
  screens/
    circles_list_screen.dart            # All circles overview
    circle_detail_screen.dart           # Single circle view with members + observers
    create_circle_screen.dart           # New circle creation flow
    join_circle_screen.dart             # Enter invite code to join
    screens.dart                        # barrel (exists)
  widgets/
    circle_card.dart                    # Circle summary card for list screen
    member_tile.dart                    # Member row in detail view
    circle_type_picker.dart             # Type selection 2x2 grid
    invite_code_display.dart            # Code display + copy/share buttons
    invite_code_input.dart              # 6-char code entry (OTP-style)
    widgets.dart                        # barrel (exists)

app/lib/core/router/app_router.dart     # MODIFY: add circle routes + auth guards

backend/supabase/migrations/
  00013_add_circle_id_to_emergency_contacts.sql  # NEW: circle_id FK + index
```

---

## 9. Testing Strategy

| Layer | What to test |
|---|---|
| Models | Freezed serialization/deserialization, equality, copyWith |
| Repository | CRUD operations against Supabase (mocked client), RLS behavior, EC sync queries |
| Providers | State transitions: loading -> data -> error, circle list refresh, detail fetch, action side effects |
| Widgets | Circle card renders correct type icon + count, member tile shows role badge, invite code input auto-advance, type picker selection |
| Screens | Create flow end-to-end (type -> name -> create), join flow (code -> preview -> confirm), detail screen admin vs member view |
| Integration | Family circle join triggers EC creation, leave triggers EC deletion, observer add creates correct EC row |

Use Mocktail for Supabase client mocking (same pattern as auth feature tests).

---

## 10. Out of Scope (Phase 1)

- Live location sharing between circle members (tracking feature, L1)
- Voice call escalation for observers (Exotel integration, Phase 2)
- Circle-level location history
- Convoy-specific features: lead/sweep roles, formation tracking, straggler detection (L4)
- Deep link invites (roadpack.app/join/CODE)
- Circle chat/messaging
- Institutional circles (L5)
- Per-circle notification sound/vibration preferences
- Circle merging or migration between types
- Push notifications for circle events (member joined/left) -- deferred to notification infrastructure
- Offline circle management (requires Drift sync layer)
