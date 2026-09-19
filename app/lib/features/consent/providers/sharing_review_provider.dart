import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/sharing_review_store.dart';

/// When the user last looked at "Who can see me".
final lastSharingReviewProvider =
    AsyncNotifierProvider<SharingReviewNotifier, DateTime?>(
      SharingReviewNotifier.new,
    );

class SharingReviewNotifier extends AsyncNotifier<DateTime?> {
  @override
  Future<DateTime?> build() =>
      ref.watch(sharingReviewStoreProvider).lastReviewedAt();

  /// Called when the user has actually seen the list — not when the app
  /// merely wanted them to.
  Future<void> markReviewed({DateTime? at}) async {
    final when = at ?? DateTime.now();
    await ref.read(sharingReviewStoreProvider).markReviewed(when);
    state = AsyncData(when);
  }
}

/// FR-014's monthly nudge.
///
/// Deliberately false while the last-reviewed date is still loading: a
/// banner that flashes on every cold start trains the user to dismiss it,
/// and a reminder people have learned to ignore protects nobody.
final sharingReviewDueProvider = Provider<bool>((ref) {
  final async = ref.watch(lastSharingReviewProvider);
  return async.maybeWhen(
    data: (last) => sharingReviewDue(last),
    orElse: () => false,
  );
});
