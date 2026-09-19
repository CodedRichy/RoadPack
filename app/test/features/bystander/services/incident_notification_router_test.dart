import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/core/network/push_notification_service.dart';
import 'package:roadpack/features/alerts/models/alert_notification.dart';

/// A payload as `alert-cascade` sends it to a watcher today.
const _alertPayload = <String, dynamic>{
  'incident_id': 'inc-9',
  'lat': '9.9816',
  'lng': '76.2999',
  'victim_name': 'Rahul',
  'victim_phone': '+919847012345',
};

void main() {
  group('IncidentNotificationRouter', () {
    test('leaves the existing alert payload on the alert path', () {
      final routed = IncidentNotificationRouter.route(_alertPayload);
      expect(routed!.target, IncidentNotificationTarget.alert);
      expect(routed.incidentId, 'inc-9');
    });

    test('the alert payload still parses exactly as it did', () {
      // The additive routing must not have changed what the alerts feature
      // sees. If this ever fails, the existing cascade UI has regressed.
      final alert = AlertNotification.fromPushData(_alertPayload);
      expect(alert.incidentId, 'inc-9');
      expect(alert.lat, 9.9816);
      expect(alert.lng, 76.2999);
      expect(alert.victimName, 'Rahul');
      expect(alert.victimPhone, '+919847012345');
    });

    test('routes an own-device incident to the bystander screen', () {
      for (final kind in ['bystander', 'incident_self', 'self_incident']) {
        final routed = IncidentNotificationRouter.route({
          'incident_id': 'inc-1',
          'target': kind,
        });
        expect(
          routed!.target,
          IncidentNotificationTarget.bystander,
          reason: kind,
        );
      }

      final flagged = IncidentNotificationRouter.route({
        'incident_id': 'inc-1',
        'bystander': 'true',
      });
      expect(flagged!.target, IncidentNotificationTarget.bystander);
    });

    test('a payload with no incident id routes nowhere', () {
      expect(IncidentNotificationRouter.route(const {}), isNull);
      expect(
        IncidentNotificationRouter.route(const {'incident_id': ''}),
        isNull,
      );
      expect(
        IncidentNotificationRouter.route(const {'type': 'bystander'}),
        isNull,
      );
    });

    test('Phase 1 identifies as a notification action, not a lock overlay', () {
      expect(IncidentNotificationRouter.openBystanderActionId, isNotEmpty);
      expect(IncidentNotificationRouter.channelId, isNotEmpty);
    });
  });
}
