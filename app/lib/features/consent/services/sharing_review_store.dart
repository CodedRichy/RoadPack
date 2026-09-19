import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers when the user last reviewed who can see them (FR-014's monthly
/// reminder, backing SG-01).
///
/// Device-local on purpose: the reminder is a nudge, not a legal record,
/// and it should not cost a round trip on a bad connection.
abstract interface class SharingReviewStore {
  Future<DateTime?> lastReviewedAt();
  Future<void> markReviewed(DateTime at);
}

class PrefsSharingReviewStore implements SharingReviewStore {
  const PrefsSharingReviewStore();

  static const _key = 'roadpack.sharing_review.last_at';

  @override
  Future<DateTime?> lastReviewedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  @override
  Future<void> markReviewed(DateTime at) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, at.toUtc().toIso8601String());
  }
}

final sharingReviewStoreProvider = Provider<SharingReviewStore>(
  (ref) => const PrefsSharingReviewStore(),
);

/// How long between prompts to review the sharing list.
const Duration kSharingReviewInterval = Duration(days: 30);

/// Whether the user is due a review prompt.
///
/// A user who has never reviewed is due immediately — the first month is
/// exactly when someone who was added to a circle during onboarding has no
/// idea who is watching.
bool sharingReviewDue(DateTime? lastReviewedAt, {DateTime? now}) {
  if (lastReviewedAt == null) return true;
  final today = now ?? DateTime.now();
  return today.difference(lastReviewedAt) >= kSharingReviewInterval;
}
