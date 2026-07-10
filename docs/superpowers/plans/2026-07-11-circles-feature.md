# Safety Circles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Safety Circles feature -- circle CRUD, invite flow, member/observer management, and emergency contact auto-sync for alert cascade wiring.

**Architecture:** Circle-centric three-layer design (repository -> service -> providers). Circles own the social graph. Family circle members auto-sync to `emergency_contacts` (the authoritative table for alert routing). Observers (non-app users) stored directly in `emergency_contacts` with a new `circle_id` FK. All data flows through Supabase RLS via the authenticated client from the auth feature.

**Tech Stack:** Flutter 3.41+, Riverpod 2.6+, Supabase (supabase_flutter 2.9+), Freezed 2.5+, GoRouter 14.8+, share_plus 10+, Mocktail 1.0+

## Global Constraints

- All Supabase queries go through `authenticatedSupabaseProvider` (from auth feature) -- never use the anonymous client for circles data
- Follow existing auth feature patterns: Freezed models, Mocktail mocking, AsyncNotifier providers, ConsumerWidget/ConsumerStatefulWidget screens
- Material3 dark-first theme -- all new widgets must use `Theme.of(context)` colors, no hardcoded colors
- Circle type enum values must exactly match DB CHECK constraint: `'family'`, `'friends'`, `'commute'`, `'convoy'`
- Circle role enum values must exactly match DB CHECK constraint: `'admin'`, `'member'`, `'observer'`
- Invite codes: 6 chars, alphanumeric (a-z, 0-9), generated client-side with `Random.secure()`
- Family circle limit: max 1 per user (enforced app-side before create)
- Max members from `AppConstants`: family=15, friends=25, commute=100, convoy=50
- EC auto-sync is bidirectional for family circles: joiner becomes EC of each existing member, and each existing member becomes EC of joiner
- Observers are stored in `emergency_contacts` table (not `circle_members`) with `circle_id` FK
- `ON DELETE SET NULL` for `circle_id` FK on emergency_contacts -- deleting a circle preserves EC relationships
- All screens require auth + onboarded (same guard pattern as existing `/home` route)
- Run `dart run build_runner build --delete-conflicting-outputs` after creating Freezed models
- Run all tests from `app/` directory: `flutter test`

---

### Task 1: Database Migration + Dependency + Freezed Models

**Files:**
- Create: `backend/supabase/migrations/00013_add_circle_id_to_emergency_contacts.sql`
- Modify: `app/pubspec.yaml`
- Create: `app/lib/features/circles/models/circle.dart`
- Create: `app/lib/features/circles/models/circle_member.dart`
- Modify: `app/lib/features/circles/models/models.dart`
- Create: `app/test/features/circles/models/circle_test.dart`
- Create: `app/test/features/circles/models/circle_member_test.dart`

**Interfaces:**
- Consumes: nothing (first task)
- Produces:
  - `Circle` freezed class with factory `Circle.fromJson(Map<String, dynamic>)` and fields: `String id`, `String name`, `CircleType type`, `String createdBy`, `String? inviteCode`, `int? maxMembers`, `Map<String, dynamic> settings`, `DateTime createdAt`, `DateTime? expiresAt`
  - `CircleType` enum: `family`, `friends`, `commute`, `convoy` (with `String value` getter returning DB string)
  - `CircleMember` freezed class with factory `CircleMember.fromJson(Map<String, dynamic>)` and fields: `String circleId`, `String userId`, `CircleRole role`, `Map<String, dynamic> permissions`, `DateTime? acceptedAt`, `DateTime joinedAt`, `String? userName` (joined from users table)
  - `CircleRole` enum: `admin`, `member`, `observer` (with `String value` getter returning DB string)
  - `EmergencyContact` freezed class with factory `EmergencyContact.fromJson(Map<String, dynamic>)` and fields: `String id`, `String userId`, `String name`, `String phone`, `String? relationship`, `int priority`, `List<String> alertMethod`, `bool optedOut`, `bool isAppUser`, `String? appUserId`, `String? circleId`

- [ ] **Step 1: Write the migration**

Create `backend/supabase/migrations/00013_add_circle_id_to_emergency_contacts.sql`:

```sql
-- RoadPack v2: add circle_id FK to emergency_contacts for circle-based EC sync

ALTER TABLE emergency_contacts
  ADD COLUMN circle_id UUID REFERENCES circles(id) ON DELETE SET NULL;

CREATE INDEX idx_emergency_contacts_circle ON emergency_contacts(circle_id)
  WHERE circle_id IS NOT NULL;
```

- [ ] **Step 2: Add share_plus dependency**

In `app/pubspec.yaml`, add under `dependencies` (after `url_launcher`):

```yaml
  share_plus: ^10.1.4
```

Run:
```bash
cd app && flutter pub get
```
Expected: resolves successfully, no version conflicts.

- [ ] **Step 3: Write the Circle model**

Create `app/lib/features/circles/models/circle.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'circle.freezed.dart';
part 'circle.g.dart';

enum CircleType {
  family,
  friends,
  commute,
  convoy;

  String get value => name;

  static CircleType fromString(String s) =>
      CircleType.values.firstWhere((e) => e.name == s);

  String get displayName {
    switch (this) {
      case CircleType.family:
        return 'Family';
      case CircleType.friends:
        return 'Friends';
      case CircleType.commute:
        return 'Commute Group';
      case CircleType.convoy:
        return 'Convoy';
    }
  }

  String get defaultName {
    switch (this) {
      case CircleType.family:
        return 'My Family';
      case CircleType.friends:
        return 'Friends';
      case CircleType.commute:
        return 'Commute Group';
      case CircleType.convoy:
        return 'Convoy';
    }
  }

  String get description {
    switch (this) {
      case CircleType.family:
        return 'Your closest people. Members are automatically added as emergency contacts.';
      case CircleType.friends:
        return 'Friends who ride or commute. Add specific members as emergency contacts.';
      case CircleType.commute:
        return 'Regular commute group.';
      case CircleType.convoy:
        return 'Temporary group ride. Set a duration.';
    }
  }
}

@freezed
class Circle with _$Circle {
  const Circle._();

  const factory Circle({
    required String id,
    required String name,
    required CircleType type,
    required String createdBy,
    String? inviteCode,
    int? maxMembers,
    @Default(<String, dynamic>{}) Map<String, dynamic> settings,
    required DateTime createdAt,
    DateTime? expiresAt,
  }) = _Circle;

  factory Circle.fromJson(Map<String, dynamic> json) {
    return Circle(
      id: json['id'] as String,
      name: json['name'] as String,
      type: CircleType.fromString(json['type'] as String),
      createdBy: json['created_by'] as String,
      inviteCode: json['invite_code'] as String?,
      maxMembers: json['max_members'] as int?,
      settings: (json['settings'] as Map<String, dynamic>?) ?? const {},
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
    );
  }

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  bool get isFamily => type == CircleType.family;
}
```

- [ ] **Step 4: Write the CircleMember model**

Create `app/lib/features/circles/models/circle_member.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'circle_member.freezed.dart';
part 'circle_member.g.dart';

enum CircleRole {
  admin,
  member,
  observer;

  String get value => name;

  static CircleRole fromString(String s) =>
      CircleRole.values.firstWhere((e) => e.name == s);

  String get displayName {
    switch (this) {
      case CircleRole.admin:
        return 'Admin';
      case CircleRole.member:
        return 'Member';
      case CircleRole.observer:
        return 'Observer';
    }
  }
}

@freezed
class CircleMember with _$CircleMember {
  const factory CircleMember({
    required String circleId,
    required String userId,
    required CircleRole role,
    @Default(<String, dynamic>{}) Map<String, dynamic> permissions,
    DateTime? acceptedAt,
    required DateTime joinedAt,
    String? userName,
  }) = _CircleMember;

  factory CircleMember.fromJson(Map<String, dynamic> json) {
    final userMap = json['users'] as Map<String, dynamic>?;
    return CircleMember(
      circleId: json['circle_id'] as String,
      userId: json['user_id'] as String,
      role: CircleRole.fromString(json['role'] as String),
      permissions:
          (json['permissions'] as Map<String, dynamic>?) ?? const {},
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'] as String)
          : null,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      userName: userMap?['name'] as String?,
    );
  }

  bool get isAdmin => role == CircleRole.admin;
}
```

Note: `fromJson` extracts `userName` from a joined `users` subquery (Supabase returns `{ ..., "users": { "name": "..." } }` when using `select('*, users(name)')`).

- [ ] **Step 5: Write the EmergencyContact model**

Add to the bottom of `app/lib/features/circles/models/circle_member.dart` (same file -- it's a small model closely related to circle membership):

```dart
@freezed
class EmergencyContact with _$EmergencyContact {
  const factory EmergencyContact({
    required String id,
    required String userId,
    required String name,
    required String phone,
    String? relationship,
    required int priority,
    @Default(<String>['push', 'sms']) List<String> alertMethod,
    @Default(false) bool optedOut,
    @Default(false) bool isAppUser,
    String? appUserId,
    String? circleId,
  }) = _EmergencyContact;

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    final rawAlert = json['alert_method'];
    List<String> alertMethod;
    if (rawAlert is List) {
      alertMethod = rawAlert.cast<String>();
    } else {
      alertMethod = const ['push', 'sms'];
    }

    return EmergencyContact(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      relationship: json['relationship'] as String?,
      priority: json['priority'] as int,
      alertMethod: alertMethod,
      optedOut: json['opted_out'] as bool? ?? false,
      isAppUser: json['is_app_user'] as bool? ?? false,
      appUserId: json['app_user_id'] as String?,
      circleId: json['circle_id'] as String?,
    );
  }
}
```

- [ ] **Step 6: Update barrel export**

Replace `app/lib/features/circles/models/models.dart` with:

```dart
export 'circle.dart';
export 'circle_member.dart';
```

- [ ] **Step 7: Run build_runner**

```bash
cd app && dart run build_runner build --delete-conflicting-outputs
```

Expected: generates `circle.freezed.dart`, `circle.g.dart`, `circle_member.freezed.dart`, `circle_member.g.dart` without errors.

- [ ] **Step 8: Write model tests**

Create `app/test/features/circles/models/circle_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/circles/models/circle.dart';

void main() {
  group('CircleType', () {
    test('fromString round-trips all types', () {
      for (final t in CircleType.values) {
        expect(CircleType.fromString(t.value), t);
      }
    });

    test('displayName returns human-readable text', () {
      expect(CircleType.family.displayName, 'Family');
      expect(CircleType.convoy.displayName, 'Convoy');
    });

    test('defaultName returns pre-fill text', () {
      expect(CircleType.family.defaultName, 'My Family');
      expect(CircleType.commute.defaultName, 'Commute Group');
    });
  });

  group('Circle', () {
    final json = {
      'id': 'c1',
      'name': 'Test Circle',
      'type': 'family',
      'created_by': 'user_1',
      'invite_code': 'abc123',
      'max_members': 15,
      'settings': <String, dynamic>{},
      'created_at': '2026-07-11T10:00:00Z',
      'expires_at': null,
    };

    test('fromJson parses a circle row', () {
      final circle = Circle.fromJson(json);
      expect(circle.id, 'c1');
      expect(circle.name, 'Test Circle');
      expect(circle.type, CircleType.family);
      expect(circle.createdBy, 'user_1');
      expect(circle.inviteCode, 'abc123');
      expect(circle.maxMembers, 15);
      expect(circle.isFamily, isTrue);
    });

    test('isExpired is false when expiresAt is null', () {
      final circle = Circle.fromJson(json);
      expect(circle.isExpired, isFalse);
    });

    test('isExpired is true when expiresAt is in the past', () {
      final circle = Circle.fromJson({
        ...json,
        'expires_at': '2020-01-01T00:00:00Z',
      });
      expect(circle.isExpired, isTrue);
    });

    test('equality works via Freezed', () {
      final a = Circle.fromJson(json);
      final b = Circle.fromJson(json);
      expect(a, equals(b));
    });

    test('copyWith updates name', () {
      final circle = Circle.fromJson(json);
      final renamed = circle.copyWith(name: 'New Name');
      expect(renamed.name, 'New Name');
      expect(renamed.id, circle.id);
    });
  });
}
```

Create `app/test/features/circles/models/circle_member_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/circles/models/circle_member.dart';

void main() {
  group('CircleRole', () {
    test('fromString round-trips all roles', () {
      for (final r in CircleRole.values) {
        expect(CircleRole.fromString(r.value), r);
      }
    });
  });

  group('CircleMember', () {
    final json = {
      'circle_id': 'c1',
      'user_id': 'user_1',
      'role': 'admin',
      'permissions': <String, dynamic>{},
      'accepted_at': '2026-07-11T10:00:00Z',
      'joined_at': '2026-07-11T10:00:00Z',
      'users': {'name': 'Alice'},
    };

    test('fromJson parses a member row with joined user name', () {
      final member = CircleMember.fromJson(json);
      expect(member.circleId, 'c1');
      expect(member.userId, 'user_1');
      expect(member.role, CircleRole.admin);
      expect(member.userName, 'Alice');
      expect(member.isAdmin, isTrue);
    });

    test('fromJson handles missing users join', () {
      final member = CircleMember.fromJson({
        ...json,
        'users': null,
      });
      expect(member.userName, isNull);
    });
  });

  group('EmergencyContact', () {
    final json = {
      'id': 'ec1',
      'user_id': 'user_1',
      'name': 'Mom',
      'phone': '+911234567890',
      'relationship': 'parent',
      'priority': 1,
      'alert_method': ['push', 'sms'],
      'opted_out': false,
      'is_app_user': true,
      'app_user_id': 'user_2',
      'circle_id': 'c1',
    };

    test('fromJson parses an EC row', () {
      final ec = EmergencyContact.fromJson(json);
      expect(ec.id, 'ec1');
      expect(ec.name, 'Mom');
      expect(ec.alertMethod, ['push', 'sms']);
      expect(ec.isAppUser, isTrue);
      expect(ec.circleId, 'c1');
    });

    test('fromJson defaults when nullable fields are null', () {
      final ec = EmergencyContact.fromJson({
        ...json,
        'relationship': null,
        'app_user_id': null,
        'circle_id': null,
        'opted_out': null,
        'is_app_user': null,
      });
      expect(ec.relationship, isNull);
      expect(ec.optedOut, isFalse);
      expect(ec.isAppUser, isFalse);
    });
  });
}
```

- [ ] **Step 9: Run tests**

```bash
cd app && flutter test test/features/circles/models/
```

Expected: all tests PASS.

- [ ] **Step 10: Commit**

```bash
git add backend/supabase/migrations/00013_add_circle_id_to_emergency_contacts.sql \
      app/pubspec.yaml app/pubspec.lock \
      app/lib/features/circles/models/ \
      app/test/features/circles/models/
git commit -m "feat(circles): add migration, share_plus dep, freezed models (Circle, CircleMember, EmergencyContact)"
```

---

### Task 2: Circle Repository (Supabase CRUD + EC Sync)

**Files:**
- Create: `app/lib/features/circles/services/circle_repository.dart`
- Modify: `app/lib/features/circles/services/services.dart`
- Create: `app/test/features/circles/services/circle_repository_test.dart`

**Interfaces:**
- Consumes:
  - `authenticatedSupabaseProvider` from `app/lib/features/auth/providers/authenticated_supabase_provider.dart` -- returns `SupabaseClient?`
  - `Circle.fromJson`, `CircleMember.fromJson`, `EmergencyContact.fromJson` from Task 1
  - `CircleType`, `CircleRole` enums from Task 1
- Produces:
  - `circleRepositoryProvider` -- `Provider<CircleRepository?>` (null when not authenticated)
  - `CircleRepository` class with methods:
    - `Future<List<Circle>> fetchCircles()` -- all circles for current user
    - `Future<Circle> createCircle({required String name, required CircleType type, required String userId, int? maxMembers, DateTime? expiresAt})` -- returns created circle
    - `Future<Circle?> findByInviteCode(String code)` -- lookup by invite code, null if not found/expired
    - `Future<int> memberCount(String circleId)` -- count of circle_members
    - `Future<void> joinCircle({required String circleId, required String userId})` -- insert circle_member with role=member
    - `Future<void> leaveCircle({required String circleId, required String userId})` -- delete circle_member + EC cleanup
    - `Future<List<CircleMember>> fetchMembers(String circleId)` -- members with joined user names
    - `Future<List<EmergencyContact>> fetchObservers(String circleId)` -- ECs where circle_id matches and is_app_user=false
    - `Future<void> addObserver({required String circleId, required String userId, required String name, required String phone, String? relationship})` -- insert EC row
    - `Future<void> removeObserver({required String ecId})` -- delete EC row
    - `Future<void> removeMember({required String circleId, required String userId})` -- admin removes member
    - `Future<void> updateMemberRole({required String circleId, required String userId, required CircleRole role})` -- admin promotes/demotes
    - `Future<void> syncFamilyEc({required String circleId, required String newUserId, required List<CircleMember> existingMembers})` -- creates bidirectional EC rows
    - `Future<void> removeFamilyEc({required String circleId, required String userId})` -- deletes EC rows for leaving user
    - `Future<void> toggleEc({required String circleId, required String ownerUserId, required String targetUserId, required String targetName, required bool enable})` -- non-family explicit EC toggle
    - `Future<void> deleteCircle(String circleId)` -- delete circle (CASCADE)
    - `Future<void> regenerateInviteCode({required String circleId, required String newCode})` -- update invite_code
    - `Future<bool> hasExistingFamilyCircle(String userId)` -- check if user already has a family circle

- [ ] **Step 1: Write the failing test**

Create `app/test/features/circles/services/circle_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:roadpack/features/circles/models/circle.dart';
import 'package:roadpack/features/circles/models/circle_member.dart';
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
    test('fetchCircles returns parsed list', () async {
      final qb = MockSupabaseQueryBuilder();
      final fb = MockPostgrestFilterBuilder();
      when(() => mockClient.from('circles')).thenReturn(qb);
      when(() => qb.select()).thenReturn(fb);
      when(() => fb.order('created_at')).thenAnswer((_) async => [
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

    test('hasExistingFamilyCircle returns true when family circle exists',
        () async {
      final qb = MockSupabaseQueryBuilder();
      final fb = MockPostgrestFilterBuilder();
      final tb = MockPostgrestTransformBuilder();
      when(() => mockClient.from('circles')).thenReturn(qb);
      when(() => qb.select()).thenReturn(fb);
      when(() => fb.eq('type', 'family')).thenReturn(fb);
      when(() => fb.limit(1)).thenReturn(tb);
      when(() => tb.then(any())).thenAnswer((_) async => [
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
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd app && flutter test test/features/circles/services/circle_repository_test.dart
```
Expected: FAIL -- `circle_repository.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `app/lib/features/circles/services/circle_repository.dart`:

```dart
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/authenticated_supabase_provider.dart';
import '../models/circle.dart';
import '../models/circle_member.dart';

final circleRepositoryProvider = Provider<CircleRepository?>((ref) {
  final client = ref.watch(authenticatedSupabaseProvider);
  if (client == null) return null;
  return CircleRepository(client);
});

class CircleRepository {
  CircleRepository(this._client);

  final SupabaseClient _client;

  static const _chars = 'abcdefghijklmnopqrstuvwxyz0123456789';

  static String generateInviteCode() {
    final rng = Random.secure();
    return List.generate(6, (_) => _chars[rng.nextInt(_chars.length)]).join();
  }

  Future<List<Circle>> fetchCircles() async {
    final data = await _client
        .from('circles')
        .select()
        .order('created_at');
    return data.map((row) => Circle.fromJson(row)).toList();
  }

  Future<Circle> createCircle({
    required String name,
    required CircleType type,
    required String userId,
    int? maxMembers,
    DateTime? expiresAt,
  }) async {
    String inviteCode = generateInviteCode();
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final row = await _client.from('circles').insert({
          'name': name,
          'type': type.value,
          'created_by': userId,
          'invite_code': inviteCode,
          'max_members': maxMembers,
          'expires_at': expiresAt?.toIso8601String(),
        }).select().single();

        await _client.from('circle_members').insert({
          'circle_id': row['id'],
          'user_id': userId,
          'role': 'admin',
          'accepted_at': DateTime.now().toIso8601String(),
        });

        return Circle.fromJson(row);
      } on PostgrestException catch (e) {
        if (e.code == '23505' && attempt < 2) {
          inviteCode = generateInviteCode();
          continue;
        }
        rethrow;
      }
    }
    throw StateError('Failed to generate unique invite code after 3 attempts');
  }

  Future<Circle?> findByInviteCode(String code) async {
    final row = await _client
        .from('circles')
        .select()
        .eq('invite_code', code.toLowerCase())
        .maybeSingle();
    if (row == null) return null;
    final circle = Circle.fromJson(row);
    if (circle.isExpired) return null;
    return circle;
  }

  Future<int> memberCount(String circleId) async {
    final data = await _client
        .from('circle_members')
        .select('user_id')
        .eq('circle_id', circleId);
    return data.length;
  }

  Future<void> joinCircle({
    required String circleId,
    required String userId,
  }) async {
    await _client.from('circle_members').insert({
      'circle_id': circleId,
      'user_id': userId,
      'role': 'member',
      'accepted_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<CircleMember>> fetchMembers(String circleId) async {
    final data = await _client
        .from('circle_members')
        .select('*, users(name)')
        .eq('circle_id', circleId)
        .order('joined_at');
    return data.map((row) => CircleMember.fromJson(row)).toList();
  }

  Future<List<EmergencyContact>> fetchObservers(String circleId) async {
    final data = await _client
        .from('emergency_contacts')
        .select()
        .eq('circle_id', circleId)
        .eq('is_app_user', false);
    return data.map((row) => EmergencyContact.fromJson(row)).toList();
  }

  Future<void> addObserver({
    required String circleId,
    required String userId,
    required String name,
    required String phone,
    String? relationship,
  }) async {
    final nextPriority = await _nextEcPriority(userId);
    await _client.from('emergency_contacts').insert({
      'user_id': userId,
      'name': name,
      'phone': phone,
      'relationship': relationship,
      'priority': nextPriority,
      'alert_method': ['sms'],
      'is_app_user': false,
      'circle_id': circleId,
    });
  }

  Future<void> removeObserver({required String ecId}) async {
    await _client.from('emergency_contacts').delete().eq('id', ecId);
  }

  Future<void> removeMember({
    required String circleId,
    required String userId,
  }) async {
    await _client
        .from('circle_members')
        .delete()
        .eq('circle_id', circleId)
        .eq('user_id', userId);
  }

  Future<void> updateMemberRole({
    required String circleId,
    required String userId,
    required CircleRole role,
  }) async {
    await _client
        .from('circle_members')
        .update({'role': role.value})
        .eq('circle_id', circleId)
        .eq('user_id', userId);
  }

  Future<void> syncFamilyEc({
    required String circleId,
    required String newUserId,
    required List<CircleMember> existingMembers,
  }) async {
    for (final member in existingMembers) {
      if (member.userId == newUserId) continue;

      final priorityForMember = await _nextEcPriority(member.userId);
      final priorityForNew = await _nextEcPriority(newUserId);

      await _client.from('emergency_contacts').insert({
        'user_id': member.userId,
        'app_user_id': newUserId,
        'name': '',
        'phone': '',
        'priority': priorityForMember,
        'alert_method': ['push', 'sms'],
        'is_app_user': true,
        'circle_id': circleId,
      });

      await _client.from('emergency_contacts').insert({
        'user_id': newUserId,
        'app_user_id': member.userId,
        'name': member.userName ?? '',
        'phone': '',
        'priority': priorityForNew,
        'alert_method': ['push', 'sms'],
        'is_app_user': true,
        'circle_id': circleId,
      });
    }
  }

  Future<void> removeFamilyEc({
    required String circleId,
    required String userId,
  }) async {
    await _client
        .from('emergency_contacts')
        .delete()
        .eq('circle_id', circleId)
        .or('user_id.eq.$userId,app_user_id.eq.$userId');
  }

  Future<void> toggleEc({
    required String circleId,
    required String ownerUserId,
    required String targetUserId,
    required String targetName,
    required bool enable,
  }) async {
    if (enable) {
      final priority = await _nextEcPriority(ownerUserId);
      await _client.from('emergency_contacts').insert({
        'user_id': ownerUserId,
        'app_user_id': targetUserId,
        'name': targetName,
        'phone': '',
        'priority': priority,
        'alert_method': ['push', 'sms'],
        'is_app_user': true,
        'circle_id': circleId,
      });
    } else {
      await _client
          .from('emergency_contacts')
          .delete()
          .eq('circle_id', circleId)
          .eq('user_id', ownerUserId)
          .eq('app_user_id', targetUserId);
    }
  }

  Future<void> leaveCircle({
    required String circleId,
    required String userId,
  }) async {
    await _client
        .from('circle_members')
        .delete()
        .eq('circle_id', circleId)
        .eq('user_id', userId);
  }

  Future<void> deleteCircle(String circleId) async {
    await _client.from('circles').delete().eq('id', circleId);
  }

  Future<void> regenerateInviteCode({
    required String circleId,
    required String newCode,
  }) async {
    await _client
        .from('circles')
        .update({'invite_code': newCode})
        .eq('id', circleId);
  }

  Future<bool> hasExistingFamilyCircle(String userId) async {
    final data = await _client
        .from('circles')
        .select()
        .eq('type', 'family')
        .limit(1);
    return data.isNotEmpty;
  }

  Future<int> _nextEcPriority(String userId) async {
    final data = await _client
        .from('emergency_contacts')
        .select('priority')
        .eq('user_id', userId)
        .order('priority', ascending: false)
        .limit(1);
    if (data.isEmpty) return 1;
    return (data.first['priority'] as int) + 1;
  }
}
```

- [ ] **Step 4: Update barrel export**

Replace `app/lib/features/circles/services/services.dart` with:

```dart
export 'circle_repository.dart';
```

- [ ] **Step 5: Run tests**

```bash
cd app && flutter test test/features/circles/services/circle_repository_test.dart
```

Expected: all tests PASS (basic parsing + static method tests). Note: most repository methods are Supabase mutation calls that are impractical to mock with Mocktail's fluent builder pattern -- the tests focus on parsing and static logic. Integration tests in a real Supabase environment would cover the mutations.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/circles/services/ \
      app/test/features/circles/services/
git commit -m "feat(circles): add CircleRepository with Supabase CRUD and EC sync"
```

---

### Task 3: Riverpod Providers (Circles List, Detail, Actions)

**Files:**
- Create: `app/lib/features/circles/providers/circles_provider.dart`
- Create: `app/lib/features/circles/providers/circle_detail_provider.dart`
- Create: `app/lib/features/circles/providers/circle_actions_provider.dart`
- Modify: `app/lib/features/circles/providers/providers.dart`
- Create: `app/test/features/circles/providers/circles_provider_test.dart`

**Interfaces:**
- Consumes:
  - `circleRepositoryProvider` from Task 2 -- returns `CircleRepository?`
  - `clerkAuthProvider` from auth feature -- provides `authState.userId`
  - `Circle`, `CircleMember`, `EmergencyContact`, `CircleType`, `CircleRole` from Task 1
- Produces:
  - `circlesProvider` -- `AsyncNotifierProvider<CirclesNotifier, List<Circle>>`: list of user's circles, with `refresh()` method
  - `circleDetailProvider(String circleId)` -- `FutureProvider.family<CircleDetail, String>`: returns `CircleDetail` record containing `Circle circle`, `List<CircleMember> members`, `List<EmergencyContact> observers`
  - `CircleDetail` class with `circle`, `members`, `observers` fields
  - `circleActionsProvider` -- `Provider<CircleActions>`: stateless action dispatcher with methods `createCircle(...)`, `joinCircle(...)`, `leaveCircle(...)`, `removeMember(...)`, `addObserver(...)`, `removeObserver(...)`, `updateRole(...)`, `toggleEc(...)`, `deleteCircle(...)`, `regenerateInviteCode(...)`

- [ ] **Step 1: Write the failing test**

Create `app/test/features/circles/providers/circles_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roadpack/features/auth/models/auth_state.dart';
import 'package:roadpack/features/auth/providers/clerk_auth_provider.dart';
import 'package:roadpack/features/circles/models/circle.dart';
import 'package:roadpack/features/circles/providers/circles_provider.dart';
import 'package:roadpack/features/circles/services/circle_repository.dart';

class MockCircleRepository extends Mock implements CircleRepository {}

final _testCircle = Circle(
  id: 'c1',
  name: 'My Family',
  type: CircleType.family,
  createdBy: 'user_1',
  inviteCode: 'abc123',
  maxMembers: 15,
  createdAt: DateTime(2026, 7, 11),
);

void main() {
  group('CirclesNotifier', () {
    late MockCircleRepository mockRepo;
    late ProviderContainer container;

    setUp(() {
      mockRepo = MockCircleRepository();
      container = ProviderContainer(
        overrides: [
          circleRepositoryProvider.overrideWithValue(mockRepo),
          clerkAuthProvider.overrideWith(
            () => _FakeAuthNotifier(
              const AuthState(
                status: AuthStatus.authenticated,
                userId: 'user_1',
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
    });

    test('build fetches circles from repository', () async {
      when(() => mockRepo.fetchCircles())
          .thenAnswer((_) async => [_testCircle]);

      final sub = container.listen(circlesProvider, (_, __) {});
      await container.read(circlesProvider.future);

      expect(sub.read().value, hasLength(1));
      expect(sub.read().value!.first.name, 'My Family');
    });

    test('refresh re-fetches circles', () async {
      when(() => mockRepo.fetchCircles())
          .thenAnswer((_) async => [_testCircle]);

      await container.read(circlesProvider.future);
      await container.read(circlesProvider.notifier).refresh();

      verify(() => mockRepo.fetchCircles()).called(2);
    });
  });
}

class _FakeAuthNotifier extends AsyncNotifier<AuthState>
    implements ClerkAuthNotifier {
  _FakeAuthNotifier(this._state);
  final AuthState _state;

  @override
  Future<AuthState> build() async => _state;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd app && flutter test test/features/circles/providers/circles_provider_test.dart
```
Expected: FAIL -- `circles_provider.dart` does not exist.

- [ ] **Step 3: Write circles_provider.dart**

Create `app/lib/features/circles/providers/circles_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/circle.dart';
import '../services/circle_repository.dart';

final circlesProvider =
    AsyncNotifierProvider<CirclesNotifier, List<Circle>>(CirclesNotifier.new);

class CirclesNotifier extends AsyncNotifier<List<Circle>> {
  @override
  Future<List<Circle>> build() async {
    final repo = ref.watch(circleRepositoryProvider);
    if (repo == null) return [];
    return repo.fetchCircles();
  }

  Future<void> refresh() async {
    final repo = ref.read(circleRepositoryProvider);
    if (repo == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => repo.fetchCircles());
  }
}
```

- [ ] **Step 4: Write circle_detail_provider.dart**

Create `app/lib/features/circles/providers/circle_detail_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/circle.dart';
import '../models/circle_member.dart';
import '../services/circle_repository.dart';

class CircleDetail {
  const CircleDetail({
    required this.circle,
    required this.members,
    required this.observers,
  });

  final Circle circle;
  final List<CircleMember> members;
  final List<EmergencyContact> observers;

  int get totalCount => members.length + observers.length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CircleDetail &&
          circle == other.circle &&
          _listEquals(members, other.members) &&
          _listEquals(observers, other.observers);

  @override
  int get hashCode => Object.hash(circle, members.length, observers.length);

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

final circleDetailProvider =
    FutureProvider.family<CircleDetail, String>((ref, circleId) async {
  final repo = ref.watch(circleRepositoryProvider);
  if (repo == null) {
    throw StateError('Not authenticated');
  }

  final circles = ref.read(circlesProvider).valueOrNull ?? [];
  final circle = circles.firstWhere(
    (c) => c.id == circleId,
    orElse: () => throw StateError('Circle not found'),
  );

  final members = await repo.fetchMembers(circleId);
  final observers = await repo.fetchObservers(circleId);

  return CircleDetail(
    circle: circle,
    members: members,
    observers: observers,
  );
});
```

Wait -- `circleDetailProvider` references `circlesProvider` which is in a different file. Add the import. The file already imports `circle_repository.dart` which re-exports via the services barrel, but `circlesProvider` is in `circles_provider.dart`. Add the import at the top:

```dart
import 'circles_provider.dart';
```

- [ ] **Step 5: Write circle_actions_provider.dart**

Create `app/lib/features/circles/providers/circle_actions_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/clerk_auth_provider.dart';
import '../models/circle.dart';
import '../models/circle_member.dart';
import '../services/circle_repository.dart';
import 'circles_provider.dart';

final circleActionsProvider = Provider<CircleActions>((ref) {
  return CircleActions(ref);
});

class CircleActions {
  CircleActions(this._ref);

  final Ref _ref;

  CircleRepository? get _repo => _ref.read(circleRepositoryProvider);
  String? get _userId =>
      _ref.read(clerkAuthProvider).valueOrNull?.userId;

  Future<Circle> createCircle({
    required String name,
    required CircleType type,
    int? maxMembers,
    DateTime? expiresAt,
  }) async {
    final repo = _repo;
    final userId = _userId;
    if (repo == null || userId == null) {
      throw StateError('Not authenticated');
    }

    if (type == CircleType.family) {
      final exists = await repo.hasExistingFamilyCircle(userId);
      if (exists) {
        throw StateError('You already have a family circle');
      }
    }

    final circle = await repo.createCircle(
      name: name,
      type: type,
      userId: userId,
      maxMembers: maxMembers,
      expiresAt: expiresAt,
    );

    await _ref.read(circlesProvider.notifier).refresh();
    return circle;
  }

  Future<Circle?> lookupInviteCode(String code) async {
    final repo = _repo;
    if (repo == null) return null;
    return repo.findByInviteCode(code);
  }

  Future<void> joinCircle({required Circle circle}) async {
    final repo = _repo;
    final userId = _userId;
    if (repo == null || userId == null) {
      throw StateError('Not authenticated');
    }

    if (circle.maxMembers != null) {
      final count = await repo.memberCount(circle.id);
      if (count >= circle.maxMembers!) {
        throw StateError('Circle is full');
      }
    }

    await repo.joinCircle(circleId: circle.id, userId: userId);

    if (circle.isFamily) {
      final members = await repo.fetchMembers(circle.id);
      await repo.syncFamilyEc(
        circleId: circle.id,
        newUserId: userId,
        existingMembers: members,
      );
    }

    await _ref.read(circlesProvider.notifier).refresh();
  }

  Future<void> leaveCircle({
    required String circleId,
    required bool isFamily,
  }) async {
    final repo = _repo;
    final userId = _userId;
    if (repo == null || userId == null) return;

    if (isFamily) {
      await repo.removeFamilyEc(circleId: circleId, userId: userId);
    }

    final members = await repo.fetchMembers(circleId);
    final myMembership = members.where((m) => m.userId == userId).firstOrNull;
    if (myMembership != null && myMembership.isAdmin) {
      final others = members.where((m) => m.userId != userId).toList();
      if (others.isEmpty) {
        await repo.deleteCircle(circleId);
        await _ref.read(circlesProvider.notifier).refresh();
        return;
      }
      final hasOtherAdmin = others.any((m) => m.isAdmin);
      if (!hasOtherAdmin) {
        others.sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
        await repo.updateMemberRole(
          circleId: circleId,
          userId: others.first.userId,
          role: CircleRole.admin,
        );
      }
    }

    await repo.leaveCircle(circleId: circleId, userId: userId);
    await _ref.read(circlesProvider.notifier).refresh();
  }

  Future<void> removeMember({
    required String circleId,
    required String userId,
    required bool isFamily,
  }) async {
    final repo = _repo;
    if (repo == null) return;

    if (isFamily) {
      await repo.removeFamilyEc(circleId: circleId, userId: userId);
    }

    await repo.removeMember(circleId: circleId, userId: userId);
  }

  Future<void> addObserver({
    required String circleId,
    required String name,
    required String phone,
    String? relationship,
  }) async {
    final repo = _repo;
    final userId = _userId;
    if (repo == null || userId == null) return;

    await repo.addObserver(
      circleId: circleId,
      userId: userId,
      name: name,
      phone: phone,
      relationship: relationship,
    );
  }

  Future<void> removeObserver({required String ecId}) async {
    final repo = _repo;
    if (repo == null) return;
    await repo.removeObserver(ecId: ecId);
  }

  Future<void> updateRole({
    required String circleId,
    required String userId,
    required CircleRole role,
  }) async {
    final repo = _repo;
    if (repo == null) return;
    await repo.updateMemberRole(
      circleId: circleId,
      userId: userId,
      role: role,
    );
  }

  Future<void> toggleEc({
    required String circleId,
    required String targetUserId,
    required String targetName,
    required bool enable,
  }) async {
    final repo = _repo;
    final userId = _userId;
    if (repo == null || userId == null) return;
    await repo.toggleEc(
      circleId: circleId,
      ownerUserId: userId,
      targetUserId: targetUserId,
      targetName: targetName,
      enable: enable,
    );
  }

  Future<void> deleteCircle(String circleId) async {
    final repo = _repo;
    if (repo == null) return;
    await repo.deleteCircle(circleId);
    await _ref.read(circlesProvider.notifier).refresh();
  }

  Future<String> regenerateInviteCode(String circleId) async {
    final repo = _repo;
    if (repo == null) throw StateError('Not authenticated');
    final newCode = CircleRepository.generateInviteCode();
    await repo.regenerateInviteCode(circleId: circleId, newCode: newCode);
    return newCode;
  }
}
```

- [ ] **Step 6: Update barrel export**

Replace `app/lib/features/circles/providers/providers.dart` with:

```dart
export 'circles_provider.dart';
export 'circle_detail_provider.dart';
export 'circle_actions_provider.dart';
```

- [ ] **Step 7: Run tests**

```bash
cd app && flutter test test/features/circles/providers/circles_provider_test.dart
```

Expected: all tests PASS.

- [ ] **Step 8: Commit**

```bash
git add app/lib/features/circles/providers/ \
      app/test/features/circles/providers/
git commit -m "feat(circles): add Riverpod providers (list, detail, actions)"
```

---

### Task 4: Reusable Widgets (CircleCard, MemberTile, TypePicker, InviteCodeDisplay, InviteCodeInput)

**Files:**
- Create: `app/lib/features/circles/widgets/circle_card.dart`
- Create: `app/lib/features/circles/widgets/member_tile.dart`
- Create: `app/lib/features/circles/widgets/circle_type_picker.dart`
- Create: `app/lib/features/circles/widgets/invite_code_display.dart`
- Create: `app/lib/features/circles/widgets/invite_code_input.dart`
- Modify: `app/lib/features/circles/widgets/widgets.dart`
- Create: `app/test/features/circles/widgets/circle_card_test.dart`
- Create: `app/test/features/circles/widgets/invite_code_input_test.dart`

**Interfaces:**
- Consumes:
  - `Circle`, `CircleType` from Task 1
  - `CircleMember`, `CircleRole`, `EmergencyContact` from Task 1
- Produces:
  - `CircleCard({required Circle circle, required int memberCount, required CircleRole userRole, required VoidCallback onTap})`
  - `MemberTile({required CircleMember member, required bool isCurrentUser, required bool isAdmin, required bool isEc, VoidCallback? onPromote, VoidCallback? onDemote, VoidCallback? onRemove, VoidCallback? onToggleEc, VoidCallback? onLeave})`
  - `CircleTypePicker({required ValueChanged<CircleType> onSelected, CircleType? selected})`
  - `InviteCodeDisplay({required String code, VoidCallback? onShare})`
  - `InviteCodeInput({required ValueChanged<String> onCompleted, String? errorText})`

- [ ] **Step 1: Write CircleCard widget**

Create `app/lib/features/circles/widgets/circle_card.dart`:

```dart
import 'package:flutter/material.dart';

import '../models/circle.dart';
import '../models/circle_member.dart';

class CircleCard extends StatelessWidget {
  const CircleCard({
    super.key,
    required this.circle,
    required this.memberCount,
    required this.userRole,
    required this.onTap,
  });

  final Circle circle;
  final int memberCount;
  final CircleRole userRole;
  final VoidCallback onTap;

  IconData _iconForType(CircleType type) {
    switch (type) {
      case CircleType.family:
        return Icons.favorite;
      case CircleType.friends:
        return Icons.people;
      case CircleType.commute:
        return Icons.route;
      case CircleType.convoy:
        return Icons.two_wheeler;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            _iconForType(circle.type),
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(circle.name),
        subtitle: Text(
          '${circle.type.displayName} -- $memberCount members',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (circle.isExpired)
              Chip(
                label: Text(
                  'Expired',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            if (circle.isExpired) const SizedBox(width: 4),
            Chip(
              label: Text(
                userRole.displayName,
                style: theme.textTheme.labelSmall,
              ),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
```

- [ ] **Step 2: Write MemberTile widget**

Create `app/lib/features/circles/widgets/member_tile.dart`:

```dart
import 'package:flutter/material.dart';

import '../models/circle_member.dart';

class MemberTile extends StatelessWidget {
  const MemberTile({
    super.key,
    required this.member,
    required this.isCurrentUser,
    required this.isAdmin,
    required this.isEc,
    this.onPromote,
    this.onDemote,
    this.onRemove,
    this.onToggleEc,
    this.onLeave,
  });

  final CircleMember member;
  final bool isCurrentUser;
  final bool isAdmin;
  final bool isEc;
  final VoidCallback? onPromote;
  final VoidCallback? onDemote;
  final VoidCallback? onRemove;
  final VoidCallback? onToggleEc;
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = (member.userName ?? '?')
        .split(' ')
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0].toUpperCase())
        .join();

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.secondaryContainer,
        child: Text(
          initials.isEmpty ? '?' : initials,
          style: TextStyle(color: theme.colorScheme.onSecondaryContainer),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              member.userName ?? 'Unknown',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isCurrentUser) ...[
            const SizedBox(width: 4),
            Text('(you)', style: theme.textTheme.bodySmall),
          ],
        ],
      ),
      subtitle: Row(
        children: [
          Chip(
            label: Text(
              member.role.displayName,
              style: theme.textTheme.labelSmall,
            ),
            visualDensity: VisualDensity.compact,
          ),
          if (isEc) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.shield,
              size: 16,
              color: theme.colorScheme.primary,
            ),
          ],
        ],
      ),
      trailing: _buildMenu(context),
    );
  }

  Widget? _buildMenu(BuildContext context) {
    final items = <PopupMenuEntry<String>>[];

    if (isCurrentUser) {
      items.add(const PopupMenuItem(value: 'leave', child: Text('Leave circle')));
    } else if (isAdmin) {
      if (member.isAdmin) {
        items.add(const PopupMenuItem(value: 'demote', child: Text('Demote to member')));
      } else {
        items.add(const PopupMenuItem(value: 'promote', child: Text('Promote to admin')));
      }
      items.add(const PopupMenuItem(value: 'remove', child: Text('Remove')));
      if (onToggleEc != null) {
        items.add(PopupMenuItem(
          value: 'ec',
          child: Text(isEc ? 'Remove as emergency contact' : 'Mark as emergency contact'),
        ));
      }
    }

    if (items.isEmpty) return null;

    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'leave':
            onLeave?.call();
          case 'promote':
            onPromote?.call();
          case 'demote':
            onDemote?.call();
          case 'remove':
            onRemove?.call();
          case 'ec':
            onToggleEc?.call();
        }
      },
      itemBuilder: (_) => items,
    );
  }
}
```

- [ ] **Step 3: Write CircleTypePicker widget**

Create `app/lib/features/circles/widgets/circle_type_picker.dart`:

```dart
import 'package:flutter/material.dart';

import '../models/circle.dart';

class CircleTypePicker extends StatelessWidget {
  const CircleTypePicker({
    super.key,
    required this.onSelected,
    this.selected,
  });

  final ValueChanged<CircleType> onSelected;
  final CircleType? selected;

  IconData _iconForType(CircleType type) {
    switch (type) {
      case CircleType.family:
        return Icons.favorite;
      case CircleType.friends:
        return Icons.people;
      case CircleType.commute:
        return Icons.route;
      case CircleType.convoy:
        return Icons.two_wheeler;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: CircleType.values.map((type) {
        final isSelected = selected == type;
        return Card(
          elevation: isSelected ? 4 : 1,
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surface,
          child: InkWell(
            onTap: () => onSelected(type),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _iconForType(type),
                    size: 32,
                    color: isSelected
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurface,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    type.displayName,
                    style: theme.textTheme.titleSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    type.description,
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
```

- [ ] **Step 4: Write InviteCodeDisplay widget**

Create `app/lib/features/circles/widgets/invite_code_display.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InviteCodeDisplay extends StatelessWidget {
  const InviteCodeDisplay({
    super.key,
    required this.code,
    this.onShare,
  });

  final String code;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Invite Code', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SelectableText(
              code.toUpperCase(),
              style: theme.textTheme.headlineMedium?.copyWith(
                letterSpacing: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy'),
                ),
                if (onShare != null) ...[
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Write InviteCodeInput widget**

Create `app/lib/features/circles/widgets/invite_code_input.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InviteCodeInput extends StatefulWidget {
  const InviteCodeInput({
    super.key,
    required this.onCompleted,
    this.errorText,
  });

  final ValueChanged<String> onCompleted;
  final String? errorText;

  @override
  State<InviteCodeInput> createState() => _InviteCodeInputState();
}

class _InviteCodeInputState extends State<InviteCodeInput> {
  static const _length = 6;
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_length, (_) => TextEditingController());
    _focusNodes = List.generate(_length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onChanged(int index, String value) {
    if (value.isNotEmpty && index < _length - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    final code = _controllers.map((c) => c.text).join();
    if (code.length == _length) {
      widget.onCompleted(code.toLowerCase());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(_length, (i) {
            return SizedBox(
              width: 44,
              child: TextField(
                controller: _controllers[i],
                focusNode: _focusNodes[i],
                textAlign: TextAlign.center,
                maxLength: 1,
                textCapitalization: TextCapitalization.none,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                ],
                onChanged: (v) => _onChanged(i, v),
                decoration: const InputDecoration(
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
              ),
            );
          }),
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.errorText!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}
```

- [ ] **Step 6: Update barrel export**

Replace `app/lib/features/circles/widgets/widgets.dart` with:

```dart
export 'circle_card.dart';
export 'member_tile.dart';
export 'circle_type_picker.dart';
export 'invite_code_display.dart';
export 'invite_code_input.dart';
```

- [ ] **Step 7: Write widget tests**

Create `app/test/features/circles/widgets/circle_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/circles/models/circle.dart';
import 'package:roadpack/features/circles/models/circle_member.dart';
import 'package:roadpack/features/circles/widgets/circle_card.dart';

void main() {
  final testCircle = Circle(
    id: 'c1',
    name: 'My Family',
    type: CircleType.family,
    createdBy: 'u1',
    inviteCode: 'abc123',
    maxMembers: 15,
    createdAt: DateTime(2026, 7, 11),
  );

  testWidgets('CircleCard renders name, type, count, role', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CircleCard(
            circle: testCircle,
            memberCount: 3,
            userRole: CircleRole.admin,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('My Family'), findsOneWidget);
    expect(find.text('Family -- 3 members'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsOneWidget);

    await tester.tap(find.byType(ListTile));
    expect(tapped, isTrue);
  });
}
```

Create `app/test/features/circles/widgets/invite_code_input_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/circles/widgets/invite_code_input.dart';

void main() {
  testWidgets('InviteCodeInput calls onCompleted after 6 chars', (tester) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InviteCodeInput(
            onCompleted: (code) => result = code,
          ),
        ),
      ),
    );

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(6));

    for (var i = 0; i < 6; i++) {
      await tester.enterText(fields.at(i), 'a');
      await tester.pump();
    }

    expect(result, 'aaaaaa');
  });

  testWidgets('InviteCodeInput shows error text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InviteCodeInput(
            onCompleted: (_) {},
            errorText: 'Invalid code',
          ),
        ),
      ),
    );

    expect(find.text('Invalid code'), findsOneWidget);
  });
}
```

- [ ] **Step 8: Run tests**

```bash
cd app && flutter test test/features/circles/widgets/
```

Expected: all tests PASS.

- [ ] **Step 9: Commit**

```bash
git add app/lib/features/circles/widgets/ \
      app/test/features/circles/widgets/
git commit -m "feat(circles): add reusable widgets (card, member tile, type picker, invite code)"
```

---

### Task 5: Circles List Screen

**Files:**
- Create: `app/lib/features/circles/screens/circles_list_screen.dart`
- Modify: `app/lib/features/circles/screens/screens.dart`
- Create: `app/test/features/circles/screens/circles_list_screen_test.dart`

**Interfaces:**
- Consumes:
  - `circlesProvider` from Task 3 -- `AsyncNotifierProvider<CirclesNotifier, List<Circle>>`
  - `clerkAuthProvider` from auth feature -- `authState.userId`
  - `CircleCard` widget from Task 4
  - GoRouter `context.go('/circles/new')`, `context.go('/circles/join')`, `context.go('/circles/$id')`
- Produces:
  - `CirclesListScreen` -- `ConsumerWidget` rendering the list of circles with FAB + join action

- [ ] **Step 1: Write the failing test**

Create `app/test/features/circles/screens/circles_list_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/circles/models/circle.dart';
import 'package:roadpack/features/circles/providers/circles_provider.dart';
import 'package:roadpack/features/circles/screens/circles_list_screen.dart';

void main() {
  final testCircles = [
    Circle(
      id: 'c1',
      name: 'My Family',
      type: CircleType.family,
      createdBy: 'u1',
      inviteCode: 'abc123',
      maxMembers: 15,
      createdAt: DateTime(2026, 7, 11),
    ),
  ];

  testWidgets('shows empty state when no circles', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          circlesProvider.overrideWith(() => _FixedCirclesNotifier([])),
        ],
        child: const MaterialApp(home: CirclesListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create your first Safety Circle'), findsOneWidget);
  });

  testWidgets('shows circle card when circles exist', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          circlesProvider.overrideWith(
            () => _FixedCirclesNotifier(testCircles),
          ),
        ],
        child: const MaterialApp(home: CirclesListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My Family'), findsOneWidget);
  });
}

class _FixedCirclesNotifier extends CirclesNotifier {
  _FixedCirclesNotifier(this._circles);
  final List<Circle> _circles;

  @override
  Future<List<Circle>> build() async => _circles;
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd app && flutter test test/features/circles/screens/circles_list_screen_test.dart
```
Expected: FAIL -- `circles_list_screen.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `app/lib/features/circles/screens/circles_list_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/circle_member.dart';
import '../providers/circles_provider.dart';
import '../widgets/circle_card.dart';

class CirclesListScreen extends ConsumerWidget {
  const CirclesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circlesAsync = ref.watch(circlesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Circles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.login),
            tooltip: 'Join Circle',
            onPressed: () => context.go('/circles/join'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/circles/new'),
        icon: const Icon(Icons.add),
        label: const Text('Create Circle'),
      ),
      body: circlesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Something went wrong'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => ref.read(circlesProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (circles) {
          if (circles.isEmpty) {
            return _buildEmptyState(context);
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(circlesProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: circles.length,
              itemBuilder: (context, index) {
                final circle = circles[index];
                return CircleCard(
                  circle: circle,
                  memberCount: circle.maxMembers ?? 0,
                  userRole: CircleRole.member,
                  onTap: () => context.go('/circles/${circle.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Create your first Safety Circle',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your circles help ensure the right people are alerted when something happens on the road',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go('/circles/new'),
              icon: const Icon(Icons.add),
              label: const Text('Create Circle'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Update barrel export**

Replace `app/lib/features/circles/screens/screens.dart` with:

```dart
export 'circles_list_screen.dart';
```

- [ ] **Step 5: Run tests**

```bash
cd app && flutter test test/features/circles/screens/circles_list_screen_test.dart
```

Expected: all tests PASS.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/circles/screens/ \
      app/test/features/circles/screens/
git commit -m "feat(circles): add circles list screen with empty state"
```

---

### Task 6: Create Circle + Join Circle Screens

**Files:**
- Create: `app/lib/features/circles/screens/create_circle_screen.dart`
- Create: `app/lib/features/circles/screens/join_circle_screen.dart`
- Modify: `app/lib/features/circles/screens/screens.dart`
- Create: `app/test/features/circles/screens/create_circle_screen_test.dart`
- Create: `app/test/features/circles/screens/join_circle_screen_test.dart`

**Interfaces:**
- Consumes:
  - `circleActionsProvider` from Task 3 -- `Provider<CircleActions>` with `createCircle(...)`, `lookupInviteCode(...)`, `joinCircle(...)`
  - `CircleTypePicker` from Task 4
  - `InviteCodeInput` from Task 4
  - `CircleType` enum from Task 1 (`.defaultName`, `.displayName`)
  - `Circle` model from Task 1 (returned by `lookupInviteCode`)
  - `AppConstants.maxFamilyCircleMembers` (15), `AppConstants.maxFriendsCircleMembers` (25), `AppConstants.maxCommuteCircleMembers` (100), `AppConstants.maxConvoyCircleMembers` (50)
  - GoRouter `context.go('/circles/$id')`
- Produces:
  - `CreateCircleScreen` -- `ConsumerStatefulWidget`
  - `JoinCircleScreen` -- `ConsumerStatefulWidget`

- [ ] **Step 1: Write failing test for CreateCircleScreen**

Create `app/test/features/circles/screens/create_circle_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/circles/models/circle.dart';
import 'package:roadpack/features/circles/screens/create_circle_screen.dart';
import 'package:roadpack/features/circles/widgets/circle_type_picker.dart';

void main() {
  testWidgets('CreateCircleScreen shows type picker', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: CreateCircleScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircleTypePicker), findsOneWidget);
    expect(find.text('Family'), findsOneWidget);
    expect(find.text('Friends'), findsOneWidget);
  });

  testWidgets('selecting type pre-fills name field', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: CreateCircleScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Family'));
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(find.byType(TextField).first);
    expect(textField.controller?.text, 'My Family');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd app && flutter test test/features/circles/screens/create_circle_screen_test.dart
```
Expected: FAIL -- `create_circle_screen.dart` does not exist.

- [ ] **Step 3: Write CreateCircleScreen**

Create `app/lib/features/circles/screens/create_circle_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../models/circle.dart';
import '../providers/circle_actions_provider.dart';
import '../widgets/circle_type_picker.dart';

class CreateCircleScreen extends ConsumerStatefulWidget {
  const CreateCircleScreen({super.key});

  @override
  ConsumerState<CreateCircleScreen> createState() =>
      _CreateCircleScreenState();
}

class _CreateCircleScreenState extends ConsumerState<CreateCircleScreen> {
  final _nameController = TextEditingController();
  CircleType? _selectedType;
  Duration _convoyDuration = const Duration(hours: 4);
  bool _isLoading = false;

  static const _convoyDurations = [
    Duration(hours: 2),
    Duration(hours: 4),
    Duration(hours: 8),
    Duration(hours: 12),
    Duration(hours: 24),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  int _maxMembersForType(CircleType type) {
    switch (type) {
      case CircleType.family:
        return AppConstants.maxFamilyCircleMembers;
      case CircleType.friends:
        return AppConstants.maxFriendsCircleMembers;
      case CircleType.commute:
        return AppConstants.maxCommuteCircleMembers;
      case CircleType.convoy:
        return AppConstants.maxConvoyCircleMembers;
    }
  }

  Future<void> _create() async {
    final type = _selectedType;
    final name = _nameController.text.trim();
    if (type == null || name.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final circle = await ref.read(circleActionsProvider).createCircle(
            name: name,
            type: type,
            maxMembers: _maxMembersForType(type),
            expiresAt: type == CircleType.convoy
                ? DateTime.now().add(_convoyDuration)
                : null,
          );
      if (mounted) context.go('/circles/${circle.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Circle')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CircleTypePicker(
              selected: _selectedType,
              onSelected: (type) {
                setState(() {
                  _selectedType = type;
                  _nameController.text = type.defaultName;
                });
              },
            ),
            if (_selectedType != null) ...[
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Circle name',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_selectedType == CircleType.convoy) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<Duration>(
                  value: _convoyDuration,
                  items: _convoyDurations.map((d) {
                    return DropdownMenuItem(
                      value: d,
                      child: Text('${d.inHours} hours'),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _convoyDuration = v);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Duration',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isLoading ? null : _create,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Write JoinCircleScreen**

Create `app/lib/features/circles/screens/join_circle_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/circle.dart';
import '../providers/circle_actions_provider.dart';
import '../widgets/invite_code_input.dart';

class JoinCircleScreen extends ConsumerStatefulWidget {
  const JoinCircleScreen({super.key});

  @override
  ConsumerState<JoinCircleScreen> createState() => _JoinCircleScreenState();
}

class _JoinCircleScreenState extends ConsumerState<JoinCircleScreen> {
  Circle? _preview;
  String? _errorText;
  bool _isLoading = false;
  bool _isJoining = false;

  Future<void> _onCodeCompleted(String code) async {
    setState(() {
      _isLoading = true;
      _errorText = null;
      _preview = null;
    });

    try {
      final circle =
          await ref.read(circleActionsProvider).lookupInviteCode(code);
      if (circle == null) {
        setState(() => _errorText = 'Invalid code');
      } else {
        setState(() => _preview = circle);
      }
    } catch (e) {
      setState(() => _errorText = 'Something went wrong');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _join() async {
    final circle = _preview;
    if (circle == null) return;

    setState(() => _isJoining = true);
    try {
      await ref.read(circleActionsProvider).joinCircle(circle: circle);
      if (mounted) context.go('/circles/${circle.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Join Circle')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter invite code',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            InviteCodeInput(
              onCompleted: _onCodeCompleted,
              errorText: _errorText,
            ),
            if (_isLoading) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_preview != null) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        _preview!.name,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _preview!.type.displayName,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _isJoining ? null : _join,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: _isJoining
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Join'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Write failing test for JoinCircleScreen**

Create `app/test/features/circles/screens/join_circle_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/circles/screens/join_circle_screen.dart';
import 'package:roadpack/features/circles/widgets/invite_code_input.dart';

void main() {
  testWidgets('JoinCircleScreen shows invite code input', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: JoinCircleScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Enter invite code'), findsOneWidget);
    expect(find.byType(InviteCodeInput), findsOneWidget);
  });
}
```

- [ ] **Step 6: Update barrel export**

Replace `app/lib/features/circles/screens/screens.dart` with:

```dart
export 'circles_list_screen.dart';
export 'create_circle_screen.dart';
export 'join_circle_screen.dart';
```

- [ ] **Step 7: Run tests**

```bash
cd app && flutter test test/features/circles/screens/
```

Expected: all tests PASS.

- [ ] **Step 8: Commit**

```bash
git add app/lib/features/circles/screens/ \
      app/test/features/circles/screens/
git commit -m "feat(circles): add create and join circle screens"
```

---

### Task 7: Circle Detail Screen

**Files:**
- Create: `app/lib/features/circles/screens/circle_detail_screen.dart`
- Modify: `app/lib/features/circles/screens/screens.dart`
- Create: `app/test/features/circles/screens/circle_detail_screen_test.dart`

**Interfaces:**
- Consumes:
  - `circleDetailProvider(circleId)` from Task 3 -- `FutureProvider.family<CircleDetail, String>`
  - `circleActionsProvider` from Task 3 -- all action methods
  - `clerkAuthProvider` from auth feature -- for current user ID
  - `MemberTile` from Task 4
  - `InviteCodeDisplay` from Task 4
  - `share_plus` package -- `Share.share(code)` for sharing invite code
  - GoRouter `context.go('/circles')` on leave/delete
- Produces:
  - `CircleDetailScreen` -- `ConsumerWidget` taking `circleId` as constructor param

- [ ] **Step 1: Write the failing test**

Create `app/test/features/circles/screens/circle_detail_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/auth/models/auth_state.dart';
import 'package:roadpack/features/auth/providers/clerk_auth_provider.dart';
import 'package:roadpack/features/circles/models/circle.dart';
import 'package:roadpack/features/circles/models/circle_member.dart';
import 'package:roadpack/features/circles/providers/circle_detail_provider.dart';
import 'package:roadpack/features/circles/screens/circle_detail_screen.dart';

void main() {
  final testDetail = CircleDetail(
    circle: Circle(
      id: 'c1',
      name: 'My Family',
      type: CircleType.family,
      createdBy: 'user_1',
      inviteCode: 'abc123',
      maxMembers: 15,
      createdAt: DateTime(2026, 7, 11),
    ),
    members: [
      CircleMember(
        circleId: 'c1',
        userId: 'user_1',
        role: CircleRole.admin,
        joinedAt: DateTime(2026, 7, 11),
        userName: 'Alice',
      ),
    ],
    observers: [],
  );

  testWidgets('shows circle name and invite code', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          circleDetailProvider('c1')
              .overrideWith((ref) async => testDetail),
          clerkAuthProvider.overrideWith(
            () => _FakeAuthNotifier(const AuthState(
              status: AuthStatus.authenticated,
              userId: 'user_1',
            )),
          ),
        ],
        child: const MaterialApp(
          home: CircleDetailScreen(circleId: 'c1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My Family'), findsOneWidget);
    expect(find.text('ABC123'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
  });
}

class _FakeAuthNotifier extends AsyncNotifier<AuthState>
    implements ClerkAuthNotifier {
  _FakeAuthNotifier(this._state);
  final AuthState _state;

  @override
  Future<AuthState> build() async => _state;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd app && flutter test test/features/circles/screens/circle_detail_screen_test.dart
```
Expected: FAIL -- `circle_detail_screen.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `app/lib/features/circles/screens/circle_detail_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../auth/providers/clerk_auth_provider.dart';
import '../models/circle_member.dart';
import '../providers/circle_actions_provider.dart';
import '../providers/circle_detail_provider.dart';
import '../widgets/invite_code_display.dart';
import '../widgets/member_tile.dart';

class CircleDetailScreen extends ConsumerWidget {
  const CircleDetailScreen({super.key, required this.circleId});

  final String circleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(circleDetailProvider(circleId));
    final currentUserId =
        ref.watch(clerkAuthProvider).valueOrNull?.userId;

    return detailAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Something went wrong'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => ref.invalidate(circleDetailProvider(circleId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (detail) {
        final circle = detail.circle;
        final isAdmin = detail.members
            .any((m) => m.userId == currentUserId && m.isAdmin);

        return Scaffold(
          appBar: AppBar(
            title: Text(circle.name),
            actions: [
              if (isAdmin)
                PopupMenuButton<String>(
                  onSelected: (value) =>
                      _onAdminAction(context, ref, value, circle.id),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'regenerate',
                      child: Text('Regenerate invite code'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete circle'),
                    ),
                  ],
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Chip(label: Text(circle.type.displayName)),
              const SizedBox(height: 12),
              if (circle.inviteCode != null)
                InviteCodeDisplay(
                  code: circle.inviteCode!,
                  onShare: () {
                    SharePlus.instance.share(
                      ShareParams(
                        text: 'Join my Safety Circle on RoadPack! '
                            'Code: ${circle.inviteCode!.toUpperCase()}',
                      ),
                    );
                  },
                ),
              const SizedBox(height: 24),
              Text(
                'Members (${detail.members.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...detail.members.map((member) => MemberTile(
                    member: member,
                    isCurrentUser: member.userId == currentUserId,
                    isAdmin: isAdmin,
                    isEc: false,
                    onLeave: member.userId == currentUserId
                        ? () => _confirmLeave(context, ref, circle.id,
                            circle.isFamily)
                        : null,
                    onPromote: isAdmin && !member.isAdmin
                        ? () => _updateRole(ref, circle.id, member.userId,
                            CircleRole.admin)
                        : null,
                    onDemote: isAdmin && member.isAdmin &&
                            member.userId != currentUserId
                        ? () => _updateRole(ref, circle.id, member.userId,
                            CircleRole.member)
                        : null,
                    onRemove: isAdmin && member.userId != currentUserId
                        ? () => _removeMember(ref, circle.id, member.userId,
                            circle.isFamily)
                        : null,
                    onToggleEc: !circle.isFamily && isAdmin &&
                            member.userId != currentUserId
                        ? () => _toggleEc(ref, circle.id, member.userId,
                            member.userName ?? '', true)
                        : null,
                  )),
              if (detail.observers.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Observers (${detail.observers.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...detail.observers.map((obs) => ListTile(
                      leading: CircleAvatar(
                        child: Icon(Icons.phone,
                            color: Theme.of(context)
                                .colorScheme
                                .onSecondaryContainer),
                      ),
                      title: Text(obs.name),
                      subtitle: Text(_maskPhone(obs.phone)),
                      trailing: isAdmin
                          ? IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () =>
                                  _removeObserver(ref, obs.id),
                            )
                          : const Chip(label: Text('SMS')),
                    )),
              ],
              if (isAdmin) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _showAddObserver(context, ref, circle.id),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Observer'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _maskPhone(String phone) {
    if (phone.length < 4) return phone;
    return '${phone.substring(0, phone.length - 4)}****${phone.substring(phone.length - 4)}';
  }

  Future<void> _confirmLeave(
    BuildContext context,
    WidgetRef ref,
    String circleId,
    bool isFamily,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave circle?'),
        content: Text(isFamily
            ? 'Leaving will remove all emergency contact links from this circle.'
            : 'Are you sure you want to leave?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref
          .read(circleActionsProvider)
          .leaveCircle(circleId: circleId, isFamily: isFamily);
      if (context.mounted) context.go('/circles');
    }
  }

  Future<void> _onAdminAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    String circleId,
  ) async {
    if (action == 'regenerate') {
      final newCode = await ref
          .read(circleActionsProvider)
          .regenerateInviteCode(circleId);
      ref.invalidate(circleDetailProvider(circleId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('New code: ${newCode.toUpperCase()}')),
        );
      }
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete circle?'),
          content: const Text('This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed == true && context.mounted) {
        await ref.read(circleActionsProvider).deleteCircle(circleId);
        if (context.mounted) context.go('/circles');
      }
    }
  }

  void _updateRole(
    WidgetRef ref,
    String circleId,
    String userId,
    CircleRole role,
  ) {
    ref.read(circleActionsProvider).updateRole(
          circleId: circleId,
          userId: userId,
          role: role,
        );
    ref.invalidate(circleDetailProvider(circleId));
  }

  void _removeMember(
    WidgetRef ref,
    String circleId,
    String userId,
    bool isFamily,
  ) {
    ref.read(circleActionsProvider).removeMember(
          circleId: circleId,
          userId: userId,
          isFamily: isFamily,
        );
    ref.invalidate(circleDetailProvider(circleId));
  }

  void _removeObserver(WidgetRef ref, String ecId) {
    ref.read(circleActionsProvider).removeObserver(ecId: ecId);
    ref.invalidate(circleDetailProvider(circleId));
  }

  void _toggleEc(
    WidgetRef ref,
    String circleId,
    String targetUserId,
    String targetName,
    bool enable,
  ) {
    ref.read(circleActionsProvider).toggleEc(
          circleId: circleId,
          targetUserId: targetUserId,
          targetName: targetName,
          enable: enable,
        );
    ref.invalidate(circleDetailProvider(circleId));
  }

  void _showAddObserver(
    BuildContext context,
    WidgetRef ref,
    String circleId,
  ) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add Observer',
                style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Observers receive SMS alerts but don\'t need the app.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                prefixText: '+91 ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final phone = '+91${phoneCtrl.text.trim()}';
                if (name.isEmpty || phoneCtrl.text.trim().length < 10) return;
                await ref.read(circleActionsProvider).addObserver(
                      circleId: circleId,
                      name: name,
                      phone: phone,
                    );
                ref.invalidate(circleDetailProvider(circleId));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Update barrel export**

Replace `app/lib/features/circles/screens/screens.dart` with:

```dart
export 'circles_list_screen.dart';
export 'create_circle_screen.dart';
export 'join_circle_screen.dart';
export 'circle_detail_screen.dart';
```

- [ ] **Step 5: Run tests**

```bash
cd app && flutter test test/features/circles/screens/
```

Expected: all tests PASS.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/circles/screens/ \
      app/test/features/circles/screens/
git commit -m "feat(circles): add circle detail screen with members, observers, admin actions"
```

---

### Task 8: Router Integration + Top-Level Barrel Export

**Files:**
- Modify: `app/lib/core/router/app_router.dart`
- Modify: `app/lib/features/circles/circles.dart`
- Modify: `app/test/core/router/app_router_test.dart`

**Interfaces:**
- Consumes:
  - `CirclesListScreen` from Task 5
  - `CreateCircleScreen` from Task 6
  - `JoinCircleScreen` from Task 6
  - `CircleDetailScreen` from Task 7
  - `authRedirect` function (existing, in app_router.dart)
- Produces:
  - 4 new routes: `/circles`, `/circles/new`, `/circles/join`, `/circles/:id`
  - All require auth + onboarded (same guard as `/home`)

- [ ] **Step 1: Write the failing test**

Add to `app/test/core/router/app_router_test.dart`:

```dart
  test('unauthenticated user on /circles redirects to /sign-in', () {
    expect(
      authRedirect(
        isAuthenticated: false,
        isOnboarded: false,
        location: '/circles',
      ),
      '/sign-in',
    );
  });

  test('authenticated onboarded user on /circles stays', () {
    expect(
      authRedirect(
        isAuthenticated: true,
        isOnboarded: true,
        location: '/circles',
      ),
      isNull,
    );
  });

  test('authenticated non-onboarded user on /circles redirects to /onboarding', () {
    expect(
      authRedirect(
        isAuthenticated: true,
        isOnboarded: false,
        location: '/circles',
      ),
      '/onboarding',
    );
  });
```

- [ ] **Step 2: Run test to verify the new tests pass with existing redirect logic**

```bash
cd app && flutter test test/core/router/app_router_test.dart
```

Expected: the existing `authRedirect` already handles these cases generically (unauthenticated -> `/sign-in`, authenticated + not onboarded + not onboarding route -> `/onboarding`, authenticated + onboarded + any other route -> null). These tests should PASS with the existing logic. If they fail, the redirect function needs updating.

- [ ] **Step 3: Add circle routes to app_router.dart**

Modify `app/lib/core/router/app_router.dart`. Add these imports at the top:

```dart
import '../../features/circles/screens/circles_list_screen.dart';
import '../../features/circles/screens/create_circle_screen.dart';
import '../../features/circles/screens/join_circle_screen.dart';
import '../../features/circles/screens/circle_detail_screen.dart';
```

Add these routes inside the `routes: [...]` list in `appRouterProvider`, after the `/home` route:

```dart
      GoRoute(
        path: '/circles',
        builder: (context, state) => const CirclesListScreen(),
      ),
      GoRoute(
        path: '/circles/new',
        builder: (context, state) => const CreateCircleScreen(),
      ),
      GoRoute(
        path: '/circles/join',
        builder: (context, state) => const JoinCircleScreen(),
      ),
      GoRoute(
        path: '/circles/:id',
        builder: (context, state) {
          final circleId = state.pathParameters['id']!;
          return CircleDetailScreen(circleId: circleId);
        },
      ),
```

- [ ] **Step 4: Update top-level barrel**

The existing `app/lib/features/circles/circles.dart` already exports all barrels. Verify it includes:

```dart
export 'models/models.dart';
export 'providers/providers.dart';
export 'screens/screens.dart';
export 'services/services.dart';
export 'widgets/widgets.dart';
```

- [ ] **Step 5: Run all tests**

```bash
cd app && flutter test
```

Expected: ALL tests pass (existing auth tests + new circles tests + router tests).

- [ ] **Step 6: Commit**

```bash
git add app/lib/core/router/app_router.dart \
      app/lib/features/circles/circles.dart \
      app/test/core/router/app_router_test.dart
git commit -m "feat(circles): add circle routes to GoRouter with auth guards"
```
