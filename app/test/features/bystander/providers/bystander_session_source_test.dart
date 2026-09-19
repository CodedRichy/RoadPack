import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/auth/providers/user_profile_provider.dart';
import 'package:roadpack/features/bystander/bystander.dart';
import 'package:roadpack/features/emergency_profile/models/emergency_contact.dart';
import 'package:roadpack/features/emergency_profile/providers/emergency_contacts_provider.dart';

/// Stands in for the Supabase-backed profile notifier. Returning a value
/// synchronously is the point: nothing in session assembly may await.
class _FakeProfile extends UserProfileNotifier {
  _FakeProfile(this._profile);
  final UserProfile? _profile;
  @override
  Future<UserProfile?> build() async => _profile;
}

class _FakeContacts extends EmergencyContactsNotifier {
  _FakeContacts(this._contacts);
  final List<EmergencyContact> _contacts;
  @override
  Future<List<EmergencyContact>> build() async => _contacts;
}

/// A fix the device already holds. Never fetched during the test - a network
/// or GNSS call on this path would be the bug.
class _FakeFix extends LocalFixNotifier {
  _FakeFix(this._fix);
  final LocalFix? _fix;
  @override
  LocalFix? build() => _fix;
}

final _fixAt = DateTime.utc(2026, 9, 8, 10, 15);

ProviderContainer _container({
  LocalIncidentSnapshot? incident,
  UserProfile? profile,
  List<EmergencyContact> contacts = const [],
  LocalFix? fix,
}) {
  final container = ProviderContainer(
    overrides: [
      localIncidentProvider.overrideWithValue(incident),
      localFixProvider.overrideWith(() => _FakeFix(fix)),
      userProfileProvider.overrideWith(() => _FakeProfile(profile)),
      emergencyContactsProvider.overrideWith(() => _FakeContacts(contacts)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

const _profile = UserProfile(
  userId: 'u1',
  name: 'Rahul',
  bloodGroup: 'O+',
  medicalNotes: 'Diabetic',
);

void main() {
  test('no incident means no session - the screen is not reachable', () {
    final c = _container();
    expect(c.read(assembledBystanderSessionProvider), isNull);
  });

  test('assembles synchronously with nothing loaded (offline, signed out)', () {
    final c = _container(
      incident: const LocalIncidentSnapshot(id: 'inc-1', active: true),
      fix: LocalFix(lat: 9.9816, lng: 76.2999, at: _fixAt, accuracyMeters: 8),
    );

    // Read immediately: the async sources have not resolved and must not be
    // waited on.
    final session = c.read(assembledBystanderSessionProvider)!;
    expect(session.incidentId, 'inc-1');
    expect(session.victimDisplayName, kUnnamedRider);
    expect(session.lat, 9.9816);
    expect(session.locationAt, _fixAt);
    expect(session.contactPhone, isNull);
  });

  test('fills in profile and contact #1 once local caches are warm', () async {
    final c = _container(
      incident: const LocalIncidentSnapshot(id: 'inc-1', active: true),
      profile: _profile,
      contacts: const [
        EmergencyContact(
          id: 'c1',
          userId: 'u1',
          name: 'Asha',
          phone: '+919847012345',
          priority: 1,
        ),
      ],
      fix: LocalFix(lat: 9.9816, lng: 76.2999, at: _fixAt),
    );

    await c.read(userProfileProvider.future);
    await c.read(emergencyContactsProvider.future);

    final session = c.read(assembledBystanderSessionProvider)!;
    expect(session.victimDisplayName, 'Rahul');
    expect(session.contactName, 'Asha');
    expect(session.contactPhone, '+919847012345');
    expect(IceQrPayload.forSession(session), isNotNull);
  });

  test('a resolved incident seals the ICE card', () async {
    final c = _container(
      incident: const LocalIncidentSnapshot(id: 'inc-1', active: false),
      profile: _profile,
    );
    await c.read(userProfileProvider.future);

    final session = c.read(assembledBystanderSessionProvider)!;
    expect(session.incidentActive, isFalse);
    expect(session.ice, isNull);
    expect(IceQrPayload.forSession(session), isNull);
  });

  test('the notification tracks the incident and tears down on resolve', () {
    final presenter = RecordingBystanderNotificationPresenter();
    final incident = StateProvider<LocalIncidentSnapshot?>(
      (ref) => const LocalIncidentSnapshot(id: 'inc-1', active: true),
    );

    final c = ProviderContainer(
      overrides: [
        localIncidentProvider.overrideWith((ref) => ref.watch(incident)),
        localFixProvider.overrideWith(() => _FakeFix(null)),
        userProfileProvider.overrideWith(() => _FakeProfile(null)),
        emergencyContactsProvider.overrideWith(() => _FakeContacts(const [])),
        bystanderNotificationPresenterProvider.overrideWithValue(presenter),
      ],
    );
    addTearDown(c.dispose);

    final controller = c.read(bystanderNotificationControllerProvider);
    expect(presenter.shown.single.incidentId, 'inc-1');

    c.read(incident.notifier).state = const LocalIncidentSnapshot(
      id: 'inc-1',
      active: false,
    );
    c.read(assembledBystanderSessionProvider);

    expect(presenter.dismissed, ['inc-1']);
    expect(controller.showingFor, isNull);
  });

  test('a failing notification cannot disturb the incident path', () {
    // Isolation is the point of this test: the notification is a
    // presentation concern. If raising it can throw into the provider graph,
    // it can take crash detection, SOS or the cascade with it.
    final incident = StateProvider<LocalIncidentSnapshot?>(
      (ref) => const LocalIncidentSnapshot(id: 'inc-1', active: true),
    );

    final c = ProviderContainer(
      overrides: [
        localIncidentProvider.overrideWith((ref) => ref.watch(incident)),
        localFixProvider.overrideWith(() => _FakeFix(null)),
        userProfileProvider.overrideWith(() => _FakeProfile(null)),
        emergencyContactsProvider.overrideWith(() => _FakeContacts(const [])),
        bystanderNotificationPresenterProvider.overrideWithValue(
          _ExplodingPresenter(),
        ),
      ],
    );
    addTearDown(c.dispose);

    expect(() => c.read(bystanderNotificationControllerProvider), returnsNormally);

    // The incident still reads correctly, and still resolves correctly.
    expect(c.read(assembledBystanderSessionProvider)!.incidentActive, isTrue);
    c.read(incident.notifier).state = const LocalIncidentSnapshot(
      id: 'inc-1',
      active: false,
    );
    final resolved = c.read(assembledBystanderSessionProvider)!;
    expect(resolved.incidentActive, isFalse);
    expect(resolved.ice, isNull);
    expect(IceQrPayload.forSession(resolved), isNull);
  });

  test('the bystander session provider still fails closed by default', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(() => c.read(bystanderSessionProvider), throwsUnimplementedError);
  });
}

class _ExplodingPresenter implements BystanderNotificationPresenter {
  @override
  Future<void> show(BystanderSession session) async =>
      throw StateError('notification subsystem down');

  @override
  Future<void> dismiss(String incidentId) async =>
      throw StateError('notification subsystem down');
}
