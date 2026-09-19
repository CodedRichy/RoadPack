import 'pack_status.dart';

/// A row of `pack_ride_members`.
///
/// The gap readout does not source its display decision from here — that comes
/// from `PackGap.displayState`. This model carries identity, role, status and
/// the raw chainage the server last recorded.
class PackMember {
  const PackMember({
    required this.rideId,
    required this.userId,
    required this.role,
    required this.statusCode,
    required this.statusAuto,
    this.displayName,
    this.chainageM,
    this.chainageAt,
    this.statusNote,
    this.incidentId,
    this.offRoute = false,
    this.offRouteDistM,
  });

  final String rideId;
  final String userId;
  final String? displayName;
  final PackRole role;

  /// Metres travelled along the frozen route line. Null until the first fix.
  final double? chainageM;

  /// When that chainage was recorded. Null means never located.
  ///
  /// This is the value "last seen Xm ago" is computed from. It is never
  /// projected forward: a position is only ever as fresh as its timestamp.
  final DateTime? chainageAt;

  final PackStatus statusCode;

  /// True when the server set the status, not the rider. Rendered distinctly
  /// (PM-43) — "stopped" someone typed and "stopped" a sensor guessed are not
  /// the same claim.
  final bool statusAuto;

  final String? statusNote;
  final String? incidentId;
  final bool offRoute;
  final double? offRouteDistM;

  bool get isLeader => role == PackRole.leader;
  bool get isSweep => role == PackRole.sweep;

  PackMember copyWith({
    String? rideId,
    String? userId,
    String? displayName,
    PackRole? role,
    double? chainageM,
    DateTime? chainageAt,
    PackStatus? statusCode,
    bool? statusAuto,
    String? statusNote,
    String? incidentId,
    bool? offRoute,
    double? offRouteDistM,
  }) {
    return PackMember(
      rideId: rideId ?? this.rideId,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      chainageM: chainageM ?? this.chainageM,
      chainageAt: chainageAt ?? this.chainageAt,
      statusCode: statusCode ?? this.statusCode,
      statusAuto: statusAuto ?? this.statusAuto,
      statusNote: statusNote ?? this.statusNote,
      incidentId: incidentId ?? this.incidentId,
      offRoute: offRoute ?? this.offRoute,
      offRouteDistM: offRouteDistM ?? this.offRouteDistM,
    );
  }

  factory PackMember.fromJson(Map<String, dynamic> json) {
    final user = json['users'] as Map<String, dynamic>?;
    return PackMember(
      rideId: json['ride_id'] as String,
      userId: json['user_id'] as String,
      displayName: (json['display_name'] ?? user?['name']) as String?,
      role: PackRole.fromWire(json['role'] as String),
      chainageM: _double(json['chainage_m']),
      chainageAt: _date(json['chainage_at']),
      statusCode: PackStatus.fromWire(json['status_code'] as String),
      statusAuto: json['status_auto'] as bool? ?? false,
      statusNote: json['status_note'] as String?,
      incidentId: json['incident_id'] as String?,
      offRoute: json['off_route'] as bool? ?? false,
      offRouteDistM: _double(json['off_route_dist_m']),
    );
  }

  Map<String, dynamic> toJson() => {
    'ride_id': rideId,
    'user_id': userId,
    'display_name': displayName,
    'role': role.wire,
    'chainage_m': chainageM,
    'chainage_at': chainageAt?.toIso8601String(),
    'status_code': statusCode.wire,
    'status_auto': statusAuto,
    'status_note': statusNote,
    'incident_id': incidentId,
    'off_route': offRoute,
    'off_route_dist_m': offRouteDistM,
  };

  @override
  bool operator ==(Object other) =>
      other is PackMember &&
      other.rideId == rideId &&
      other.userId == userId &&
      other.role == role &&
      other.statusCode == statusCode &&
      other.statusAuto == statusAuto &&
      other.chainageAt == chainageAt;

  @override
  int get hashCode =>
      Object.hash(rideId, userId, role, statusCode, statusAuto, chainageAt);
}

DateTime? _date(Object? v) =>
    v == null ? null : DateTime.parse(v as String).toUtc();

double? _double(Object? v) => v == null ? null : (v as num).toDouble();
