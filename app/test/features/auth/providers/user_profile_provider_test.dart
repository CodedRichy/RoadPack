import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roadpack/features/auth/providers/clerk_auth_provider.dart';
import 'package:roadpack/features/auth/providers/user_profile_provider.dart';
import 'package:roadpack/features/auth/services/clerk_service.dart';

class MockClerkService extends Mock implements ClerkService {}

void main() {
  group('UserProfile', () {
    test('isOnboarded is false when dateOfBirth is null', () {
      const profile = UserProfile(userId: 'u1', name: 'Test');
      expect(profile.isOnboarded, isFalse);
    });

    test('isOnboarded is true when dateOfBirth is set', () {
      final profile = UserProfile(
        userId: 'u1',
        name: 'Test',
        dateOfBirth: DateTime(2000, 1, 1),
      );
      expect(profile.isOnboarded, isTrue);
    });

    test('fromJson parses a fully populated row', () {
      final profile = UserProfile.fromJson({
        'id': 'u1',
        'name': 'Test User',
        'date_of_birth': '2000-01-01',
        'vehicle_type': 'two_wheeler',
        'vehicle_reg': 'KA01AB1234',
      });

      expect(profile.userId, 'u1');
      expect(profile.name, 'Test User');
      expect(profile.dateOfBirth, DateTime.parse('2000-01-01'));
      expect(profile.vehicleType, 'two_wheeler');
      expect(profile.vehicleReg, 'KA01AB1234');
      expect(profile.isOnboarded, isTrue);
    });

    test('fromJson tolerates a webhook-only row (nullable columns)', () {
      final profile = UserProfile.fromJson({
        'id': 'u1',
        'name': '',
        'date_of_birth': null,
        'vehicle_type': null,
        'vehicle_reg': null,
      });

      expect(profile.userId, 'u1');
      expect(profile.dateOfBirth, isNull);
      expect(profile.isOnboarded, isFalse);
    });

    test('fromJson parses safety and tracking settings', () {
      final profile = UserProfile.fromJson({
        'id': 'user_1',
        'name': 'Test',
        'date_of_birth': '2000-01-01',
        'vehicle_type': 'motorcycle',
        'vehicle_reg': 'KL-01-AB-1234',
        'crash_sensitivity': 'high',
        'phone_mount': 'handlebar',
        'non_arrival_delay_min': 10,
        'non_arrival_enabled': true,
        'blood_group': 'O+',
        'medical_notes': 'Asthma',
      });

      expect(profile.crashSensitivity, 'high');
      expect(profile.phoneMountType, 'handlebar');
      expect(profile.nonArrivalDelayMin, 10);
      expect(profile.nonArrivalEnabled, true);
      expect(profile.bloodGroup, 'O+');
      expect(profile.medicalNotes, 'Asthma');
    });

    test('fromJson tolerates null settings', () {
      final profile = UserProfile.fromJson({
        'id': 'user_2',
        'name': null,
        'date_of_birth': null,
        'vehicle_type': null,
        'vehicle_reg': null,
        'crash_sensitivity': null,
        'phone_mount': null,
        'non_arrival_delay_min': null,
        'non_arrival_enabled': null,
        'blood_group': null,
        'medical_notes': null,
      });

      expect(profile.crashSensitivity, isNull);
      expect(profile.phoneMountType, isNull);
      expect(profile.nonArrivalDelayMin, isNull);
      expect(profile.nonArrivalEnabled, isNull);
      expect(profile.bloodGroup, isNull);
      expect(profile.medicalNotes, isNull);
    });

    test('copyWith replaces only the given fields', () {
      const profile = UserProfile(
        userId: 'u1',
        name: 'A',
        crashSensitivity: 'high',
        bloodGroup: 'O+',
      );

      final updated = profile.copyWith(name: 'B');

      expect(updated.name, 'B');
      expect(updated.crashSensitivity, 'high');
      expect(updated.bloodGroup, 'O+');
    });

    test('copyWith clears a nullable field when passed null explicitly', () {
      const profile = UserProfile(
        userId: 'u1',
        bloodGroup: 'O+',
        medicalNotes: 'Asthma',
      );

      final updated = profile.copyWith(bloodGroup: null);

      expect(updated.bloodGroup, isNull);
      expect(updated.medicalNotes, 'Asthma');
    });

    test('equality is value-based', () {
      final a = UserProfile(
        userId: 'u1',
        name: 'A',
        dateOfBirth: DateTime(2000),
      );
      final b = UserProfile(
        userId: 'u1',
        name: 'A',
        dateOfBirth: DateTime(2000),
      );
      final c = UserProfile(
        userId: 'u1',
        name: 'B',
        dateOfBirth: DateTime(2000),
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('UserProfileNotifier.build', () {
    // authenticatedSupabaseProvider and userProfileProvider's Supabase
    // fetch/retry/insert paths are not exercised here: SupabaseClient's
    // query builder (`.from().select().eq().maybeSingle()`) is a fluent
    // chain of generic, non-trivially-mockable types, and instantiating a
    // real SupabaseClient requires network access. This path (not
    // authenticated -> null, no Supabase client ever constructed) is
    // covered because it returns before touching Supabase at all.
    late MockClerkService mockService;
    late ProviderContainer container;

    setUp(() {
      mockService = MockClerkService();
      container = ProviderContainer(
        overrides: [clerkServiceProvider.overrideWithValue(mockService)],
      );
    });

    tearDown(() => container.dispose());

    test('resolves to null when there is no authenticated session', () async {
      when(() => mockService.isSignedIn).thenReturn(false);
      await container.read(clerkAuthProvider.future);

      final profile = await container.read(userProfileProvider.future);

      expect(profile, isNull);
    });

    test('fetchProfile is a no-op when unauthenticated', () async {
      when(() => mockService.isSignedIn).thenReturn(false);
      await container.read(clerkAuthProvider.future);

      await container.read(userProfileProvider.future);
      final notifier = container.read(userProfileProvider.notifier);
      await notifier.fetchProfile();

      expect(container.read(userProfileProvider).value, isNull);
    });

    test('update methods are a no-op when unauthenticated', () async {
      when(() => mockService.isSignedIn).thenReturn(false);
      await container.read(clerkAuthProvider.future);

      await container.read(userProfileProvider.future);
      final notifier = container.read(userProfileProvider.notifier);

      // Should return without throwing (no userId/Supabase client
      // available) rather than attempting a network call.
      await notifier.updateName('New Name');
      await notifier.updateDateOfBirth(DateTime(2000, 1, 1));
      await notifier.updateVehicle('two_wheeler', 'KA01AB1234');
      await notifier.addEmergencyContact(
        name: 'Contact',
        phone: '+911234567890',
        relationship: 'parent',
      );

      expect(container.read(userProfileProvider).value, isNull);
    });
  });
}
