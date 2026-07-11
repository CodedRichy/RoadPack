import 'package:freezed_annotation/freezed_annotation.dart';

import 'event_types.dart';

part 'incident.freezed.dart';

@freezed
class Incident with _$Incident {
  const Incident._();

  const factory Incident({
    required String id,
    required String userId,
    required IncidentType type,
    IncidentSeverity? severity,
    double? confidence,
    double? lat,
    double? lng,
    double? speedAtEvent,
    required IncidentStatus status,
    String? cancelledReason,
    required DateTime createdAt,
    DateTime? firstAckAt,
    DateTime? resolvedAt,
  }) = _Incident;

  factory Incident.fromJson(Map<String, dynamic> json) {
    return Incident(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: IncidentType.values.firstWhere(
        (e) => e.value == json['type'],
      ),
      severity: json['severity'] != null
          ? IncidentSeverity.values.firstWhere(
              (e) => e.value == json['severity'],
            )
          : null,
      confidence: (json['confidence'] as num?)?.toDouble(),
      lat: null,
      lng: null,
      speedAtEvent: (json['speed_at_event'] as num?)?.toDouble(),
      status: IncidentStatus.values.firstWhere(
        (e) => e.value == json['status'],
      ),
      cancelledReason: json['cancelled_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      firstAckAt: json['first_ack_at'] != null
          ? DateTime.parse(json['first_ack_at'] as String)
          : null,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
    );
  }

  bool get isResolved => status == IncidentStatus.resolved;
  bool get isCancelled => status == IncidentStatus.cancelled;
  bool get isActive => !isResolved && !isCancelled;
}
