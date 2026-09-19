import 'pack_status.dart';

/// A pack ride. Mirrors the `pack_rides` row the RPCs return.
///
/// Hand-written rather than generated: Pack Mode's models are read by the gap
/// readout, which is the one place in the app where a wrong field is a safety
/// bug, so the mapping is kept where it can be reviewed.
class PackRide {
  const PackRide({
    required this.id,
    required this.leaderId,
    required this.status,
    required this.shareToken,
    required this.expiresAt,
    this.circleId,
    this.name,
    this.shareExpiresAt,
    this.shareRevokedAt,
    this.routeLengthM,
    this.startedAt,
    this.endedAt,
  });

  final String id;
  final String? circleId;
  final String leaderId;
  final String? name;
  final PackRideStatus status;
  final String shareToken;
  final DateTime? shareExpiresAt;
  final DateTime? shareRevokedAt;
  final double? routeLengthM;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime expiresAt;

  bool get isActive => status == PackRideStatus.active;
  bool get isEnded => status == PackRideStatus.ended;

  /// Whether the share link is still a live location feed.
  ///
  /// Revoked, expired, or the ride is over — any one of those and the link is
  /// dead. The UI must never describe a dead link as live, or a live one as
  /// dead: the rider makes a privacy decision on this single boolean.
  bool isShareLive([DateTime? now]) {
    final at = now ?? DateTime.now().toUtc();
    if (isEnded) return false;
    if (shareRevokedAt != null) return false;
    if (shareExpiresAt != null && !shareExpiresAt!.isAfter(at)) return false;
    return expiresAt.isAfter(at);
  }

  PackRide copyWith({
    String? id,
    String? circleId,
    String? leaderId,
    String? name,
    PackRideStatus? status,
    String? shareToken,
    DateTime? shareExpiresAt,
    DateTime? shareRevokedAt,
    double? routeLengthM,
    DateTime? startedAt,
    DateTime? endedAt,
    DateTime? expiresAt,
  }) {
    return PackRide(
      id: id ?? this.id,
      circleId: circleId ?? this.circleId,
      leaderId: leaderId ?? this.leaderId,
      name: name ?? this.name,
      status: status ?? this.status,
      shareToken: shareToken ?? this.shareToken,
      shareExpiresAt: shareExpiresAt ?? this.shareExpiresAt,
      shareRevokedAt: shareRevokedAt ?? this.shareRevokedAt,
      routeLengthM: routeLengthM ?? this.routeLengthM,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  factory PackRide.fromJson(Map<String, dynamic> json) {
    return PackRide(
      id: json['id'] as String,
      circleId: json['circle_id'] as String?,
      leaderId: json['leader_id'] as String,
      name: json['name'] as String?,
      status: PackRideStatus.fromWire(json['status'] as String),
      shareToken: json['share_token'] as String,
      shareExpiresAt: _date(json['share_expires_at']),
      shareRevokedAt: _date(json['share_revoked_at']),
      routeLengthM: _double(json['route_length_m']),
      startedAt: _date(json['started_at']),
      endedAt: _date(json['ended_at']),
      expiresAt: _date(json['expires_at'])!,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'circle_id': circleId,
    'leader_id': leaderId,
    'name': name,
    'status': status.wire,
    'share_token': shareToken,
    'share_expires_at': shareExpiresAt?.toIso8601String(),
    'share_revoked_at': shareRevokedAt?.toIso8601String(),
    'route_length_m': routeLengthM,
    'started_at': startedAt?.toIso8601String(),
    'ended_at': endedAt?.toIso8601String(),
    'expires_at': expiresAt.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is PackRide &&
      other.id == id &&
      other.status == status &&
      other.shareToken == shareToken &&
      other.shareRevokedAt == shareRevokedAt;

  @override
  int get hashCode => Object.hash(id, status, shareToken, shareRevokedAt);
}

DateTime? _date(Object? v) =>
    v == null ? null : DateTime.parse(v as String).toUtc();

double? _double(Object? v) => v == null ? null : (v as num).toDouble();
