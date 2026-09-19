import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/models/auth_state.dart';
import '../../features/auth/providers/clerk_auth_provider.dart';
import '../../features/auth/providers/user_profile_provider.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/sign_in_screen.dart';
import '../../features/auth/screens/verify_screen.dart';
import '../../features/circles/screens/circles_list_screen.dart';
import '../../features/circles/screens/create_circle_screen.dart';
import '../../features/circles/screens/join_circle_screen.dart';
import '../../features/circles/screens/circle_detail_screen.dart';
import '../../features/alerts/screens/alert_detail_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/tracking/screens/routes_screen.dart';
import '../../features/tracking/screens/trip_history_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/emergency_profile/screens/emergency_contacts_screen.dart';
import '../../features/emergency_profile/screens/ice_card_screen.dart';
import '../../features/live_map/screens/live_map_screen.dart';
import '../../features/live_map/screens/offline_maps_screen.dart';
import '../../features/commute/screens/commute_routes_screen.dart';
import '../../features/commute/screens/non_arrival_check_screen.dart';
import '../../features/commute/screens/route_editor_screen.dart';
import '../../features/commute/models/commute_route.dart';
import '../../features/pack/screens/pack_ride_screen.dart';
import '../../features/pack/screens/create_pack_ride_screen.dart';
import '../../features/pack/screens/join_pack_ride_screen.dart';
import '../../features/bystander/screens/bystander_screen.dart';
import '../../features/consent/screens/consent_center_screen.dart';
import '../../features/consent/screens/parental_consent_screen.dart';
import '../../features/circles/screens/who_can_see_me_screen.dart';
import '../../features/bystander/providers/bystander_providers.dart';
import '../../features/bystander/providers/bystander_session_source.dart';
import '../theme/theme.dart';

/// Routes that survive a sign-in bounce.
///
/// A rider who taps a pack share link, installs the app and signs in must land
/// back on the claim screen holding their token (TRD 7.3). Dropping them on
/// /home loses the token and breaks the acquisition loop, because the link is
/// usually in a WhatsApp thread they have already scrolled past.
bool isResumableDeepLink(String location) => location.startsWith('/pack/join');

/// Routes reachable without an account.
///
/// The bystander screen is opened by whoever picks up a crash victim's phone.
/// They are not the account holder, cannot unlock anything, and are frequently
/// on a dead network -- bouncing them to sign-in would make the screen useless
/// precisely when it exists to be used (FR-007). It leaks nothing on its own:
/// the session that feeds it is assembled only while an incident is active,
/// and the ICE payload stays sealed otherwise.
bool isPublicRoute(String location) => location.startsWith('/bystander');

/// Where to send the user after authentication, given a pending deep link.
String _postAuthTarget({required bool isOnboarded, String? pendingLink}) {
  if (!isOnboarded) return '/onboarding';
  if (pendingLink != null && isResumableDeepLink(pendingLink)) {
    return pendingLink;
  }
  return '/home';
}

String? authRedirect({
  required bool isAuthenticated,
  required bool isOnboarded,
  required String location,

  /// Full requested location including query, when it differs from
  /// [location]. Used only to preserve a resumable deep link across sign-in.
  String? requestedUri,

  /// The deep link stashed when the user was bounced to sign-in.
  String? pendingLink,
}) {
  final isAuthRoute =
      location.startsWith('/sign-in') || location.startsWith('/verify');
  final isOnboardingRoute = location == '/onboarding';

  // Never redirect away from a public route, in either direction: a signed-in
  // owner may also be looking at their own bystander screen.
  if (isPublicRoute(location)) return null;

  if (!isAuthenticated && !isAuthRoute) return '/sign-in';
  if (isAuthenticated && isAuthRoute) {
    return _postAuthTarget(isOnboarded: isOnboarded, pendingLink: pendingLink);
  }
  if (isAuthenticated && !isOnboarded && !isOnboardingRoute) {
    return '/onboarding';
  }
  if (isAuthenticated && isOnboarded && isOnboardingRoute) {
    return _postAuthTarget(isOnboarded: true, pendingLink: pendingLink);
  }
  return null;
}

/// Holds a deep link across the sign-in / onboarding detour.
///
/// In-memory on purpose: a pack share token is short-lived and scoped to an
/// active ride, so persisting it past process death would outlive the ride it
/// belongs to and widen the sharing window the anti-abuse rules deliberately
/// keep narrow.
class PendingDeepLink extends ChangeNotifier {
  String? _link;
  String? get link => _link;

  void capture(String location) {
    if (!isResumableDeepLink(location) || _link == location) return;
    _link = location;
    notifyListeners();
  }

  String? consume() {
    final taken = _link;
    _link = null;
    return taken;
  }
}

final pendingDeepLinkProvider = Provider<PendingDeepLink>(
  (ref) => PendingDeepLink(),
);

class AuthChangeNotifier extends ChangeNotifier {
  AuthChangeNotifier(this._ref) {
    _ref.listen(clerkAuthProvider, (_, __) => notifyListeners());
    _ref.listen(userProfileProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = AuthChangeNotifier(ref);
  final pending = ref.watch(pendingDeepLinkProvider);

  return GoRouter(
    initialLocation: '/sign-in',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authState =
          ref.read(clerkAuthProvider).valueOrNull ?? const AuthState();
      final profile = ref.read(userProfileProvider).valueOrNull;
      final isAuthenticated = authState.isAuthenticated;

      // Stash a share link before the sign-in bounce discards it.
      if (!isAuthenticated) {
        pending.capture(state.uri.toString());
      }

      final target = authRedirect(
        isAuthenticated: isAuthenticated,
        isOnboarded: profile?.isOnboarded ?? false,
        location: state.matchedLocation,
        requestedUri: state.uri.toString(),
        pendingLink: pending.link,
      );

      // Consume the stash only once we are actually handing it back, so a
      // failed sign-in does not silently drop the token.
      if (target != null && isResumableDeepLink(target)) {
        pending.consume();
      }
      return target;
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
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/circles',
        builder: (context, state) => const CirclesListScreen(),
      ),
      GoRoute(
        path: '/circles/new',
        builder: (context, state) => const CreateCircleScreen(),
      ),
      GoRoute(
        path: '/circles/join',
        builder: (context, state) => const JoinCircleScreen(),
      ),
      GoRoute(
        path: '/circles/visibility',
        builder: (context, state) => const WhoCanSeeMeScreen(),
      ),
      GoRoute(
        path: '/circles/:id',
        builder: (context, state) {
          final circleId = state.pathParameters['id']!;
          return CircleDetailScreen(circleId: circleId);
        },
      ),
      GoRoute(
        path: '/alerts/:id',
        builder: (context, state) {
          final incidentId = state.pathParameters['id']!;
          return AlertDetailScreen(incidentId: incidentId);
        },
      ),
      GoRoute(
        path: '/routes',
        builder: (context, state) => const RoutesScreen(),
      ),
      GoRoute(
        path: '/trips',
        builder: (context, state) => const TripHistoryScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/offline-maps',
        builder: (context, state) => const OfflineMapsScreen(),
      ),
      GoRoute(
        path: '/emergency-contacts',
        builder: (context, state) => const EmergencyContactsScreen(),
      ),
      GoRoute(path: '/ice', builder: (context, state) => const IceCardScreen()),
      GoRoute(
        path: '/settings/consent',
        builder: (context, state) => ConsentCenterScreen(
          onOpenParentalConsent: () => context.go('/consent/parental'),
        ),
      ),
      GoRoute(
        path: '/consent/parental',
        builder: (context, state) => const ParentalConsentScreen(),
      ),
      // Public (see isPublicRoute). The screen reads the fail-closed
      // bystanderSessionProvider, so the session is supplied here from locally
      // assembled incident state; with no active incident there is nothing to
      // show and nothing to leak.
      GoRoute(
        path: '/bystander',
        builder: (context, state) => Consumer(
          builder: (context, ref, _) {
            final session = ref.watch(assembledBystanderSessionProvider);
            if (session == null) return const _NoActiveIncident();
            return ProviderScope(
              overrides: [bystanderSessionProvider.overrideWithValue(session)],
              child: const BystanderScreen(),
            );
          },
        ),
      ),
      GoRoute(path: '/map', builder: (context, state) => const LiveMapScreen()),
      // Paths come from the screens themselves so the route table and the
      // navigation call sites cannot drift apart.
      GoRoute(
        path: CommuteRoutesScreen.routePath,
        builder: (context, state) => const CommuteRoutesScreen(),
      ),
      GoRoute(
        path: '/commute/route',
        builder: (context, state) =>
            RouteEditorScreen(route: state.extra as CommuteRoute?),
      ),
      GoRoute(
        path: NonArrivalCheckScreen.routePath,
        builder: (context, state) => const NonArrivalCheckScreen(),
      ),
      GoRoute(
        path: '/pack/new',
        builder: (context, state) => const CreatePackRideScreen(),
      ),
      // Deep-link target for the web viewer's install-and-claim path (TRD 7.3).
      // The token rides in as a path parameter so a rider who has just
      // installed the app claims their slot without re-pasting the link.
      GoRoute(
        path: '/pack/join',
        builder: (context, state) =>
            JoinPackRideScreen(initialToken: state.uri.queryParameters['t']),
      ),
      GoRoute(
        path: '/pack/:id',
        builder: (context, state) =>
            PackRideScreen(rideId: state.pathParameters['id']!),
      ),
    ],
  );
});

/// Shown when /bystander is opened with no incident in progress.
///
/// Deliberately says nothing about the phone's owner: this route is public, so
/// its empty state must be safe for a stranger who opened it out of curiosity.
class _NoActiveIncident extends StatelessWidget {
  const _NoActiveIncident();

  @override
  Widget build(BuildContext context) {
    final semantics = context.semantics;
    return Scaffold(
      backgroundColor: semantics.canvas,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Text(
            'No emergency is in progress on this phone.',
            textAlign: TextAlign.center,
            style: TextStyle(color: semantics.textSecondary),
          ),
        ),
      ),
    );
  }
}
