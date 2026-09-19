import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';
import '../models/commute_route.dart';

/// One commute, with the facts that decide whether it protects anybody
/// (FR-040): repetition count, confidence, typical start, typical duration and
/// the days it runs.
///
/// The card refuses to overstate itself. A route still learning says how many
/// more trips it needs; a route whose schedule is incomplete says it is not
/// watching, even when the toggle is on, because the edge function will skip
/// it and a green switch over a dead watch is exactly the kind of comfortable
/// lie this product exists to avoid.
class CommuteRouteCard extends StatelessWidget {
  const CommuteRouteCard({
    required this.route,
    required this.onToggleNonArrival,
    this.onTap,
    super.key,
  });

  final CommuteRoute route;
  final ValueChanged<bool> onToggleNonArrival;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpace.md),
      decoration: BoxDecoration(
        color: s.surface1,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: s.hairline,
          width: AppStroke.resolve(AppStroke.hairline, sunlight: s.isSunlight),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        route.displayName,
                        style: AppType.displayStyle(AppType.titleSm),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    _SourceTag(route: route),
                  ],
                ),
                const SizedBox(height: AppSpace.md),
                _ScheduleRow(route: route),
                const SizedBox(height: AppSpace.md),
                _DayStrip(daysActive: route.daysActive),
                if (route.isLearning) ...[
                  const SizedBox(height: AppSpace.md),
                  _LearningNote(route: route),
                ],
                const SizedBox(height: AppSpace.md),
                Divider(color: s.hairline, height: 1),
                const SizedBox(height: AppSpace.sm),
                _WatchRow(route: route, onChanged: onToggleNonArrival),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceTag extends StatelessWidget {
  const _SourceTag({required this.route});

  final CommuteRoute route;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;
    final manual = route.source == RouteSource.manual;
    final label = manual
        ? l10n.commuteAddedByYouBadge
        : l10n.commuteTripsBadge(route.repetitionCount);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xs,
      ),
      decoration: BoxDecoration(
        color: s.surface2,
        borderRadius: AppRadius.smAll,
      ),
      child: Text(
        label,
        style: AppType.eyebrow(AppType.labelSm).copyWith(color: s.textMuted),
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.route});

  final CommuteRoute route;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: _Field(
            label: l10n.commuteLeavesLabel,
            value: route.typicalStart ?? '--:--',
          ),
        ),
        Expanded(
          child: _Field(
            label: l10n.commuteTakesLabel,
            value: route.typicalDurationMin == null
                ? '--'
                : l10n.minutesShort(route.typicalDurationMin!),
          ),
        ),
        Expanded(
          child: _Field(
            label: l10n.commuteArrivesLabel,
            value: _arrival(route) ?? '--:--',
          ),
        ),
      ],
    );
  }

  static String? _arrival(CommuteRoute route) {
    final start = route.typicalStartMinutes;
    final duration = route.typicalDurationMin;
    if (start == null || duration == null) return null;
    final total = (start + duration) % (24 * 60);
    return '${(total ~/ 60).toString().padLeft(2, '0')}:'
        '${(total % 60).toString().padLeft(2, '0')}';
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppType.eyebrow(AppType.labelSm).copyWith(color: s.textMuted),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          value,
          style: AppType.figure(AppType.bodyMd).copyWith(color: s.textPrimary),
        ),
      ],
    );
  }
}

/// Seven fixed slots, so a rider reads the shape of their week rather than a
/// list of chips whose position moves with the content.
class _DayStrip extends StatelessWidget {
  const _DayStrip({required this.daysActive});

  final List<int> daysActive;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;
    final letters = [
      l10n.commuteDayLetterMon,
      l10n.commuteDayLetterTue,
      l10n.commuteDayLetterWed,
      l10n.commuteDayLetterThu,
      l10n.commuteDayLetterFri,
      l10n.commuteDayLetterSat,
      l10n.commuteDayLetterSun,
    ];

    return Semantics(
      label: l10n.commuteDaysActiveSemantics(daysActive.length),
      excludeSemantics: true,
      child: Row(
        children: [
          for (var day = 1; day <= 7; day++) ...[
            Container(
              width: AppSpace.xl,
              height: AppSpace.xl,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: daysActive.contains(day)
                    ? s.protectedFill
                    : Colors.transparent,
                borderRadius: AppRadius.smAll,
                border: Border.all(
                  color: daysActive.contains(day)
                      ? s.protectedAccent
                      : s.hairline,
                  width: AppStroke.resolve(
                    AppStroke.hairline,
                    sunlight: s.isSunlight,
                  ),
                ),
              ),
              child: Text(
                letters[day - 1],
                style:
                    AppType.bodyStyle(
                      AppType.labelSm,
                      weight: FontWeight.w600,
                    ).copyWith(
                      color: daysActive.contains(day)
                          ? s.protectedAccent
                          : s.textMuted,
                    ),
              ),
            ),
            if (day < 7) const SizedBox(width: AppSpace.xs),
          ],
        ],
      ),
    );
  }
}

class _LearningNote extends StatelessWidget {
  const _LearningNote({required this.route});

  final CommuteRoute route;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final remaining = route.repetitionsRemaining;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.timelapse, size: 16, color: s.attentionAccent),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Text(
            context.l10n.commuteLearningNote(remaining),
            style: AppType.bodyStyle(
              AppType.bodySm,
            ).copyWith(color: s.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _WatchRow extends StatelessWidget {
  const _WatchRow({required this.route, required this.onChanged});

  final CommuteRoute route;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;

    final (String title, String? detail) = switch (route) {
      _ when !route.nonArrivalEnabled => (
        l10n.commuteNotWatchingTitle,
        null,
      ),
      _ when !route.isKnown => (
        l10n.commuteWatchingOnceLearnedTitle,
        l10n.commuteNeedsMoreTripsDetail(route.repetitionsRemaining),
      ),
      _ when !route.canWatch => (
        l10n.commuteNotWatchingYetTitle,
        l10n.commuteMissingScheduleDetail,
      ),
      _ => (l10n.commuteWatchingTitle, null),
    };

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    AppType.bodyStyle(
                      AppType.bodySm,
                      weight: FontWeight.w600,
                    ).copyWith(
                      color: route.isWatched
                          ? s.protectedAccent
                          : s.textSecondary,
                    ),
              ),
              if (detail != null) ...[
                const SizedBox(height: AppSpace.xs),
                Text(
                  detail,
                  style: AppType.bodyStyle(
                    AppType.labelMd,
                  ).copyWith(color: s.textMuted),
                ),
              ],
            ],
          ),
        ),
        Switch(value: route.nonArrivalEnabled, onChanged: onChanged),
      ],
    );
  }
}
