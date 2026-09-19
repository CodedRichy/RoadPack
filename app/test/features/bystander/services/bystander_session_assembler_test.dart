import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/bystander/bystander.dart';
import 'package:roadpack/features/emergency_profile/models/emergency_contact.dart';

EmergencyContact _c(
  String id,
  String name,
  String phone,
  int priority, {
  bool optedOut = false,
  String? relationship,
}) => EmergencyContact(
  id: id,
  userId: 'u1',
  name: name,
  phone: phone,
  priority: priority,
  optedOut: optedOut,
  relationship: relationship,
);

final _fixAt = DateTime.utc(2026, 9, 8, 10, 15);
final _fix = LocalFix(
  lat: 9.9816,
  lng: 76.2999,
  at: _fixAt,
  accuracyMeters: 12.5,
);

void main() {
  group('BystanderSessionAssembler', () {
    test('assembles a complete session from local state only', () {
      final session = BystanderSessionAssembler.assemble(
        incident: const LocalIncidentSnapshot(id: 'inc-1', active: true),
        victimName: 'Rahul',
        fix: _fix,
        contacts: [
          _c('c2', 'Asha', '+919847012345', 1, relationship: 'Wife'),
          _c('c3', 'Vinod', '+919847099999', 2),
        ],
        bloodGroup: 'O+',
        medicalNotes: 'Diabetic\nPenicillin allergy',
      );

      expect(session.incidentId, 'inc-1');
      expect(session.incidentActive, isTrue);
      expect(session.victimDisplayName, 'Rahul');
      expect(session.lat, 9.9816);
      expect(session.lng, 76.2999);
      expect(session.accuracyMeters, 12.5);
      // The real fix time, not "now": the screen states the age of the fix.
      expect(session.locationAt, _fixAt);
      expect(session.contactName, 'Asha');
      expect(session.contactPhone, '+919847012345');
      expect(session.ice!.bloodGroup, 'O+');
      expect(session.ice!.conditions, ['Diabetic', 'Penicillin allergy']);
      expect(session.ice!.contacts.map((c) => c.name), ['Asha', 'Vinod']);
    });

    test('contact #1 is the lowest priority that has not opted out', () {
      final session = BystanderSessionAssembler.assemble(
        incident: const LocalIncidentSnapshot(id: 'i', active: true),
        contacts: [
          _c('a', 'Opted Out', '+911111111111', 1, optedOut: true),
          _c('b', 'No Number', '', 2),
          _c('c', 'Reachable', '+912222222222', 3),
        ],
      );
      expect(session.contactName, 'Reachable');
      expect(session.ice!.contacts.single.name, 'Reachable');
    });

    test('degrades with no auth, no profile, no contacts and no fix', () {
      final session = BystanderSessionAssembler.assemble(
        incident: const LocalIncidentSnapshot(id: 'inc-offline', active: true),
      );

      expect(session.incidentId, 'inc-offline');
      expect(session.victimDisplayName, kUnnamedRider);
      expect(session.hasLocation, isFalse);
      expect(session.hasContact, isFalse);
      expect(session.ice, isNull);
      // Still a legitimate, renderable session.
      expect(session.incidentActive, isTrue);
    });

    test('a resolved incident seals ICE', () {
      final session = BystanderSessionAssembler.assemble(
        incident: const LocalIncidentSnapshot(id: 'inc-2', active: false),
        victimName: 'Rahul',
        fix: _fix,
        contacts: [_c('c', 'Asha', '+919847012345', 1)],
        bloodGroup: 'O+',
      );

      expect(session.incidentActive, isFalse);
      // Not merely hidden: not assembled.
      expect(session.ice, isNull);
      expect(IceQrPayload.forSession(session), isNull);
      // Contact #1 survives - calling a family member is not gated on ICE.
      expect(session.contactPhone, '+919847012345');
    });

    test('never invents coordinates when there is no fix', () {
      final session = BystanderSessionAssembler.assemble(
        incident: const LocalIncidentSnapshot(id: 'i', active: true),
        victimName: 'Rahul',
      );
      expect(session.lat, isNull);
      expect(session.locationAt, isNull);
      expect(session.readableCoordinates, isNull);
    });
  });

  group('BystanderNotificationController', () {
    BystanderSession session({required bool active}) => BystanderSession(
      incidentId: 'inc-1',
      incidentActive: active,
      victimDisplayName: 'Rahul',
    );

    test('raises once for an active incident', () async {
      final presenter = RecordingBystanderNotificationPresenter();
      final controller = BystanderNotificationController(presenter);

      await controller.sync(session(active: true));
      await controller.sync(session(active: true));

      expect(presenter.shown, hasLength(1));
      expect(controller.showingFor, 'inc-1');
    });

    test('tears down the moment the incident stops being active', () async {
      final presenter = RecordingBystanderNotificationPresenter();
      final controller = BystanderNotificationController(presenter);

      await controller.sync(session(active: true));
      await controller.sync(session(active: false));

      expect(presenter.dismissed, ['inc-1']);
      expect(controller.showingFor, isNull);
    });

    test('a failing presenter cannot throw into the incident path', () async {
      final controller = BystanderNotificationController(_ThrowingPresenter());
      await expectLater(controller.sync(session(active: true)), completes);
    });
  });
}

class _ThrowingPresenter implements BystanderNotificationPresenter {
  @override
  Future<void> show(BystanderSession session) async =>
      throw StateError('notification channel unavailable');

  @override
  Future<void> dismiss(String incidentId) async =>
      throw StateError('notification channel unavailable');
}
