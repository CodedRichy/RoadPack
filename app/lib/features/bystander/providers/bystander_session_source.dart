import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/network/push_notification_service.dart';
import '../../auth/providers/user_profile_provider.dart';
import '../../crash_detection/models/crash_state.dart';
import '../../crash_detection/providers/crash_detection_provider.dart';
import '../../emergency_profile/providers/emergency_contacts_provider.dart';
import '../../sos/models/sos_state.dart';
import '../../sos/providers/sos_state_provider.dart';
import '../models/bystander_session.dart';
import '../services/bystander_notification.dart';
import '../services/bystander_session_assembler.dart';
import '../services/local_bystander_notification_presenter.dart';

/// Reads a position without touching the network.
///
/// Returns null rather than throwing: at a crash site the location service
/// may be off, permission may never have been granted, and neither is a
/// reason for the bystander screen to fail to open.
typedef LocalFixSource = Future<LocalFix?> Function();

/// Last-known fix only. Deliberately NOT `getCurrentPosition`: that waits on
/// a GNSS lock and would block the one screen that must come up instantly.
/// The fix that comes back carries the OS's own timestamp, so the screen can
/// state its age truthfully instead of implying it is current.
final localFixSourceProvider = Provider<LocalFixSource>((ref) {
  return () async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position == null) return null;
      return LocalFix(
        lat: position.latitude,
        lng: position.longitude,
        at: position.timestamp,
        accuracyMeters: position.accuracy,
      );
    } catch (e) {
      debugPrint('[Bystander] last-known fix unavailable: $e');
      return null;
    }
  };
});

/// The most recent fix this device holds, synchronously readable.
///
/// Synchronous on purpose: session assembly must never await. The value is
/// warmed in the background and stays null until something has actually been
/// read, because a screen with no coordinates is honest and a screen with
/// invented coordinates is not.
final localFixProvider = NotifierProvider<LocalFixNotifier, LocalFix?>(
  LocalFixNotifier.new,
);

class LocalFixNotifier extends Notifier<LocalFix?> {
  @override
  LocalFix? build() {
    unawaited(refresh());
    return null;
  }

  /// Best-effort warm. Never throws, never replaces a fix with nothing.
  Future<void> refresh() async {
    final fix = await ref.read(localFixSourceProvider)();
    if (fix != null) state = fix;
  }

  /// For callers that already hold a fix (the tracking service, a dispatch
  /// path that just captured one) so it is not read twice.
  void record(LocalFix fix) => state = fix;
}

/// The incident this device is currently the subject of, if any.
///
/// Both local incident sources are consulted. `active` is derived from the
/// state machine rather than from the wire row, because the wire row is the
/// thing we may not be able to reach.
final localIncidentProvider = Provider<LocalIncidentSnapshot?>((ref) {
  final sos = ref.watch(sosStateProvider);
  final sosIncident = sos.activeIncident;
  if (sosIncident != null) {
    return LocalIncidentSnapshot(
      id: sosIncident.id,
      active: sos.status != SosStatus.resolved &&
          sos.status != SosStatus.cancelled &&
          sosIncident.isActive,
    );
  }

  final crash = ref.watch(crashDetectionProvider);
  final crashIncident = crash.activeIncident;
  if (crashIncident != null) {
    return LocalIncidentSnapshot(
      id: crashIncident.id,
      active: crash.status == CrashDetectionStatus.active &&
          crashIncident.isActive,
    );
  }

  return null;
});

/// The assembled snapshot, or null when there is no incident.
///
/// Every source is read with `valueOrNull`: an unauthenticated or offline
/// device gets a session with fewer fields, never a spinner and never a
/// throw. The screen degrades; it does not fail to open.
final assembledBystanderSessionProvider = Provider<BystanderSession?>((ref) {
  final incident = ref.watch(localIncidentProvider);
  if (incident == null) return null;

  final profile = ref.watch(userProfileProvider).valueOrNull;
  final contacts = ref.watch(emergencyContactsProvider).valueOrNull ?? const [];

  return BystanderSessionAssembler.assemble(
    incident: incident,
    victimName: profile?.name,
    fix: ref.watch(localFixProvider),
    contacts: contacts,
    bloodGroup: profile?.bloodGroup,
    medicalNotes: profile?.medicalNotes,
  );
});

/// The platform notification surface. Overridden in tests; nothing else in
/// the feature touches the plugin.
final notificationDriverProvider = Provider<NotificationDriver>((ref) {
  return FlutterLocalNotificationDriver(
    // Tapping the notification (or its action) is published on the same
    // stream as an FCM bystander push, so the shell has exactly one place
    // that navigates to /bystander.
    onOpen: (incidentId) => incidentNotificationTaps.add(
      IncidentNotification(incidentId, IncidentNotificationTarget.bystander),
    ),
  );
});

/// The FR-090 Phase-1 notification presenter: a notification with an action
/// that opens the bystander screen. Not a full-screen intent over the lock
/// screen -- that is Phase 2.
final bystanderNotificationPresenterProvider =
    Provider<BystanderNotificationPresenter>(
      (ref) => LocalBystanderNotificationPresenter(
        ref.watch(notificationDriverProvider),
      ),
    );

/// Keeps the incident notification in step with the session.
///
/// Raised while the incident is active; torn down the moment it is not, so
/// nobody can tap through to an ICE card that has already sealed.
final bystanderNotificationControllerProvider =
    Provider<BystanderNotificationController>((ref) {
      final controller = BystanderNotificationController(
        ref.watch(bystanderNotificationPresenterProvider),
      );
      ref.listen<BystanderSession?>(
        assembledBystanderSessionProvider,
        (_, next) => unawaited(controller.sync(next)),
        fireImmediately: true,
      );
      return controller;
    });
