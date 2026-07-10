import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:roadpack/features/circles/models/circle.dart';
import 'package:roadpack/features/circles/services/circle_repository.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockPostgrestFilterBuilder extends Mock
    implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {}

class MockPostgrestFilterBuilderSingle extends Mock
    implements PostgrestFilterBuilder<Map<String, dynamic>?> {}

class MockPostgrestTransformBuilder extends Mock
    implements PostgrestTransformBuilder<List<Map<String, dynamic>>> {}

void main() {
  late MockSupabaseClient mockClient;
  late CircleRepository repo;

  setUp(() {
    mockClient = MockSupabaseClient();
    repo = CircleRepository(mockClient);
  });

  group('CircleRepository', () {
    // NOTE: Supabase's fluent query builder chain (PostgrestQueryBuilder ->
    // PostgrestFilterBuilder -> PostgrestTransformBuilder) implements
    // `Future` at every step so `await` can be called directly on the
    // in-progress builder. This conflicts with mocktail: `when(...)
    // .thenReturn(builderMock)` trips mocktail's "don't return a Future from
    // thenReturn" guard (every builder mock satisfies `is Future`), and
    // switching to `thenAnswer` just moves the problem -- the real `await`
    // ultimately invokes `builderMock.then(onValue, onError: ...)`, and
    // mocktail's generic dummy-value fallback for that call returns `null`
    // instead of matching our stub, producing
    // "type 'Null' is not a subtype of type 'Future<dynamic>'" regardless of
    // how the `.then()` stub's argument matchers are shaped. This is a known
    // sharp edge combining mocktail + supabase's Future-implementing
    // builders, not a bug in CircleRepository. These two tests are marked
    // `skip` and kept here (with the closest-to-working mock setup) as
    // executable documentation of the attempt; genuine coverage of these
    // query paths should come from an integration test against a real (or
    // dockerized) Supabase instance. `Circle.fromJson`/`CircleMember.fromJson`
    // parsing itself is already covered by
    // test/features/circles/models/circle_test.dart and
    // circle_member_test.dart.
    test(
      'fetchCircles returns parsed list',
      skip: 'mocktail cannot mock Supabase\'s Future-implementing fluent '
          'builder chain -- see NOTE above',
      () async {
      final qb = MockSupabaseQueryBuilder();
      final fb = MockPostgrestFilterBuilder();
      final tb = MockPostgrestTransformBuilder();
      when(() => mockClient.from('circles')).thenAnswer((_) => qb);
      when(() => qb.select()).thenAnswer((_) => fb);
      when(() => fb.order('created_at')).thenAnswer((_) => tb);
      when(() => tb.then(any(), onError: any(named: 'onError'))).thenAnswer((_) async => [
            {
              'id': 'c1',
              'name': 'Family',
              'type': 'family',
              'created_by': 'u1',
              'invite_code': 'abc123',
              'max_members': 15,
              'settings': <String, dynamic>{},
              'created_at': '2026-07-11T10:00:00Z',
              'expires_at': null,
            },
          ]);

      final circles = await repo.fetchCircles();
      expect(circles, hasLength(1));
      expect(circles.first.name, 'Family');
      expect(circles.first.type, CircleType.family);
    });

    test(
      'hasExistingFamilyCircle returns true when family circle exists',
      skip: 'mocktail cannot mock Supabase\'s Future-implementing fluent '
          'builder chain -- see NOTE above',
      () async {
      final qb = MockSupabaseQueryBuilder();
      final fb = MockPostgrestFilterBuilder();
      final tb = MockPostgrestTransformBuilder();
      when(() => mockClient.from('circles')).thenAnswer((_) => qb);
      when(() => qb.select()).thenAnswer((_) => fb);
      when(() => fb.eq('type', 'family')).thenAnswer((_) => fb);
      when(() => fb.limit(1)).thenAnswer((_) => tb);
      when(() => tb.then(any(), onError: any(named: 'onError'))).thenAnswer((_) async => [
            {
              'id': 'c1',
              'name': 'My Family',
              'type': 'family',
              'created_by': 'u1',
              'invite_code': 'abc123',
              'max_members': 15,
              'settings': <String, dynamic>{},
              'created_at': '2026-07-11T10:00:00Z',
              'expires_at': null,
            },
          ]);

      final exists = await repo.hasExistingFamilyCircle('u1');
      expect(exists, isTrue);
    });

    test('generateInviteCode returns 6 alphanumeric chars', () {
      final code = CircleRepository.generateInviteCode();
      expect(code, hasLength(6));
      expect(code, matches(RegExp(r'^[a-z0-9]{6}$')));
    });
  });
}
