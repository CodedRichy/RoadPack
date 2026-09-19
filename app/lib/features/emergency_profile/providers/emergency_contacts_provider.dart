import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/clerk_auth_provider.dart';
import '../models/emergency_contact.dart';
import '../services/emergency_contact_repository.dart';
import '../services/emergency_contact_validator.dart';

/// The signed-in user's emergency contacts, in cascade order.
final emergencyContactsProvider =
    AsyncNotifierProvider<EmergencyContactsNotifier, List<EmergencyContact>>(
      EmergencyContactsNotifier.new,
    );

class EmergencyContactsNotifier extends AsyncNotifier<List<EmergencyContact>> {
  @override
  Future<List<EmergencyContact>> build() async {
    final gateway = ref.watch(emergencyContactGatewayProvider);
    if (gateway == null) return const [];
    return gateway.fetchContacts();
  }

  Future<void> refresh() async {
    final gateway = ref.read(emergencyContactGatewayProvider);
    if (gateway == null) return;
    state = await AsyncValue.guard(gateway.fetchContacts);
  }
}

/// FR-004 precondition: tracking may not activate until the user has at
/// least one emergency contact, because an alert cascade with nobody to call
/// is a silent failure dressed up as protection.
///
/// Deliberately false while loading or errored — the safe answer to "can we
/// start tracking?" when we do not yet know is no.
final emergencyProfileReadyProvider = Provider<bool>((ref) {
  final contacts = ref.watch(emergencyContactsProvider);
  return contacts.maybeWhen(
    data: EmergencyContactValidator.meetsMinimum,
    orElse: () => false,
  );
});

/// How many more contacts the user may add (0..5).
final emergencyContactSlotsLeftProvider = Provider<int>((ref) {
  final contacts = ref.watch(emergencyContactsProvider).valueOrNull ?? const [];
  final left = EmergencyContactValidator.maxContacts - contacts.length;
  return left < 0 ? 0 : left;
});

/// The user's own number, used to block listing yourself as your own
/// emergency contact. Sourced from the Clerk session, which is where the
/// verified number lives.
final ownPhoneProvider = Provider<String?>((ref) {
  return ref.watch(clerkAuthProvider).valueOrNull?.phone;
});
