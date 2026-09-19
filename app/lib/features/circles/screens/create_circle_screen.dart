import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';
import '../models/circle.dart';
import '../providers/circle_actions_provider.dart';
import '../widgets/circle_type_picker.dart';

class CreateCircleScreen extends ConsumerStatefulWidget {
  const CreateCircleScreen({super.key});

  @override
  ConsumerState<CreateCircleScreen> createState() => _CreateCircleScreenState();
}

class _CreateCircleScreenState extends ConsumerState<CreateCircleScreen> {
  final _nameController = TextEditingController();
  CircleType? _selectedType;
  Duration _convoyDuration = const Duration(hours: 4);
  bool _isLoading = false;

  /// Off until the creator says otherwise.
  ///
  /// Turning this on lets every member of the circle watch the others' live
  /// position, so it is a consent decision, not a convenience default
  /// (SG-01). Creating a circle with sharing already on would also decide it
  /// on behalf of everyone who joins later, none of whom is in the room yet.
  bool _locationSharing = false;

  static const _convoyDurations = [
    Duration(hours: 2),
    Duration(hours: 4),
    Duration(hours: 8),
    Duration(hours: 12),
    Duration(hours: 24),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  int _maxMembersForType(CircleType type) {
    switch (type) {
      case CircleType.family:
        return AppConstants.maxFamilyCircleMembers;
      case CircleType.friends:
        return AppConstants.maxFriendsCircleMembers;
      case CircleType.commute:
        return AppConstants.maxCommuteCircleMembers;
      case CircleType.convoy:
        return AppConstants.maxConvoyCircleMembers;
    }
  }

  Future<void> _create() async {
    final type = _selectedType;
    final name = _nameController.text.trim();
    if (type == null || name.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final circle = await ref
          .read(circleActionsProvider)
          .createCircle(
            name: name,
            type: type,
            locationSharing: _locationSharing,
            maxMembers: _maxMembersForType(type),
            expiresAt: type == CircleType.convoy
                ? DateTime.now().add(_convoyDuration)
                : null,
          );
      if (mounted) context.go('/circles/${circle.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.circlesCreateCircle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CircleTypePicker(
              selected: _selectedType,
              onSelected: (type) {
                setState(() {
                  _selectedType = type;
                  _nameController.text = type.defaultName(l10n);
                });
              },
            ),
            if (_selectedType != null) ...[
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.circlesNameLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (_selectedType == CircleType.convoy) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<Duration>(
                  initialValue: _convoyDuration,
                  items: _convoyDurations.map((d) {
                    return DropdownMenuItem(
                      value: d,
                      child: Text(l10n.circlesDurationHours(d.inHours)),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _convoyDuration = v);
                  },
                  decoration: InputDecoration(
                    labelText: l10n.circlesDurationLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _LocationSharingChoice(
                value: _locationSharing,
                onChanged: (v) => setState(() => _locationSharing = v),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isLoading ? null : _create,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.circlesCreateAction),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The one sharing decision made at creation time, stated plainly.
///
/// It is a pair of choices rather than a bare switch because "off" is a
/// real, supported way to use a circle — the alert cascade still reaches
/// everyone in a crash. Only the continuous live position is being decided
/// here, and the copy has to say which is which or the user cannot consent
/// to anything.
class _LocationSharingChoice extends StatelessWidget {
  const _LocationSharingChoice({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.semantics;
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: s.surface2,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: value ? s.watchAccent : s.border,
          width: AppStroke.resolve(AppStroke.hairline, sunlight: s.isSunlight),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.circlesLocationSharingTitle,
                  style: AppType.bodyStyle(
                    AppType.bodyMd,
                    weight: FontWeight.w600,
                  ).copyWith(color: s.textPrimary),
                ),
              ),
              SizedBox(
                height: AppSpace.gloveTarget,
                child: Center(
                  child: Switch(value: value, onChanged: onChanged),
                ),
              ),
            ],
          ),
          Text(
            value
                ? l10n.circlesLocationSharingOnDetail
                : l10n.circlesLocationSharingOffDetail,
            style: AppType.bodyStyle(
              AppType.bodySm,
            ).copyWith(color: s.textSecondary),
          ),
        ],
      ),
    );
  }
}
