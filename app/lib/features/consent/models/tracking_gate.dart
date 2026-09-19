import '../../../l10n/l10n.dart';

/// A single reason tracking cannot start yet.
///
/// These are ordered the way the user should fix them, and each one has a
/// plain-language line. A gate that says "not allowed" without saying why
/// gets uninstalled.
enum TrackingBlocker {
  /// FR-004: the profile has no name, so an alert would name nobody.
  nameMissing,

  /// FR-004: no verified phone number on the account.
  phoneMissing,

  /// FR-004: nobody to call. An alert cascade with an empty contact list is
  /// a silent failure dressed up as protection.
  noEmergencyContact,

  /// FR-003: no date of birth, so we cannot tell whether the age gate
  /// applies. Fails closed.
  dateOfBirthMissing,

  /// FR-003 / DPDPA C6: user is under 18 and there is no live parental
  /// consent on the ledger.
  parentalConsentMissing,

  /// The user has not agreed to location tracking, or has withdrawn it.
  trackingConsentMissing,

  /// The consent ledger could not be read at all. Distinct from
  /// [trackingConsentMissing] because the fix is different — retry or sign
  /// in again, rather than tap yes.
  consentStateUnknown;

  String title(AppLocalizations l10n) {
    switch (this) {
      case TrackingBlocker.nameMissing:
        return l10n.consentBlockerNameTitle;
      case TrackingBlocker.phoneMissing:
        return l10n.consentBlockerPhoneTitle;
      case TrackingBlocker.noEmergencyContact:
        return l10n.consentBlockerContactTitle;
      case TrackingBlocker.dateOfBirthMissing:
        return l10n.consentBlockerDobTitle;
      case TrackingBlocker.parentalConsentMissing:
        return l10n.consentBlockerParentalTitle;
      case TrackingBlocker.trackingConsentMissing:
        return l10n.consentBlockerTrackingTitle;
      case TrackingBlocker.consentStateUnknown:
        return l10n.consentUnknownLedgerTitle;
    }
  }

  String explanation(AppLocalizations l10n) {
    switch (this) {
      case TrackingBlocker.nameMissing:
        return l10n.consentBlockerNameBody;
      case TrackingBlocker.phoneMissing:
        return l10n.consentBlockerPhoneBody;
      case TrackingBlocker.noEmergencyContact:
        return l10n.consentBlockerContactBody;
      case TrackingBlocker.dateOfBirthMissing:
        return l10n.consentBlockerDobBody;
      case TrackingBlocker.parentalConsentMissing:
        return l10n.consentBlockerParentalBody;
      case TrackingBlocker.trackingConsentMissing:
        return l10n.consentBlockerTrackingBody;
      case TrackingBlocker.consentStateUnknown:
        return l10n.consentBlockerUnknownBody;
    }
  }
}

/// The answer to "may tracking start?", and nothing else.
///
/// FR-004 exists because a dozen call sites each deciding this for
/// themselves is how a minor ends up tracked. There is one gate; everything
/// that starts location collection asks it.
class TrackingGate {
  const TrackingGate(this.blockers);

  /// Everything is in order.
  const TrackingGate.clear() : blockers = const [];

  final List<TrackingBlocker> blockers;

  /// The only question callers should ask.
  bool get mayStart => blockers.isEmpty;

  /// The blocker to put in front of the user first.
  TrackingBlocker? get primary => blockers.isEmpty ? null : blockers.first;

  bool has(TrackingBlocker blocker) => blockers.contains(blocker);

  /// True when the block is the age gate specifically. The UI routes this
  /// one to the parental consent flow rather than to the profile editor.
  bool get needsParentalConsent => has(TrackingBlocker.parentalConsentMissing);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackingGate &&
          runtimeType == other.runtimeType &&
          _listEquals(blockers, other.blockers);

  @override
  int get hashCode => Object.hashAll(blockers);

  static bool _listEquals(List<TrackingBlocker> a, List<TrackingBlocker> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() => 'TrackingGate(mayStart: $mayStart, blockers: $blockers)';
}
