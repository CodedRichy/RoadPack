import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'authenticated_supabase_provider.dart';
import 'clerk_auth_provider.dart';

/// Sentinel used by [UserProfile.copyWith] to distinguish "argument not
/// passed" (keep the current value) from "explicitly passed as null" (clear
/// the field). A plain `value ?? this.value` default can't tell those apart,
/// which would silently un-clear fields like [UserProfile.vehicleType] when
/// a caller (e.g. [UserProfileNotifier.updateVehicle]) explicitly passes
/// `null` to clear them.
class _Unset {
  const _Unset();
}

const _unset = _Unset();

/// The signed-in user's row from the `users` table (migration 00002).
///
/// [dateOfBirth] doubles as the onboarding-completion proxy (see
/// `docs/superpowers/specs/2026-07-10-auth-feature-design.md` section 5):
/// the Clerk webhook creates the row with it `NULL`, and the onboarding
/// flow's DOB step is the only place that ever sets it.
class UserProfile {
  const UserProfile({
    required this.userId,
    this.name,
    this.dateOfBirth,
    this.vehicleType,
    this.vehicleReg,
    this.crashSensitivity,
    this.phoneMountType,
    this.nonArrivalDelayMin,
    this.nonArrivalEnabled,
    this.bloodGroup,
    this.medicalNotes,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['id'] as String,
      name: json['name'] as String?,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'] as String)
          : null,
      vehicleType: json['vehicle_type'] as String?,
      vehicleReg: json['vehicle_reg'] as String?,
      crashSensitivity: json['crash_sensitivity'] as String?,
      phoneMountType: json['phone_mount'] as String?,
      nonArrivalDelayMin: json['non_arrival_delay_min'] as int?,
      nonArrivalEnabled: json['non_arrival_enabled'] as bool?,
      bloodGroup: json['blood_group'] as String?,
      medicalNotes: json['medical_notes'] as String?,
    );
  }

  final String userId;
  final String? name;
  final DateTime? dateOfBirth;
  final String? vehicleType;
  final String? vehicleReg;
  final String? crashSensitivity;
  final String? phoneMountType;
  final int? nonArrivalDelayMin;
  final bool? nonArrivalEnabled;
  final String? bloodGroup;
  final String? medicalNotes;

  /// True once onboarding is complete. `date_of_birth` is `NULL` on the
  /// webhook-created row and is only ever written by the onboarding flow's
  /// final step, so its presence reliably signals a completed profile.
  bool get isOnboarded => dateOfBirth != null;

  /// Returns a copy with the given fields replaced. Omit an argument to
  /// keep the current value; pass `null` explicitly to clear a nullable
  /// field (see [_Unset]). [userId] can't be cleared, only replaced.
  UserProfile copyWith({
    String? userId,
    Object? name = _unset,
    Object? dateOfBirth = _unset,
    Object? vehicleType = _unset,
    Object? vehicleReg = _unset,
    Object? crashSensitivity = _unset,
    Object? phoneMountType = _unset,
    Object? nonArrivalDelayMin = _unset,
    Object? nonArrivalEnabled = _unset,
    Object? bloodGroup = _unset,
    Object? medicalNotes = _unset,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      name: identical(name, _unset) ? this.name : name as String?,
      dateOfBirth: identical(dateOfBirth, _unset)
          ? this.dateOfBirth
          : dateOfBirth as DateTime?,
      vehicleType: identical(vehicleType, _unset)
          ? this.vehicleType
          : vehicleType as String?,
      vehicleReg: identical(vehicleReg, _unset)
          ? this.vehicleReg
          : vehicleReg as String?,
      crashSensitivity: identical(crashSensitivity, _unset)
          ? this.crashSensitivity
          : crashSensitivity as String?,
      phoneMountType: identical(phoneMountType, _unset)
          ? this.phoneMountType
          : phoneMountType as String?,
      nonArrivalDelayMin: identical(nonArrivalDelayMin, _unset)
          ? this.nonArrivalDelayMin
          : nonArrivalDelayMin as int?,
      nonArrivalEnabled: identical(nonArrivalEnabled, _unset)
          ? this.nonArrivalEnabled
          : nonArrivalEnabled as bool?,
      bloodGroup: identical(bloodGroup, _unset)
          ? this.bloodGroup
          : bloodGroup as String?,
      medicalNotes: identical(medicalNotes, _unset)
          ? this.medicalNotes
          : medicalNotes as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          name == other.name &&
          dateOfBirth == other.dateOfBirth &&
          vehicleType == other.vehicleType &&
          vehicleReg == other.vehicleReg &&
          crashSensitivity == other.crashSensitivity &&
          phoneMountType == other.phoneMountType &&
          nonArrivalDelayMin == other.nonArrivalDelayMin &&
          nonArrivalEnabled == other.nonArrivalEnabled &&
          bloodGroup == other.bloodGroup &&
          medicalNotes == other.medicalNotes;

  @override
  int get hashCode => Object.hash(
    userId,
    name,
    dateOfBirth,
    vehicleType,
    vehicleReg,
    crashSensitivity,
    phoneMountType,
    nonArrivalDelayMin,
    nonArrivalEnabled,
    bloodGroup,
    medicalNotes,
  );

  @override
  String toString() =>
      'UserProfile(userId: $userId, name: $name, dateOfBirth: $dateOfBirth, '
      'vehicleType: $vehicleType, vehicleReg: $vehicleReg, '
      'crashSensitivity: $crashSensitivity, phoneMountType: $phoneMountType, '
      'nonArrivalDelayMin: $nonArrivalDelayMin, '
      'nonArrivalEnabled: $nonArrivalEnabled, bloodGroup: $bloodGroup, '
      'medicalNotes: $medicalNotes)';
}

/// Fetches and caches the signed-in user's profile, exposing
/// [UserProfile.isOnboarded] for router guards (design spec section 6) and
/// the mutation methods the onboarding flow and settings screens use.
///
/// Resolves to `null` when there is no authenticated Clerk session.
final userProfileProvider =
    AsyncNotifierProvider<UserProfileNotifier, UserProfile?>(
      UserProfileNotifier.new,
    );

class UserProfileNotifier extends AsyncNotifier<UserProfile?> {
  /// Backoff schedule for the webhook-row race (design spec section 4):
  /// the Clerk webhook may not have created the `users` row yet by the time
  /// the client's session is valid and this fetch runs.
  static const _retryDelays = [
    Duration(milliseconds: 500),
    Duration(seconds: 1),
    Duration(seconds: 2),
  ];

  SupabaseClient? get _supabase => ref.read(authenticatedSupabaseProvider);

  /// The current user's Clerk id, preferring the live auth state over the
  /// (possibly stale, possibly not-yet-loaded) cached profile so the
  /// mutation methods below still resolve correctly even if called before
  /// [build] has finished its first fetch.
  String? get _userId =>
      ref.read(clerkAuthProvider).valueOrNull?.userId ?? state.value?.userId;

  @override
  Future<UserProfile?> build() async {
    final authState = ref.watch(clerkAuthProvider).valueOrNull;
    final userId = authState?.userId;
    if (authState == null || !authState.isAuthenticated || userId == null) {
      return null;
    }

    return _fetchWithRetry(userId, fallbackPhone: authState.phone);
  }

  /// Re-fetches the profile from Supabase (e.g. pull-to-refresh, or after
  /// the app resumes). No-op if there is no authenticated session.
  Future<void> fetchProfile() async {
    final authState = ref.read(clerkAuthProvider).valueOrNull;
    final userId = authState?.userId;
    if (authState == null || !authState.isAuthenticated || userId == null) {
      return;
    }

    state = const AsyncLoading<UserProfile?>();
    state = await AsyncValue.guard(
      () => _fetchWithRetry(userId, fallbackPhone: authState.phone),
    );
  }

  /// Fetches the `users` row for [userId], retrying with backoff to cover
  /// the webhook race. If the row still doesn't exist after all retries,
  /// falls back to a client-side insert (allowed by the `users_insert` RLS
  /// policy: `requesting_user_id() = id`, migration 00002).
  Future<UserProfile> _fetchWithRetry(
    String userId, {
    String? fallbackPhone,
  }) async {
    final supabase = _supabase;
    if (supabase == null) return UserProfile(userId: userId);

    for (var attempt = 0; attempt <= _retryDelays.length; attempt++) {
      final response = await supabase
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        return UserProfile.fromJson(response);
      }

      if (attempt < _retryDelays.length) {
        await Future<void>.delayed(_retryDelays[attempt]);
      }
    }

    return _insertFallbackRow(supabase, userId, fallbackPhone: fallbackPhone);
  }

  /// Creates a bare row for [userId] when the webhook hasn't fired in time.
  ///
  /// `phone` is `UNIQUE NOT NULL` (migration 00002), so this prefers the
  /// phone number captured during sign-in (`AuthState.phone`, retained
  /// through `verifyCode` — see `clerk_auth_provider.dart`) over an empty
  /// string. A unique-constraint conflict (e.g. an email-only sign-in with
  /// no phone racing another such fallback) is swallowed rather than
  /// surfaced as a hard error: the webhook will eventually create the real
  /// row, and the next [fetchProfile] call picks it up. In the meantime the
  /// caller gets an unpersisted, not-onboarded profile rather than a crash.
  Future<UserProfile> _insertFallbackRow(
    SupabaseClient supabase,
    String userId, {
    String? fallbackPhone,
  }) async {
    try {
      await supabase.from('users').insert({
        'id': userId,
        'phone': fallbackPhone ?? '',
        'name': '',
      });
    } on PostgrestException {
      // Row already exists (webhook or a racing fallback beat us to it) —
      // nothing more to do client-side.
    }

    return UserProfile(userId: userId);
  }

  Future<void> updateName(String name) async {
    final userId = _userId;
    final supabase = _supabase;
    if (userId == null || supabase == null) return;

    await supabase.from('users').update({'name': name}).eq('id', userId);

    final current = state.value;
    state = AsyncData(
      (current ?? UserProfile(userId: userId)).copyWith(name: name),
    );
  }

  Future<void> updateDateOfBirth(DateTime dob) async {
    final userId = _userId;
    final supabase = _supabase;
    if (userId == null || supabase == null) return;

    await supabase
        .from('users')
        .update({'date_of_birth': dob.toIso8601String().split('T').first})
        .eq('id', userId);

    final current = state.value;
    state = AsyncData(
      (current ?? UserProfile(userId: userId)).copyWith(dateOfBirth: dob),
    );
  }

  Future<void> updateVehicle(String? type, String? reg) async {
    final userId = _userId;
    final supabase = _supabase;
    if (userId == null || supabase == null) return;

    await supabase
        .from('users')
        .update({'vehicle_type': type, 'vehicle_reg': reg})
        .eq('id', userId);

    final current = state.value;
    state = AsyncData(
      (current ?? UserProfile(userId: userId)).copyWith(
        vehicleType: type,
        vehicleReg: reg,
      ),
    );
  }

  /// Updates crash-detection sensitivity and phone mount type, used to tune
  /// the L2 crash detection engine's thresholds.
  Future<void> updateSafetySettings({
    required String crashSensitivity,
    required String phoneMountType,
  }) async {
    final userId = _userId;
    final supabase = _supabase;
    if (userId == null || supabase == null) return;

    await supabase
        .from('users')
        .update({
          'crash_sensitivity': crashSensitivity,
          'phone_mount': phoneMountType,
        })
        .eq('id', userId);

    final current = state.value;
    state = AsyncData(
      (current ?? UserProfile(userId: userId)).copyWith(
        crashSensitivity: crashSensitivity,
        phoneMountType: phoneMountType,
      ),
    );
  }

  /// Updates the "non-arrival" check-in settings: whether it's enabled, and
  /// how many minutes past the expected arrival time before it fires.
  Future<void> updateNonArrivalSettings({
    required bool enabled,
    required int delayMin,
  }) async {
    final userId = _userId;
    final supabase = _supabase;
    if (userId == null || supabase == null) return;

    await supabase
        .from('users')
        .update({
          'non_arrival_enabled': enabled,
          'non_arrival_delay_min': delayMin,
        })
        .eq('id', userId);

    final current = state.value;
    state = AsyncData(
      (current ?? UserProfile(userId: userId)).copyWith(
        nonArrivalEnabled: enabled,
        nonArrivalDelayMin: delayMin,
      ),
    );
  }

  /// Updates the user's emergency medical profile. Pass `null` for either
  /// argument to clear that field (e.g. the user removing their blood group
  /// from their profile).
  Future<void> updateEmergencyProfile({
    String? bloodGroup,
    String? medicalNotes,
  }) async {
    final userId = _userId;
    final supabase = _supabase;
    if (userId == null || supabase == null) return;

    await supabase
        .from('users')
        .update({'blood_group': bloodGroup, 'medical_notes': medicalNotes})
        .eq('id', userId);

    final current = state.value;
    state = AsyncData(
      (current ?? UserProfile(userId: userId)).copyWith(
        bloodGroup: bloodGroup,
        medicalNotes: medicalNotes,
      ),
    );
  }

  Future<void> addEmergencyContact({
    required String name,
    required String phone,
    required String relationship,
  }) async {
    final userId = _userId;
    final supabase = _supabase;
    if (userId == null || supabase == null) return;

    await supabase.from('emergency_contacts').insert({
      'user_id': userId,
      'name': name,
      'phone': phone,
      'relationship': relationship,
      'priority': 1,
    });
  }
}
