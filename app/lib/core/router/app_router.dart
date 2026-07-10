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
  if (isAuthenticated && !isOnboarded && !isOnboardingRoute) {
    return '/onboarding';
  }
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
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('RoadPack v2'))),
      ),
    ],
  );
});
