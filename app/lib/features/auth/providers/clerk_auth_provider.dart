import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_state.dart';
import '../services/clerk_service.dart';

/// Bridges [ClerkService] into a Riverpod [AsyncNotifier], exposing a
/// synchronous, watchable [AuthState] for the rest of the app.
final clerkAuthProvider = AsyncNotifierProvider<ClerkAuthNotifier, AuthState>(
  ClerkAuthNotifier.new,
);

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
      state = AsyncData(state.value!.copyWith(status: AuthStatus.codeSent));
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
      state = AsyncData(state.value!.copyWith(status: AuthStatus.codeSent));
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
      state.value!.copyWith(status: AuthStatus.verifying, errorMessage: null),
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
        AuthState(status: AuthStatus.authenticated, userId: _service.userId),
      );
    } on Exception catch (e) {
      state = AsyncData(state.value!.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> signOut() async {
    await _service.signOut();
    state = const AsyncData(AuthState());
  }
}
