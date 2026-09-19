import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';

/// The monthly nudge from FR-014 / SG-01: a recurring prompt to look at who
/// can see you.
///
/// Attention tier, dismissible, and never modal. A safety product that
/// interrupts you every month with a full-screen blocker gets uninstalled,
/// and an uninstalled app protects nobody.
class SharingReviewBanner extends StatelessWidget {
  const SharingReviewBanner({
    super.key,
    required this.watcherCount,
    required this.onReview,
    this.onDismiss,
  });

  final int watcherCount;
  final VoidCallback onReview;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpace.lg),
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: s.surface3,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: s.attentionAccent,
          width: AppStroke.resolve(AppStroke.regular, sunlight: s.isSunlight),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.circlesMonthlyCheckTitle,
            style: AppType.bodyStyle(
              AppType.bodyMd,
              weight: FontWeight.w600,
            ).copyWith(color: s.textPrimary),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            l10n.circlesWatcherCountBanner(watcherCount),
            style: AppType.bodyStyle(
              AppType.bodySm,
            ).copyWith(color: s.textSecondary),
          ),
          const SizedBox(height: AppSpace.lg),
          Row(
            children: [
              SizedBox(
                height: AppSpace.gloveTarget,
                child: FilledButton(
                  onPressed: onReview,
                  child: Text(l10n.circlesReviewListAction),
                ),
              ),
              if (onDismiss != null) ...[
                const SizedBox(width: AppSpace.md),
                SizedBox(
                  height: AppSpace.gloveTarget,
                  child: TextButton(
                    onPressed: onDismiss,
                    child: Text(l10n.circlesNotNowAction),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
