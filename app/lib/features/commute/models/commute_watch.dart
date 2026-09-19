import 'grace_window.dart';

/// What the rider told us when asked.
///
/// The wire values are the ones `check-in-response` validates
/// (`['fine', 'running_late', 'need_help']`) — do not invent a fourth without
/// changing the edge function first, or the response is rejected with a 422
/// and the rider's answer is lost.
enum CheckInResponse {
  fine('fine'),
  runningLate('running_late'),
  needHelp('need_help');

  const CheckInResponse(this.wire);

  final String wire;

  static CheckInResponse? fromWire(String? wire) {
    for (final r in values) {
      if (r.wire == wire) return r;
    }
    return null;
  }
}

/// How long "I'm running late" buys (FR-044).
enum RunningLateSnooze {
  thirty(30),
  sixty(60);

  const RunningLateSnooze(this.minutes);

  final int minutes;

  Duration get duration => Duration(minutes: minutes);

  String get label => minutes == 60 ? '1 hour' : '$minutes min';
}

/// The stage a commute watch is at.
enum CommuteWatchPhase {
  /// Inside the expected arrival plus grace window. Nothing has happened and
  /// nothing is shown beyond the ordinary protected state.
  travelling,

  /// The window lapsed and the rider is being asked. **Attention tier, not
  /// emergency** — nobody has been alerted yet and the overwhelmingly likely
  /// explanation is traffic.
  pendingCheckIn,

  /// The check-in went unanswered (or the rider asked for help). The circle is
  /// being told. This is the only phase that earns the emergency tier.
  escalated,

  /// Arrived, or answered. Over.
  resolved,
}

/// One commute instance being watched for non-arrival (FR-042/043/044).
///
/// Immutable and clock-free: every question is answered against a `now` passed
/// in by the caller. That is deliberate — the escalation rule is the part of
/// this feature that can wake somebody's mother at midnight, so it has to be
/// testable without waiting five real minutes, and it must never depend on a
/// timer having fired.
///
/// The server is the authority: `non-arrival-check` creates the incident and
/// queues the cascade at `delay_seconds: 300`. This model mirrors that
/// timeline so the client can show an honest countdown, and it never escalates
/// anything itself.
class CommuteWatch {
  const CommuteWatch({
    required this.routeId,
    required this.expectedArrivalAt,
    this.window = GraceWindow.defaultWindow,
    this.extension = Duration.zero,
    this.checkInPromptedAt,
    this.response,
    this.respondedAt,
    this.arrivedAt,
    this.incidentId,
    this.hasNotifiedCircle = false,
  });

  /// The gap between the check-in prompt and the circle being told, matching
  /// the `cascade_jobs.delay_seconds: 300` the edge function queues and the
  /// PRD's "no response in 5 min" acceptance criterion.
  static const Duration escalationDelay = Duration(minutes: 5);

  final String routeId;

  /// Typical start plus typical duration for this instance.
  final DateTime expectedArrivalAt;

  /// The rider's configured grace (10/15/30, default 15).
  final GraceWindow window;

  /// Everything "I'm running late" has added, accumulated across presses.
  final Duration extension;

  /// When the check-in was actually put in front of the rider. Null until it
  /// has been. Escalation counts from here when it is set, because a push that
  /// arrived late must not shorten the five minutes the rider gets to answer.
  final DateTime? checkInPromptedAt;

  final CheckInResponse? response;
  final DateTime? respondedAt;
  final DateTime? arrivedAt;

  /// The `incidents` row `non-arrival-check` opened, needed to answer it.
  final String? incidentId;

  /// Whether the circle has actually been told. Set only when the server has
  /// escalated. "I'm running late" must never flip this.
  final bool hasNotifiedCircle;

  /// When the app will ask the rider, i.e. expected arrival + grace + snoozes.
  DateTime get deadline => expectedArrivalAt.add(window.duration + extension);

  /// When the circle gets told if nobody answers.
  DateTime get escalatesAt =>
      (checkInPromptedAt ?? deadline).add(escalationDelay);

  bool get isResolved =>
      arrivedAt != null ||
      response == CheckInResponse.fine ||
      response == CheckInResponse.runningLate;

  CommuteWatchPhase phaseAt(DateTime now) {
    // Arriving, or saying you are fine, ends it — including after the point
    // the circle would otherwise have been told.
    if (isResolved) return CommuteWatchPhase.resolved;

    // An explicit call for help skips the waiting entirely.
    if (response == CheckInResponse.needHelp) {
      return CommuteWatchPhase.escalated;
    }

    if (now.isBefore(deadline)) return CommuteWatchPhase.travelling;
    if (now.isBefore(escalatesAt)) return CommuteWatchPhase.pendingCheckIn;
    return CommuteWatchPhase.escalated;
  }

  /// Time left before the rider will be asked. Zero once the window lapsed.
  Duration remainingAt(DateTime now) => _clamp(deadline.difference(now));

  /// Time left to answer before the circle is told.
  Duration remainingToEscalationAt(DateTime now) =>
      _clamp(escalatesAt.difference(now));

  /// "I'm running late" (FR-044).
  ///
  /// Extends the window, clears the pending prompt, and returns the watch to
  /// [CommuteWatchPhase.travelling]. It notifies nobody — that is the entire
  /// point. If pressing this cost the rider an explanation to their family,
  /// they would stop using it, and then the feature protects nobody.
  ///
  /// Server-side the paired call is `check-in-response` with `running_late`,
  /// which cancels the incident with `cancelled_reason: 'user_running_late'`
  /// and never invokes `alert-cascade`.
  CommuteWatch extendBy(RunningLateSnooze snooze) {
    return CommuteWatch(
      routeId: routeId,
      expectedArrivalAt: expectedArrivalAt,
      window: window,
      extension: extension + snooze.duration,
      arrivedAt: arrivedAt,
      hasNotifiedCircle: hasNotifiedCircle,
      // Prompt, response and incident are all cleared: the current check-in is
      // answered and closed, and the next window opens fresh.
    );
  }

  /// Records the rider's answer. [CheckInResponse.runningLate] is handled by
  /// [extendBy] instead, because it changes the schedule rather than ending
  /// the watch.
  CommuteWatch withResponse(CheckInResponse response, {DateTime? at}) {
    return copyWith(
      response: response,
      respondedAt: at ?? DateTime.now().toUtc(),
    );
  }

  CommuteWatch copyWith({
    String? routeId,
    DateTime? expectedArrivalAt,
    GraceWindow? window,
    Duration? extension,
    DateTime? checkInPromptedAt,
    CheckInResponse? response,
    DateTime? respondedAt,
    DateTime? arrivedAt,
    String? incidentId,
    bool? hasNotifiedCircle,
  }) {
    return CommuteWatch(
      routeId: routeId ?? this.routeId,
      expectedArrivalAt: expectedArrivalAt ?? this.expectedArrivalAt,
      window: window ?? this.window,
      extension: extension ?? this.extension,
      checkInPromptedAt: checkInPromptedAt ?? this.checkInPromptedAt,
      response: response ?? this.response,
      respondedAt: respondedAt ?? this.respondedAt,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      incidentId: incidentId ?? this.incidentId,
      hasNotifiedCircle: hasNotifiedCircle ?? this.hasNotifiedCircle,
    );
  }

  static Duration _clamp(Duration d) => d.isNegative ? Duration.zero : d;

  @override
  bool operator ==(Object other) =>
      other is CommuteWatch &&
      other.routeId == routeId &&
      other.expectedArrivalAt == expectedArrivalAt &&
      other.window == window &&
      other.extension == extension &&
      other.checkInPromptedAt == checkInPromptedAt &&
      other.response == response &&
      other.respondedAt == respondedAt &&
      other.arrivedAt == arrivedAt &&
      other.incidentId == incidentId &&
      other.hasNotifiedCircle == hasNotifiedCircle;

  @override
  int get hashCode => Object.hash(
    routeId,
    expectedArrivalAt,
    window,
    extension,
    checkInPromptedAt,
    response,
    respondedAt,
    arrivedAt,
    incidentId,
    hasNotifiedCircle,
  );

  @override
  String toString() =>
      'CommuteWatch($routeId, deadline: $deadline, '
      'escalatesAt: $escalatesAt, response: ${response?.wire})';
}
