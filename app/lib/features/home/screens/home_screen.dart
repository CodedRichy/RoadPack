import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';
import '../../auth/providers/user_profile_provider.dart';
import '../../circles/models/circle.dart';
import '../../circles/providers/circles_provider.dart';
import '../../crash_detection/models/crash_state.dart';
import '../../crash_detection/providers/crash_detection_provider.dart';
import '../../emergency_profile/providers/emergency_contacts_provider.dart';
import '../../tracking/services/tracking_service.dart';
import '../widgets/milestone.dart';

/// The front door.
///
/// This screen answers two questions and defers everything else: *am I
/// protected right now*, and *who is watching*. Navigation is a quiet row at
/// the bottom, because a menu is what you build when you don't know what the
/// screen is for.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.semantics;
    final protection = ref.watch(protectionStatusProvider);
    final circles = ref.watch(circlesProvider);
    final sunlight = ref.watch(sunlightModeProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.appTitle,
          style: AppType.displayStyle(AppType.titleSm),
        ),
        actions: [
          IconButton(
            tooltip: sunlight
                ? l10n.homeSwitchToNight
                : l10n.homeSwitchToSunlight,
            icon: Icon(sunlight ? Icons.dark_mode : Icons.light_mode),
            onPressed: () => ref.read(sunlightModeProvider.notifier).toggle(),
          ),
          IconButton(
            tooltip: l10n.commonSettings,
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: AppSpace.xs),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(circlesProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            AppSpace.lg,
            AppSpace.gutter,
            AppSpace.huge,
          ),
          children: [
            Milestone(status: protection),
            const SizedBox(height: AppSpace.xl),
            _ChecklistRow(status: protection),
            const SizedBox(height: AppSpace.xxl),
            const _PackFrontDoor(),
            const SizedBox(height: AppSpace.xxl),
            _WatchersSection(circles: circles),
            const SizedBox(height: AppSpace.xxl),
            Divider(color: s.hairline),
            const _NavRow(),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Protection status
// --------------------------------------------------------------------------

/// What the milestone reads.
enum ProtectionLevel {
  /// Everything that can watch the rider is watching.
  armed,

  /// Some cover, but a gap the rider should know about.
  partial,

  /// Nothing is watching.
  off,

  /// An incident is live right now. Emergency tier.
  incident,
}

/// Which hole in the rider's cover is the one worth naming.
enum ProtectionGapKind { noContact, crashOff, trackingOff, nonArrivalOff }

/// The single most important thing standing between the rider and cover,
/// named specifically enough to act on and carrying the route that fixes it.
///
/// "Partly covered" on its own is a shrug. The rider needs to know *which*
/// hole and *where the patch is*.
@immutable
class ProtectionGap {
  const ProtectionGap({required this.kind, required this.route});

  final ProtectionGapKind kind;

  /// Where the fix lives.
  final String route;

  /// Copy is resolved at render time rather than stored on the model: the gap
  /// is a fact about the rider's cover, and that fact does not change when the
  /// phone changes language.
  String headline(AppLocalizations l10n) => switch (kind) {
    ProtectionGapKind.noContact => l10n.gapNoContactHeadline,
    ProtectionGapKind.crashOff => l10n.gapCrashOffHeadline,
    ProtectionGapKind.trackingOff => l10n.gapTrackingOffHeadline,
    ProtectionGapKind.nonArrivalOff => l10n.gapNonArrivalOffHeadline,
  };

  String detail(AppLocalizations l10n) => switch (kind) {
    ProtectionGapKind.noContact => l10n.gapNoContactDetail,
    ProtectionGapKind.crashOff => l10n.gapCrashOffDetail,
    ProtectionGapKind.trackingOff => l10n.gapTrackingOffDetail,
    ProtectionGapKind.nonArrivalOff => l10n.gapNonArrivalOffDetail,
  };

  String actionLabel(AppLocalizations l10n) => switch (kind) {
    ProtectionGapKind.noContact => l10n.gapNoContactAction,
    ProtectionGapKind.crashOff || ProtectionGapKind.trackingOff =>
      l10n.gapTurnOnAction,
    ProtectionGapKind.nonArrivalOff => l10n.gapSetUpCommutesAction,
  };
}

@immutable
class ProtectionStatus {
  const ProtectionStatus({
    required this.level,
    required this.crashDetection,
    required this.tracking,
    required this.nonArrival,
    required this.emergencyContact,
  });

  /// Folds the raw facts into the one verdict the front door shows.
  ///
  /// The rule that matters: **an emergency contact is a precondition for
  /// cover, not a nice-to-have.** Crash detection can fire perfectly and the
  /// cascade still reaches nobody, so a rider without a contact is never told
  /// they are covered — no matter how many systems are running.
  factory ProtectionStatus.resolve({
    required bool crashDetection,
    required bool tracking,
    required bool nonArrival,
    required bool emergencyContact,
    bool incident = false,
  }) {
    final live = [
      crashDetection,
      tracking,
      nonArrival,
    ].where((e) => e).length;

    final level = switch (0) {
      _ when incident => ProtectionLevel.incident,
      _ when live == 0 => ProtectionLevel.off,
      _ when live == 3 && emergencyContact => ProtectionLevel.armed,
      _ => ProtectionLevel.partial,
    };

    return ProtectionStatus(
      level: level,
      crashDetection: crashDetection,
      tracking: tracking,
      nonArrival: nonArrival,
      emergencyContact: emergencyContact,
    );
  }

  final ProtectionLevel level;
  final bool crashDetection;
  final bool tracking;
  final bool nonArrival;

  /// Whether at least one verified emergency contact exists to receive the
  /// cascade. Sourced from `emergencyProfileReadyProvider`, which is
  /// deliberately false while loading.
  final bool emergencyContact;

  /// How many of the three watchers are live.
  int get activeCount =>
      (crashDetection ? 1 : 0) + (tracking ? 1 : 0) + (nonArrival ? 1 : 0);

  /// The gap worth naming, or null when there is nothing to fix.
  ///
  /// Ordered by consequence: a missing contact breaks every system at once,
  /// so it is reported before any individual system that is merely off.
  ProtectionGap? get gap {
    if (level == ProtectionLevel.incident) return null;
    if (!emergencyContact) {
      return const ProtectionGap(
        kind: ProtectionGapKind.noContact,
        route: '/emergency-contacts',
      );
    }
    if (!crashDetection) {
      return const ProtectionGap(
        kind: ProtectionGapKind.crashOff,
        route: '/settings',
      );
    }
    if (!tracking) {
      return const ProtectionGap(
        kind: ProtectionGapKind.trackingOff,
        route: '/settings',
      );
    }
    if (!nonArrival) {
      return const ProtectionGap(
        kind: ProtectionGapKind.nonArrivalOff,
        route: '/commute',
      );
    }
    return null;
  }
}

/// Folds the three independent safety systems into the one fact the rider
/// actually needs at the front door.
final protectionStatusProvider = Provider<ProtectionStatus>((ref) {
  final crash = ref.watch(crashDetectionProvider);
  final tracking = ref.watch(trackingServiceProvider) != null;
  final profile = ref.watch(userProfileProvider).valueOrNull;
  final nonArrival = profile?.nonArrivalEnabled ?? false;

  final crashLive = switch (crash.status) {
    CrashDetectionStatus.monitoring => true,
    CrashDetectionStatus.detected => true,
    CrashDetectionStatus.countdown => true,
    CrashDetectionStatus.dispatching => true,
    CrashDetectionStatus.active => true,
    _ => false,
  };

  final incident =
      crash.status == CrashDetectionStatus.countdown ||
      crash.status == CrashDetectionStatus.dispatching ||
      crash.status == CrashDetectionStatus.active;

  return ProtectionStatus.resolve(
    crashDetection: crashLive,
    tracking: tracking,
    nonArrival: nonArrival,
    // Fail-closed by construction: this provider reports false while the
    // contact list is still loading or errored, so the front door under-claims
    // rather than over-claims protection.
    emergencyContact: ref.watch(emergencyProfileReadyProvider),
    incident: incident,
  );
});

// --------------------------------------------------------------------------
// Sections
// --------------------------------------------------------------------------

/// The three systems, spelled out under the milestone.
///
/// A single fused status word is fast to read but hides which system is down,
/// so the milestone gives the verdict and this row gives the evidence.
class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.status});

  final ProtectionStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      children: [
        Expanded(
          child: _Check(
            label: l10n.checkCrashDetection,
            on: status.crashDetection,
          ),
        ),
        Expanded(
          child: _Check(label: l10n.checkLocationTracking, on: status.tracking),
        ),
        Expanded(
          child: _Check(label: l10n.checkNonArrival, on: status.nonArrival),
        ),
        // The fourth column is not a system the app runs; it is the person the
        // other three shout at. Without it the row is a lie of omission.
        Expanded(
          child: _Check(
            label: l10n.checkEmergencyContact,
            on: status.emergencyContact,
          ),
        ),
      ],
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.label, required this.on});

  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;
    final colour = on ? s.protectedAccent : s.textMuted;

    return Semantics(
      label: l10n.checkSemantics(
        label.replaceAll('\n', ' '),
        on ? l10n.commonOn : l10n.commonOff,
      ),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // State is carried by the bar's weight as well as its colour, so the
          // row still reads with red-green colour vision deficiency.
          Container(
            height: on ? AppStroke.emphatic : AppStroke.hairline,
            margin: const EdgeInsets.only(right: AppSpace.sm),
            color: colour,
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            label,
            style: AppType.bodyStyle(
              AppType.bodySm,
              weight: on ? FontWeight.w600 : FontWeight.w400,
            ).copyWith(color: on ? s.textPrimary : s.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Who is watching.
class _WatchersSection extends StatelessWidget {
  const _WatchersSection({required this.circles});

  final AsyncValue<List<Circle>> circles;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.watchersHeading,
          style: AppType.eyebrow(AppType.labelMd).copyWith(color: s.textMuted),
        ),
        const SizedBox(height: AppSpace.md),
        circles.when(
          loading: () => _WatchersSkeleton(colour: s.surface2),
          error: (e, _) =>
              _WatchersMessage(text: l10n.watchersError, action: null),
          data: (list) {
            if (list.isEmpty) {
              return _WatchersMessage(
                text: l10n.watchersEmpty,
                action: (l10n.watchersCreateCircle, '/circles/new'),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${list.length}',
                        style: AppType.figure(
                          AppType.titleLg,
                        ).copyWith(color: s.watchAccent),
                      ),
                      TextSpan(
                        text: '  ${l10n.circleCountWord(list.length)}',
                        style: AppType.bodyStyle(
                          AppType.bodyMd,
                        ).copyWith(color: s.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.sm,
                  children: [
                    for (final circle in list) _CircleChip(circle: circle),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CircleChip extends StatelessWidget {
  const _CircleChip({required this.circle});

  final Circle circle;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;

    return InkWell(
      borderRadius: AppRadius.pillAll,
      onTap: () => context.push('/circles/${circle.id}'),
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSpace.tapTarget),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: AppSpace.md,
        ),
        decoration: BoxDecoration(
          borderRadius: AppRadius.pillAll,
          border: Border.all(
            color: s.watchAccent,
            width: AppStroke.resolve(AppStroke.regular, sunlight: s.isSunlight),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              circle.name,
              style: AppType.bodyStyle(
                AppType.bodyMd,
                weight: FontWeight.w500,
              ).copyWith(color: s.textPrimary),
            ),
            const SizedBox(width: AppSpace.sm),
            Text(
              circle.type.displayName(l10n).toUpperCase(),
              style: AppType.eyebrow(
                AppType.labelSm,
              ).copyWith(color: s.watchAccent),
            ),
          ],
        ),
      ),
    );
  }
}

class _WatchersMessage extends StatelessWidget {
  const _WatchersMessage({required this.text, required this.action});

  final String text;
  final (String, String)? action;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: AppType.bodyStyle(
            AppType.bodyMd,
          ).copyWith(color: s.textSecondary),
        ),
        if (action != null) ...[
          const SizedBox(height: AppSpace.lg),
          FilledButton(
            onPressed: () => context.push(action!.$2),
            child: Text(action!.$1),
          ),
        ],
      ],
    );
  }
}

class _WatchersSkeleton extends StatelessWidget {
  const _WatchersSkeleton({required this.colour});

  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final width in const [120.0, 92.0])
          Container(
            width: width,
            height: AppSpace.tapTarget,
            margin: const EdgeInsets.only(right: AppSpace.sm),
            decoration: BoxDecoration(
              color: colour,
              borderRadius: AppRadius.pillAll,
            ),
          ),
      ],
    );
  }
}

/// Pack Mode: the one thing on this screen a rider comes here to *start*.
///
/// Everything else on the front door is a status readout. This is an action,
/// and it is the surface a rider shares with people who have never installed
/// the app, so it gets its own block rather than a line in the nav list.
class _PackFrontDoor extends StatelessWidget {
  const _PackFrontDoor();

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;

    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: s.surface1,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: s.hairline,
          width: AppStroke.resolve(AppStroke.hairline, sunlight: s.isSunlight),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.packEyebrow,
            style: AppType.eyebrow(AppType.labelMd).copyWith(color: s.textMuted),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            context.l10n.packTagline,
            style: AppType.bodyStyle(
              AppType.bodyMd,
            ).copyWith(color: s.textSecondary),
          ),
          const SizedBox(height: AppSpace.lg),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: AppSpace.gloveTarget,
                  child: FilledButton(
                    onPressed: () => context.push('/pack/new'),
                    child: Text(context.l10n.packStartRide),
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: SizedBox(
                  height: AppSpace.gloveTarget,
                  child: OutlinedButton(
                    onPressed: () => context.push('/pack/join'),
                    child: Text(context.l10n.packJoinRide),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Navigation, deliberately last and deliberately quiet.
class _NavRow extends StatelessWidget {
  const _NavRow();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      children: [
        _NavLine(label: l10n.navLiveMap, route: '/map'),
        _NavLine(label: l10n.navSafetyCircles, route: '/circles'),
        _NavLine(label: l10n.navCommutes, route: '/commute'),
        _NavLine(label: l10n.navKnownRoutes, route: '/routes'),
        _NavLine(label: l10n.navTripHistory, route: '/trips'),
      ],
    );
  }
}

class _NavLine extends StatelessWidget {
  const _NavLine({required this.label, required this.route});

  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;

    return InkWell(
      borderRadius: AppRadius.smAll,
      onTap: () => context.push(route),
      child: Container(
        height: AppSpace.gloveTarget,
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppType.bodyStyle(
                  AppType.bodyMd,
                  weight: FontWeight.w500,
                ).copyWith(color: s.textSecondary),
              ),
            ),
            Icon(Icons.arrow_forward, size: 18, color: s.textMuted),
          ],
        ),
      ),
    );
  }
}
