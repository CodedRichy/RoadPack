import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/commute_route.dart';
import '../models/commute_watch.dart';
import '../models/non_arrival_config.dart';
import '../services/commute_service.dart';
import 'non_arrival_config_provider.dart';

/// The commute watch currently in play, or null when nothing is being watched.
///
/// One at a time: a rider has one body and one commute in progress, and a
/// second countdown on screen would only make the first ambiguous.
final commuteWatchProvider =
    NotifierProvider<CommuteWatchNotifier, CommuteWatch?>(
      CommuteWatchNotifier.new,
    );

class CommuteWatchNotifier extends Notifier<CommuteWatch?> {
  @override
  CommuteWatch? build() => null;

  NonArrivalConfig get _config => ref.read(nonArrivalConfigProvider);

  /// Opens a watch for [route] on [day] (defaults to today).
  ///
  /// Returns null and watches nothing when non-arrival is off, the route is
  /// not yet known, or its schedule is incomplete — the client must not show a
  /// countdown the server would never act on.
  CommuteWatch? startFor(CommuteRoute route, {DateTime? day}) {
    final config = _config;
    if (!config.enabled || !route.nonArrivalEnabled) return null;
    if (!route.isKnown || !route.canWatch) return null;

    final on = day ?? DateTime.now();
    if (!route.isActiveOn(on)) return null;

    final expected = route.expectedArrivalOn(on);
    if (expected == null) return null;

    final watch = CommuteWatch(
      routeId: route.id,
      expectedArrivalAt: expected,
      window: config.window,
    );
    state = watch;
    return watch;
  }

  /// Adopts a watch the server has already opened an incident for, e.g. when
  /// a check-in push is tapped.
  void adopt(CommuteWatch watch) => state = watch;

  /// Records that the check-in was actually shown to the rider. The five
  /// minutes before escalation run from here, not from the deadline, so a push
  /// that arrived late does not eat the rider's time to answer.
  void markPrompted({DateTime? at}) {
    final current = state;
    if (current == null || current.checkInPromptedAt != null) return;

    final now = at ?? DateTime.now();
    // A watch that has already escalated does not get its clock reset by the
    // rider finally opening the screen. Restarting the five minutes there
    // would show a countdown to an event that has already happened — the
    // circle has been told, and the screen must say so.
    if (current.phaseAt(now) == CommuteWatchPhase.escalated) return;

    state = current.copyWith(checkInPromptedAt: now);
  }

  /// FR-044. Extends the window and tells nobody.
  ///
  /// The local state is extended first and unconditionally: if the network
  /// call fails, the rider has still pressed the button, and the one thing
  /// this control may never do is leave them looking at a live countdown after
  /// they answered it. The server-side incident is cancelled by the same call
  /// with `cancelled_reason: 'user_running_late'`; a failure there leaves the
  /// server's own five-minute cascade delay as the backstop, which is the
  /// correct way for this to fail.
  Future<void> imRunningLate(RunningLateSnooze snooze) async {
    final current = state;
    if (current == null) return;

    final incidentId = current.incidentId;
    state = current.extendBy(snooze);

    if (incidentId == null) return;
    await _respond(incidentId, CheckInResponse.runningLate);
  }

  /// "I'm fine" — closes the watch and the incident.
  Future<void> imFine() async {
    final current = state;
    if (current == null) return;
    state = current.withResponse(CheckInResponse.fine);
    final incidentId = current.incidentId;
    if (incidentId == null) return;
    await _respond(incidentId, CheckInResponse.fine);
  }

  /// "I need help" — hands straight to the cascade.
  Future<void> needHelp() async {
    final current = state;
    if (current == null) return;
    state = current.withResponse(CheckInResponse.needHelp);
    final incidentId = current.incidentId;
    if (incidentId == null) return;
    await _respond(incidentId, CheckInResponse.needHelp);
  }

  /// The rider reached the destination. Ends the watch quietly.
  void arrived({DateTime? at}) {
    final current = state;
    if (current == null) return;
    state = current.copyWith(arrivedAt: at ?? DateTime.now());
  }

  void clear() => state = null;

  Future<void> _respond(String incidentId, CheckInResponse response) async {
    final service = ref.read(commuteServiceProvider);
    if (service == null) return;
    try {
      await service.respondToCheckIn(
        incidentId: incidentId,
        response: response,
      );
    } on CommuteServiceException catch (e) {
      // An already-closed incident is an ordinary outcome, not a failure.
      if (!e.alreadyClosed) {
        debugPrint('[Commute] Check-in response failed: $e');
      }
    }
  }
}

/// The phase of the active watch, re-evaluated every second while one exists.
///
/// A stream rather than a widget-local timer so every surface that shows the
/// state — the home screen, the check-in sheet, a route card — agrees on it.
final commuteWatchPhaseProvider = StreamProvider<CommuteWatchPhase?>((ref) {
  final watch = ref.watch(commuteWatchProvider);
  if (watch == null) return Stream<CommuteWatchPhase?>.value(null);

  Stream<CommuteWatchPhase?> ticks() async* {
    yield watch.phaseAt(DateTime.now());
    yield* Stream<void>.periodic(
      const Duration(seconds: 1),
    ).map((_) => watch.phaseAt(DateTime.now()));
  }

  return ticks().distinct();
});
