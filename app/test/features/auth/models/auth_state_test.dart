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
