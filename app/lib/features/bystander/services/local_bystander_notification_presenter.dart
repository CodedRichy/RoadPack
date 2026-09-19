import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../core/network/push_notification_service.dart';
import '../models/bystander_session.dart';
import 'bystander_notification.dart';

/// The platform surface this presenter needs, and nothing else.
///
/// A seam rather than a direct plugin call, so the FR-090 lifecycle can be
/// verified without a method channel. The notification is a presentation
/// concern hanging off the incident path; it must be provable that it cannot
/// reach back into crash detection, SOS, or the cascade.
abstract interface class NotificationDriver {
  /// Initialise, create the channel and ask for permission. Returns false
  /// when notifications are unavailable — a denied permission is a degraded
  /// state, not an error.
  Future<bool> ensureReady();

  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String payload,
  });

  Future<void> cancel(int id);
}

/// `flutter_local_notifications` behind [NotificationDriver].
class FlutterLocalNotificationDriver implements NotificationDriver {
  FlutterLocalNotificationDriver({
    FlutterLocalNotificationsPlugin? plugin,
    this.onOpen,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Called with the incident id when the notification or its action is
  /// tapped.
  final void Function(String incidentId)? onOpen;

  bool? _ready;

  /// Importance.max so it survives on a locked, dozing budget phone.
  /// `fullScreenIntent` stays false: over-lock presentation is FR-090
  /// Phase 2 and is deliberately not built here.
  static const channel = AndroidNotificationChannel(
    IncidentNotificationRouter.channelId,
    'Emergency help screen',
    description:
        'Shows a helper what to do when this phone reports a crash or SOS.',
    importance: Importance.max,
  );

  @override
  Future<bool> ensureReady() async {
    if (_ready != null) return _ready!;
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: _onResponse,
      );

      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        await android.createNotificationChannel(channel);
        // POST_NOTIFICATIONS on Android 13+. A refusal is answered with
        // "no notification", never with a throw.
        final granted = await android.requestNotificationsPermission();
        return _ready = granted ?? false;
      }

      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return _ready = await ios.requestPermissions(alert: true) ?? false;
      }

      return _ready = false;
    } catch (e) {
      debugPrint('[Bystander] notifications unavailable: $e');
      return _ready = false;
    }
  }

  void _onResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    onOpen?.call(payload);
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.max,
        priority: Priority.high,
        // Stays up for as long as the incident does; the controller is what
        // takes it down.
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: true,
        // Phase 2, not Phase 1.
        fullScreenIntent: false,
        // Legible on a locked screen because it carries no personal data:
        // the name, number and medical facts live behind the screen.
        visibility: NotificationVisibility.public,
        actions: const <AndroidNotificationAction>[
          AndroidNotificationAction(
            IncidentNotificationRouter.openBystanderActionId,
            'Show help screen',
            showsUserInterface: true,
            cancelNotification: false,
          ),
        ],
      ),
      iOS: const DarwinNotificationDetails(presentAlert: true),
    );
    return _plugin.show(id, title, body, details, payload: payload);
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id);
}

/// FR-090 Phase 1: an incident notification whose action opens the bystander
/// screen.
///
/// Every method is total. `ensureReady` returning false, a platform channel
/// that is not there, a revoked permission — each ends as "no notification",
/// which is a worse outcome for the bystander but not an outcome that can
/// touch the incident path. Nothing here is awaited by crash detection, SOS,
/// or the cascade.
class LocalBystanderNotificationPresenter
    implements BystanderNotificationPresenter {
  LocalBystanderNotificationPresenter(this.driver);

  final NotificationDriver driver;

  /// Fixed id: there is only ever one incident notification for this device,
  /// and re-showing must replace rather than stack.
  static const notificationId = 907;

  /// Deliberately impersonal and free of any personal data — it is readable
  /// on a locked screen by whoever picked the phone up. It also makes no
  /// claim that help has been dispatched.
  static const title = 'Someone may need help';
  static const body = 'Tap to see what to do and who to call.';

  @override
  Future<void> show(BystanderSession session) async {
    try {
      if (!await driver.ensureReady()) return;
      await driver.show(
        id: notificationId,
        title: title,
        body: body,
        payload: session.incidentId,
      );
    } catch (e) {
      debugPrint('[Bystander] could not raise incident notification: $e');
    }
  }

  @override
  Future<void> dismiss(String incidentId) async {
    try {
      await driver.cancel(notificationId);
    } catch (e) {
      debugPrint('[Bystander] could not dismiss incident notification: $e');
    }
  }
}
