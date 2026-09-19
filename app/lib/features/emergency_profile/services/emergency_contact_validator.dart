import '../models/emergency_contact.dart';

/// Why an emergency-contact edit was rejected.
enum EmergencyContactError {
  tooMany,
  tooFew,
  missingName,
  invalidPhone,
  duplicatePhone,
  selfContact;

  String get message {
    switch (this) {
      case EmergencyContactError.tooMany:
        return 'You can list up to '
            '${EmergencyContactValidator.maxContacts} emergency contacts.';
      case EmergencyContactError.tooFew:
        return 'There is no contact to remove.';
      case EmergencyContactError.missingName:
        return 'Add a name so a bystander knows who they are calling.';
      case EmergencyContactError.invalidPhone:
        return 'Enter a 10-digit Indian mobile number.';
      case EmergencyContactError.duplicatePhone:
        return 'That number is already on your list.';
      case EmergencyContactError.selfContact:
        return 'You cannot list your own number.';
    }
  }
}

/// Thrown by the actions layer when a mutation would violate FR-020.
class EmergencyContactException implements Exception {
  const EmergencyContactException(this.error);

  final EmergencyContactError error;

  String get message => error.message;

  @override
  String toString() => 'EmergencyContactException(${error.name}): $message';
}

/// Pure validation for the emergency-contact list.
///
/// Kept free of Supabase and Riverpod so the FR-020 constraints can be tested
/// directly — these rules gate whether tracking may activate at all (FR-004),
/// so they must be verifiable without a backend.
abstract final class EmergencyContactValidator {
  /// FR-020: at least one contact before tracking can activate.
  static const int minContacts = 1;

  /// FR-020: at most five. More than five turns the cascade into a phone
  /// tree nobody answers.
  static const int maxContacts = 5;

  /// Canonicalises an Indian mobile number to `+91XXXXXXXXXX`, or returns
  /// null if it is not one.
  ///
  /// Accepts what people actually type: spaces, hyphens, brackets, a leading
  /// `0`, `91`, `+91` or `0091`. Rejects landlines and non-Indian numbers —
  /// the SMS/voice cascade is provisioned for Indian mobiles only, so
  /// accepting anything else would mean silently un-contactable contacts.
  static String? normalisePhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.startsWith('+')) digits = digits.substring(1);
    if (digits.startsWith('0091')) digits = digits.substring(4);
    if (digits.startsWith('91') && digits.length == 12) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0') && digits.length == 11) {
      digits = digits.substring(1);
    }
    if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(digits)) return null;
    return '+91$digits';
  }

  static bool meetsMinimum(List<EmergencyContact> contacts) =>
      contacts.length >= minContacts;

  static bool hasRoom(List<EmergencyContact> contacts) =>
      contacts.length < maxContacts;

  /// Validates adding (or, with [excludeId], editing) a contact.
  /// Returns null when the edit is allowed.
  static EmergencyContactError? validateAdd({
    required List<EmergencyContact> existing,
    required String name,
    required String phone,
    String? ownPhone,
    String? excludeId,
  }) {
    final isEdit = excludeId != null;
    if (!isEdit && !hasRoom(existing)) return EmergencyContactError.tooMany;
    if (name.trim().isEmpty) return EmergencyContactError.missingName;

    final normalised = normalisePhone(phone);
    if (normalised == null) return EmergencyContactError.invalidPhone;

    final own = ownPhone == null ? null : normalisePhone(ownPhone);
    if (own != null && own == normalised) {
      return EmergencyContactError.selfContact;
    }

    for (final c in existing) {
      if (c.id == excludeId) continue;
      if (normalisePhone(c.phone) == normalised) {
        return EmergencyContactError.duplicatePhone;
      }
    }
    return null;
  }

  static EmergencyContactError? validateRemove({
    required List<EmergencyContact> existing,
  }) {
    if (existing.isEmpty) return EmergencyContactError.tooFew;
    return null;
  }
}
