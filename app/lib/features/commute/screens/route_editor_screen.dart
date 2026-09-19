import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';
import '../models/commute_route.dart';
import '../providers/commute_routes_provider.dart';

/// Create or edit a commute by hand (FR-041).
///
/// For the rider whose commute the app has not learned — a new job, a child's
/// school run, the first week on a bike. Waiting three trips to be protected
/// is the wrong answer when somebody can simply tell us.
///
/// Points are captured from the device rather than typed. A rider standing at
/// the destination taps once; a rider typing coordinates gets them wrong, and
/// a destination 500 m out is a non-arrival alert every single evening.
class RouteEditorScreen extends ConsumerStatefulWidget {
  const RouteEditorScreen({this.route, super.key});

  /// The route being edited, or null to create one.
  final CommuteRoute? route;

  @override
  ConsumerState<RouteEditorScreen> createState() => _RouteEditorScreenState();
}

class _RouteEditorScreenState extends ConsumerState<RouteEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _duration;

  TimeOfDay? _start;
  late Set<int> _days;
  ({double lat, double lng})? _origin;
  ({double lat, double lng})? _destination;
  bool _saving = false;
  String? _locationError;

  bool get _isEditing => widget.route != null;

  @override
  void initState() {
    super.initState();
    final route = widget.route;
    _name = TextEditingController(text: route?.name ?? '');
    _duration = TextEditingController(
      text: route?.typicalDurationMin?.toString() ?? '',
    );
    _days = {...?route?.daysActive};
    final startMinutes = route?.typicalStartMinutes;
    if (startMinutes != null) {
      _start = TimeOfDay(hour: startMinutes ~/ 60, minute: startMinutes % 60);
    }
    if (route != null) {
      _origin = (lat: route.originLat, lng: route.originLng);
      _destination = (lat: route.destLat, lng: route.destLng);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _duration.dispose();
    super.dispose();
  }

  bool get _isComplete =>
      _origin != null &&
      _destination != null &&
      _start != null &&
      _days.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: s.canvas,
      appBar: AppBar(
        title: Text(
          _isEditing ? l10n.commuteEditRoute : l10n.commuteAddRoute,
          style: AppType.displayStyle(AppType.titleSm),
        ),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: l10n.commuteDeleteRouteTooltip,
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _confirmDelete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            AppSpace.lg,
            AppSpace.gutter,
            AppSpace.huge,
          ),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.commonName,
                hintText: l10n.commuteNameHint,
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? l10n.commuteNameValidation
                  : null,
            ),
            const SizedBox(height: AppSpace.xl),
            _SectionLabel(l10n.commuteSectionWhere),
            _PointRow(
              label: l10n.commuteStartPoint,
              point: _origin,
              onCapture: () => _capture(origin: true),
            ),
            const SizedBox(height: AppSpace.sm),
            _PointRow(
              label: l10n.commuteDestinationPoint,
              point: _destination,
              onCapture: () => _capture(origin: false),
            ),
            if (_locationError != null) ...[
              const SizedBox(height: AppSpace.sm),
              Text(
                _locationError!,
                style: AppType.bodyStyle(
                  AppType.bodySm,
                ).copyWith(color: s.attentionAccent),
              ),
            ],
            const SizedBox(height: AppSpace.xl),
            _SectionLabel(l10n.commuteSectionWhen),
            _StartTimeRow(
              value: _start,
              onPick: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _start ?? const TimeOfDay(hour: 8, minute: 30),
                );
                if (picked != null) setState(() => _start = picked);
              },
            ),
            const SizedBox(height: AppSpace.md),
            TextFormField(
              controller: _duration,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.commuteDurationLabel,
                hintText: '35',
              ),
              validator: (value) {
                final minutes = int.tryParse(value?.trim() ?? '');
                if (minutes == null || minutes <= 0) {
                  return l10n.commuteDurationEmptyValidation;
                }
                if (minutes > 12 * 60) {
                  return l10n.commuteDurationTooLongValidation;
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpace.xl),
            _SectionLabel(l10n.commuteSectionDays),
            _DayPicker(
              selected: _days,
              onChanged: (days) => setState(() => _days = days),
            ),
            const SizedBox(height: AppSpace.xxl),
            SizedBox(
              height: AppSpace.gloveTarget,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(
                  _isEditing ? l10n.commuteSaveChanges : l10n.commuteAddRoute,
                ),
              ),
            ),
            if (!_isComplete) ...[
              const SizedBox(height: AppSpace.md),
              Text(
                l10n.commuteRouteIncompleteHint,
                style: AppType.bodyStyle(
                  AppType.bodySm,
                ).copyWith(color: s.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _capture({required bool origin}) async {
    final l10n = context.l10n;
    setState(() => _locationError = null);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() => _locationError = l10n.commuteLocationPermissionError);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      setState(() {
        final point = (lat: position.latitude, lng: position.longitude);
        if (origin) {
          _origin = point;
        } else {
          _destination = point;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _locationError = l10n.commuteLocationFixError);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_isComplete) {
      setState(() => _locationError = context.l10n.commuteIncompleteError);
      return;
    }

    setState(() => _saving = true);
    final notifier = ref.read(commuteRoutesProvider.notifier);
    final start = _start!;
    final startText =
        '${start.hour.toString().padLeft(2, '0')}:'
        '${start.minute.toString().padLeft(2, '0')}';
    final days = _days.toList()..sort();

    try {
      final existing = widget.route;
      if (existing == null) {
        await notifier.createManual(
          name: _name.text.trim(),
          originLat: _origin!.lat,
          originLng: _origin!.lng,
          destLat: _destination!.lat,
          destLng: _destination!.lng,
          typicalStart: startText,
          typicalDurationMin: int.parse(_duration.text.trim()),
          daysActive: days,
        );
      } else {
        await notifier.save(
          existing.copyWith(
            name: _name.text.trim(),
            originLat: _origin!.lat,
            originLng: _origin!.lng,
            destLat: _destination!.lat,
            destLng: _destination!.lng,
            typicalStart: startText,
            typicalDurationMin: int.parse(_duration.text.trim()),
            daysActive: days,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final route = widget.route;
    if (route == null) return;
    final l10n = context.l10n;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.commuteDeleteRouteTitle),
        content: Text(l10n.commuteDeleteRouteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commuteKeepAction),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commuteDeleteAction),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(commuteRoutesProvider.notifier).delete(route.id);
    if (mounted) Navigator.of(context).pop();
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Text(
        text,
        style: AppType.eyebrow(AppType.labelSm).copyWith(color: s.textMuted),
      ),
    );
  }
}

class _PointRow extends StatelessWidget {
  const _PointRow({
    required this.label,
    required this.point,
    required this.onCapture,
  });

  final String label;
  final ({double lat, double lng})? point;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;
    final set = point != null;

    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: s.surface1,
        borderRadius: AppRadius.mdAll,
        border: Border.all(
          color: s.hairline,
          width: AppStroke.resolve(AppStroke.hairline, sunlight: s.isSunlight),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppType.bodyStyle(
                    AppType.bodySm,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  set
                      ? '${point!.lat.toStringAsFixed(5)}, '
                            '${point!.lng.toStringAsFixed(5)}'
                      : l10n.commutePointNotSet,
                  style: AppType.figure(
                    AppType.labelMd,
                  ).copyWith(color: set ? s.textSecondary : s.textMuted),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onCapture,
            icon: const Icon(Icons.my_location, size: 18),
            label: Text(
              set ? l10n.commuteUpdatePoint : l10n.commuteUseHerePoint,
            ),
          ),
        ],
      ),
    );
  }
}

class _StartTimeRow extends StatelessWidget {
  const _StartTimeRow({required this.value, required this.onPick});

  final TimeOfDay? value;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final text = value == null
        ? '--:--'
        : '${value!.hour.toString().padLeft(2, '0')}:'
              '${value!.minute.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: onPick,
      borderRadius: AppRadius.mdAll,
      child: Container(
        height: AppSpace.gloveTarget,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
        decoration: BoxDecoration(
          color: s.surface1,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: s.hairline,
            width: AppStroke.resolve(
              AppStroke.hairline,
              sunlight: s.isSunlight,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.commuteUsuallyLeavesAt,
                style: AppType.bodyStyle(AppType.bodySm),
              ),
            ),
            Text(
              text,
              style: AppType.figure(
                AppType.bodyLg,
              ).copyWith(color: s.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayPicker extends StatelessWidget {
  const _DayPicker({required this.selected, required this.onChanged});

  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;
    final letters = _dayLetters(l10n);
    final names = _dayNames(l10n);

    return Row(
      children: [
        for (var day = 1; day <= 7; day++) ...[
          Expanded(
            child: Semantics(
              button: true,
              selected: selected.contains(day),
              label: names[day - 1],
              excludeSemantics: true,
              child: Material(
                color: selected.contains(day) ? s.protectedFill : s.surface1,
                borderRadius: AppRadius.smAll,
                child: InkWell(
                  onTap: () {
                    final next = {...selected};
                    if (!next.remove(day)) next.add(day);
                    onChanged(next);
                  },
                  borderRadius: AppRadius.smAll,
                  child: Container(
                    height: AppSpace.tapTarget,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.smAll,
                      border: Border.all(
                        color: selected.contains(day)
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
                            AppType.bodySm,
                            weight: FontWeight.w600,
                          ).copyWith(
                            color: selected.contains(day)
                                ? s.protectedAccent
                                : s.textMuted,
                          ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (day < 7) const SizedBox(width: AppSpace.xs),
        ],
      ],
    );
  }

  static List<String> _dayLetters(AppLocalizations l10n) => [
    l10n.commuteDayLetterMon,
    l10n.commuteDayLetterTue,
    l10n.commuteDayLetterWed,
    l10n.commuteDayLetterThu,
    l10n.commuteDayLetterFri,
    l10n.commuteDayLetterSat,
    l10n.commuteDayLetterSun,
  ];

  static List<String> _dayNames(AppLocalizations l10n) => [
    l10n.commuteDayNameMonday,
    l10n.commuteDayNameTuesday,
    l10n.commuteDayNameWednesday,
    l10n.commuteDayNameThursday,
    l10n.commuteDayNameFriday,
    l10n.commuteDayNameSaturday,
    l10n.commuteDayNameSunday,
  ];
}
