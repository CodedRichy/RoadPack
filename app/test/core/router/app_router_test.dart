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

  group('pack share deep link survives sign-in', () {
    const link = '/pack/join?t=abc123';

    test('a pack join link is resumable; ordinary routes are not', () {
      expect(isResumableDeepLink(link), isTrue);
      expect(isResumableDeepLink('/home'), isFalse);
      expect(isResumableDeepLink('/circles'), isFalse);
    });

    test('signing in with a pending link lands on the claim screen', () {
      expect(
        authRedirect(
          isAuthenticated: true,
          isOnboarded: true,
          location: '/sign-in',
          pendingLink: link,
        ),
        link,
      );
    });

    test('onboarding still wins over a pending link', () {
      expect(
        authRedirect(
          isAuthenticated: true,
          isOnboarded: false,
          location: '/sign-in',
          pendingLink: link,
        ),
        '/onboarding',
      );
    });

    test('the link is handed back after onboarding completes', () {
      expect(
        authRedirect(
          isAuthenticated: true,
          isOnboarded: true,
          location: '/onboarding',
          pendingLink: link,
        ),
        link,
      );
    });

    test('without a pending link the destination is unchanged', () {
      expect(
        authRedirect(
          isAuthenticated: true,
          isOnboarded: true,
          location: '/sign-in',
        ),
        '/home',
      );
    });

    test('a non-resumable pending location is ignored', () {
      expect(
        authRedirect(
          isAuthenticated: true,
          isOnboarded: true,
          location: '/sign-in',
          pendingLink: '/settings',
        ),
        '/home',
      );
    });

    test('PendingDeepLink captures only resumable links and consumes once', () {
      final pending = PendingDeepLink();

      pending.capture('/circles');
      expect(pending.link, isNull);

      pending.capture(link);
      expect(pending.link, link);
      expect(pending.consume(), link);
      expect(pending.consume(), isNull);
    });
  });
}
