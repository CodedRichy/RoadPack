import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/l10n.dart';
import '../models/member_position.dart';
import '../models/member_presence.dart';
import 'freshness_chip.dart';

/// Detail for one tapped member (FR-050), written to FR-053's rules.
///
/// Two things this sheet deliberately refuses to do:
///  * present a speed taken from a fix that is no longer fresh — a stale speed
///    describes a moment that has passed, and reading "61 km/h" next to a
///    four-minute-old dot invites exactly the wrong wait/continue decision;
///  * offer any live affordance (pulsing dot, "following", live label) unless
///    the device is genuinely still reporting.
class MemberDetailSheet extends StatelessWidget {
  const MemberDetailSheet({
    super.key,
    required this.member,
    required this.now,
    this.onClose,
  });

  final MapMember member;

  /// Injected rather than read from the clock so age is deterministic and
  /// testable, and so every marker on one frame ages against one instant.
  final DateTime now;

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;
    final presence = MemberPresence.resolve(
      position: member.position,
      now: now,
    );
    final speed = presence.trustedSpeedKmh;
    final battery = presence.batteryLevel;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        AppSpace.lg,
        AppSpace.gutter,
        AppSpace.xl,
      ),
      decoration: BoxDecoration(
        color: s.surface1,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
        border: Border.all(
          color: s.hairline,
          width: AppStroke.resolve(AppStroke.hairline, sunlight: s.isSunlight),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  member.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.displayStyle(
                    AppType.titleSm,
                  ).copyWith(color: s.textPrimary),
                ),
              ),
              if (onClose != null)
                IconButton(
                  onPressed: onClose,
                  iconSize: 24,
                  constraints: const BoxConstraints(
                    minWidth: AppSpace.gloveTarget,
                    minHeight: AppSpace.gloveTarget,
                  ),
                  icon: Icon(Icons.close, color: s.textSecondary),
                  tooltip: l10n.commonClose,
                ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          FreshnessChip(presence: presence),
          const SizedBox(height: AppSpace.md),
          Text(
            presence.detail(context.l10n),
            style: AppType.bodyStyle(
              AppType.bodySm,
            ).copyWith(color: s.textSecondary),
          ),
          const SizedBox(height: AppSpace.lg),
          Wrap(
            spacing: AppSpace.xl,
            runSpacing: AppSpace.lg,
            children: [
              _Readout(
                label: l10n.mapLastUpdateLabel,
                value: presence.age == null
                    ? '--'
                    : l10n.mapLastUpdateValue(
                        MemberPresence.formatAge(presence.age!),
                      ),
                muted: presence.isStale,
              ),
              if (speed != null)
                _Readout(
                  label: l10n.mapSpeedLabel,
                  value: l10n.mapSpeedValue(speed.round()),
                  muted: false,
                )
              else
                _Readout(
                  label: l10n.mapSpeedLabel,
                  value: presence.isStale
                      ? l10n.mapSpeedNotCurrent
                      : l10n.mapSpeedUnknown,
                  muted: true,
                ),
              if (battery != null)
                _Readout(
                  label: l10n.mapBatteryLabel,
                  value: l10n.mapBatteryValue(battery),
                  muted: presence.isStale,
                ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          Text(
            _footnote(l10n, presence),
            style: AppType.bodyStyle(
              AppType.labelMd,
            ).copyWith(color: s.textMuted),
          ),
        ],
      ),
    );
  }

  String _footnote(AppLocalizations l10n, MemberPresence presence) {
    switch (presence.state) {
      case MemberDisplayState.locating:
        return l10n.mapFootnoteLocating;
      case MemberDisplayState.live:
      case MemberDisplayState.stationary:
        return l10n.mapFootnoteLive;
      case MemberDisplayState.stale:
      case MemberDisplayState.unreachable:
        return l10n.mapFootnoteStale;
    }
  }
}

class _Readout extends StatelessWidget {
  const _Readout({
    required this.label,
    required this.value,
    required this.muted,
  });

  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppType.eyebrow(AppType.labelSm).copyWith(color: s.textMuted),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          value,
          style: AppType.figure(
            AppType.bodyLg,
          ).copyWith(color: muted ? s.textMuted : s.textPrimary),
        ),
      ],
    );
  }
}
