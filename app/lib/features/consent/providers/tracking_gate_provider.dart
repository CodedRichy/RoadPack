import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/clerk_auth_provider.dart';
import '../../auth/providers/user_profile_provider.dart';
import '../../emergency_profile/providers/emergency_contacts_provider.dart';
import '../models/age_gate.dart';
import '../models/consent_ledger.dart';
import '../models/consent_type.dart';
import '../models/tracking_gate.dart';
import 'consent_provider.dart';

/// FR-003 + FR-004, in one place.
///
/// Every code path that starts location collection asks this provider and
/// nothing else. The reason it is one provider rather than a helper each
/// call site composes for itself is that the failure mode of the second
/// arrangement is a minor being tracked because one screen forgot the age
/// check.
///
/// Fail-closed rules baked in here:
/// * an unreadable consent ledger blocks tracking ([ConsentLedger.isKnown]);
/// * a missing or unparseable date of birth is treated as under-18;
/// * a profile still loading blocks tracking, because "not yet known" is
///   not "fine".
final trackingGateProvider = Provider<TrackingGate>((ref) {
  final profileAsync = ref.watch(userProfileProvider);
  final authState = ref.watch(clerkAuthProvider).valueOrNull;
  final contactsReady = ref.watch(emergencyProfileReadyProvider);
  final ledger = ref.watch(consentLedgerProvider);

  final blockers = <TrackingBlocker>[];

  final profile = profileAsync.valueOrNull;
  final name = profile?.name?.trim() ?? '';
  if (name.isEmpty) blockers.add(TrackingBlocker.nameMissing);

  final phone = authState?.phone?.trim() ?? '';
  if (phone.isEmpty) blockers.add(TrackingBlocker.phoneMissing);

  if (!contactsReady) blockers.add(TrackingBlocker.noEmergencyContact);

  final band = AgeGate.bandFor(profile?.dateOfBirth);
  if (band == AgeBand.unknown) {
    blockers.add(TrackingBlocker.dateOfBirthMissing);
  }

  if (!ledger.isKnown) {
    // One blocker, not three. The user cannot fix "unknown" by tapping the
    // consent toggles, so listing those as separate to-dos would send them
    // somewhere that cannot help.
    blockers.add(TrackingBlocker.consentStateUnknown);
    return TrackingGate(List.unmodifiable(blockers));
  }

  if (band.requiresParentalConsent && !ledger.isGranted(ConsentType.parental)) {
    blockers.add(TrackingBlocker.parentalConsentMissing);
  }

  if (!ledger.isGranted(ConsentType.tracking)) {
    blockers.add(TrackingBlocker.trackingConsentMissing);
  }

  return TrackingGate(List.unmodifiable(blockers));
});

/// The one-line form for call sites that only need the yes/no.
final mayStartTrackingProvider = Provider<bool>(
  (ref) => ref.watch(trackingGateProvider).mayStart,
);
