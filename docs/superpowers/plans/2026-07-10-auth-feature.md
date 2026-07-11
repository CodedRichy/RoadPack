# Auth Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement Clerk-based authentication with phone OTP, email OTP, and Google Sign-In, Supabase JWT bridge, webhook user sync, multi-step onboarding, and router auth guards.

**Architecture:** Clerk Flutter SDK provides headless auth (sessions, tokens, multi-provider). A Riverpod provider chain bridges Clerk sessions to Supabase JWTs for RLS-authenticated queries. A Deno Edge Function syncs Clerk user events to the `users` table via webhook. GoRouter redirect logic gates unauthenticated and un-onboarded users.

**Tech Stack:** clerk_flutter, google_sign_in, supabase_flutter (existing), flutter_riverpod (existing), go_router (existing), freezed (existing), Deno (Edge Functions), svix (webhook verification)

## Global Constraints

- Dark-first Material3 theme (existing `AppTheme`)
- All constants via `--dart-define` (no hardcoded keys)
- Clerk user IDs are TEXT, not UUID (matches existing `requesting_user_id()` function)
- RLS policies on `users` and `emergency_contacts` tables already exist
- Offline-first: JWT cached locally by Clerk SDK; queued writes via Drift
- ASCII-only CLI output (Windows constraint)
- UTF-8 encoding on all file I/O
- Phase 1 only: no Apple Sign-In, no biometric, no account deletion

---

## File Map

### New Files

| File | Responsibility |
|---|---|
| `app/lib/features/auth/models/auth_state.dart` | AuthStatus enum + AuthState freezed model |
| `app/lib/features/auth/services/clerk_service.dart` | Thin wrapper around clerk_flutter SDK |
| `app/lib/features/auth/providers/clerk_auth_provider.dart` | ClerkAuthNotifier — session state management |
| `app/lib/features/auth/providers/supabase_token_provider.dart` | Clerk session -> Supabase JWT token |
| `app/lib/features/auth/providers/authenticated_supabase_provider.dart` | SupabaseClient with JWT auth header |
| `app/lib/features/auth/providers/user_profile_provider.dart` | Fetch/cache own user row, isOnboarded check |
| `app/lib/features/auth/widgets/phone_input.dart` | Phone field with +91 prefix |
| `app/lib/features/auth/widgets/otp_input.dart` | 6-digit OTP code field |
| `app/lib/features/auth/widgets/social_sign_in_button.dart` | Google sign-in button |
| `app/lib/features/auth/widgets/onboarding_step.dart` | Reusable onboarding page template |
| `app/lib/features/auth/screens/sign_in_screen.dart` | Phone/email/Google sign-in |
| `app/lib/features/auth/screens/verify_screen.dart` | OTP code entry |
| `app/lib/features/auth/screens/onboarding_screen.dart` | Multi-page profile setup (PageView) |
| `backend/supabase/functions/clerk-webhook/index.ts` | Clerk webhook -> users table sync |
| `backend/supabase/migrations/00012_alter_users_nullable_dob.sql` | Make date_of_birth nullable for onboarding |
| `app/test/features/auth/models/auth_state_test.dart` | Auth model unit tests |
| `app/test/features/auth/services/clerk_service_test.dart` | Clerk service unit tests |
| `app/test/features/auth/providers/clerk_auth_provider_test.dart` | Auth provider unit tests |
| `app/test/features/auth/providers/user_profile_provider_test.dart` | Profile provider unit tests |
| `app/test/features/auth/widgets/phone_input_test.dart` | Phone input widget test |
| `app/test/features/auth/screens/sign_in_screen_test.dart` | Sign-in screen widget test |
| `app/test/core/router/app_router_test.dart` | Router redirect logic tests |

### Modified Files

| File | Changes |
|---|---|
| `app/pubspec.yaml` | Add clerk_flutter, google_sign_in, mocktail deps |
| `app/lib/core/constants/app_constants.dart` | Add `clerkPublishableKey` constant |
| `app/lib/core/network/supabase_client.dart` | Add `accessToken` callback for JWT injection |
| `app/lib/core/router/app_router.dart` | Replace scaffold route with auth-guarded router provider |
| `app/lib/main.dart` | Add Clerk initialization |
| `app/lib/app.dart` | Change to ConsumerWidget, use router provider |
| `app/lib/features/auth/models/models.dart` | Export auth_state.dart |
| `app/lib/features/auth/services/services.dart` | Export clerk_service.dart |
| `app/lib/features/auth/providers/providers.dart` | Export all auth providers |
| `app/lib/features/auth/screens/screens.dart` | Export all auth screens |
| `app/lib/features/auth/widgets/widgets.dart` | Export all auth widgets |

---

### Task 1: Auth State Model + Project Setup

**Files:**
- Modify: `app/pubspec.yaml` — add clerk_flutter, google_sign_in, mocktail
- Modify: `app/lib/core/constants/app_constants.dart` — add clerkPublishableKey
- Create: `backend/supabase/migrations/00012_alter_users_nullable_dob.sql`
- Create: `app/lib/features/auth/models/auth_state.dart`
- Modify: `app/lib/features/auth/models/models.dart` — export
- Create: `app/test/features/auth/models/auth_state_test.dart`

**Interfaces:**
- Consumes: nothing
- Produces: `AuthStatus` enum (`idle`, `identifierEntered`, `codeSent`, `verifying`, `authenticated`), `AuthState` freezed class with fields `status`, `userId`, `phone`, `email`, `errorMessage`

- [ ] **Step 1: Add dependencies to pubspec.yaml**

Add to `app/pubspec.yaml` under `dependencies:`:

```yaml
  clerk_flutter: ^0.3.0
  google_sign_in: ^6.2.2
```

Add under `dev_dependencies:`:

```yaml
  mocktail: ^1.0.4
```

- [ ] **Step 2: Run pub get**

```bash
cd app && flutter pub get
```

Expected: resolves without errors, `pubspec.lock` updated.

- [ ] **Step 3: Add Clerk constant to AppConstants**

In `app/lib/core/constants/app_constants.dart`, add after the `supabaseAnonKey` line:

```dart
  static const String clerkPublishableKey = String.fromEnvironment('CLERK_PUBLISHABLE_KEY');
```

- [ ] **Step 4: Create schema migration**

Create `backend/supabase/migrations/00012_alter_users_nullable_dob.sql`:

```sql
-- Allow NULL date_of_birth for users who haven't completed onboarding yet
-- Onboarding sets this field; its presence signals profile completion

ALTER TABLE users ALTER COLUMN date_of_birth DROP NOT NULL;
```

- [ ] **Step 5: Write the failing test for AuthState**

Create `app/test/features/auth/models/auth_state_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/auth/models/auth_state.dart';

void main() {
  group('AuthState', () {
    test('initial state has idle status', () {
      const state = AuthState();
      expect(state.status, AuthStatus.idle);
      expect(state.userId, isNull);
      expect(state.phone, isNull);
      expect(state.email, isNull);
      expect(state.errorMessage, isNull);
    });

    test('copyWith updates status', () {
      const state = AuthState();
      final updated = state.copyWith(status: AuthStatus.authenticated, userId: 'user_abc');
      expect(updated.status, AuthStatus.authenticated);
      expect(updated.userId, 'user_abc');
    });

    test('equality works', () {
      const a = AuthState(status: AuthStatus.codeSent, phone: '+911234567890');
      const b = AuthState(status: AuthStatus.codeSent, phone: '+911234567890');
      expect(a, equals(b));
    });

    test('isAuthenticated convenience getter', () {
      const idle = AuthState();
      const authed = AuthState(status: AuthStatus.authenticated, userId: 'user_1');
      expect(idle.isAuthenticated, isFalse);
      expect(authed.isAuthenticated, isTrue);
    });
  });
}
```

- [ ] **Step 6: Run test to verify it fails**

```bash
cd app && flutter test test/features/auth/models/auth_state_test.dart
```

Expected: FAIL — `auth_state.dart` does not exist.

- [ ] **Step 7: Create AuthState model**

Create `app/lib/features/auth/models/auth_state.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_state.freezed.dart';

enum AuthStatus {
  idle,
  identifierEntered,
  codeSent,
  verifying,
  authenticated,
}

@freezed
class AuthState with _$AuthState {
  const AuthState._();

  const factory AuthState({
    @Default(AuthStatus.idle) AuthStatus status,
    String? userId,
    String? phone,
    String? email,
    String? errorMessage,
  }) = _AuthState;

  bool get isAuthenticated => status == AuthStatus.authenticated;
}
```

- [ ] **Step 8: Run build_runner to generate freezed code**

```bash
cd app && dart run build_runner build --delete-conflicting-outputs
```

Expected: generates `auth_state.freezed.dart`.

- [ ] **Step 9: Update barrel export**

Replace contents of `app/lib/features/auth/models/models.dart`:

```dart
export 'auth_state.dart';
```

- [ ] **Step 10: Run test to verify it passes**

```bash
cd app && flutter test test/features/auth/models/auth_state_test.dart -v
```

Expected: all 4 tests PASS.

- [ ] **Step 11: Commit**

```bash
git add app/pubspec.yaml app/pubspec.lock app/lib/core/constants/app_constants.dart backend/supabase/migrations/00012_alter_users_nullable_dob.sql app/lib/features/auth/models/ app/test/features/auth/models/
git commit -m "feat(auth): add auth state model, dependencies, and schema migration"
```

---

### Task 2: Clerk Service

**Files:**
- Create: `app/lib/features/auth/services/clerk_service.dart`
- Modify: `app/lib/features/auth/services/services.dart` — export
- Create: `app/test/features/auth/services/clerk_service_test.dart`

**Interfaces:**
- Consumes: `clerk_flutter` SDK
- Produces: `ClerkService` class with methods: `initialize()`, `isSignedIn`, `currentSession`, `userId`, `startPhoneSignIn(phone)`, `startEmailSignIn(email)`, `verifyCode(code)`, `signInWithGoogle()`, `getSupabaseToken()`, `signOut()`; `clerkServiceProvider` Riverpod provider

- [ ] **Step 1: Write the failing test**

Create `app/test/features/auth/services/clerk_service_test.dart`:

```dart
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roadpack/features/auth/services/clerk_service.dart';

class MockClerkAuth extends Mock implements ClerkAuth {}

void main() {
  late MockClerkAuth mockClerk;
  late ClerkService service;

  setUp(() {
    mockClerk = MockClerkAuth();
    service = ClerkService(mockClerk);
  });

  group('ClerkService', () {
    test('isSignedIn returns false when no active session', () {
      when(() => mockClerk.client).thenReturn(_mockClientNoSession());
      expect(service.isSignedIn, isFalse);
    });

    test('isSignedIn returns true with active session', () {
      when(() => mockClerk.client).thenReturn(_mockClientWithSession());
      expect(service.isSignedIn, isTrue);
    });
  });
}

// Helper stubs — adjust if clerk_flutter API differs
Client _mockClientNoSession() {
  final client = _MockClient();
  when(() => client.activeSessions).thenReturn([]);
  return client;
}

Client _mockClientWithSession() {
  final client = _MockClient();
  final session = _MockSession();
  when(() => client.activeSessions).thenReturn([session]);
  return client;
}

class _MockClient extends Mock implements Client {}
class _MockSession extends Mock implements Session {}
```

> **Note to implementer:** The mock types (`Client`, `Session`, `ClerkAuth`) must match the actual `clerk_flutter` exports. Run `flutter pub get` and check the package's exported types. Adjust mock class names if the SDK uses different class names (e.g., `ClerkClient` instead of `Client`).

- [ ] **Step 2: Run test to verify it fails**

```bash
cd app && flutter test test/features/auth/services/clerk_service_test.dart
```

Expected: FAIL — `clerk_service.dart` does not exist.

- [ ] **Step 3: Create ClerkService**

Create `app/lib/features/auth/services/clerk_service.dart`:

```dart
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';

final clerkServiceProvider = Provider<ClerkService>((ref) {
  return ClerkService(
    ClerkAuth(publishableKey: AppConstants.clerkPublishableKey),
  );
});

class ClerkService {
  ClerkService(this._clerk);
  final ClerkAuth _clerk;

  ClerkAuth get clerk => _clerk;

  Future<void> initialize() async {
    await _clerk.initialize();
  }

  bool get isSignedIn => _clerk.client.activeSessions.isNotEmpty;

  Session? get currentSession =>
      _clerk.client.activeSessions.isNotEmpty
          ? _clerk.client.activeSessions.first
          : null;

  String? get userId => currentSession?.user?.id;

  SignIn? _activeSignIn;

  Future<void> startPhoneSignIn(String phone) async {
    _activeSignIn = await _clerk.client.signIn.create(
      identifier: phone,
    );
    await _activeSignIn!.prepareFirstFactor(
      strategy: Strategy.phoneCode,
    );
  }

  Future<void> startEmailSignIn(String email) async {
    _activeSignIn = await _clerk.client.signIn.create(
      identifier: email,
    );
    await _activeSignIn!.prepareFirstFactor(
      strategy: Strategy.emailCode,
    );
  }

  Future<bool> verifyCode(String code) async {
    if (_activeSignIn == null) return false;
    final result = await _activeSignIn!.attemptFirstFactor(
      strategy: _activeSignIn!.firstFactorVerification?.strategy ??
          Strategy.phoneCode,
      code: code,
    );
    final success = result.status == SignInStatus.complete;
    if (success) _activeSignIn = null;
    return success;
  }

  Future<void> signInWithGoogle() async {
    await _clerk.client.signIn.authenticateWithRedirect(
      strategy: Strategy.oauthGoogle,
    );
  }

  Future<String?> getSupabaseToken() async {
    return currentSession?.getToken(template: 'supabase');
  }

  Future<void> signOut() async {
    _activeSignIn = null;
    await _clerk.signOut();
  }
}
```

> **Note to implementer:** The `clerk_flutter` API (class names like `ClerkAuth`, `Client`, `SignIn`, `Strategy`, method signatures) is based on Clerk SDK conventions. After `flutter pub get`, check the actual package exports in your IDE autocomplete and adjust any mismatched names. The wrapper isolates these — only this file needs changes.

- [ ] **Step 4: Update barrel export**

Replace contents of `app/lib/features/auth/services/services.dart`:

```dart
export 'clerk_service.dart';
```

- [ ] **Step 5: Run test to verify it passes**

```bash
cd app && flutter test test/features/auth/services/clerk_service_test.dart -v
```

Expected: PASS. If mock types don't match clerk_flutter exports, adjust the mock classes to match the actual types.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/auth/services/ app/test/features/auth/services/
git commit -m "feat(auth): add Clerk service wrapper"
```

---

### Task 3: Auth Providers (Clerk Auth + JWT Bridge)

**Files:**
- Create: `app/lib/features/auth/providers/clerk_auth_provider.dart`
- Create: `app/lib/features/auth/providers/supabase_token_provider.dart`
- Create: `app/lib/features/auth/providers/authenticated_supabase_provider.dart`
- Modify: `app/lib/features/auth/providers/providers.dart` — export
- Create: `app/test/features/auth/providers/clerk_auth_provider_test.dart`

**Interfaces:**
- Consumes: `ClerkService` (from Task 2), `AppConstants` (supabaseUrl, supabaseAnonKey)
- Produces: `clerkAuthProvider` (AsyncNotifierProvider exposing `AuthState`), `supabaseTokenProvider` (FutureProvider<String?>), `authenticatedSupabaseProvider` (Provider<SupabaseClient>)

- [ ] **Step 1: Write the failing test**

Create `app/test/features/auth/providers/clerk_auth_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roadpack/features/auth/models/auth_state.dart';
import 'package:roadpack/features/auth/providers/clerk_auth_provider.dart';
import 'package:roadpack/features/auth/services/clerk_service.dart';

class MockClerkService extends Mock implements ClerkService {}

void main() {
  late ProviderContainer container;
  late MockClerkService mockService;

  setUp(() {
    mockService = MockClerkService();
    container = ProviderContainer(
      overrides: [
        clerkServiceProvider.overrideWithValue(mockService),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('ClerkAuthNotifier', () {
    test('initial state checks existing session — not signed in', () async {
      when(() => mockService.isSignedIn).thenReturn(false);

      final state = await container.read(clerkAuthProvider.future);
      expect(state.status, AuthStatus.idle);
      expect(state.isAuthenticated, isFalse);
    });

    test('initial state checks existing session — already signed in', () async {
      when(() => mockService.isSignedIn).thenReturn(true);
      when(() => mockService.userId).thenReturn('user_abc');

      final state = await container.read(clerkAuthProvider.future);
      expect(state.status, AuthStatus.authenticated);
      expect(state.userId, 'user_abc');
    });

    test('startPhoneSignIn transitions to codeSent', () async {
      when(() => mockService.isSignedIn).thenReturn(false);
      when(() => mockService.startPhoneSignIn(any())).thenAnswer((_) async {});

      await container.read(clerkAuthProvider.future);
      final notifier = container.read(clerkAuthProvider.notifier);
      await notifier.startPhoneSignIn('+911234567890');

      final state = container.read(clerkAuthProvider).value!;
      expect(state.status, AuthStatus.codeSent);
      expect(state.phone, '+911234567890');
    });

    test('verifyCode transitions to authenticated on success', () async {
      when(() => mockService.isSignedIn).thenReturn(false);
      when(() => mockService.startPhoneSignIn(any())).thenAnswer((_) async {});
      when(() => mockService.verifyCode(any())).thenAnswer((_) async => true);
      when(() => mockService.userId).thenReturn('user_xyz');

      await container.read(clerkAuthProvider.future);
      final notifier = container.read(clerkAuthProvider.notifier);
      await notifier.startPhoneSignIn('+911234567890');
      await notifier.verifyCode('123456');

      final state = container.read(clerkAuthProvider).value!;
      expect(state.status, AuthStatus.authenticated);
      expect(state.userId, 'user_xyz');
    });

    test('verifyCode sets error on failure', () async {
      when(() => mockService.isSignedIn).thenReturn(false);
      when(() => mockService.startPhoneSignIn(any())).thenAnswer((_) async {});
      when(() => mockService.verifyCode(any())).thenAnswer((_) async => false);

      await container.read(clerkAuthProvider.future);
      final notifier = container.read(clerkAuthProvider.notifier);
      await notifier.startPhoneSignIn('+911234567890');
      await notifier.verifyCode('000000');

      final state = container.read(clerkAuthProvider).value!;
      expect(state.status, AuthStatus.codeSent);
      expect(state.errorMessage, isNotNull);
    });

    test('signOut transitions back to idle', () async {
      when(() => mockService.isSignedIn).thenReturn(true);
      when(() => mockService.userId).thenReturn('user_abc');
      when(() => mockService.signOut()).thenAnswer((_) async {});

      await container.read(clerkAuthProvider.future);
      final notifier = container.read(clerkAuthProvider.notifier);
      await notifier.signOut();

      final state = container.read(clerkAuthProvider).value!;
      expect(state.status, AuthStatus.idle);
      expect(state.userId, isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd app && flutter test test/features/auth/providers/clerk_auth_provider_test.dart
```

Expected: FAIL — provider file does not exist.

- [ ] **Step 3: Create ClerkAuthNotifier provider**

Create `app/lib/features/auth/providers/clerk_auth_provider.dart`:

```dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auth_state.dart';
import '../services/clerk_service.dart';

final clerkAuthProvider =
    AsyncNotifierProvider<ClerkAuthNotifier, AuthState>(ClerkAuthNotifier.new);

class ClerkAuthNotifier extends AsyncNotifier<AuthState> {
  ClerkService get _service => ref.read(clerkServiceProvider);

  @override
  Future<AuthState> build() async {
    if (_service.isSignedIn) {
      return AuthState(
        status: AuthStatus.authenticated,
        userId: _service.userId,
      );
    }
    return const AuthState();
  }

  Future<void> startPhoneSignIn(String phone) async {
    state = AsyncData(
      state.value!.copyWith(
        status: AuthStatus.identifierEntered,
        phone: phone,
        errorMessage: null,
      ),
    );
    try {
      await _service.startPhoneSignIn(phone);
      state = AsyncData(
        state.value!.copyWith(status: AuthStatus.codeSent),
      );
    } on Exception catch (e) {
      state = AsyncData(
        state.value!.copyWith(
          status: AuthStatus.idle,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> startEmailSignIn(String email) async {
    state = AsyncData(
      state.value!.copyWith(
        status: AuthStatus.identifierEntered,
        email: email,
        errorMessage: null,
      ),
    );
    try {
      await _service.startEmailSignIn(email);
      state = AsyncData(
        state.value!.copyWith(status: AuthStatus.codeSent),
      );
    } on Exception catch (e) {
      state = AsyncData(
        state.value!.copyWith(
          status: AuthStatus.idle,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> verifyCode(String code) async {
    state = AsyncData(
      state.value!.copyWith(
        status: AuthStatus.verifying,
        errorMessage: null,
      ),
    );
    try {
      final success = await _service.verifyCode(code);
      if (success) {
        state = AsyncData(
          AuthState(
            status: AuthStatus.authenticated,
            userId: _service.userId,
            phone: state.value!.phone,
            email: state.value!.email,
          ),
        );
      } else {
        state = AsyncData(
          state.value!.copyWith(
            status: AuthStatus.codeSent,
            errorMessage: 'Invalid code, try again',
          ),
        );
      }
    } on Exception catch (e) {
      state = AsyncData(
        state.value!.copyWith(
          status: AuthStatus.codeSent,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      await _service.signInWithGoogle();
      state = AsyncData(
        AuthState(
          status: AuthStatus.authenticated,
          userId: _service.userId,
        ),
      );
    } on Exception catch (e) {
      state = AsyncData(
        state.value!.copyWith(errorMessage: e.toString()),
      );
    }
  }

  Future<void> signOut() async {
    await _service.signOut();
    state = const AsyncData(AuthState());
  }
}
```

- [ ] **Step 4: Create Supabase token provider**

Create `app/lib/features/auth/providers/supabase_token_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/clerk_service.dart';
import 'clerk_auth_provider.dart';

final supabaseTokenProvider = FutureProvider<String?>((ref) async {
  final authState = ref.watch(clerkAuthProvider).valueOrNull;
  if (authState == null || !authState.isAuthenticated) return null;

  final service = ref.read(clerkServiceProvider);
  return service.getSupabaseToken();
});
```

- [ ] **Step 5: Create authenticated Supabase provider**

Create `app/lib/features/auth/providers/authenticated_supabase_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../services/clerk_service.dart';
import 'clerk_auth_provider.dart';

final authenticatedSupabaseProvider = Provider<SupabaseClient?>((ref) {
  final authState = ref.watch(clerkAuthProvider).valueOrNull;
  if (authState == null || !authState.isAuthenticated) return null;

  final service = ref.read(clerkServiceProvider);

  return SupabaseClient(
    AppConstants.supabaseUrl,
    AppConstants.supabaseAnonKey,
    accessToken: () async {
      final token = await service.getSupabaseToken();
      if (token == null) throw Exception('No Supabase token available');
      return token;
    },
  );
});
```

- [ ] **Step 6: Update barrel export**

Replace contents of `app/lib/features/auth/providers/providers.dart`:

```dart
export 'authenticated_supabase_provider.dart';
export 'clerk_auth_provider.dart';
export 'supabase_token_provider.dart';
```

- [ ] **Step 7: Run test to verify it passes**

```bash
cd app && flutter test test/features/auth/providers/clerk_auth_provider_test.dart -v
```

Expected: all 6 tests PASS.

- [ ] **Step 8: Commit**

```bash
git add app/lib/features/auth/providers/ app/test/features/auth/providers/clerk_auth_provider_test.dart
git commit -m "feat(auth): add Clerk auth, Supabase token, and authenticated client providers"
```

---

### Task 4: User Profile Provider

**Files:**
- Create: `app/lib/features/auth/providers/user_profile_provider.dart`
- Modify: `app/lib/features/auth/providers/providers.dart` — add export
- Create: `app/test/features/auth/providers/user_profile_provider_test.dart`

**Interfaces:**
- Consumes: `authenticatedSupabaseProvider` (from Task 3), `clerkAuthProvider` (from Task 3)
- Produces: `userProfileProvider` (AsyncNotifierProvider) exposing `UserProfile` with fields `userId`, `name`, `dateOfBirth`, `vehicleType`, `vehicleReg`, `isOnboarded`; methods `fetchProfile()`, `updateName(name)`, `updateDateOfBirth(dob)`, `updateVehicle(type, reg)`, `addEmergencyContact(name, phone, relationship)`

- [ ] **Step 1: Write the failing test**

Create `app/test/features/auth/providers/user_profile_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roadpack/features/auth/models/auth_state.dart';
import 'package:roadpack/features/auth/providers/authenticated_supabase_provider.dart';
import 'package:roadpack/features/auth/providers/clerk_auth_provider.dart';
import 'package:roadpack/features/auth/providers/user_profile_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  group('UserProfile', () {
    test('isOnboarded is false when dateOfBirth is null', () {
      const profile = UserProfile(userId: 'u1', name: 'Test');
      expect(profile.isOnboarded, isFalse);
    });

    test('isOnboarded is true when dateOfBirth is set', () {
      final profile = UserProfile(
        userId: 'u1',
        name: 'Test',
        dateOfBirth: DateTime(2000, 1, 1),
      );
      expect(profile.isOnboarded, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd app && flutter test test/features/auth/providers/user_profile_provider_test.dart
```

Expected: FAIL — `user_profile_provider.dart` does not exist.

- [ ] **Step 3: Create UserProfileProvider**

Create `app/lib/features/auth/providers/user_profile_provider.dart`:

```dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'authenticated_supabase_provider.dart';
import 'clerk_auth_provider.dart';

class UserProfile {
  const UserProfile({
    required this.userId,
    this.name,
    this.dateOfBirth,
    this.vehicleType,
    this.vehicleReg,
  });

  final String userId;
  final String? name;
  final DateTime? dateOfBirth;
  final String? vehicleType;
  final String? vehicleReg;

  bool get isOnboarded => dateOfBirth != null;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['id'] as String,
      name: json['name'] as String?,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'] as String)
          : null,
      vehicleType: json['vehicle_type'] as String?,
      vehicleReg: json['vehicle_reg'] as String?,
    );
  }
}

final userProfileProvider =
    AsyncNotifierProvider<UserProfileNotifier, UserProfile?>(
        UserProfileNotifier.new);

class UserProfileNotifier extends AsyncNotifier<UserProfile?> {
  SupabaseClient? get _supabase => ref.read(authenticatedSupabaseProvider);

  @override
  Future<UserProfile?> build() async {
    final authState = ref.watch(clerkAuthProvider).valueOrNull;
    if (authState == null || !authState.isAuthenticated) return null;

    return _fetchWithRetry(authState.userId!);
  }

  Future<UserProfile> _fetchWithRetry(String userId) async {
    const delays = [
      Duration(milliseconds: 500),
      Duration(seconds: 1),
      Duration(seconds: 2),
    ];

    for (var i = 0; i <= delays.length; i++) {
      final response = await _supabase!
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        return UserProfile.fromJson(response);
      }

      if (i < delays.length) {
        await Future.delayed(delays[i]);
      }
    }

    // Fallback: create row from client side
    await _supabase!.from('users').insert({
      'id': userId,
      'phone': '',
      'name': '',
    });

    return UserProfile(userId: userId);
  }

  Future<void> updateName(String name) async {
    final userId = state.value?.userId;
    if (userId == null) return;

    await _supabase!.from('users').update({'name': name}).eq('id', userId);
    state = AsyncData(
      UserProfile(
        userId: userId,
        name: name,
        dateOfBirth: state.value?.dateOfBirth,
        vehicleType: state.value?.vehicleType,
        vehicleReg: state.value?.vehicleReg,
      ),
    );
  }

  Future<void> updateDateOfBirth(DateTime dob) async {
    final userId = state.value?.userId;
    if (userId == null) return;

    await _supabase!
        .from('users')
        .update({'date_of_birth': dob.toIso8601String().split('T').first})
        .eq('id', userId);
    state = AsyncData(
      UserProfile(
        userId: userId,
        name: state.value?.name,
        dateOfBirth: dob,
        vehicleType: state.value?.vehicleType,
        vehicleReg: state.value?.vehicleReg,
      ),
    );
  }

  Future<void> updateVehicle(String? type, String? reg) async {
    final userId = state.value?.userId;
    if (userId == null) return;

    await _supabase!
        .from('users')
        .update({'vehicle_type': type, 'vehicle_reg': reg})
        .eq('id', userId);
    state = AsyncData(
      UserProfile(
        userId: userId,
        name: state.value?.name,
        dateOfBirth: state.value?.dateOfBirth,
        vehicleType: type,
        vehicleReg: reg,
      ),
    );
  }

  Future<void> addEmergencyContact({
    required String name,
    required String phone,
    required String relationship,
  }) async {
    final userId = state.value?.userId;
    if (userId == null) return;

    await _supabase!.from('emergency_contacts').insert({
      'user_id': userId,
      'name': name,
      'phone': phone,
      'relationship': relationship,
      'priority': 1,
    });
  }
}
```

- [ ] **Step 4: Update barrel export**

Add to `app/lib/features/auth/providers/providers.dart`:

```dart
export 'user_profile_provider.dart';
```

Full file:

```dart
export 'authenticated_supabase_provider.dart';
export 'clerk_auth_provider.dart';
export 'supabase_token_provider.dart';
export 'user_profile_provider.dart';
```

- [ ] **Step 5: Run test to verify it passes**

```bash
cd app && flutter test test/features/auth/providers/user_profile_provider_test.dart -v
```

Expected: 2 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/auth/providers/ app/test/features/auth/providers/user_profile_provider_test.dart
git commit -m "feat(auth): add user profile provider with retry and onboarding check"
```

---

### Task 5: Auth Widgets

**Files:**
- Create: `app/lib/features/auth/widgets/phone_input.dart`
- Create: `app/lib/features/auth/widgets/otp_input.dart`
- Create: `app/lib/features/auth/widgets/social_sign_in_button.dart`
- Create: `app/lib/features/auth/widgets/onboarding_step.dart`
- Modify: `app/lib/features/auth/widgets/widgets.dart` — export
- Create: `app/test/features/auth/widgets/phone_input_test.dart`

**Interfaces:**
- Consumes: `AppColors` (from core/theme)
- Produces: `PhoneInput` widget (onSubmit callback with formatted phone), `OtpInput` widget (onCompleted callback with 6-digit code), `SocialSignInButton` widget (onPressed callback), `OnboardingStep` widget (title, subtitle, child, onNext)

- [ ] **Step 1: Write the failing widget test**

Create `app/test/features/auth/widgets/phone_input_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/auth/widgets/phone_input.dart';

void main() {
  group('PhoneInput', () {
    testWidgets('shows +91 prefix', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PhoneInput(onSubmit: (_) {}),
          ),
        ),
      );
      expect(find.text('+91'), findsOneWidget);
    });

    testWidgets('calls onSubmit with prefixed phone number', (tester) async {
      String? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PhoneInput(onSubmit: (phone) => submitted = phone),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '9876543210');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(submitted, '+919876543210');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd app && flutter test test/features/auth/widgets/phone_input_test.dart
```

Expected: FAIL — `phone_input.dart` does not exist.

- [ ] **Step 3: Create PhoneInput widget**

Create `app/lib/features/auth/widgets/phone_input.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PhoneInput extends StatefulWidget {
  const PhoneInput({super.key, required this.onSubmit, this.errorText});

  final ValueChanged<String> onSubmit;
  final String? errorText;

  @override
  State<PhoneInput> createState() => _PhoneInputState();
}

class _PhoneInputState extends State<PhoneInput> {
  final _controller = TextEditingController();
  static const _prefix = '+91';

  void _submit() {
    final digits = _controller.text.trim();
    if (digits.length == 10) {
      widget.onSubmit('$_prefix$digits');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: TextInputType.phone,
      maxLength: 10,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onSubmitted: (_) => _submit(),
      decoration: InputDecoration(
        prefixIcon: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('+91', style: TextStyle(fontSize: 16)),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        hintText: 'Phone number',
        counterText: '',
        errorText: widget.errorText,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
```

- [ ] **Step 4: Create OtpInput widget**

Create `app/lib/features/auth/widgets/otp_input.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    required this.onCompleted,
    this.errorText,
    this.length = 6,
  });

  final ValueChanged<String> onCompleted;
  final String? errorText;
  final int length;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onChanged(int index, String value) {
    if (value.isNotEmpty && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    final code = _controllers.map((c) => c.text).join();
    if (code.length == widget.length) {
      widget.onCompleted(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(widget.length, (i) {
            return SizedBox(
              width: 44,
              child: TextField(
                controller: _controllers[i],
                focusNode: _focusNodes[i],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) => _onChanged(i, v),
                decoration: const InputDecoration(
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
              ),
            );
          }),
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.errorText!,
            style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
          ),
        ],
      ],
    );
  }
}
```

- [ ] **Step 5: Create SocialSignInButton widget**

Create `app/lib/features/auth/widgets/social_sign_in_button.dart`:

```dart
import 'package:flutter/material.dart';

class SocialSignInButton extends StatelessWidget {
  const SocialSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  final VoidCallback onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.g_mobiledata, size: 24),
      label: const Text('Continue with Google'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
```

- [ ] **Step 6: Create OnboardingStep widget**

Create `app/lib/features/auth/widgets/onboarding_step.dart`:

```dart
import 'package:flutter/material.dart';

class OnboardingStep extends StatelessWidget {
  const OnboardingStep({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    required this.onNext,
    this.nextLabel = 'Continue',
    this.showSkip = false,
    this.onSkip,
    this.isLoading = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final VoidCallback onNext;
  final String nextLabel;
  final bool showSkip;
  final VoidCallback? onSkip;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: Theme.of(context).textTheme.bodyLarge),
          ],
          const SizedBox(height: 32),
          Expanded(child: child),
          FilledButton(
            onPressed: isLoading ? null : onNext,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(nextLabel),
          ),
          if (showSkip) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: onSkip,
                child: const Text('Skip for now'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: Update barrel export**

Replace contents of `app/lib/features/auth/widgets/widgets.dart`:

```dart
export 'onboarding_step.dart';
export 'otp_input.dart';
export 'phone_input.dart';
export 'social_sign_in_button.dart';
```

- [ ] **Step 8: Run tests to verify they pass**

```bash
cd app && flutter test test/features/auth/widgets/phone_input_test.dart -v
```

Expected: 2 tests PASS.

- [ ] **Step 9: Commit**

```bash
git add app/lib/features/auth/widgets/ app/test/features/auth/widgets/
git commit -m "feat(auth): add phone input, OTP input, social button, and onboarding step widgets"
```

---

### Task 6: Sign-In + Verify Screens

**Files:**
- Create: `app/lib/features/auth/screens/sign_in_screen.dart`
- Create: `app/lib/features/auth/screens/verify_screen.dart`
- Modify: `app/lib/features/auth/screens/screens.dart` — export
- Create: `app/test/features/auth/screens/sign_in_screen_test.dart`

**Interfaces:**
- Consumes: `clerkAuthProvider` (Task 3), `PhoneInput`, `OtpInput`, `SocialSignInButton` (Task 5)
- Produces: `SignInScreen` widget (phone/email/Google entry), `VerifyScreen` widget (OTP code entry)

- [ ] **Step 1: Write the failing widget test**

Create `app/test/features/auth/screens/sign_in_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/auth/models/auth_state.dart';
import 'package:roadpack/features/auth/providers/clerk_auth_provider.dart';
import 'package:roadpack/features/auth/screens/sign_in_screen.dart';

void main() {
  group('SignInScreen', () {
    testWidgets('renders phone input by default', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clerkAuthProvider.overrideWith(() => _IdleAuthNotifier()),
          ],
          child: const MaterialApp(home: SignInScreen()),
        ),
      );
      expect(find.text('+91'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('can switch to email input', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clerkAuthProvider.overrideWith(() => _IdleAuthNotifier()),
          ],
          child: const MaterialApp(home: SignInScreen()),
        ),
      );
      await tester.tap(find.text('Use email instead'));
      await tester.pump();
      expect(find.text('Email address'), findsOneWidget);
    });
  });
}

class _IdleAuthNotifier extends AsyncNotifier<AuthState>
    implements ClerkAuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState();
  @override
  Future<void> startPhoneSignIn(String phone) async {}
  @override
  Future<void> startEmailSignIn(String email) async {}
  @override
  Future<void> verifyCode(String code) async {}
  @override
  Future<void> signInWithGoogle() async {}
  @override
  Future<void> signOut() async {}
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd app && flutter test test/features/auth/screens/sign_in_screen_test.dart
```

Expected: FAIL — `sign_in_screen.dart` does not exist.

- [ ] **Step 3: Create SignInScreen**

Create `app/lib/features/auth/screens/sign_in_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auth_state.dart';
import '../providers/clerk_auth_provider.dart';
import '../widgets/phone_input.dart';
import '../widgets/social_sign_in_button.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _useEmail = false;
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(clerkAuthProvider).valueOrNull ?? const AuthState();
    final isLoading = authState.status == AuthStatus.identifierEntered;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 64),
              Text(
                'Welcome to RoadPack',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to stay safe on the road',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 48),
              if (_useEmail)
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  onSubmitted: (_) => _submitEmail(),
                  decoration: InputDecoration(
                    hintText: 'Email address',
                    errorText: authState.errorMessage,
                    border: const OutlineInputBorder(),
                    suffixIcon: isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.arrow_forward),
                            onPressed: _submitEmail,
                          ),
                  ),
                )
              else
                PhoneInput(
                  onSubmit: _submitPhone,
                  errorText: authState.errorMessage,
                ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _useEmail = !_useEmail),
                  child: Text(_useEmail ? 'Use phone instead' : 'Use email instead'),
                ),
              ),
              const Spacer(),
              const Divider(),
              const SizedBox(height: 16),
              SocialSignInButton(
                onPressed: () => ref.read(clerkAuthProvider.notifier).signInWithGoogle(),
                isLoading: isLoading,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _submitPhone(String phone) {
    ref.read(clerkAuthProvider.notifier).startPhoneSignIn(phone);
  }

  void _submitEmail() {
    final email = _emailController.text.trim();
    if (email.isNotEmpty) {
      ref.read(clerkAuthProvider.notifier).startEmailSignIn(email);
    }
  }
}
```

- [ ] **Step 4: Create VerifyScreen**

Create `app/lib/features/auth/screens/verify_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auth_state.dart';
import '../providers/clerk_auth_provider.dart';
import '../widgets/otp_input.dart';

class VerifyScreen extends ConsumerWidget {
  const VerifyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(clerkAuthProvider).valueOrNull ?? const AuthState();
    final isVerifying = authState.status == AuthStatus.verifying;
    final identifier = authState.phone ?? authState.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Verify')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                'Enter verification code',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Code sent to $identifier',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              if (isVerifying)
                const Center(child: CircularProgressIndicator())
              else
                OtpInput(
                  onCompleted: (code) =>
                      ref.read(clerkAuthProvider.notifier).verifyCode(code),
                  errorText: authState.errorMessage,
                ),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: isVerifying
                      ? null
                      : () {
                          if (authState.phone != null) {
                            ref
                                .read(clerkAuthProvider.notifier)
                                .startPhoneSignIn(authState.phone!);
                          } else if (authState.email != null) {
                            ref
                                .read(clerkAuthProvider.notifier)
                                .startEmailSignIn(authState.email!);
                          }
                        },
                  child: const Text('Resend code'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Update barrel export**

Replace contents of `app/lib/features/auth/screens/screens.dart`:

```dart
export 'onboarding_screen.dart';
export 'sign_in_screen.dart';
export 'verify_screen.dart';
```

> **Note:** `onboarding_screen.dart` doesn't exist yet (Task 7). Remove that export line now; re-add it in Task 7. Or create a placeholder file to avoid compile errors. Recommended: only export existing files now:

```dart
export 'sign_in_screen.dart';
export 'verify_screen.dart';
```

- [ ] **Step 6: Run test to verify it passes**

```bash
cd app && flutter test test/features/auth/screens/sign_in_screen_test.dart -v
```

Expected: 2 tests PASS.

- [ ] **Step 7: Commit**

```bash
git add app/lib/features/auth/screens/ app/test/features/auth/screens/
git commit -m "feat(auth): add sign-in and OTP verification screens"
```

---

### Task 7: Onboarding Screen

**Files:**
- Create: `app/lib/features/auth/screens/onboarding_screen.dart`
- Modify: `app/lib/features/auth/screens/screens.dart` — add export
- Create: `app/test/features/auth/screens/onboarding_screen_test.dart`

**Interfaces:**
- Consumes: `userProfileProvider` (Task 4), `OnboardingStep` widget (Task 5)
- Produces: `OnboardingScreen` widget — 4-page PageView (name, DOB, vehicle, emergency contact)

- [ ] **Step 1: Write the failing widget test**

Create `app/test/features/auth/screens/onboarding_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/auth/providers/user_profile_provider.dart';
import 'package:roadpack/features/auth/screens/onboarding_screen.dart';

void main() {
  group('OnboardingScreen', () {
    testWidgets('shows name page first', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith(() => _TestProfileNotifier()),
          ],
          child: const MaterialApp(home: OnboardingScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('What should we call you?'), findsOneWidget);
    });
  });
}

class _TestProfileNotifier extends AsyncNotifier<UserProfile?>
    implements UserProfileNotifier {
  @override
  Future<UserProfile?> build() async =>
      const UserProfile(userId: 'u1', name: 'Test');
  @override
  Future<void> updateName(String name) async {}
  @override
  Future<void> updateDateOfBirth(DateTime dob) async {}
  @override
  Future<void> updateVehicle(String? type, String? reg) async {}
  @override
  Future<void> addEmergencyContact({
    required String name,
    required String phone,
    required String relationship,
  }) async {}
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd app && flutter test test/features/auth/screens/onboarding_screen_test.dart
```

Expected: FAIL — `onboarding_screen.dart` does not exist.

- [ ] **Step 3: Create OnboardingScreen**

Create `app/lib/features/auth/screens/onboarding_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_profile_provider.dart';
import '../widgets/onboarding_step.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  final _nameController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _contactRelationController = TextEditingController();

  DateTime? _selectedDob;
  String _vehicleType = 'none';
  final _vehicleRegController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile?.name != null && profile!.name!.isNotEmpty) {
      _nameController.text = profile.name!;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _contactRelationController.dispose();
    _vehicleRegController.dispose();
    super.dispose();
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildNamePage(),
            _buildDobPage(),
            _buildVehiclePage(),
            _buildEmergencyContactPage(),
          ],
        ),
      ),
    );
  }

  Widget _buildNamePage() {
    return OnboardingStep(
      title: 'What should we call you?',
      child: TextField(
        controller: _nameController,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          hintText: 'Your name',
          border: OutlineInputBorder(),
        ),
      ),
      onNext: () async {
        final name = _nameController.text.trim();
        if (name.length < 2) return;
        setState(() => _isLoading = true);
        await ref.read(userProfileProvider.notifier).updateName(name);
        setState(() => _isLoading = false);
        _nextPage();
      },
      isLoading: _isLoading,
    );
  }

  Widget _buildDobPage() {
    return OnboardingStep(
      title: 'Date of birth',
      subtitle: 'Needed for safety features',
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selectedDob != null
                  ? '${_selectedDob!.day}/${_selectedDob!.month}/${_selectedDob!.year}'
                  : 'Tap to select',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime(now.year - 18),
                  firstDate: DateTime(now.year - 100),
                  lastDate: now,
                );
                if (picked != null) setState(() => _selectedDob = picked);
              },
              child: const Text('Select date'),
            ),
          ],
        ),
      ),
      onNext: () async {
        if (_selectedDob == null) return;
        setState(() => _isLoading = true);
        await ref.read(userProfileProvider.notifier).updateDateOfBirth(_selectedDob!);
        setState(() => _isLoading = false);
        _nextPage();
      },
      isLoading: _isLoading,
    );
  }

  Widget _buildVehiclePage() {
    return OnboardingStep(
      title: 'Your vehicle',
      subtitle: 'Affects crash detection sensitivity',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            value: _vehicleType,
            items: const [
              DropdownMenuItem(value: 'none', child: Text('No vehicle')),
              DropdownMenuItem(value: 'two_wheeler', child: Text('Two wheeler')),
              DropdownMenuItem(value: 'four_wheeler', child: Text('Four wheeler')),
            ],
            onChanged: (v) => setState(() => _vehicleType = v ?? 'none'),
            decoration: const InputDecoration(
              labelText: 'Vehicle type',
              border: OutlineInputBorder(),
            ),
          ),
          if (_vehicleType != 'none') ...[
            const SizedBox(height: 16),
            TextField(
              controller: _vehicleRegController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'Registration number (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ],
      ),
      onNext: () async {
        setState(() => _isLoading = true);
        final type = _vehicleType == 'none' ? null : _vehicleType;
        final reg = _vehicleRegController.text.trim();
        await ref
            .read(userProfileProvider.notifier)
            .updateVehicle(type, reg.isEmpty ? null : reg);
        setState(() => _isLoading = false);
        _nextPage();
      },
      isLoading: _isLoading,
    );
  }

  Widget _buildEmergencyContactPage() {
    return OnboardingStep(
      title: 'Emergency contact',
      subtitle: 'This person will be contacted if something happens to you on the road',
      showSkip: true,
      onSkip: () => _finishOnboarding(),
      child: Column(
        children: [
          TextField(
            controller: _contactNameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Contact name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contactPhoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              hintText: 'Phone number',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contactRelationController,
            decoration: const InputDecoration(
              hintText: 'Relationship (e.g., spouse, parent)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      onNext: () async {
        final name = _contactNameController.text.trim();
        final phone = _contactPhoneController.text.trim();
        final relation = _contactRelationController.text.trim();
        if (name.isEmpty || phone.isEmpty) return;
        setState(() => _isLoading = true);
        await ref.read(userProfileProvider.notifier).addEmergencyContact(
              name: name,
              phone: phone,
              relationship: relation,
            );
        setState(() => _isLoading = false);
        _finishOnboarding();
      },
      nextLabel: 'Finish',
      isLoading: _isLoading,
    );
  }

  void _finishOnboarding() {
    // Router redirect will handle navigation to /home
    // since profile is now onboarded (DOB is set)
    ref.invalidate(userProfileProvider);
  }
}
```

- [ ] **Step 4: Update barrel export**

Replace contents of `app/lib/features/auth/screens/screens.dart`:

```dart
export 'onboarding_screen.dart';
export 'sign_in_screen.dart';
export 'verify_screen.dart';
```

- [ ] **Step 5: Run test to verify it passes**

```bash
cd app && flutter test test/features/auth/screens/onboarding_screen_test.dart -v
```

Expected: 1 test PASS.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/auth/screens/ app/test/features/auth/screens/onboarding_screen_test.dart
git commit -m "feat(auth): add multi-page onboarding screen"
```

---

### Task 8: Router Auth Guards + App Integration

**Files:**
- Modify: `app/lib/core/router/app_router.dart` — replace with auth-guarded router provider
- Modify: `app/lib/core/network/supabase_client.dart` — no changes needed (authenticated client is a separate provider in Task 3)
- Modify: `app/lib/main.dart` — add Clerk initialization
- Modify: `app/lib/app.dart` — change to ConsumerWidget, use router provider
- Create: `app/test/core/router/app_router_test.dart`

**Interfaces:**
- Consumes: `clerkAuthProvider` (Task 3), `userProfileProvider` (Task 4), `clerkServiceProvider` (Task 2), all screens (Tasks 6-7)
- Produces: `appRouterProvider` (Provider<GoRouter>) with auth redirect logic, `AuthChangeNotifier` bridge for GoRouter refreshListenable

- [ ] **Step 1: Write the failing router redirect test**

Create `app/test/core/router/app_router_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/core/router/app_router.dart';

void main() {
  group('authRedirect', () {
    test('unauthenticated + non-auth route -> /sign-in', () {
      final result = authRedirect(
        isAuthenticated: false,
        isOnboarded: false,
        location: '/home',
      );
      expect(result, '/sign-in');
    });

    test('authenticated + auth route + onboarded -> /home', () {
      final result = authRedirect(
        isAuthenticated: true,
        isOnboarded: true,
        location: '/sign-in',
      );
      expect(result, '/home');
    });

    test('authenticated + auth route + not onboarded -> /onboarding', () {
      final result = authRedirect(
        isAuthenticated: true,
        isOnboarded: false,
        location: '/sign-in',
      );
      expect(result, '/onboarding');
    });

    test('authenticated + not onboarded + non-onboarding route -> /onboarding', () {
      final result = authRedirect(
        isAuthenticated: true,
        isOnboarded: false,
        location: '/home',
      );
      expect(result, '/onboarding');
    });

    test('authenticated + onboarded + home route -> null (no redirect)', () {
      final result = authRedirect(
        isAuthenticated: true,
        isOnboarded: true,
        location: '/home',
      );
      expect(result, isNull);
    });

    test('unauthenticated + sign-in route -> null (no redirect)', () {
      final result = authRedirect(
        isAuthenticated: false,
        isOnboarded: false,
        location: '/sign-in',
      );
      expect(result, isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd app && flutter test test/core/router/app_router_test.dart
```

Expected: FAIL — `authRedirect` function does not exist.

- [ ] **Step 3: Rewrite app_router.dart with auth guards**

Replace contents of `app/lib/core/router/app_router.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/models/auth_state.dart';
import '../../features/auth/providers/clerk_auth_provider.dart';
import '../../features/auth/providers/user_profile_provider.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/sign_in_screen.dart';
import '../../features/auth/screens/verify_screen.dart';

String? authRedirect({
  required bool isAuthenticated,
  required bool isOnboarded,
  required String location,
}) {
  final isAuthRoute =
      location.startsWith('/sign-in') || location.startsWith('/verify');
  final isOnboardingRoute = location == '/onboarding';

  if (!isAuthenticated && !isAuthRoute) return '/sign-in';
  if (isAuthenticated && isAuthRoute) {
    return isOnboarded ? '/home' : '/onboarding';
  }
  if (isAuthenticated && !isOnboarded && !isOnboardingRoute) return '/onboarding';
  return null;
}

class AuthChangeNotifier extends ChangeNotifier {
  AuthChangeNotifier(this._ref) {
    _ref.listen(clerkAuthProvider, (_, __) => notifyListeners());
    _ref.listen(userProfileProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = AuthChangeNotifier(ref);

  return GoRouter(
    initialLocation: '/sign-in',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authState =
          ref.read(clerkAuthProvider).valueOrNull ?? const AuthState();
      final profile = ref.read(userProfileProvider).valueOrNull;

      return authRedirect(
        isAuthenticated: authState.isAuthenticated,
        isOnboarded: profile?.isOnboarded ?? false,
        location: state.matchedLocation,
      );
    },
    routes: [
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/verify',
        builder: (context, state) => const VerifyScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('RoadPack v2')),
        ),
      ),
    ],
  );
});
```

- [ ] **Step 4: Update main.dart — add Clerk initialization**

Replace contents of `app/lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/core.dart';
import 'features/auth/services/clerk_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConstants.supabaseUrl.isNotEmpty) {
    await initSupabase();
  }

  final container = ProviderContainer();
  if (AppConstants.clerkPublishableKey.isNotEmpty) {
    await container.read(clerkServiceProvider).initialize();
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const App(),
    ),
  );
}
```

- [ ] **Step 5: Update app.dart — use router provider**

Replace contents of `app/lib/app.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/core.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('hi'),
        Locale('ml'),
      ],
    );
  }
}
```

- [ ] **Step 6: Run router tests**

```bash
cd app && flutter test test/core/router/app_router_test.dart -v
```

Expected: all 6 tests PASS.

- [ ] **Step 7: Verify the full app compiles**

```bash
cd app && flutter analyze
```

Expected: no errors (warnings acceptable).

- [ ] **Step 8: Commit**

```bash
git add app/lib/core/router/app_router.dart app/lib/main.dart app/lib/app.dart app/test/core/router/
git commit -m "feat(auth): add router auth guards, Clerk init, and app integration"
```

---

### Task 9: Clerk Webhook Edge Function

**Files:**
- Create: `backend/supabase/functions/clerk-webhook/index.ts`

**Interfaces:**
- Consumes: Clerk webhook events (`user.created`, `user.updated`), Svix signature verification
- Produces: Upserts `users` table rows via Supabase service role client

- [ ] **Step 1: Create the webhook handler**

Create `backend/supabase/functions/clerk-webhook/index.ts`:

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface WebhookEvent {
  type: string
  data: {
    id: string
    first_name?: string | null
    last_name?: string | null
    phone_numbers?: Array<{ phone_number: string }>
    email_addresses?: Array<{ email_address: string }>
  }
}

async function verifyWebhookSignature(
  payload: string,
  headers: Headers,
  secret: string,
): Promise<boolean> {
  const svixId = headers.get('svix-id')
  const svixTimestamp = headers.get('svix-timestamp')
  const svixSignature = headers.get('svix-signature')

  if (!svixId || !svixTimestamp || !svixSignature) return false

  const timestampNum = parseInt(svixTimestamp, 10)
  const now = Math.floor(Date.now() / 1000)
  if (Math.abs(now - timestampNum) > 300) return false

  const secretBytes = Uint8Array.from(
    atob(secret.startsWith('whsec_') ? secret.slice(6) : secret),
    (c) => c.charCodeAt(0),
  )

  const toSign = new TextEncoder().encode(`${svixId}.${svixTimestamp}.${payload}`)
  const key = await crypto.subtle.importKey(
    'raw',
    secretBytes,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const signature = await crypto.subtle.sign('HMAC', key, toSign)
  const computedSig = btoa(String.fromCharCode(...new Uint8Array(signature)))

  const expectedSignatures = svixSignature.split(' ')
  return expectedSignatures.some((sig) => {
    const sigValue = sig.startsWith('v1,') ? sig.slice(3) : sig
    return sigValue === computedSig
  })
}

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  const webhookSecret = Deno.env.get('CLERK_WEBHOOK_SECRET')
  if (!webhookSecret) {
    return new Response('Webhook secret not configured', { status: 500 })
  }

  const payload = await req.text()
  const isValid = await verifyWebhookSignature(payload, req.headers, webhookSecret)
  if (!isValid) {
    return new Response('Invalid signature', { status: 401 })
  }

  const event: WebhookEvent = JSON.parse(payload)

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  const userId = event.data.id
  const phone = event.data.phone_numbers?.[0]?.phone_number ?? ''
  const firstName = event.data.first_name ?? ''
  const lastName = event.data.last_name ?? ''
  const name = [firstName, lastName].filter(Boolean).join(' ') || phone || 'User'

  if (event.type === 'user.created') {
    const { error } = await supabase.from('users').insert({
      id: userId,
      phone,
      name,
    })

    if (error) {
      console.error('Insert failed:', error.message)
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      })
    }
  } else if (event.type === 'user.updated') {
    const { error } = await supabase
      .from('users')
      .update({ phone, name })
      .eq('id', userId)

    if (error) {
      console.error('Update failed:', error.message)
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      })
    }
  } else {
    return new Response(JSON.stringify({ status: 'ignored', type: event.type }), {
      headers: { 'Content-Type': 'application/json' },
    })
  }

  return new Response(
    JSON.stringify({ status: 'ok' }),
    { headers: { 'Content-Type': 'application/json' } },
  )
})
```

- [ ] **Step 2: Test the webhook locally (manual)**

Deploy locally with Supabase CLI:

```bash
cd backend && supabase functions serve clerk-webhook --env-file .env.local
```

Test with curl:

```bash
curl -X POST http://localhost:54321/functions/v1/clerk-webhook \
  -H "Content-Type: application/json" \
  -d '{"type":"user.created","data":{"id":"user_test","first_name":"Test","phone_numbers":[{"phone_number":"+911234567890"}]}}'
```

Expected: 401 (no valid signature headers) — confirms signature verification is working.

- [ ] **Step 3: Commit**

```bash
git add backend/supabase/functions/clerk-webhook/
git commit -m "feat(auth): add Clerk webhook edge function for user sync"
```

---

## Post-Plan Checklist (Self-Review)

**Spec coverage:**
- [x] Architecture: 3-layer (Clerk SDK, auth bridge, webhook) — Tasks 2-4, 9
- [x] Auth flow: phone OTP, email OTP, Google — Tasks 2, 3, 6
- [x] Auth state machine: idle -> codeSent -> verifying -> authenticated — Tasks 1, 3
- [x] Session persistence: Clerk SDK handles — Task 2 (ClerkService.initialize)
- [x] JWT integration: Clerk -> Supabase token — Tasks 3 (providers)
- [x] Riverpod provider chain — Tasks 3, 4
- [x] Offline handling: Clerk caches JWT — acknowledged in architecture
- [x] Webhook: user.created + user.updated — Task 9
- [x] Webhook race condition: retry with backoff + client fallback — Task 4
- [x] Onboarding: 4 pages (name, DOB, vehicle, emergency contact) — Task 7
- [x] Router auth guards — Task 8
- [x] Route structure: /sign-in, /verify, /onboarding, /home — Task 8
- [x] Router refresh via ChangeNotifier bridge — Task 8
- [x] File structure: matches spec Section 7 — all files listed
- [x] Error handling: all scenarios from spec Section 8 covered in respective tasks
- [x] Schema migration: date_of_birth nullable — Task 1

**Type consistency:** `AuthState`, `AuthStatus`, `UserProfile`, `ClerkService`, `authRedirect` — names match across all tasks.

**Placeholder scan:** No TBD, TODO, or "implement later" found.
