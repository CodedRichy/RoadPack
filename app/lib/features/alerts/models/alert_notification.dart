import 'package:freezed_annotation/freezed_annotation.dart';

part 'alert_notification.freezed.dart';

@freezed
class AlertNotification with _$AlertNotification {
  const factory AlertNotification({
    required String incidentId,
    required double lat,
    required double lng,
    required String victimName,
    required String victimPhone,
    required DateTime receivedAt,
    @Default(false) bool acknowledged,
  }) = _AlertNotification;

  factory AlertNotification.fromPushData(Map<String, dynamic> data) {
    return AlertNotification(
      incidentId: data['incident_id'] as String,
      lat: double.tryParse(data['lat']?.toString() ?? '') ?? 0.0,
      lng: double.tryParse(data['lng']?.toString() ?? '') ?? 0.0,
      victimName: data['victim_name'] as String? ?? 'Unknown',
      victimPhone: data['victim_phone'] as String? ?? '',
      receivedAt: DateTime.now(),
    );
  }
}
