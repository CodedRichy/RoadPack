import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';
import '../../circles/models/circle.dart';
import '../../circles/providers/circles_provider.dart';
import '../providers/pack_actions_provider.dart';
import '../services/pack_route_resolver.dart';

/// Start a pack ride.
///
/// Three inputs, and only one of them is required. A ride that takes a form to
/// start is a ride that gets started in a WhatsApp group instead, so the name
/// is optional, the circle is optional, and the destination is the only thing
/// the product genuinely cannot work without — chainage needs a line to
/// measure along.
class CreatePackRideScreen extends ConsumerStatefulWidget {
  const CreatePackRideScreen({super.key, this.onCreated});

  /// Where to go once the ride exists. Left to the caller so this screen does
  /// not need to know the route table.
  final void Function(BuildContext context, String rideId)? onCreated;

  @override
  ConsumerState<CreatePackRideScreen> createState() =>
      _CreatePackRideScreenState();
}

class _CreatePackRideScreenState extends ConsumerState<CreatePackRideScreen> {
  final _name = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  String? _circleId;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    if (lat == null || lng == null) {
      setState(() => _error = context.l10n.packDestinationInvalid);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final draft = await ref.read(packRouteResolverProvider)(
        destLat: lat,
        destLng: lng,
      );
      final name = _name.text.trim();
      final ride = await ref
          .read(packActionsProvider)
          .createRide(
            destinationWkt: draft.destinationWkt,
            routeLineWkt: draft.routeLineWkt,
            routeSource: draft.source,
            name: name.isEmpty ? null : name,
            circleId: _circleId,
          );
      if (mounted) widget.onCreated?.call(context, ride.id);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is TrackingNotPermitted
              ? e.message(context.l10n)
              : e.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;
    final circles = ref.watch(circlesProvider).valueOrNull ?? const <Circle>[];

    return Scaffold(
      backgroundColor: s.canvas,
      appBar: AppBar(title: Text(l10n.packCreateTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.gutter),
        children: [
          TextField(
            key: const Key('pack-create-name'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: l10n.packRideNameLabel,
              hintText: l10n.packRideNameHint,
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          DropdownButtonFormField<String?>(
            key: const Key('pack-create-circle'),
            initialValue: _circleId,
            decoration: InputDecoration(
              labelText: l10n.packCircleLabel,
              helperText: l10n.packCircleHelper,
            ),
            items: [
              DropdownMenuItem(value: null, child: Text(l10n.packNoCircleOption)),
              for (final circle in circles)
                DropdownMenuItem(value: circle.id, child: Text(circle.name)),
            ],
            onChanged: (value) => setState(() => _circleId = value),
          ),
          const SizedBox(height: AppSpace.lg),
          Text(
            l10n.packDestinationHeading,
            style: AppType.eyebrow(
              AppType.labelMd,
            ).copyWith(color: s.textSecondary),
          ),
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('pack-create-lat'),
                  controller: _lat,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
                  ],
                  style: AppType.figure(AppType.bodyMd),
                  decoration: InputDecoration(labelText: l10n.packLatitudeLabel),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: TextField(
                  key: const Key('pack-create-lng'),
                  controller: _lng,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
                  ],
                  style: AppType.figure(AppType.bodyMd),
                  decoration: InputDecoration(labelText: l10n.packLongitudeLabel),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          Text(
            l10n.packCreateShareNotice,
            style: AppType.bodyStyle(
              AppType.bodySm,
            ).copyWith(color: s.textMuted),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.lg),
            Text(
              _error!,
              key: const Key('pack-create-error'),
              style: AppType.bodyStyle(
                AppType.bodySm,
              ).copyWith(color: s.attentionAccent),
            ),
          ],
          const SizedBox(height: AppSpace.xl),
          FilledButton(
            key: const Key('pack-create-submit'),
            onPressed: _busy ? null : _create,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, AppSpace.gloveTarget),
            ),
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.packCreateSubmit),
          ),
        ],
      ),
    );
  }
}
