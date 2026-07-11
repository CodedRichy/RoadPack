import 'package:freezed_annotation/freezed_annotation.dart';

part 'incident.freezed.dart';

@freezed
class Incident with _$Incident {
  const Incident._();

  const factory Incident({
    required String id,
    required String userId,
    required String type,
    String? severity,
    double? confidence,
    double? lat,
    double? lng,
    double? speedAtEvent,
    required String status,
    String? cancelledReason,
    required DateTime createdAt,
    DateTime? firstAckAt,
    DateTime? resolvedAt,
  }) = _Incident;

  factory Incident.fromJson(Map<String, dynamic> json) {
    return Incident(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      severity: json['severity'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      lat: null,
      lng: null,
      speedAtEvent: (json['speed_at_event'] as num?)?.toDouble(),
      status: json['status'] as String,
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

  bool get isResolved => status == 'resolved';
  bool get isCancelled => status == 'cancelled';
  bool get isActive => !isResolved && !isCancelled;
}
