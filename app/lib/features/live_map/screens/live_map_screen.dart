import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/l10n.dart';
import '../models/member_position.dart';
import '../models/member_presence.dart';
import '../providers/live_map_providers.dart';
import '../widgets/member_detail_sheet.dart';
import '../widgets/member_marker_icons.dart';
import '../widgets/member_marker_spec.dart';
import '../widgets/stale_data_banner.dart';

/// FR-050 / FR-053. Circle members on a map, with their trust state stated.
///
/// The camera is never animated to follow a marker and the markers are never
/// animated between fixes: both would manufacture the impression of live
/// motion out of nothing. A marker moves when, and only when, a new fix lands.
class LiveMapScreen extends ConsumerStatefulWidget {
  const LiveMapScreen({super.key});

  static const CameraPosition initialCamera = CameraPosition(
    // Ernakulam — the pilot district.
    target: LatLng(9.9816, 76.2999),
    zoom: 11,
  );

  @override
  ConsumerState<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends ConsumerState<LiveMapScreen> {
  final Map<String, BitmapDescriptor> _icons = {};

  Future<void> _ensureIcons(List<MemberMarkerSpec> specs) async {
    var added = false;
    for (final spec in specs) {
      final key = '${spec.presence.state}';
      if (_icons.containsKey(key)) continue;
      _icons[key] = await MemberMarkerIcons.forSpec(spec);
      added = true;
    }
    if (added && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final now =
        ref.watch(mapClockProvider).valueOrNull ?? DateTime.now().toUtc();
    final membersAsync = ref.watch(liveMembersProvider);
    final members = membersAsync.valueOrNull ?? const <MapMember>[];

    final specs = MemberMarkerSpec.buildAll(
      members: members,
      now: now,
      semantics: s,
      l10n: context.l10n,
    );
    unawaitedIcons(specs);

    final selectedId = ref.watch(selectedMemberIdProvider);
    final selected = members.where((m) => m.userId == selectedId).firstOrNull;

    var stale = 0;
    var unreachable = 0;
    for (final spec in specs) {
      if (spec.presence.state == MemberDisplayState.unreachable) {
        unreachable++;
      } else if (spec.presence.state == MemberDisplayState.stale) {
        stale++;
      }
    }

    return Scaffold(
      backgroundColor: s.canvas,
      appBar: AppBar(title: Text(context.l10n.navLiveMap)),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: LiveMapScreen.initialCamera,
            markers: _markers(specs),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            // Compass and toolbar off: fewer controls to hit with gloves on.
            compassEnabled: false,
            mapToolbarEnabled: false,
            onTap: (_) =>
                ref.read(selectedMemberIdProvider.notifier).state = null,
          ),
          Positioned(
            top: AppSpace.md,
            left: AppSpace.gutter,
            right: AppSpace.gutter,
            child: Column(
              children: [
                StaleDataBanner(
                  staleCount: stale,
                  unreachableCount: unreachable,
                ),
                if (membersAsync.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpace.sm),
                    child: _OfflineNotice(semantics: s),
                  ),
                if (membersAsync.hasValue && members.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpace.sm),
                    child: _EmptyNotice(semantics: s),
                  ),
              ],
            ),
          ),
          if (selected != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: MemberDetailSheet(
                member: selected,
                now: now,
                onClose: () =>
                    ref.read(selectedMemberIdProvider.notifier).state = null,
              ),
            ),
        ],
      ),
    );
  }

  void unawaitedIcons(List<MemberMarkerSpec> specs) {
    // Fire and forget: icon generation must never block a frame of the map.
    _ensureIcons(specs);
  }

  Set<Marker> _markers(List<MemberMarkerSpec> specs) => {
    for (final spec in specs)
      Marker(
        markerId: MarkerId(spec.userId),
        // Straight from the last fix. Nothing here interpolates.
        position: LatLng(spec.latitude, spec.longitude),
        icon: _icons['${spec.presence.state}'] ?? BitmapDescriptor.defaultMarker,
        alpha: spec.opacity,
        zIndexInt: spec.zIndex,
        anchor: const Offset(0.5, 0.5),
        consumeTapEvents: true,
        infoWindow: InfoWindow(
          title: spec.displayName,
          snippet: spec.label,
        ),
        onTap: () =>
            ref.read(selectedMemberIdProvider.notifier).state = spec.userId,
      ),
  };
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice({required this.semantics});

  final AppSemantics semantics;

  @override
  Widget build(BuildContext context) => _Notice(
    semantics: semantics,
    text: context.l10n.mapOfflineNoticeText,
  );
}

class _EmptyNotice extends StatelessWidget {
  const _EmptyNotice({required this.semantics});

  final AppSemantics semantics;

  @override
  Widget build(BuildContext context) => _Notice(
    semantics: semantics,
    text: context.l10n.mapEmptyNoticeText,
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.semantics, required this.text});

  final AppSemantics semantics;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpace.md),
    decoration: BoxDecoration(
      color: semantics.surface1,
      borderRadius: AppRadius.mdAll,
      border: Border.all(
        color: semantics.hairline,
        width: AppStroke.resolve(
          AppStroke.hairline,
          sunlight: semantics.isSunlight,
        ),
      ),
    ),
    child: Text(
      text,
      style: AppType.bodyStyle(
        AppType.labelMd,
      ).copyWith(color: semantics.textSecondary),
    ),
  );
}
