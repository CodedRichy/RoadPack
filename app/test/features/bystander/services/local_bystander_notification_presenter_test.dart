import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/core/network/push_notification_service.dart';
import 'package:roadpack/features/bystander/bystander.dart';

class _FakeDriver implements NotificationDriver {
  _FakeDriver({this.ready = true});

  final bool ready;
  final shown = <Map<String, Object>>[];
  final cancelled = <int>[];
  int readyCalls = 0;

  @override
  Future<bool> ensureReady() async {
    readyCalls++;
    return ready;
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async => shown.add({
    'id': id,
    'title': title,
    'body': body,
    'payload': payload,
  });

  @override
  Future<void> cancel(int id) async => cancelled.add(id);
}

/// Every platform call fails. This is the shape of a phone with the plugin
/// missing, notifications revoked mid-incident, or a channel that died.
class _BrokenDriver implements NotificationDriver {
  @override
  Future<bool> ensureReady() async => throw StateError('no channel');
  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async => throw StateError('no channel');
  @override
  Future<void> cancel(int id) async => throw StateError('no channel');
}

BystanderSession _session({bool active = true}) => BystanderSession(
  incidentId: 'inc-1',
  incidentActive: active,
  victimDisplayName: 'Rahul',
  contactName: 'Asha',
  contactPhone: '+919847012345',
  ice: const IceProfile(bloodGroup: 'O+'),
);

void main() {
  group('LocalBystanderNotificationPresenter', () {
    test('raises one notification carrying the incident id as payload', () async {
      final driver = _FakeDriver();
      await LocalBystanderNotificationPresenter(driver).show(_session());

      expect(driver.shown, hasLength(1));
      expect(driver.shown.single['id'], 907);
      expect(driver.shown.single['payload'], 'inc-1');
    });

    test('the notification itself carries no personal data', () async {
      final driver = _FakeDriver();
      await LocalBystanderNotificationPresenter(driver).show(_session());

      final text =
          '${driver.shown.single['title']} ${driver.shown.single['body']}';
      // It sits on a locked screen. Name, number and medical facts stay
      // behind the screen, where the incident gate still applies.
      expect(text, isNot(contains('Rahul')));
      expect(text, isNot(contains('Asha')));
      expect(text, isNot(contains('919847012345')));
      expect(text, isNot(contains('O+')));
      // And it must not imply an ambulance is on its way.
      expect(text.toLowerCase(), isNot(contains('ambulance')));
      expect(text.toLowerCase(), isNot(contains('dispatch')));
    });

    test('a denied permission degrades to no notification, not a crash', () async {
      final driver = _FakeDriver(ready: false);
      await LocalBystanderNotificationPresenter(driver).show(_session());

      expect(driver.readyCalls, 1);
      expect(driver.shown, isEmpty);
    });

    test('dismiss cancels the one notification id', () async {
      final driver = _FakeDriver();
      await LocalBystanderNotificationPresenter(driver).dismiss('inc-1');
      expect(driver.cancelled, [907]);
    });

    test('a broken platform channel cannot throw at the caller', () async {
      final presenter = LocalBystanderNotificationPresenter(_BrokenDriver());
      await expectLater(presenter.show(_session()), completes);
      await expectLater(presenter.dismiss('inc-1'), completes);
    });

    test('lifecycle: raised while active, torn down on resolve', () async {
      final driver = _FakeDriver();
      final controller = BystanderNotificationController(
        LocalBystanderNotificationPresenter(driver),
      );

      await controller.sync(_session());
      await controller.sync(_session());
      expect(driver.shown, hasLength(1));

      await controller.sync(_session(active: false));
      expect(driver.cancelled, [907]);
      expect(controller.showingFor, isNull);
    });
  });

  test('the Phase-1 action id is what the router advertises', () {
    // The notification action and the FCM data payload land on the same
    // handler; if these ever diverge the tap opens nothing.
    expect(
      IncidentNotificationRouter.openBystanderActionId,
      'open_bystander',
    );
    expect(IncidentNotificationRouter.channelId, 'roadpack_incident_self');
  });
}
