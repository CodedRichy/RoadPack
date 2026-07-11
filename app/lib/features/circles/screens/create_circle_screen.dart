import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Create Circle')),
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
                  _nameController.text = type.defaultName;
                });
              },
            ),
            if (_selectedType != null) ...[
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Circle name',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_selectedType == CircleType.convoy) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<Duration>(
                  initialValue: _convoyDuration,
                  items: _convoyDurations.map((d) {
                    return DropdownMenuItem(
                      value: d,
                      child: Text('${d.inHours} hours'),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _convoyDuration = v);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Duration',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
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
                    : const Text('Create'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
