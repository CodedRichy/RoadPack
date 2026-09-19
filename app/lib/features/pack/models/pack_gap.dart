import 'pack_status.dart';

/// One row of `fn_pack_member_gaps`.
///
/// This is the product's core readout in data form: how far behind the leader
/// each rider is, measured along the route rather than as the crow flies, and
/// — critically — whether that number may be shown at all.
///
/// [displayState] is decided server-side and is authoritative. The client does
/// not re-derive staleness or off-route from timestamps: a second
/// implementation is a second thing that can drift, and the failure mode of
/// drift here is showing a rider who is face-down in a ditch as riding fine.
class PackGap {
  const PackGap({
    required this.userId,
    required this.role,
    required this.displayState,
    required this.statusCode,
    required this.statusAuto,
    required this.offRoute,
    required this.stale,
    this.chainageM,
    this.gapM,
    this.gapS,
    this.gapEstimated = false,
    this.straightM,
  });

  final String userId;
  final PackRole role;

  /// Metres along the route. Null before the first fix.
  final double? chainageM;

  /// Signed metres relative to the furthest-along member: 0 for the rider at
  /// the front, negative for everyone behind. Null whenever the server
  /// refused to compute one.
  final double? gapM;

  /// The same gap in seconds, derived from the leader's breadcrumb trail.
  final double? gapS;

  /// True when [gapS] could not be read off a breadcrumb and was estimated.
  /// It must render with a visible marker; an estimate presented as a
  /// measurement is a lie with a decimal point.
  final bool gapEstimated;

  final PackDisplayState displayState;
  final PackStatus statusCode;
  final bool statusAuto;
  final bool offRoute;

  /// Straight-line metres from the route, only when off route.
  final double? straightM;

  final bool stale;

  /// The one gate on rendering a number. Never bypass it.
  bool get canShowGap => !displayState.suppressesGap && gapM != null;

  /// The member at the front of the pack has nothing to be behind.
  bool get isFront => canShowGap && gapM!.abs() < 1;

  /// Metres behind the front rider, unsigned, for display.
  double? get metresBehind => gapM?.abs();

  PackGap copyWith({
    String? userId,
    PackRole? role,
    double? chainageM,
    double? gapM,
    double? gapS,
    bool? gapEstimated,
    PackDisplayState? displayState,
    PackStatus? statusCode,
    bool? statusAuto,
    bool? offRoute,
    double? straightM,
    bool? stale,
  }) {
    return PackGap(
      userId: userId ?? this.userId,
      role: role ?? this.role,
      chainageM: chainageM ?? this.chainageM,
      gapM: gapM ?? this.gapM,
      gapS: gapS ?? this.gapS,
      gapEstimated: gapEstimated ?? this.gapEstimated,
      displayState: displayState ?? this.displayState,
      statusCode: statusCode ?? this.statusCode,
      statusAuto: statusAuto ?? this.statusAuto,
      offRoute: offRoute ?? this.offRoute,
      straightM: straightM ?? this.straightM,
      stale: stale ?? this.stale,
    );
  }

  factory PackGap.fromJson(Map<String, dynamic> json) {
    return PackGap(
      userId: json['user_id'] as String,
      role: PackRole.fromWire(json['role'] as String),
      chainageM: _double(json['chainage_m']),
      gapM: _double(json['gap_m']),
      gapS: _double(json['gap_s']),
      gapEstimated: json['gap_estimated'] as bool? ?? false,
      displayState: PackDisplayState.fromWire(json['display_state'] as String),
      statusCode: PackStatus.fromWire(json['status_code'] as String),
      statusAuto: json['status_auto'] as bool? ?? false,
      offRoute: json['off_route'] as bool? ?? false,
      straightM: _double(json['straight_m']),
      stale: json['stale'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'role': role.wire,
    'chainage_m': chainageM,
    'gap_m': gapM,
    'gap_s': gapS,
    'gap_estimated': gapEstimated,
    'display_state': displayState.wire,
    'status_code': statusCode.wire,
    'status_auto': statusAuto,
    'off_route': offRoute,
    'straight_m': straightM,
    'stale': stale,
  };

  @override
  bool operator ==(Object other) =>
      other is PackGap &&
      other.userId == userId &&
      other.gapM == gapM &&
      other.gapS == gapS &&
      other.displayState == displayState &&
      other.statusCode == statusCode &&
      other.statusAuto == statusAuto;

  @override
  int get hashCode =>
      Object.hash(userId, gapM, gapS, displayState, statusCode, statusAuto);
}

double? _double(Object? v) => v == null ? null : (v as num).toDouble();
