import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/tracking_database.dart';

class LearnResult {
  const LearnResult({
    required this.matched,
    required this.promoted,
    this.routeId,
  });
  final bool matched;
  final bool promoted;
  final String? routeId;
}

class RouteLearner {
  RouteLearner(this._db);

  final TrackingDatabase _db;

  static const _matchRadiusM = 500.0;
  static const _timeWindowMin = 90;
  static const _promotionThreshold = 3;

  Future<LearnResult> processCompletedTrip(Trip trip) async {
    if (trip.destLat == null || trip.destLng == null) {
      return const LearnResult(matched: false, promoted: false);
    }

    final candidates = await _db.getAllCandidates();
    final match = _findMatch(candidates, trip);

    if (match != null) {
      final updatedCount = match.tripCount + 1;
      final dayOfWeek = trip.startTime.weekday;
      final days = (jsonDecode(match.daysSeen) as List).cast<int>();
      if (!days.contains(dayOfWeek)) days.add(dayOfWeek);

      final newOriginLat =
          (match.originLat * match.tripCount + trip.originLat) / updatedCount;
      final newOriginLng =
          (match.originLng * match.tripCount + trip.originLng) / updatedCount;
      final newDestLat =
          (match.destLat * match.tripCount + trip.destLat!) / updatedCount;
      final newDestLng =
          (match.destLng * match.tripCount + trip.destLng!) / updatedCount;

      final tripDurationMin =
          trip.endTime?.difference(trip.startTime).inMinutes;
      final int? newDuration;
      if (tripDurationMin != null && match.typicalDurationMin != null) {
        newDuration =
            ((match.typicalDurationMin! * match.tripCount + tripDurationMin) /
                    updatedCount)
                .round();
      } else {
        newDuration = tripDurationMin ?? match.typicalDurationMin;
      }

      final tripStartMinutes =
          trip.startTime.hour * 60 + trip.startTime.minute;
      final existingStart = match.typicalStart != null
          ? _parseTimeToMinutes(match.typicalStart!)
          : tripStartMinutes;
      final newStartMin =
          ((existingStart * match.tripCount + tripStartMinutes) / updatedCount)
              .round();
      final newStart =
          '${(newStartMin ~/ 60).toString().padLeft(2, '0')}:${(newStartMin % 60).toString().padLeft(2, '0')}';

      await _db.updateCandidate(RouteCandidatesCompanion(
        id: Value(match.id),
        originLat: Value(newOriginLat),
        originLng: Value(newOriginLng),
        destLat: Value(newDestLat),
        destLng: Value(newDestLng),
        tripCount: Value(updatedCount),
        daysSeen: Value(jsonEncode(days)),
        typicalStart: Value(newStart),
        typicalDurationMin: Value(newDuration),
        lastTripAt: Value(trip.startTime),
      ));

      if (updatedCount >= _promotionThreshold) {
        final routeId = await _promoteToKnownRoute(
          candidateId: match.id,
          tripCount: updatedCount,
          originLat: newOriginLat,
          originLng: newOriginLng,
          destLat: newDestLat,
          destLng: newDestLng,
          days: days,
          typicalStart: newStart,
          typicalDurationMin: newDuration,
        );
        return LearnResult(matched: true, promoted: true, routeId: routeId);
      }

      return const LearnResult(matched: true, promoted: false);
    }

    // No match — create new candidate
    final dayOfWeek = trip.startTime.weekday;
    final tripDurationMin =
        trip.endTime?.difference(trip.startTime).inMinutes;
    final startMin = trip.startTime.hour * 60 + trip.startTime.minute;
    final startStr =
        '${(startMin ~/ 60).toString().padLeft(2, '0')}:${(startMin % 60).toString().padLeft(2, '0')}';

    await _db.insertCandidate(RouteCandidatesCompanion.insert(
      id: const Uuid().v4(),
      originLat: trip.originLat,
      originLng: trip.originLng,
      destLat: trip.destLat!,
      destLng: trip.destLng!,
      daysSeen: jsonEncode([dayOfWeek]),
      lastTripAt: trip.startTime,
      typicalStart: Value(startStr),
      typicalDurationMin: Value(tripDurationMin),
    ));

    return const LearnResult(matched: false, promoted: false);
  }

  RouteCandidate? _findMatch(List<RouteCandidate> candidates, Trip trip) {
    for (final c in candidates) {
      final originDist = _distanceMeters(
          c.originLat, c.originLng, trip.originLat, trip.originLng);
      final destDist =
          _distanceMeters(c.destLat, c.destLng, trip.destLat!, trip.destLng!);

      if (originDist > _matchRadiusM || destDist > _matchRadiusM) continue;

      if (c.typicalStart != null) {
        final candidateMin = _parseTimeToMinutes(c.typicalStart!);
        final tripMin = trip.startTime.hour * 60 + trip.startTime.minute;
        if ((candidateMin - tripMin).abs() > _timeWindowMin) continue;
      }

      return c;
    }
    return null;
  }

  Future<String> _promoteToKnownRoute({
    required String candidateId,
    required int tripCount,
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required List<int> days,
    required String typicalStart,
    required int? typicalDurationMin,
  }) async {
    final routeId = const Uuid().v4();
    final confidence = min(1.0, tripCount / 10);

    await _db.insertKnownRoute(KnownRoutesLocalCompanion.insert(
      id: routeId,
      originLat: originLat,
      originLng: originLng,
      destLat: destLat,
      destLng: destLng,
      daysActive: jsonEncode(days),
      typicalStart: Value(typicalStart),
      typicalDurationMin: Value(typicalDurationMin),
      confidence: Value(confidence),
      repetitionCount: Value(tripCount),
      lastTraveled: Value(DateTime.now()),
    ));

    await _db.deleteCandidate(candidateId);
    return routeId;
  }

  int _parseTimeToMinutes(String hhmm) {
    final parts = hhmm.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  static double _distanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }
}
