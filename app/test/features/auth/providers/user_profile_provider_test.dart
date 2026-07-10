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
