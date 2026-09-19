import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';
import '../models/pack_ride.dart';
import 'viewer_count_badge.dart';

/// The share link, and an honest account of what it is doing.
///
/// There is no covert mode. A device in a ride says so, permanently and
/// without being asked, because the alternative — a location feed a rider has
/// forgotten is running — is the failure this whole feature is shaped to
/// avoid. So the card leads with the live state, shows the audience, shows
/// when the link dies on its own, and keeps revoke one tap away.
class ShareLinkCard extends StatelessWidget {
  const ShareLinkCard({
    required this.ride,
    super.key,
    this.viewerCount = 0,
    this.onRevoke,
    this.now,
    this.baseUrl = 'https://roadpack.app/p',
  });

  final PackRide ride;
  final int viewerCount;
  final VoidCallback? onRevoke;
  final DateTime? now;
  final String baseUrl;

  String get shareUrl => '$baseUrl/${ride.shareToken}';

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;
    final live = ride.isShareLive(now);

    return Container(
      padding: AppSpace.card,
      decoration: BoxDecoration(
        color: s.surface1,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: live ? s.watchAccent : s.hairline,
          width: AppStroke.resolve(
            live ? AppStroke.regular : AppStroke.hairline,
            sunlight: s.isSunlight,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  live
                      ? l10n.packSharingLiveHeadline
                      : l10n.packSharingOffHeadline,
                  style: AppType.bodyStyle(
                    AppType.bodyMd,
                    weight: FontWeight.w600,
                  ).copyWith(color: s.textPrimary),
                ),
              ),
              ViewerCountBadge(count: viewerCount, isLive: live),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            live
                ? l10n.packLiveNotice(_expiryLabel(l10n))
                : l10n.packLinkExpiredNotice,
            style: AppType.bodyStyle(
              AppType.bodySm,
            ).copyWith(color: s.textSecondary),
          ),
          if (live) ...[
            const SizedBox(height: AppSpace.lg),
            SelectableText(
              shareUrl,
              key: const Key('pack-share-url'),
              style: AppType.figure(
                AppType.bodySm,
              ).copyWith(color: s.textSecondary),
            ),
            const SizedBox(height: AppSpace.md),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _share(l10n),
                    icon: const Icon(Icons.ios_share, size: 18),
                    label: Text(l10n.packShareLinkAction),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, AppSpace.gloveTarget),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                IconButton(
                  onPressed: () => _copy(context),
                  tooltip: l10n.packCopyLinkTooltip,
                  iconSize: 22,
                  constraints: const BoxConstraints(
                    minWidth: AppSpace.gloveTarget,
                    minHeight: AppSpace.gloveTarget,
                  ),
                  icon: const Icon(Icons.copy_rounded),
                ),
              ],
            ),
            if (onRevoke != null) ...[
              const SizedBox(height: AppSpace.sm),
              TextButton(
                onPressed: onRevoke,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, AppSpace.tapTarget),
                  foregroundColor: s.attentionAccent,
                ),
                child: Text(l10n.packStopSharingAction),
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _expiryLabel(AppLocalizations l10n) {
    final ends = ride.shareExpiresAt ?? ride.expiresAt;
    final remaining = ends.difference(now ?? DateTime.now().toUtc());
    if (remaining.isNegative) return l10n.packExpiresNow;
    if (remaining.inHours >= 1) {
      return l10n.packExpiresInHours(remaining.inHours);
    }
    return l10n.packExpiresInMinutes(remaining.inMinutes);
  }

  Future<void> _share(AppLocalizations l10n) async {
    final name = ride.name ?? l10n.packDefaultShareRideName;
    await Share.share(l10n.packShareMessage(name, shareUrl));
  }

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    await Clipboard.setData(ClipboardData(text: shareUrl));
    messenger.showSnackBar(SnackBar(content: Text(l10n.packLinkCopiedSnackbar)));
  }
}
