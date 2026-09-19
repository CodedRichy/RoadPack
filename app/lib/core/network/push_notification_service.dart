import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/providers/authenticated_supabase_provider.dart';
import '../../features/auth/services/clerk_service.dart';

final pushNotificationServiceProvider = Provider<PushNotificationService?>((
  ref,
) {
  final supabase = ref.watch(authenticatedSupabaseProvider);
  if (supabase == null) return null;

  final clerkService = ref.read(clerkServiceProvider);
  final service = PushNotificationService(supabase, clerkService);
  service.initialize();

  ref.onDispose(() => service.dispose());
  return service;
});

/// Where an incident push is meant to land.
///
/// `alert` is the pre-existing path: a push sent to a *watcher* about someone
/// else's incident, handled by the alerts feature. `bystander` is FR-090
/// Phase 1: a notification on the victim's own device whose action opens the
/// bystander screen for whoever picked the phone up.
enum IncidentNotificationTarget { alert, bystander }

/// A routed incident push.
@immutable
class IncidentNotification {
  const IncidentNotification(this.incidentId, this.target);

  final String incidentId;
  final IncidentNotificationTarget target;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IncidentNotification &&
          incidentId == other.incidentId &&
          target == other.target;

  @override
  int get hashCode => Object.hash(incidentId, target);

  @override
  String toString() => 'IncidentNotification($incidentId, ${target.name})';
}

/// Classifies an FCM data payload.
///
/// Purely additive: anything that is not explicitly marked as a
/// bystander/self-incident push classifies as [IncidentNotificationTarget
/// .alert] and continues down the path it always took. A payload with no
/// `incident_id` is not an incident push at all and routes nowhere.
class IncidentNotificationRouter {
  const IncidentNotificationRouter._();

  /// Android notification channel and action id for the Phase-1 notification.
  /// Phase 1 is an action on a notification; it is NOT full-screen-over-lock.
  static const channelId = 'roadpack_incident_self';
  static const openBystanderActionId = 'open_bystander';

  /// Data-payload values that mean "this is the victim's own device".
  static const _bystanderKinds = {
    'bystander',
    'incident_self',
    'self_incident',
  };

  static IncidentNotification? route(Map<String, dynamic> data) {
    final id = data['incident_id'];
    if (id is! String || id.isEmpty) return null;

    final kind = '${data['target'] ?? data['type'] ?? ''}'.toLowerCase();
    final flagged = '${data['bystander'] ?? ''}'.toLowerCase() == 'true';

    return IncidentNotification(
      id,
      _bystanderKinds.contains(kind) || flagged
          ? IncidentNotificationTarget.bystander
          : IncidentNotificationTarget.alert,
    );
  }
}

/// Bystander-screen open requests, emitted when the user taps the Phase-1
/// notification action. The app shell listens and navigates; nothing here
/// knows about routing, so this file stays free of a `go_router` dependency.
final incidentNotificationTaps =
    StreamController<IncidentNotification>.broadcast();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM] Background message: ${message.messageId}');
}

class PushNotificationService {
  PushNotificationService(this._supabase, this._clerkService);

  final SupabaseClient _supabase;
  final ClerkService _clerkService;
  final _messaging = FirebaseMessaging.instance;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<String>? _tokenRefreshSub;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final settings = await _messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[FCM] Permission denied');
        return;
      }

      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      _foregroundSub = FirebaseMessaging.onMessage.listen(
        _handleForegroundMessage,
      );

      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      _tokenRefreshSub = _messaging.onTokenRefresh.listen(_registerToken);

      final token = await _messaging.getToken();
      if (token != null) await _registerToken(token);
    } catch (e) {
      debugPrint('[FCM] Init failed: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM] Foreground: ${message.notification?.title}');
    // Phase 2: show local notification via flutter_local_notifications
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('[FCM] Opened app: ${message.data}');
    // Additive: a bystander-targeted push is published for the shell to
    // navigate on. Everything else is left exactly where it was — the alert
    // path is untouched by this branch.
    final routed = IncidentNotificationRouter.route(message.data);
    if (routed?.target == IncidentNotificationTarget.bystander) {
      incidentNotificationTaps.add(routed!);
    }
    // Phase 2: full-screen-over-lock presentation (FR-090 Phase 2).
  }

  String? _lastRegisteredToken;

  Future<void> _registerToken(String token) async {
    if (token == _lastRegisteredToken) return;

    final userId = _clerkService.userId;
    if (userId == null) return;

    try {
      final now = DateTime.now().toUtc().toIso8601String();

      // Check if this token already exists for this user
      final existing = await _supabase
          .from('devices')
          .select('id')
          .eq('user_id', userId)
          .eq('fcm_token', token)
          .maybeSingle();

      if (existing != null) {
        await _supabase
            .from('devices')
            .update({'last_heartbeat': now})
            .eq('id', existing['id'] as String);
      } else {
        await _supabase.from('devices').insert({
          'user_id': userId,
          'fcm_token': token,
          'last_heartbeat': now,
        });
      }

      _lastRegisteredToken = token;
      debugPrint('[FCM] Token registered');
    } catch (e) {
      debugPrint('[FCM] Token registration failed: $e');
    }
  }

  void dispose() {
    _foregroundSub?.cancel();
    _tokenRefreshSub?.cancel();
  }
}
