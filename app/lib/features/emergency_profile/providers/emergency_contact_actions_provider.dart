import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/emergency_contact.dart';
import '../services/emergency_contact_repository.dart';
import '../services/ice_notice_service.dart';
import '../services/emergency_contact_validator.dart';
import 'emergency_contacts_provider.dart';

final emergencyContactActionsProvider = Provider<EmergencyContactActions>((ref) {
  return EmergencyContactActions(ref);
});

/// Every mutation to the emergency-contact list goes through here so the
/// FR-020 constraints (1..5, valid Indian mobile, no duplicates, not
/// yourself) are enforced in exactly one place. Screens do not write to the
/// gateway directly.
class EmergencyContactActions {
  EmergencyContactActions(this._ref);

  final Ref _ref;

  EmergencyContactGateway? get _gateway =>
      _ref.read(emergencyContactGatewayProvider);

  List<EmergencyContact> get _current =>
      _ref.read(emergencyContactsProvider).valueOrNull ?? const [];

  Future<EmergencyContact> addContact({
    required String name,
    required String phone,
    String? relationship,
    Set<AlertMethod> alertMethods = AlertMethod.defaults,
  }) async {
    final gateway = _gateway;
    if (gateway == null) throw StateError('Not authenticated');

    final existing = _current;
    final error = EmergencyContactValidator.validateAdd(
      existing: existing,
      name: name,
      phone: phone,
      ownPhone: _ref.read(ownPhoneProvider),
    );
    if (error != null) throw EmergencyContactException(error);

    final created = await gateway.insertContact(
      name: name.trim(),
      phone: EmergencyContactValidator.normalisePhone(phone)!,
      relationship: relationship?.trim().isEmpty ?? true
          ? null
          : relationship!.trim(),
      priority: existing.length + 1,
      alertMethods: alertMethods.isEmpty ? AlertMethod.defaults : alertMethods,
    );

    await _ref.read(emergencyContactsProvider.notifier).refresh();
    return created;
  }

  Future<void> editContact({
    required String contactId,
    String? name,
    String? phone,
    String? relationship,
    Set<AlertMethod>? alertMethods,
  }) async {
    final gateway = _gateway;
    if (gateway == null) throw StateError('Not authenticated');

    final existing = _current;
    String? normalisedPhone;
    if (name != null || phone != null) {
      EmergencyContact? current;
      for (final c in existing) {
        if (c.id == contactId) {
          current = c;
          break;
        }
      }
      final error = EmergencyContactValidator.validateAdd(
        existing: existing,
        name: name ?? current?.name ?? '',
        phone: phone ?? current?.phone ?? '',
        ownPhone: _ref.read(ownPhoneProvider),
        excludeId: contactId,
      );
      if (error != null) throw EmergencyContactException(error);
      if (phone != null) {
        normalisedPhone = EmergencyContactValidator.normalisePhone(phone);
      }
    }

    await gateway.updateContact(
      contactId: contactId,
      name: name?.trim(),
      phone: normalisedPhone,
      relationship: relationship?.trim(),
      alertMethods: alertMethods,
    );
    await _ref.read(emergencyContactsProvider.notifier).refresh();
  }

  Future<void> removeContact(String contactId) async {
    final gateway = _gateway;
    if (gateway == null) throw StateError('Not authenticated');

    final existing = _current;
    final error = EmergencyContactValidator.validateRemove(existing: existing);
    if (error != null) throw EmergencyContactException(error);

    await gateway.deleteContact(contactId);

    // Close the gap so priorities stay a dense 1..n run; a sparse run makes
    // "first person we try" ambiguous in the cascade.
    final remaining = existing.where((c) => c.id != contactId).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
    await gateway.applyPriorities({
      for (var i = 0; i < remaining.length; i++) remaining[i].id: i + 1,
    });

    await _ref.read(emergencyContactsProvider.notifier).refresh();
  }

  /// Reorders the list. Priority is an ordering, not a severity — moving
  /// someone to the top only means the cascade tries them first.
  Future<void> reorder({required int oldIndex, required int newIndex}) async {
    final gateway = _gateway;
    if (gateway == null) throw StateError('Not authenticated');

    final list = [..._current]
      ..sort((a, b) => a.priority.compareTo(b.priority));
    if (oldIndex < 0 || oldIndex >= list.length) return;
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    if (target < 0) target = 0;
    if (target > list.length - 1) target = list.length - 1;
    if (target == oldIndex) return;

    final moved = list.removeAt(oldIndex);
    list.insert(target, moved);

    await gateway.applyPriorities({
      for (var i = 0; i < list.length; i++) list[i].id: i + 1,
    });
    await _ref.read(emergencyContactsProvider.notifier).refresh();
  }

  /// FR-024: fire the one-time "you were listed" notice. Fire-and-forget
  /// from the caller's point of view — a failure here must never block the
  /// user from finishing their profile.
  Future<int> sendPendingListedNotices({required String listedByName}) async {
    final service = _ref.read(iceNoticeServiceProvider);
    if (service == null) return 0;
    final sent = await service.sendPendingNotices(
      listedByName: listedByName,
      contacts: _current,
    );
    if (sent > 0) {
      await _ref.read(emergencyContactsProvider.notifier).refresh();
    }
    return sent;
  }
}
