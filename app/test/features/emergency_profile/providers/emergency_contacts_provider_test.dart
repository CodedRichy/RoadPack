import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/emergency_profile/models/models.dart';
import 'package:roadpack/features/emergency_profile/providers/providers.dart';
import 'package:roadpack/features/emergency_profile/services/services.dart';

class _FakeGateway implements EmergencyContactGateway {
  _FakeGateway([List<EmergencyContact>? seed]) : rows = [...?seed];

  final List<EmergencyContact> rows;
  var _seq = 0;

  @override
  Future<List<EmergencyContact>> fetchContacts() async =>
      List.of(rows)..sort((a, b) => a.priority.compareTo(b.priority));

  @override
  Future<EmergencyContact> insertContact({
    required String name,
    required String phone,
    String? relationship,
    required int priority,
    required Set<AlertMethod> alertMethods,
  }) async {
    final row = EmergencyContact(
      id: 'new_${++_seq}',
      userId: 'user_1',
      name: name,
      phone: phone,
      relationship: relationship,
      priority: priority,
      alertMethods: alertMethods,
    );
    rows.add(row);
    return row;
  }

  @override
  Future<void> deleteContact(String contactId) async =>
      rows.removeWhere((c) => c.id == contactId);

  @override
  Future<void> applyPriorities(Map<String, int> priorityById) async {
    for (var i = 0; i < rows.length; i++) {
      final p = priorityById[rows[i].id];
      if (p != null) rows[i] = rows[i].copyWith(priority: p);
    }
  }

  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

EmergencyContact _c(int i) => EmergencyContact(
  id: 'ec$i',
  userId: 'user_1',
  name: 'Contact $i',
  phone: '+91987654321$i',
  priority: i,
);

ProviderContainer _container(_FakeGateway gateway) {
  final c = ProviderContainer(
    overrides: [emergencyContactGatewayProvider.overrideWithValue(gateway)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('emergencyContactsProvider', () {
    test('loads contacts in priority order', () async {
      final container = _container(_FakeGateway([_c(3), _c(1), _c(2)]));
      final list = await container.read(emergencyContactsProvider.future);
      expect(list.map((c) => c.id), ['ec1', 'ec2', 'ec3']);
    });
  });

  group('EmergencyContactActions (FR-020 1..5)', () {
    test('adds a contact at the next priority', () async {
      final gateway = _FakeGateway([_c(1)]);
      final container = _container(gateway);
      await container.read(emergencyContactsProvider.future);

      await container
          .read(emergencyContactActionsProvider)
          .addContact(name: 'Achan', phone: '9000000002');

      final list = await container.read(emergencyContactsProvider.future);
      expect(list, hasLength(2));
      expect(list.last.priority, 2);
      expect(list.last.phone, '+919000000002');
    });

    test('refuses a 6th contact', () async {
      final gateway = _FakeGateway([for (var i = 1; i <= 5; i++) _c(i)]);
      final container = _container(gateway);
      await container.read(emergencyContactsProvider.future);

      await expectLater(
        container
            .read(emergencyContactActionsProvider)
            .addContact(name: 'Sixth', phone: '9000000009'),
        throwsA(
          isA<EmergencyContactException>().having(
            (e) => e.error,
            'error',
            EmergencyContactError.tooMany,
          ),
        ),
      );
      expect(gateway.rows, hasLength(5));
    });

    test('refuses a duplicate number', () async {
      final container = _container(_FakeGateway([_c(1)]));
      await container.read(emergencyContactsProvider.future);

      await expectLater(
        container
            .read(emergencyContactActionsProvider)
            .addContact(name: 'Dup', phone: '0987654321 1'),
        throwsA(isA<EmergencyContactException>()),
      );
    });

    test('reorder rewrites priorities to a dense 1..n run', () async {
      final gateway = _FakeGateway([_c(1), _c(2), _c(3)]);
      final container = _container(gateway);
      await container.read(emergencyContactsProvider.future);

      await container.read(emergencyContactActionsProvider).reorder(
        oldIndex: 2,
        newIndex: 0,
      );

      final list = await container.read(emergencyContactsProvider.future);
      expect(list.map((c) => c.id), ['ec3', 'ec1', 'ec2']);
      expect(list.map((c) => c.priority), [1, 2, 3]);
    });

    test('delete closes the priority gap', () async {
      final gateway = _FakeGateway([_c(1), _c(2), _c(3)]);
      final container = _container(gateway);
      await container.read(emergencyContactsProvider.future);

      await container.read(emergencyContactActionsProvider).removeContact('ec2');

      final list = await container.read(emergencyContactsProvider.future);
      expect(list.map((c) => c.id), ['ec1', 'ec3']);
      expect(list.map((c) => c.priority), [1, 2]);
    });
  });

  group('emergencyProfileReadyProvider (FR-004 precondition)', () {
    test('is false with no contacts', () async {
      final container = _container(_FakeGateway());
      await container.read(emergencyContactsProvider.future);
      expect(container.read(emergencyProfileReadyProvider), isFalse);
    });

    test('is true once at least one contact is listed', () async {
      final container = _container(_FakeGateway([_c(1)]));
      await container.read(emergencyContactsProvider.future);
      expect(container.read(emergencyProfileReadyProvider), isTrue);
    });

    test('is false while the list is still loading', () {
      final container = _container(_FakeGateway([_c(1)]));
      expect(container.read(emergencyProfileReadyProvider), isFalse);
    });
  });
}
