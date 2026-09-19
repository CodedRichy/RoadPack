import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/providers/user_profile_provider.dart';
import '../../sos/providers/sos_state_provider.dart';
import '../models/ice_exposure.dart';
import 'emergency_contacts_provider.dart';

/// True while an incident (SOS or a confirmed crash) is live.
///
/// Defaults to the SOS state machine. Other incident sources override this
/// provider rather than reaching into the ICE card directly, so there stays
/// exactly one place that can open the gate.
final iceIncidentActiveProvider = Provider<bool>((ref) {
  return ref.watch(sosStateProvider).isActive;
});

/// True while a tracked commute is in progress.
///
/// Overridden by the commute feature once it publishes a live state. It
/// defaults to `false`, not to "unknown": if nothing has told us a commute is
/// running, the card stays shut.
final iceCommuteActiveProvider = Provider<bool>((ref) => false);

/// Persisted store for the FR-094 commute-exposure opt-in.
///
/// Starts `false` and only ever flips to `true` once the stored preference has
/// actually been read back as `true`. Every failure path — no stored value, a
/// platform channel error, a corrupt value — leaves it `false`, because the
/// safe answer to "may we show this rider's blood group and phone numbers to a
/// stranger?" when we do not know is no.
final iceCommuteExposurePrefProvider =
    NotifierProvider<IceCommuteExposureNotifier, bool>(
      IceCommuteExposureNotifier.new,
    );

class IceCommuteExposureNotifier extends Notifier<bool> {
  static const prefsKey = 'ice_commute_exposure_opt_in';

  @override
  bool build() {
    // Fail-closed until the stored value says otherwise.
    unawaited(_load());
    return false;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getBool(prefsKey) ?? false;
      if (stored != state) state = stored;
    } catch (e) {
      debugPrint('ICE commute opt-in read failed, staying closed: \$e');
    }
  }

  /// Flips the opt-in. The in-memory state is updated first so the toggle
  /// never appears to ignore the tap; a failed write is reverted rather than
  /// left claiming a setting we did not persist.
  Future<void> set(bool value) async {
    final previous = state;
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefsKey, value);
    } catch (e) {
      debugPrint('ICE commute opt-in write failed: \$e');
      state = previous;
    }
  }
}

/// FR-094: exposing ICE data during an ordinary commute is opt-in. Absent an
/// explicit opt-in the card is incident-only.
final iceCommuteExposureOptInProvider = Provider<bool>(
  (ref) => ref.watch(iceCommuteExposurePrefProvider),
);

/// The single gate for ICE exposure (FR-023, SG-08).
///
/// Null means "not exposed", which is the state the app spends almost all of
/// its life in. Nothing downstream can render the card without the token this
/// returns.
final iceAccessProvider = Provider<IceAccess?>((ref) {
  return IceAccess.resolve(
    incidentActive: ref.watch(iceIncidentActiveProvider),
    commuteActive: ref.watch(iceCommuteActiveProvider),
    commuteExposureOptIn: ref.watch(iceCommuteExposureOptInProvider),
  );
});

/// Convenience flag for chrome that needs to know the card is live (e.g. a
/// "your ICE card is visible right now" banner honouring SG-01's no-covert
/// rule).
final iceExposedProvider = Provider<bool>(
  (ref) => ref.watch(iceAccessProvider) != null,
);

/// The ICE payload, assembled from the existing `users` medical fields and
/// this feature's contacts.
///
/// Returns null unless the gate is open — the data is not merely hidden from
/// the UI, it is not assembled at all.
final iceCardDataProvider = Provider<IceCardData?>((ref) {
  if (ref.watch(iceAccessProvider) == null) return null;

  final profile = ref.watch(userProfileProvider).valueOrNull;
  final contacts = ref.watch(emergencyContactsProvider).valueOrNull ?? const [];

  return IceCardData(
    ownerName: profile?.name,
    bloodGroup: profile?.bloodGroup,
    medicalNotes: profile?.medicalNotes,
    contacts: contacts,
  );
});
