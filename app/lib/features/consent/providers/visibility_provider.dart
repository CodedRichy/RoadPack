import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/clerk_auth_provider.dart';
import '../../circles/models/circle_member.dart';
import '../../circles/providers/circles_provider.dart';
import '../../circles/services/circle_repository.dart';
import '../models/visibility_report.dart';

/// FR-014: who can see the signed-in user's location, right now.
///
/// Built by fetching the user's circles and their members, then applying
/// the same rule `can_view_location` applies server-side. The screen must
/// never be able to reassure a user about a visibility the server does not
/// actually enforce, so the rule lives in exactly one place
/// ([VisibilityReport.from]) and is unit-tested against the SQL.
final whoCanSeeMeProvider = FutureProvider<VisibilityReport>((ref) async {
  final repo = ref.watch(circleRepositoryProvider);
  final selfUserId = ref.watch(clerkAuthProvider).valueOrNull?.userId;
  if (repo == null || selfUserId == null) {
    throw StateError('Not authenticated');
  }

  final circles = await ref.watch(circlesProvider.future);

  final membersByCircleId = <String, List<CircleMember>>{};
  for (final circle in circles) {
    membersByCircleId[circle.id] = await repo.fetchMembers(circle.id);
  }

  return VisibilityReport.from(
    selfUserId: selfUserId,
    circles: circles,
    membersByCircleId: membersByCircleId,
  );
});
