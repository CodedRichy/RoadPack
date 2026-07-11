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

    test(
      'authenticated + not onboarded + non-onboarding route -> /onboarding',
      () {
        final result = authRedirect(
          isAuthenticated: true,
          isOnboarded: false,
          location: '/home',
        );
        expect(result, '/onboarding');
      },
    );

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

    test('authenticated + onboarded + onboarding route -> /home', () {
      final result = authRedirect(
        isAuthenticated: true,
        isOnboarded: true,
        location: '/onboarding',
      );
      expect(result, '/home');
    });

    test('unauthenticated user on /circles redirects to /sign-in', () {
      expect(
        authRedirect(
          isAuthenticated: false,
          isOnboarded: false,
          location: '/circles',
        ),
        '/sign-in',
      );
    });

    test('authenticated onboarded user on /circles stays', () {
      expect(
        authRedirect(
          isAuthenticated: true,
          isOnboarded: true,
          location: '/circles',
        ),
        isNull,
      );
    });

    test(
      'authenticated non-onboarded user on /circles redirects to /onboarding',
      () {
        expect(
          authRedirect(
            isAuthenticated: true,
            isOnboarded: false,
            location: '/circles',
          ),
          '/onboarding',
        );
      },
    );
  });
}
