import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';
import '../../consent/models/visibility_report.dart';

/// One circle's row on "Who can see me" (FR-014).
///
/// Shows the sharing state, everyone it exposes and why, and — only when the
/// user can actually change it — the switch. There are two, because the
/// server has two terms: the circle-wide flag (`circles_update` RLS is
/// admin-only, so members never see that one) and the member's own
/// `permissions.share_location`, which anyone can set on their own row.
/// Offering a switch that silently no-ops would be the exact reassurance
/// FR-014 exists to prevent.
class VisibilityCircleCard extends StatelessWidget {
  const VisibilityCircleCard({
    super.key,
    required this.visibility,
    required this.onSharingChanged,
    this.onSelfSharingChanged,
    this.onLeave,
    this.busy = false,
  });

  final CircleVisibility visibility;
  final ValueChanged<bool> onSharingChanged;

  /// The member-side opt-out. Offered only while
  /// [kMemberLocationOptOutEnforced] is true — a switch the server ignores
  /// is worse than no switch, because the user would believe it worked.
  final ValueChanged<bool>? onSelfSharingChanged;

  /// A member's only real lever over a circle they do not administer.
  final VoidCallback? onLeave;

  final bool busy;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;
    final circle = visibility.circle;
    final sharing = visibility.sharingEnabled;
    final watchers = visibility.watchers;
    final canOptOut =
        kMemberLocationOptOutEnforced &&
        sharing &&
        onSelfSharingChanged != null;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpace.md),
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: s.surface2,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: sharing ? s.watchAccent : s.border,
          width: AppStroke.resolve(AppStroke.hairline, sunlight: s.isSunlight),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      circle.name,
                      style: AppType.bodyStyle(
                        AppType.bodyMd,
                        weight: FontWeight.w600,
                      ).copyWith(color: s.textPrimary),
                    ),
                    Text(
                      circle.type.displayName(l10n),
                      style: AppType.eyebrow(
                        AppType.labelSm,
                      ).copyWith(color: s.textMuted),
                    ),
                  ],
                ),
              ),
              if (visibility.viewerIsAdmin)
                SizedBox(
                  height: AppSpace.gloveTarget,
                  child: Center(
                    child: Switch(
                      value: sharing,
                      onChanged: busy ? null : onSharingChanged,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            sharing
                ? (watchers.isEmpty
                      ? l10n.circlesSharingOnEmptyDetail
                      : l10n.circlesWatchersHereDetail(watchers.length))
                : l10n.circlesSharingOffDetail,
            style: AppType.bodyStyle(
              AppType.bodySm,
            ).copyWith(color: s.textSecondary),
          ),
          if (watchers.isNotEmpty) ...[
            const SizedBox(height: AppSpace.md),
            for (final w in watchers)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.xs),
                child: Row(
                  children: [
                    Container(
                      width: AppSpace.sm,
                      height: AppSpace.sm,
                      decoration: BoxDecoration(
                        color: s.watchAccent,
                        borderRadius: AppRadius.pillAll,
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Text(
                        l10n.circlesWatcherRow(
                          w.name,
                          w.role.displayName(l10n).toLowerCase(),
                        ),
                        style: AppType.bodyStyle(
                          AppType.bodySm,
                        ).copyWith(color: s.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (canOptOut) ...[
            const SizedBox(height: AppSpace.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    l10n.circlesShareMyLocationTitle,
                    style: AppType.bodyStyle(
                      AppType.bodySm,
                      weight: FontWeight.w600,
                    ).copyWith(color: s.textPrimary),
                  ),
                ),
                SizedBox(
                  height: AppSpace.gloveTarget,
                  child: Center(
                    child: Switch(
                      value: visibility.selfSharingEnabled,
                      onChanged: busy ? null : onSelfSharingChanged,
                    ),
                  ),
                ),
              ],
            ),
            // The one thing a user must not get wrong here: switching this
            // off stops the live dot, not the safety net. If this reads as
            // "turn off protection", people who need it most will leave the
            // circle instead — which costs them the alert cascade too.
            Text(
              visibility.selfSharingEnabled
                  ? l10n.circlesSelfSharingOnDetail
                  : l10n.circlesSelfSharingOffDetail,
              style: AppType.bodyStyle(
                AppType.bodySm,
              ).copyWith(color: s.textSecondary),
            ),
          ],
          if (!visibility.viewerIsAdmin) ...[
            const SizedBox(height: AppSpace.md),
            Text(
              kMemberLocationOptOutEnforced
                  ? l10n.circlesAdminOnlyOptOutNotice
                  : l10n.circlesAdminOnlyNoOptOutNotice,
              style: AppType.bodyStyle(
                AppType.labelMd,
              ).copyWith(color: s.attentionAccent),
            ),
            if (onLeave != null) ...[
              const SizedBox(height: AppSpace.md),
              SizedBox(
                height: AppSpace.gloveTarget,
                child: OutlinedButton(
                  onPressed: busy ? null : onLeave,
                  child: Text(l10n.circlesLeaveThisCircleAction),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
