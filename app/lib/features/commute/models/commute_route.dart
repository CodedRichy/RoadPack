import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;

import '../../tracking/db/tracking_database.dart';

/// Where a route came from.
///
/// The distinction is not cosmetic: a learned route has to earn trust by
/// repetition before the app will act on it, while a manually entered one is
/// trusted from the moment the rider saves it — they told us, so we believe
/// them.
enum RouteSource {
  /// Promoted by `RouteLearner` after enough matching trips.
  learned,

  /// Entered by hand (FR-041).
  manual;

  /// Inferred from the stored repetition count.
  ///
  /// `RouteLearner` only ever promotes a candidate at
  /// [CommuteRoute.learningThreshold] trips or more, so a `known_routes` row
  /// with a zero repetition count is one the rider created themselves. This
  /// keeps manual routes on the existing table and RLS policies instead of
  /// asking for a schema change nobody else needs.
  static RouteSource fromRepetitions(int repetitionCount) =>
      repetitionCount == 0 ? RouteSource.manual : RouteSource.learned;
}

/// A commute the app is prepared to watch (FR-040, FR-041).
///
/// Reads the same `known_routes` shape the `non-arrival-check` edge function
/// reads, so what the rider sees on this screen is what the server will act
/// on. Hand-written rather than generated: the schedule fields decide when
/// somebody's family gets called, so the mapping stays where it can be read.
class CommuteRoute {
  const CommuteRoute({
    required this.id,
    required this.originLat,
    required this.originLng,
    required this.destLat,
    required this.destLng,
    this.name,
    this.typicalStart,
    this.typicalDurationMin,
    this.daysActive = const [],
    this.confidence = 0,
    this.repetitionCount = 0,
    this.nonArrivalEnabled = true,
    this.source = RouteSource.learned,
    this.lastTraveled,
  });

  /// Repetitions before a learned pattern is treated as a real commute
  /// (FR-040: "after 3–5 repetitions"). Three is the floor — the point at
  /// which acting on the pattern stops being a guess.
  static const int learningThreshold = 3;

  /// The top of the FR-040 band. At five repetitions the pattern is no longer
  /// provisional and the UI stops hedging about it.
  static const int confidentThreshold = 5;

  final String id;
  final String? name;
  final double originLat;
  final double originLng;
  final double destLat;
  final double destLng;

  /// Typical departure, `HH:mm`, matching `known_routes.typical_start`.
  final String? typicalStart;

  /// Typical door-to-door minutes, matching `known_routes.typical_duration`.
  final int? typicalDurationMin;

  /// ISO weekdays (1 = Monday … 7 = Sunday), matching `days_active` and the
  /// edge function's `currentDay` convention.
  final List<int> daysActive;

  final double confidence;
  final int repetitionCount;
  final bool nonArrivalEnabled;
  final RouteSource source;
  final DateTime? lastTraveled;

  /// Whether this route is real enough to act on.
  ///
  /// Below the threshold the app shows the pattern but will not raise an alarm
  /// on it — a false non-arrival alert on a route the rider never actually
  /// takes is exactly how people learn to switch the feature off.
  bool get isKnown =>
      source == RouteSource.manual || repetitionCount >= learningThreshold;

  bool get isLearning => !isKnown;

  /// Repetitions still needed before this becomes a known route.
  int get repetitionsRemaining =>
      math.max(0, learningThreshold - repetitionCount);

  bool get isConfident =>
      source == RouteSource.manual || repetitionCount >= confidentThreshold;

  /// Whether the schedule is complete enough for a non-arrival watch.
  ///
  /// The edge function skips any route missing a start time, a duration, or
  /// today's weekday, so a route failing this is not being watched however the
  /// toggle reads. The UI must say so rather than imply cover that isn't there.
  bool get canWatch =>
      typicalStart != null &&
      typicalDurationMin != null &&
      daysActive.isNotEmpty;

  /// Whether a non-arrival watch will actually run for this route.
  bool get isWatched => nonArrivalEnabled && isKnown && canWatch;

  int? get typicalStartMinutes => _parseHhMm(typicalStart);

  Duration? get typicalDuration => typicalDurationMin == null
      ? null
      : Duration(minutes: typicalDurationMin!);

  bool isActiveOn(DateTime day) => daysActive.contains(day.weekday);

  /// When the rider is expected to arrive on [day], or null when the schedule
  /// is incomplete.
  DateTime? expectedArrivalOn(DateTime day) {
    final startMinutes = typicalStartMinutes;
    final duration = typicalDuration;
    if (startMinutes == null || duration == null) return null;
    return DateTime(
      day.year,
      day.month,
      day.day,
      startMinutes ~/ 60,
      startMinutes % 60,
    ).add(duration);
  }

  /// A display name that never reads as an empty row.
  String get displayName {
    final n = name?.trim();
    if (n != null && n.isNotEmpty) return n;
    return 'Route ${id.length >= 6 ? id.substring(0, 6) : id}';
  }

  CommuteRoute copyWith({
    String? id,
    String? name,
    double? originLat,
    double? originLng,
    double? destLat,
    double? destLng,
    String? typicalStart,
    int? typicalDurationMin,
    List<int>? daysActive,
    double? confidence,
    int? repetitionCount,
    bool? nonArrivalEnabled,
    RouteSource? source,
    DateTime? lastTraveled,
  }) {
    return CommuteRoute(
      id: id ?? this.id,
      name: name ?? this.name,
      originLat: originLat ?? this.originLat,
      originLng: originLng ?? this.originLng,
      destLat: destLat ?? this.destLat,
      destLng: destLng ?? this.destLng,
      typicalStart: typicalStart ?? this.typicalStart,
      typicalDurationMin: typicalDurationMin ?? this.typicalDurationMin,
      daysActive: daysActive ?? this.daysActive,
      confidence: confidence ?? this.confidence,
      repetitionCount: repetitionCount ?? this.repetitionCount,
      nonArrivalEnabled: nonArrivalEnabled ?? this.nonArrivalEnabled,
      source: source ?? this.source,
      lastTraveled: lastTraveled ?? this.lastTraveled,
    );
  }

  factory CommuteRoute.fromJson(Map<String, dynamic> json) {
    final repetitionCount = (json['repetition_count'] as num?)?.toInt() ?? 0;
    return CommuteRoute(
      id: json['id'] as String,
      name: json['name'] as String?,
      originLat: (json['origin_lat'] as num).toDouble(),
      originLng: (json['origin_lng'] as num).toDouble(),
      destLat: (json['dest_lat'] as num).toDouble(),
      destLng: (json['dest_lng'] as num).toDouble(),
      typicalStart: json['typical_start'] as String?,
      typicalDurationMin: (json['typical_duration_min'] as num?)?.toInt(),
      daysActive: parseDays(json['days_active']),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      repetitionCount: repetitionCount,
      nonArrivalEnabled: json['non_arrival_enabled'] as bool? ?? true,
      source: RouteSource.fromRepetitions(repetitionCount),
      lastTraveled: json['last_traveled'] == null
          ? null
          : DateTime.parse(json['last_traveled'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'origin_lat': originLat,
    'origin_lng': originLng,
    'dest_lat': destLat,
    'dest_lng': destLng,
    'typical_start': typicalStart,
    'typical_duration_min': typicalDurationMin,
    'days_active': daysActive,
    'confidence': confidence,
    'repetition_count': repetitionCount,
    'non_arrival_enabled': nonArrivalEnabled,
    'last_traveled': lastTraveled?.toIso8601String(),
  };

  /// Reads the local drift row that `tracking/` owns.
  factory CommuteRoute.fromLocal(KnownRoutesLocalData row) {
    return CommuteRoute(
      id: row.id,
      name: row.name,
      originLat: row.originLat,
      originLng: row.originLng,
      destLat: row.destLat,
      destLng: row.destLng,
      typicalStart: row.typicalStart,
      typicalDurationMin: row.typicalDurationMin,
      daysActive: parseDays(row.daysActive),
      confidence: row.confidence,
      repetitionCount: row.repetitionCount,
      nonArrivalEnabled: row.nonArrivalEnabled,
      source: RouteSource.fromRepetitions(row.repetitionCount),
      lastTraveled: row.lastTraveled,
    );
  }

  /// Writes back into the local drift row.
  KnownRoutesLocalCompanion toCompanion() {
    return KnownRoutesLocalCompanion.insert(
      id: id,
      originLat: originLat,
      originLng: originLng,
      destLat: destLat,
      destLng: destLng,
      daysActive: jsonEncode(daysActive),
      name: Value(name),
      typicalStart: Value(typicalStart),
      typicalDurationMin: Value(typicalDurationMin),
      confidence: Value(confidence),
      repetitionCount: Value(repetitionCount),
      nonArrivalEnabled: Value(nonArrivalEnabled),
      lastTraveled: Value(lastTraveled),
    );
  }

  /// The `known_routes` row shape the server expects.
  Map<String, dynamic> toServerJson() => {
    'id': id,
    'name': name,
    'origin': 'POINT($originLng $originLat)',
    'destination': 'POINT($destLng $destLat)',
    'typical_start': typicalStart,
    'typical_duration': typicalDurationMin == null
        ? null
        : '$typicalDurationMin minutes',
    'days_active': daysActive,
    'confidence': confidence,
    'repetition_count': repetitionCount,
    'non_arrival_enabled': nonArrivalEnabled,
    'last_traveled': lastTraveled?.toIso8601String(),
  };

  /// Parses `days_active`, which arrives as a JSON array from the server and
  /// as a JSON-encoded string from the local drift row.
  ///
  /// A row we cannot parse degrades to *no* active days rather than to every
  /// day: a route that silently watches seven days a week would alarm the
  /// circle on a Sunday the rider never rides.
  static List<int> parseDays(Object? raw) {
    if (raw == null) return const [];
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! List) return const [];
      return decoded
          .map((d) => d is num ? d.toInt() : int.parse(d.toString()))
          .where((d) => d >= 1 && d <= 7)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  static int? _parseHhMm(String? hhmm) {
    if (hhmm == null) return null;
    final parts = hhmm.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return h * 60 + m;
  }

  @override
  bool operator ==(Object other) =>
      other is CommuteRoute &&
      other.id == id &&
      other.name == name &&
      other.originLat == originLat &&
      other.originLng == originLng &&
      other.destLat == destLat &&
      other.destLng == destLng &&
      other.typicalStart == typicalStart &&
      other.typicalDurationMin == typicalDurationMin &&
      _sameDays(other.daysActive, daysActive) &&
      other.confidence == confidence &&
      other.repetitionCount == repetitionCount &&
      other.nonArrivalEnabled == nonArrivalEnabled &&
      other.source == source &&
      other.lastTraveled == lastTraveled;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    originLat,
    originLng,
    destLat,
    destLng,
    typicalStart,
    typicalDurationMin,
    Object.hashAll(daysActive),
    confidence,
    repetitionCount,
    nonArrivalEnabled,
    source,
    lastTraveled,
  );

  static bool _sameDays(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'CommuteRoute($id, $displayName, ${source.name}, '
      'reps: $repetitionCount, known: $isKnown)';
}
