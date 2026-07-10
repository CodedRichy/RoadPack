import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'authenticated_supabase_provider.dart';
import 'clerk_auth_provider.dart';

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
    );
  }

  final String userId;
  final String? name;
  final DateTime? dateOfBirth;
  final String? vehicleType;
  final String? vehicleReg;

  /// True once onboarding is complete. `date_of_birth` is `NULL` on the
  /// webhook-created row and is only ever written by the onboarding flow's
  /// final step, so its presence reliably signals a completed profile.
  bool get isOnboarded => dateOfBirth != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          name == other.name &&
          dateOfBirth == other.dateOfBirth &&
          vehicleType == other.vehicleType &&
          vehicleReg == other.vehicleReg;

  @override
  int get hashCode =>
      Object.hash(userId, name, dateOfBirth, vehicleType, vehicleReg);

  @override
  String toString() =>
      'UserProfile(userId: $userId, name: $name, dateOfBirth: $dateOfBirth, '
      'vehicleType: $vehicleType, vehicleReg: $vehicleReg)';
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
      UserProfile(
        userId: userId,
        name: name,
        dateOfBirth: current?.dateOfBirth,
        vehicleType: current?.vehicleType,
        vehicleReg: current?.vehicleReg,
      ),
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
      UserProfile(
        userId: userId,
        name: current?.name,
        dateOfBirth: dob,
        vehicleType: current?.vehicleType,
        vehicleReg: current?.vehicleReg,
      ),
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
      UserProfile(
        userId: userId,
        name: current?.name,
        dateOfBirth: current?.dateOfBirth,
        vehicleType: type,
        vehicleReg: reg,
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
