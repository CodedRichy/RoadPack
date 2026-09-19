import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';
import '../models/commute_watch.dart';
import '../providers/commute_watch_provider.dart';
import '../widgets/check_in_countdown.dart';
import '../widgets/running_late_button.dart';

/// "Everything okay?" — the check-in the rider sees when a commute overruns
/// its grace window (FR-042/043/044).
///
/// This screen is an **attention** surface, never an emergency one. Nobody has
/// been alerted, and the likeliest explanation by a wide margin is traffic.
/// Dressing it in the emergency tier would spend the rider's alarm response on
/// a jam near Vytila and leave nothing for a real crash.
///
/// Layout is thumb-first: the countdown sits at the top where it is read, and
/// the three answers sit at the bottom where they are pressed. "I'm running
/// late" is the largest and lowest, because it is the one pressed most often
/// and the one pressed one-handed at a light.
class NonArrivalCheckScreen extends ConsumerStatefulWidget {
  const NonArrivalCheckScreen({super.key});

  static const String routePath = '/commute/check-in';

  @override
  ConsumerState<NonArrivalCheckScreen> createState() =>
      _NonArrivalCheckScreenState();
}

class _NonArrivalCheckScreenState extends ConsumerState<NonArrivalCheckScreen> {
  Timer? _ticker;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // The rider is looking at the question now; the five minutes start now.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(commuteWatchProvider.notifier).markPrompted();
    });
    _ticker = Timer.periodic(AppMotion.pulse, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;
    final watch = ref.watch(commuteWatchProvider);

    if (watch == null) {
      return Scaffold(
        backgroundColor: s.canvas,
        body: Center(
          child: Text(
            l10n.commuteNothingToCheckIn,
            style: AppType.bodyStyle(AppType.bodyMd),
          ),
        ),
      );
    }

    final now = DateTime.now();
    final phase = watch.phaseAt(now);
    final escalated = phase == CommuteWatchPhase.escalated;

    return Scaffold(
      backgroundColor: s.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            AppSpace.xl,
            AppSpace.gutter,
            AppSpace.xl,
          ),
          // The answers stay pinned to the bottom of the screen while the
          // explanation above them scrolls. A rider running 1.5x text on a
          // 360dp phone must still be able to reach "I'm running late"
          // without hunting for it, and an overflowing column would push it
          // off the screen exactly when it is needed most.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        escalated
                            ? l10n.commuteCircleToldHeading
                            : l10n.commuteCheckingInHeading,
                        style: AppType.eyebrow(AppType.labelMd).copyWith(
                          color: escalated ? s.emergency : s.attentionAccent,
                        ),
                      ),
                      const SizedBox(height: AppSpace.md),
                      Text(
                        escalated
                            ? l10n.commuteWeLetThemKnow
                            : l10n.commuteEverythingOkay,
                        style: AppType.displayStyle(AppType.titleMd),
                      ),
                      const SizedBox(height: AppSpace.sm),
                      Text(
                        escalated
                            ? l10n.commuteEscalatedBody
                            : l10n.commuteTravellingBody,
                        style: AppType.bodyStyle(
                          AppType.bodyMd,
                        ).copyWith(color: s.textSecondary),
                      ),
                      const SizedBox(height: AppSpace.xxl),
                      if (!escalated)
                        CheckInCountdown(
                          remaining: watch.remainingToEscalationAt(now),
                          total: CommuteWatch.escalationDelay,
                          caption: l10n.commuteAnswerCaption,
                        ),
                      const SizedBox(height: AppSpace.xl),
                    ],
                  ),
                ),
              ),
              if (!escalated) ...[
                RunningLateButton(
                  enabled: !_busy,
                  onSnooze: (snooze) => _run(
                    () => ref
                        .read(commuteWatchProvider.notifier)
                        .imRunningLate(snooze),
                    message: l10n.commuteSnoozeExtendedMessage(
                      l10n.commuteSpokenMinutes(snooze.minutes),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
              ],
              _SecondaryAnswers(
                busy: _busy,
                escalated: escalated,
                onFine: () => _run(
                  () => ref.read(commuteWatchProvider.notifier).imFine(),
                  message: l10n.commuteGladYouMadeIt,
                ),
                onNeedHelp: () => _run(
                  () => ref.read(commuteWatchProvider.notifier).needHelp(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _run(Future<void> Function() action, {String? message}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      if (message != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _SecondaryAnswers extends StatelessWidget {
  const _SecondaryAnswers({
    required this.busy,
    required this.escalated,
    required this.onFine,
    required this.onNeedHelp,
  });

  final bool busy;
  final bool escalated;
  final VoidCallback onFine;
  final VoidCallback onNeedHelp;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: AppSpace.gloveTarget,
          child: OutlinedButton(
            key: const Key('check-in-fine'),
            onPressed: busy ? null : onFine,
            child: Text(
              escalated ? l10n.commuteFineTellThem : l10n.commuteArrivedFine,
              style: AppType.bodyStyle(AppType.bodyMd, weight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        SizedBox(
          height: AppSpace.gloveTarget,
          child: Material(
            color: s.emergency,
            borderRadius: AppRadius.mdAll,
            child: InkWell(
              key: const Key('check-in-need-help'),
              onTap: busy ? null : onNeedHelp,
              borderRadius: AppRadius.mdAll,
              child: Center(
                child: Text(
                  l10n.commuteNeedHelp,
                  style: AppType.bodyStyle(
                    AppType.bodyMd,
                    weight: FontWeight.w700,
                  ).copyWith(color: s.onEmergency),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
