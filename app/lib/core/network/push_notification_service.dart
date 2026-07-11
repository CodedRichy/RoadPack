import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/providers/authenticated_supabase_provider.dart';
import '../../features/auth/services/clerk_service.dart';

final pushNotificationServiceProvider =
    Provider<PushNotificationService?>((ref) {
  final supabase = ref.watch(authenticatedSupabaseProvider);
  if (supabase == null) return null;

  final clerkService = ref.read(clerkServiceProvider);
  final service = PushNotificationService(supabase, clerkService);
  service.initialize();

  ref.onDispose(() => service.dispose());
  return service;
});

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

      _foregroundSub =
          FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      _tokenRefreshSub =
          _messaging.onTokenRefresh.listen(_registerToken);

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
    // Phase 2: navigate to incident screen based on message.data['incident_id']
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
