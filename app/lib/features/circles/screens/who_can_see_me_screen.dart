import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';
import '../../consent/models/visibility_report.dart';
import '../../consent/providers/sharing_review_provider.dart';
import '../../consent/providers/visibility_provider.dart';
import '../../consent/services/circle_sharing_service.dart';
import '../providers/circle_actions_provider.dart';
import '../providers/circles_provider.dart';
import '../widgets/visibility_circle_card.dart';

/// FR-014 — "Who can see me".
///
/// The list is derived from [VisibilityReport], which applies the same rule
/// `can_view_location(viewer, target)` applies server-side: a shared circle
/// AND that circle's `location_sharing` flag. Nothing on this screen is
/// allowed to compute visibility any other way, because a screen that
/// reassures a user about a visibility the server does not enforce is worse
/// than no screen at all.
class WhoCanSeeMeScreen extends ConsumerStatefulWidget {
  const WhoCanSeeMeScreen({super.key});

  @override
  ConsumerState<WhoCanSeeMeScreen> createState() => _WhoCanSeeMeScreenState();
}

class _WhoCanSeeMeScreenState extends ConsumerState<WhoCanSeeMeScreen> {
  bool _busy = false;
  bool _marked = false;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final async = ref.watch(whoCanSeeMeProvider);

    // Seeing the list is what counts as a review. Marking it on arrival —
    // rather than on a "done" tap — keeps the monthly prompt from nagging
    // someone who has just looked.
    if (!_marked && async.hasValue) {
      _marked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(lastSharingReviewProvider.notifier).markReviewed();
      });
    }

    return Scaffold(
      backgroundColor: s.canvas,
      appBar: AppBar(title: Text(context.l10n.circlesWhoCanSeeMeTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            _ErrorState(onRetry: () => ref.invalidate(whoCanSeeMeProvider)),
        data: (report) => _Body(
          report: report,
          busy: _busy,
          onSharingChanged: _setSharing,
          onSelfSharingChanged: _setSelfSharing,
          onLeave: _leave,
        ),
      ),
    );
  }

  Future<void> _setSharing(CircleVisibility visibility, bool enabled) async {
    final gateway = ref.read(circleSharingGatewayProvider);
    if (gateway == null) return;
    setState(() => _busy = true);
    try {
      await gateway.setLocationSharing(
        circle: visibility.circle,
        enabled: enabled,
      );
      ref.invalidate(circlesProvider);
      ref.invalidate(whoCanSeeMeProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.circlesChangeFailedMessage)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The member-side opt-out. Writes only the signed-in user's own
  /// membership row, so it needs no admin rights.
  Future<void> _setSelfSharing(
    CircleVisibility visibility,
    bool enabled,
  ) async {
    final gateway = ref.read(circleSharingGatewayProvider);
    final membership = visibility.selfMembership;
    if (gateway == null || membership == null) return;
    setState(() => _busy = true);
    try {
      await gateway.setMemberSharing(membership: membership, enabled: enabled);
      ref.invalidate(whoCanSeeMeProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.circlesChangeFailedMessage)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave(CircleVisibility visibility) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(circleActionsProvider)
          .leaveCircle(
            circleId: visibility.circle.id,
            isFamily: visibility.circle.isFamily,
          );
      ref.invalidate(circlesProvider);
      ref.invalidate(whoCanSeeMeProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.circlesLeaveError(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.report,
    required this.busy,
    required this.onSharingChanged,
    required this.onSelfSharingChanged,
    required this.onLeave,
  });

  final VisibilityReport report;
  final bool busy;
  final void Function(CircleVisibility, bool) onSharingChanged;
  final void Function(CircleVisibility, bool) onSelfSharingChanged;
  final void Function(CircleVisibility) onLeave;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;
    final count = report.watcherCount;

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.gutter,
        vertical: AppSpace.lg,
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpace.lg),
          decoration: BoxDecoration(
            color: count == 0 ? s.protectedFill : s.surface2,
            borderRadius: AppRadius.lgAll,
            border: Border.all(
              color: count == 0 ? s.protectedAccent : s.watchAccent,
              width: AppStroke.resolve(
                AppStroke.regular,
                sunlight: s.isSunlight,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.circlesWatcherCountHeadline(count),
                style: AppType.displayStyle(
                  AppType.titleSm,
                  weight: FontWeight.w600,
                ).copyWith(color: s.textPrimary),
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                l10n.circlesFullListNotice,
                style: AppType.bodyStyle(
                  AppType.bodySm,
                ).copyWith(color: s.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.xl),
        if (report.circles.isEmpty)
          Text(
            l10n.circlesNoCirclesYet,
            style: AppType.bodyStyle(
              AppType.bodyMd,
            ).copyWith(color: s.textSecondary),
          )
        else
          for (final visibility in report.circles)
            VisibilityCircleCard(
              visibility: visibility,
              busy: busy,
              onSharingChanged: (v) => onSharingChanged(visibility, v),
              onSelfSharingChanged: (v) => onSelfSharingChanged(visibility, v),
              onLeave: visibility.viewerIsAdmin
                  ? null
                  : () => onLeave(visibility),
            ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.circlesLoadWhoCanSeeError,
              style: AppType.bodyStyle(
                AppType.bodyMd,
                weight: FontWeight.w600,
              ).copyWith(color: s.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              l10n.circlesLoadWhoCanSeeErrorDetail,
              style: AppType.bodyStyle(
                AppType.bodySm,
              ).copyWith(color: s.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpace.lg),
            SizedBox(
              height: AppSpace.gloveTarget,
              child: FilledButton(
                onPressed: onRetry,
                child: Text(l10n.circlesTryAgainAction),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
