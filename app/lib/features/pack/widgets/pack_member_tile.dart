import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';
import '../models/pack_gap.dart';
import '../models/pack_member.dart';
import '../models/pack_status.dart';
import 'gap_readout.dart';
import 'pack_status_chip.dart';

/// One rider in the pack list.
///
/// Name and role on the left, status underneath, gap on the right. The gap
/// column is the one the eye lands on, so it holds the right edge at a fixed
/// width and is set in tabular figures — a number that shifts sideways every
/// five seconds is a number nobody reads.
class PackMemberTile extends StatelessWidget {
  const PackMemberTile({
    required this.gap,
    super.key,
    this.member,
    this.isCurrentUser = false,
    this.now,
    this.onTap,
  });

  final PackGap gap;

  /// Carries the display name and `chainage_at`. Absent while the roster is
  /// still loading; the tile degrades to the user id rather than blocking the
  /// gap, which is the part that matters.
  final PackMember? member;

  final bool isCurrentUser;
  final DateTime? now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;
    final incident = gap.statusCode == PackStatus.possibleIncident;
    final name = member?.displayName?.trim();

    return Semantics(
      button: onTap != null,
      container: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSpace.gloveTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.lg,
            vertical: AppSpace.md,
          ),
          decoration: BoxDecoration(
            color: s.surface1,
            borderRadius: AppRadius.mdAll,
            border: Border.all(
              // possible_incident is the only pack state that may borrow the
              // emergency tier. Everything else stays inside the hairline.
              color: incident ? s.emergency : s.hairline,
              width: AppStroke.resolve(
                incident ? AppStroke.heavy : AppStroke.hairline,
                sunlight: s.isSunlight,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _RoleMark(role: gap.role),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name == null || name.isEmpty
                          ? (isCurrentUser ? l10n.packYouLabel : gap.userId)
                          : (isCurrentUser
                                ? l10n.packNameYouSuffix(name)
                                : name),
                      overflow: TextOverflow.ellipsis,
                      style: AppType.bodyStyle(
                        AppType.bodyMd,
                        weight: FontWeight.w600,
                      ).copyWith(color: s.textPrimary),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: PackStatusChip(
                        status: gap.statusCode,
                        isAutomatic: gap.statusAuto,
                        note: member?.statusNote,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.md),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 92),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: GapReadout(
                    gap: gap,
                    lastSeenAt: member?.chainageAt,
                    now: now,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Leader and sweep are the two positions the pack navigates by. Riders in
/// between are unmarked on purpose — a list where every row is decorated is a
/// list with no signal in it.
class _RoleMark extends StatelessWidget {
  const _RoleMark({required this.role});

  final PackRole role;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;
    final (IconData icon, Color colour) = switch (role) {
      PackRole.leader => (Icons.navigation, s.protectedAccent),
      PackRole.sweep => (Icons.arrow_downward, s.watchAccent),
      PackRole.rider => (Icons.circle_outlined, s.textMuted),
    };
    final label = switch (role) {
      PackRole.leader => l10n.packRoleLeader,
      PackRole.sweep => l10n.packRoleSweep,
      PackRole.rider => l10n.packRoleRider,
    };

    return SizedBox(
      width: 28,
      child: Tooltip(
        message: label,
        child: Icon(icon, size: 18, color: colour),
      ),
    );
  }
}
