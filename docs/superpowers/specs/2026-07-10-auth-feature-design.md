# RoadPack v2 — Auth Feature Design

**Date:** 2026-07-10
**Status:** Draft
**Scope:** Clerk Flutter SDK integration, custom sign-in UI, Supabase JWT bridge, webhook user sync, onboarding flow, router auth guards

---

## Decisions

| Decision | Choice |
|---|---|
| Auth provider | Clerk (not Supabase Auth) |
| Flutter SDK | `clerk_flutter` — headless API for custom UI |
| Auth methods | Phone OTP (primary) + Email OTP + Google Sign-In |
| Sign-in UI | Custom Flutter screens (Material3 dark-first theme) |
| Onboarding | Full: name, DOB, vehicle, first emergency contact |
| JWT integration | Clerk JWT template → Supabase custom JWT secret |
| User sync | Clerk webhook → Edge Function → `users` table |

---

## 1. Architecture

Three layers:

1. **Clerk SDK** (`clerk_flutter`) — auth state, sessions, token management, multi-provider sign-in
2. **Auth bridge** — converts Clerk sessions to Supabase-compatible JWTs, manages authenticated Supabase client via Riverpod providers
3. **Webhook sync** — Deno Edge Function receives Clerk `user.created`/`user.updated` events, upserts `users` table rows

### Dependencies

| Package | Purpose |
|---|---|
| `clerk_flutter` | Clerk auth SDK for Flutter |
| `google_sign_in` | Google OAuth (used by Clerk under the hood, may need explicit dep) |
| `supabase_flutter` | Already in pubspec — Supabase client |

### Constants (via `--dart-define`)

- `CLERK_PUBLISHABLE_KEY` — Clerk frontend publishable key
- `SUPABASE_URL` — already exists
- `SUPABASE_ANON_KEY` — already exists

---

## 2. Auth Flow

### Sign-In / Sign-Up Screen

Single screen with three auth methods:

1. **Phone OTP** (top, primary)
   - Phone input with +91 auto-prefix for Indian numbers
   - Clerk sends SMS OTP → user enters code → session created
   
2. **Email OTP** (secondary)
   - Email input → Clerk sends email code → verify → session created

3. **Google Sign-In** (social button at bottom)
   - Google OAuth flow handled by Clerk
   - Clerk auto-links accounts if same email/phone already exists

### Auth State Machine

```
idle → identifier_entered → code_sent → verifying → authenticated
```

Post-authentication:
```
authenticated → [check users table] → onboarding_needed | profile_complete
onboarding_needed → onboarding → profile_complete
profile_complete → home
```

### Session Persistence

Clerk SDK persists sessions to device storage. On app launch:
- Session exists + valid → auto-authenticate, skip sign-in
- Session exists + expired → Clerk refreshes token silently
- No session → show sign-in screen

---

## 3. Clerk + Supabase JWT Integration

### Token Flow

1. Clerk session active → `session.getToken(template: 'supabase')` returns JWT
2. JWT `sub` claim = Clerk user ID (e.g. `user_2xABC`) — matches `requesting_user_id()` in database RLS
3. JWT passed to Supabase client as Bearer token in auth header
4. Token auto-refreshes via Riverpod provider watching Clerk session state

### Clerk JWT Template (Supabase)

Configured in Clerk Dashboard under JWT Templates, named `supabase`:

```json
{
  "sub": "{{user.id}}",
  "aud": "authenticated",
  "role": "authenticated",
  "iss": "clerk"
}
```

### Supabase Configuration

In Supabase Dashboard → Settings → API → JWT Settings:
- Set "JWT Secret" to Clerk's JWT signing key (from Clerk Dashboard → JWT Templates)

### Riverpod Provider Chain

```
clerkAuthProvider (AsyncNotifier)
  → watches Clerk session state (signed in / signed out / loading)
  → exposes: isAuthenticated, userId, session

supabaseTokenProvider (FutureProvider)
  → depends on clerkAuthProvider
  → calls session.getToken(template: 'supabase')
  → refreshes when session changes

authenticatedSupabaseProvider (Provider)
  → depends on supabaseTokenProvider
  → returns SupabaseClient with JWT auth header set
  → all feature providers use this for RLS-authenticated queries
```

When session expires or user signs out → Supabase client reverts to unauthenticated. RLS-protected queries return empty results / fail gracefully.

### Offline Handling

- JWT cached locally by Clerk SDK
- If token expired and device is offline, queued writes stored in Drift (SQLite)
- On reconnect: refresh token → flush queued writes with fresh JWT

---

## 4. Webhook Edge Function

### `clerk-webhook` (new Edge Function)

**Path:** `backend/supabase/functions/clerk-webhook/index.ts`

**Purpose:** Sync Clerk user data to the `users` table on signup/update.

**Events handled:**

| Event | Action |
|---|---|
| `user.created` | INSERT into `users` — id (Clerk ID), phone, name (from Clerk profile) |
| `user.updated` | UPDATE `users` — phone, name changes from Clerk side |

**Security:**
- Verifies Svix webhook signature using `CLERK_WEBHOOK_SECRET` env var
- Uses Supabase service role key (bypasses RLS) for database writes
- Rejects requests with invalid signatures (401)

**Webhook row is partial:** Only `id`, `phone`, and `name` are set by the webhook. The `date_of_birth`, `vehicle_type`, `vehicle_reg`, and other fields are NULL until the user completes onboarding via the app (through normal RLS-authenticated Supabase client).

**Race condition mitigation:** Clerk session may be valid before the webhook fires and the `users` row exists. The app handles this:
- After authentication, fetch own user row from Supabase
- If 404 / empty (webhook hasn't fired yet), retry with exponential backoff: 500ms, 1s, 2s (max 3 attempts)
- If still missing after retries, create the row from the client side as fallback (user has INSERT policy on own row)

---

## 5. Onboarding Flow

### Trigger

Authenticated user whose `users.date_of_birth` is NULL (proxy for incomplete onboarding).

### Steps (Multi-Page)

**Page 1 — Name**
- Text field, pre-filled from Clerk profile if available
- Required, 2-100 characters
- UPDATE `users SET name = ?`

**Page 2 — Date of Birth**
- Date picker, max date = today, min date = 100 years ago
- Required (needed for minor detection at query time: `date_of_birth > CURRENT_DATE - INTERVAL '18 years'`)
- UPDATE `users SET date_of_birth = ?`

**Page 3 — Vehicle**
- Vehicle type: dropdown (two_wheeler / four_wheeler / none)
- Registration number: text field (optional, shown if vehicle type != none)
- Optional but encouraged (affects crash detection sensitivity in Phase 2)
- UPDATE `users SET vehicle_type = ?, vehicle_reg = ?`

**Page 4 — First Emergency Contact**
- Name + phone + relationship fields
- "Skip for now" button (can add later from settings)
- If filled: INSERT into `emergency_contacts`
- Shows explanation: "This person will be contacted if something happens to you on the road"

### After Completion

Navigate to `/home`. Onboarding is not shown again (DOB is set = profile complete).

---

## 6. Router & Auth Guards

### GoRouter Redirect Logic

```dart
redirect: (context, state) {
  final isAuthenticated = ref.read(clerkAuthProvider).isAuthenticated;
  final isOnboarded = ref.read(userProfileProvider).isOnboarded;
  final isAuthRoute = state.matchedLocation.startsWith('/sign-in') 
                   || state.matchedLocation.startsWith('/verify');
  final isOnboardingRoute = state.matchedLocation == '/onboarding';

  if (!isAuthenticated && !isAuthRoute) return '/sign-in';
  if (isAuthenticated && isAuthRoute) {
    return isOnboarded ? '/home' : '/onboarding';
  }
  if (isAuthenticated && !isOnboarded && !isOnboardingRoute) return '/onboarding';
  return null; // no redirect
}
```

### Route Structure

| Path | Screen | Auth Required |
|---|---|---|
| `/sign-in` | Sign-in screen (phone/email/Google) | No |
| `/verify` | OTP verification | No |
| `/onboarding` | Multi-step profile setup | Yes |
| `/home` | Main app screen | Yes + onboarded |

### Router Refresh

GoRouter `refreshListenable` watches Clerk auth state via a `ChangeNotifier` bridge from the Riverpod provider. Auth state change → router re-evaluates redirects automatically.

---

## 7. File Structure

```
app/lib/features/auth/
  auth.dart                         # barrel export
  models/
    auth_state.dart                 # AuthState enum + freezed model
    models.dart                     # barrel
  providers/
    clerk_auth_provider.dart        # ClerkAuthNotifier — session management
    supabase_token_provider.dart    # JWT bridge — Clerk session → Supabase token
    authenticated_supabase_provider.dart  # Supabase client with JWT header
    user_profile_provider.dart      # Fetches/caches own user row, isOnboarded check
    providers.dart                  # barrel
  screens/
    sign_in_screen.dart             # Phone/email/Google sign-in
    verify_screen.dart              # OTP code entry
    onboarding_screen.dart          # Multi-page onboarding (PageView)
    screens.dart                    # barrel
  services/
    clerk_service.dart              # Thin wrapper around clerk_flutter API
    services.dart                   # barrel
  widgets/
    phone_input.dart                # Phone field with +91 prefix
    otp_input.dart                  # 6-digit OTP code field
    social_sign_in_button.dart      # Google sign-in button
    onboarding_step.dart            # Reusable onboarding page template
    widgets.dart                    # barrel

app/lib/core/
  constants/app_constants.dart      # MODIFY — add clerkPublishableKey
  network/supabase_client.dart      # MODIFY — support JWT auth header injection
  router/app_router.dart            # MODIFY — add auth routes + redirect logic

backend/supabase/functions/
  clerk-webhook/index.ts            # NEW — Clerk webhook handler
```

---

## 8. Error Handling

| Scenario | Handling |
|---|---|
| Invalid phone number | Clerk SDK returns validation error → show inline error |
| Wrong OTP code | Clerk SDK returns error → show "Invalid code, try again" |
| OTP expired | Show "Code expired" + resend button |
| Google sign-in cancelled | Return to sign-in screen silently |
| Network error during auth | Show retry banner, Clerk handles offline queueing |
| Webhook race (user row missing) | Exponential backoff retry (3x), then client-side INSERT fallback |
| JWT refresh failure | Sign out user, redirect to /sign-in |
| Supabase query with expired token | Catch 401, trigger token refresh, retry once |

---

## 9. Out of Scope (Phase 1)

- Apple Sign-In (no iOS in Phase 1)
- Biometric/PIN lock (Phase 2)
- Account deletion flow (Phase 2, needs DPDPA compliance)
- Account linking UI (Clerk handles behind the scenes)
- Multi-device session management
- Minor consent workflow (recorded DOB, consent flow built in circles feature)
