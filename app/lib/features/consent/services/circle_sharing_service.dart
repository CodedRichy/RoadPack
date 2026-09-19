import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/authenticated_supabase_provider.dart';
import '../../circles/models/circle.dart';
import '../../circles/models/circle_member.dart';

/// Writes the one circle setting that decides who can see the user:
/// `circles.settings->>'location_sharing'`, the flag `can_view_location`
/// reads (migration 00005).
///
/// Kept here rather than in `CircleRepository` because this is a consent
/// surface, not circle administration: FR-014 owns the control, and the
/// screen that offers it must not be able to drift from the rule the
/// visibility report applies.
///
/// Note the RLS reality: `circles_update` is `is_circle_admin(...)`, so a
/// plain member calling this gets zero rows updated, silently. The UI
/// therefore never offers the circle-wide control to a non-admin. A member's
/// own lever is [setMemberSharing], which writes their own membership row
/// and needs no admin rights.
abstract interface class CircleSharingGateway {
  Future<void> setLocationSharing({
    required Circle circle,
    required bool enabled,
  });

  /// The member-side opt-out: writes the signed-in user's own
  /// `circle_members.permissions->>'share_location'`.
  ///
  /// Allowed by the existing `circle_members_update` policy
  /// (`user_id = requesting_user_id()`), and the
  /// `prevent_membership_tampering` trigger only guards identity and role,
  /// so this needs no new policy. Migration 00021 added the matching term to
  /// `can_view_location`, so the write is enforced server-side.
  Future<void> setMemberSharing({
    required CircleMember membership,
    required bool enabled,
  });
}

final circleSharingGatewayProvider = Provider<CircleSharingGateway?>((ref) {
  final client = ref.watch(authenticatedSupabaseProvider);
  if (client == null) return null;
  return SupabaseCircleSharingGateway(client);
});

class SupabaseCircleSharingGateway implements CircleSharingGateway {
  SupabaseCircleSharingGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<void> setLocationSharing({
    required Circle circle,
    required bool enabled,
  }) async {
    // Merge rather than replace: `settings` is a shared jsonb bag and other
    // features keep their own keys in it.
    final next = <String, dynamic>{
      ...circle.settings,
      'location_sharing': enabled,
    };
    await _client
        .from('circles')
        .update({'settings': next})
        .eq('id', circle.id);
  }

  @override
  Future<void> setMemberSharing({
    required CircleMember membership,
    required bool enabled,
  }) async {
    final next = <String, dynamic>{
      ...membership.permissions,
      'share_location': enabled,
    };
    await _client
        .from('circle_members')
        .update({'permissions': next})
        .eq('circle_id', membership.circleId)
        .eq('user_id', membership.userId);
  }
}
