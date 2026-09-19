import '../models/bystander_session.dart';

/// Presents the FR-090 Phase-1 incident notification.
///
/// Phase 1 is a notification with an action that opens the bystander screen.
/// It is explicitly NOT a full-screen-over-lock presentation — that is Phase
/// 2 and needs a separate consent and permission story.
///
/// An interface, not a plugin call, so the lifecycle (raise on an active
/// incident, tear down the moment it stops being active) is verifiable
/// without a platform channel. The notification is a side effect of the
/// incident path and must never be able to fail it: every call site treats a
/// throw here as nothing at all.
abstract interface class BystanderNotificationPresenter {
  Future<void> show(BystanderSession session);
  Future<void> dismiss(String incidentId);
}

/// Default presenter: does nothing. Wiring a real platform notification
/// needs `flutter_local_notifications`, which is a dependency decision, so
/// the default is a no-op rather than a half-wired plugin call.
class NoopBystanderNotificationPresenter
    implements BystanderNotificationPresenter {
  const NoopBystanderNotificationPresenter();

  @override
  Future<void> show(BystanderSession session) async {}

  @override
  Future<void> dismiss(String incidentId) async {}
}

/// Records what was asked of it. Used by tests, and useful in debug builds.
class RecordingBystanderNotificationPresenter
    implements BystanderNotificationPresenter {
  final shown = <BystanderSession>[];
  final dismissed = <String>[];

  @override
  Future<void> show(BystanderSession session) async => shown.add(session);

  @override
  Future<void> dismiss(String incidentId) async => dismissed.add(incidentId);
}

/// Drives a [BystanderNotificationPresenter] from successive sessions.
///
/// Holds no timers and no streams of its own: it is fed by the provider that
/// watches local incident state, so "the incident resolved" and "the
/// notification came down" are the same event rather than two that can drift.
class BystanderNotificationController {
  BystanderNotificationController(this.presenter);

  final BystanderNotificationPresenter presenter;

  String? _showingFor;

  String? get showingFor => _showingFor;

  /// Feed the current session (or null when there is no incident).
  Future<void> sync(BystanderSession? session) async {
    final wanted = (session != null && session.incidentActive)
        ? session
        : null;

    try {
      if (wanted == null) {
        final previous = _showingFor;
        _showingFor = null;
        if (previous != null) await presenter.dismiss(previous);
        return;
      }
      if (_showingFor == wanted.incidentId) return;
      _showingFor = wanted.incidentId;
      await presenter.show(wanted);
    } catch (_) {
      // A notification that cannot be raised must never take the incident
      // path down with it.
    }
  }
}
