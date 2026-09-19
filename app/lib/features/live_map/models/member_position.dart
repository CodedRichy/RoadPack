import 'geo_point.dart';

/// One recorded fix for one member.
///
/// This is the ONLY source of a marker's coordinates. There is deliberately no
/// velocity, no projection and no "estimated current position" field: the app
/// renders where a device last said it was, never where it might be now.
class MemberPosition {
  const MemberPosition({
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.speedKmh,
    this.headingDegrees,
    this.batteryLevel,
    this.accuracyMeters,
    this.source,
  });

  final String userId;
  final double latitude;
  final double longitude;

  /// When the *device* took the fix, not when the server stored it.
  final DateTime recordedAt;

  final double? speedKmh;
  final double? headingDegrees;

  /// 0-100, if the device reported it.
  final int? batteryLevel;
  final double? accuracyMeters;
  final String? source;

  GeoPoint get point => GeoPoint(latitude, longitude);

  MemberPosition copyWith({
    String? userId,
    double? latitude,
    double? longitude,
    DateTime? recordedAt,
    double? speedKmh,
    double? headingDegrees,
    int? batteryLevel,
    double? accuracyMeters,
    String? source,
  }) => MemberPosition(
    userId: userId ?? this.userId,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    recordedAt: recordedAt ?? this.recordedAt,
    speedKmh: speedKmh ?? this.speedKmh,
    headingDegrees: headingDegrees ?? this.headingDegrees,
    batteryLevel: batteryLevel ?? this.batteryLevel,
    accuracyMeters: accuracyMeters ?? this.accuracyMeters,
    source: source ?? this.source,
  );

  /// Builds from a `location_history` row. Returns null when the row has no
  /// usable geometry or timestamp — an unplottable row is dropped, not faked.
  static MemberPosition? tryFromRow(Map<String, dynamic> row) {
    final userId = row['user_id'] as String?;
    if (userId == null) return null;

    final point = GeoPoint.tryParseWkt(row['point']) ?? _tryGeoJson(row['point']);
    if (point == null) return null;

    final rawAt = row['recorded_at'];
    final recordedAt = rawAt is String ? DateTime.tryParse(rawAt) : null;
    if (recordedAt == null) return null;

    // `location_history.speed` is metres/second (geolocator convention).
    final speedMs = (row['speed'] as num?)?.toDouble();

    return MemberPosition(
      userId: userId,
      latitude: point.latitude,
      longitude: point.longitude,
      recordedAt: recordedAt.toUtc(),
      speedKmh: speedMs == null ? null : speedMs * 3.6,
      headingDegrees: (row['heading'] as num?)?.toDouble(),
      batteryLevel: (row['battery_level'] as num?)?.toInt(),
      accuracyMeters: (row['accuracy'] as num?)?.toDouble(),
      source: row['source'] as String?,
    );
  }

  static GeoPoint? _tryGeoJson(Object? value) {
    if (value is Map && value['coordinates'] is List) {
      final coords = value['coordinates'] as List;
      if (coords.length >= 2 && coords[0] is num && coords[1] is num) {
        return GeoPoint(
          (coords[1] as num).toDouble(),
          (coords[0] as num).toDouble(),
        );
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'latitude': latitude,
    'longitude': longitude,
    'recorded_at': recordedAt.toIso8601String(),
    'speed_kmh': speedKmh,
    'heading': headingDegrees,
    'battery_level': batteryLevel,
    'accuracy': accuracyMeters,
    'source': source,
  };

  factory MemberPosition.fromJson(Map<String, dynamic> json) => MemberPosition(
    userId: json['user_id'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    recordedAt: DateTime.parse(json['recorded_at'] as String),
    speedKmh: (json['speed_kmh'] as num?)?.toDouble(),
    headingDegrees: (json['heading'] as num?)?.toDouble(),
    batteryLevel: (json['battery_level'] as num?)?.toInt(),
    accuracyMeters: (json['accuracy'] as num?)?.toDouble(),
    source: json['source'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is MemberPosition &&
      other.userId == userId &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.recordedAt == recordedAt &&
      other.speedKmh == speedKmh &&
      other.headingDegrees == headingDegrees &&
      other.batteryLevel == batteryLevel &&
      other.accuracyMeters == accuracyMeters &&
      other.source == source;

  @override
  int get hashCode => Object.hash(
    userId,
    latitude,
    longitude,
    recordedAt,
    speedKmh,
    headingDegrees,
    batteryLevel,
    accuracyMeters,
    source,
  );
}

/// A member the viewer is entitled to see, with their last known fix (if any).
///
/// Entitlement is resolved before construction. If a [MapMember] exists, the
/// viewer may see them; if the viewer may not, there is no [MapMember] at all.
class MapMember {
  const MapMember({
    required this.userId,
    required this.displayName,
    required this.circleId,
    this.position,
  });

  final String userId;
  final String displayName;
  final String circleId;
  final MemberPosition? position;

  bool get hasFix => position != null;

  MapMember copyWith({
    String? userId,
    String? displayName,
    String? circleId,
    MemberPosition? position,
  }) => MapMember(
    userId: userId ?? this.userId,
    displayName: displayName ?? this.displayName,
    circleId: circleId ?? this.circleId,
    position: position ?? this.position,
  );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'display_name': displayName,
    'circle_id': circleId,
    'position': position?.toJson(),
  };

  factory MapMember.fromJson(Map<String, dynamic> json) => MapMember(
    userId: json['user_id'] as String,
    displayName: json['display_name'] as String,
    circleId: json['circle_id'] as String,
    position: json['position'] == null
        ? null
        : MemberPosition.fromJson(json['position'] as Map<String, dynamic>),
  );

  @override
  bool operator ==(Object other) =>
      other is MapMember &&
      other.userId == userId &&
      other.displayName == displayName &&
      other.circleId == circleId &&
      other.position == position;

  @override
  int get hashCode => Object.hash(userId, displayName, circleId, position);
}
