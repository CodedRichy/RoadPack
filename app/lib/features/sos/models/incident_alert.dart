import 'package:freezed_annotation/freezed_annotation.dart';

part 'incident_alert.freezed.dart';

@freezed
class IncidentAlert with _$IncidentAlert {
  const factory IncidentAlert({
    required String id,
    required String incidentId,
    String? contactId,
    required String channel,
    required String status,
    DateTime? sentAt,
    DateTime? deliveredAt,
    DateTime? acknowledgedAt,
    String? ackMethod,
    String? error,
  }) = _IncidentAlert;

  factory IncidentAlert.fromJson(Map<String, dynamic> json) {
    return IncidentAlert(
      id: json['id'] as String,
      incidentId: json['incident_id'] as String,
      contactId: json['contact_id'] as String?,
      channel: json['channel'] as String,
      status: json['status'] as String,
      sentAt: json['sent_at'] != null
          ? DateTime.parse(json['sent_at'] as String)
          : null,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at'] as String)
          : null,
      acknowledgedAt: json['acknowledged_at'] != null
          ? DateTime.parse(json['acknowledged_at'] as String)
          : null,
      ackMethod: json['ack_method'] as String?,
      error: json['error'] as String?,
    );
  }
}
