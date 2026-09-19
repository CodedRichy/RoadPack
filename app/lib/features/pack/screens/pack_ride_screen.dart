import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';
import '../../auth/providers/clerk_auth_provider.dart';
import '../models/pack_gap.dart';
import '../models/pack_member.dart';
import '../models/pack_ride.dart';
import '../providers/pack_actions_provider.dart';
import '../providers/pack_ride_provider.dart';
import '../widgets/pack_member_tile.dart';
import '../widgets/share_link_card.dart';
import 'pack_status_sheet.dart';

/// The live pack.
///
/// One row per rider, sorted front to back, each showing the gap. That
/// ordering is the whole readout: the eye runs down the list and the pack's
/// shape falls out of it — who is off the front, where it has split, who has
/// dropped off the end.
///
/// Riders whose gap the server refused to compute sort last, not first. They
/// still need attention, but a row that cannot say where someone is has no
/// business claiming a position in the order.
class PackRideScreen extends ConsumerWidget {
  const PackRideScreen({required this.rideId, super.key, this.now});

  final String rideId;

  /// Injectable clock for tests.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.semantics;
    final l10n = context.l10n;
    final gaps = ref.watch(packGapsProvider(rideId));
    final directory = ref.watch(packMemberDirectoryProvider(rideId));
    final ride = ref.watch(activePackRideProvider).valueOrNull;
    final userId = ref.watch(clerkAuthProvider).valueOrNull?.userId;

    return Scaffold(
      appBar: AppBar(
        title: Text(ride?.name ?? l10n.packDefaultRideName),
        actions: [
          if (ride != null && ride.leaderId == userId)
            TextButton(
              onPressed: () => _endRide(context, ref, ride),
              child: Text(l10n.packEndRideAction),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('pack-status-fab'),
        onPressed: () => _pickStatus(context, ref, directory[userId]),
        icon: const Icon(Icons.campaign),
        label: Text(l10n.packTellPack),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(packGapsProvider(rideId).notifier).refresh();
          await ref.read(packMembersProvider(rideId).notifier).refresh();
        },
        child: gaps.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _Message(text: e.toString()),
          data: (rows) {
            if (rows.isEmpty) {
              return _Message(text: l10n.packEmptyRoster);
            }
            final ordered = _order(rows);
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter,
                AppSpace.lg,
                AppSpace.gutter,
                AppSpace.huge + AppSpace.xxl,
              ),
              itemCount: ordered.length + (ride == null ? 0 : 1),
              separatorBuilder: (_, _) => const SizedBox(height: AppSpace.sm),
              itemBuilder: (context, index) {
                if (ride != null && index == ordered.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpace.lg),
                    child: ShareLinkCard(
                      ride: ride,
                      now: now,
                      onRevoke: ride.leaderId == userId
                          ? () => ref
                                .read(packActionsProvider)
                                .revokeShare(ride.id)
                          : null,
                    ),
                  );
                }
                final gap = ordered[index];
                return PackMemberTile(
                  gap: gap,
                  member: directory[gap.userId],
                  isCurrentUser: gap.userId == userId,
                  now: now,
                );
              },
            );
          },
        ),
      ),
      backgroundColor: s.canvas,
    );
  }

  /// Front to back, then everyone the server would not place.
  static List<PackGap> _order(List<PackGap> rows) {
    final placed = rows.where((g) => g.canShowGap).toList()
      ..sort((a, b) => b.gapM!.compareTo(a.gapM!));
    final unplaced = rows.where((g) => !g.canShowGap).toList()
      // Within the unplaced, the most alarming status floats up.
      ..sort(
        (a, b) => b.statusCode.precedence.compareTo(a.statusCode.precedence),
      );
    return [...placed, ...unplaced];
  }

  Future<void> _pickStatus(
    BuildContext context,
    WidgetRef ref,
    PackMember? me,
  ) async {
    final choice = await PackStatusSheet.show(
      context,
      current: me?.statusAuto == true ? null : me?.statusCode,
      currentNote: me?.statusNote,
    );
    if (choice == null) return;
    try {
      await ref
          .read(packActionsProvider)
          .setStatus(rideId: rideId, status: choice.status, note: choice.note);
    } catch (e) {
      if (context.mounted) {
        _snack(
          context,
          e is TrackingNotPermitted
              ? e.message(context.l10n)
              : e.toString(),
        );
      }
    }
  }

  Future<void> _endRide(
    BuildContext context,
    WidgetRef ref,
    PackRide ride,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.packEndRideConfirmTitle),
        content: Text(l10n.packEndRideConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.packKeepRidingAction),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.packEndRideAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(packActionsProvider).endRide(ride.id);
    } catch (e) {
      if (context.mounted) {
        _snack(
          context,
          e is TrackingNotPermitted
              ? e.message(context.l10n)
              : e.toString(),
        );
      }
    }
  }

  static void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppType.bodyStyle(
            AppType.bodyMd,
          ).copyWith(color: s.textSecondary),
        ),
      ),
    );
  }
}
