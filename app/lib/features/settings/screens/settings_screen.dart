import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/clerk_auth_provider.dart';
import '../../auth/providers/user_profile_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _medicalNotesController;
  late FocusNode _medicalNotesFocusNode;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _medicalNotesController = TextEditingController();
    _medicalNotesFocusNode = FocusNode();
    _medicalNotesFocusNode.addListener(_onMedicalNotesFocusChange);
  }

  @override
  void dispose() {
    _medicalNotesFocusNode.removeListener(_onMedicalNotesFocusChange);
    _medicalNotesFocusNode.dispose();
    _nameController.dispose();
    _medicalNotesController.dispose();
    super.dispose();
  }

  void _onMedicalNotesFocusChange() {
    if (_medicalNotesFocusNode.hasFocus) return;
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile == null) return;
    ref
        .read(userProfileProvider.notifier)
        .updateEmergencyProfile(
          bloodGroup: profile.bloodGroup,
          medicalNotes: _medicalNotesController.text,
        );
  }

  void _initFromProfile(UserProfile profile) {
    if (_initialized) return;
    _nameController.text = profile.name ?? '';
    _medicalNotesController.text = profile.medicalNotes ?? '';
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Not signed in'));
          }
          _initFromProfile(profile);
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _buildSafetySection(profile),
              _buildTrackingSection(profile),
              _buildEmergencyProfileSection(profile),
              _buildAccountSection(profile),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSafetySection(UserProfile profile) {
    final sensitivity = profile.crashSensitivity ?? 'medium';
    final mount = profile.phoneMountType ?? 'unknown';

    return _Section(
      title: 'Safety',
      children: [
        ListTile(
          title: const Text('Crash Sensitivity'),
          subtitle: Text(_sensitivityLabel(sensitivity)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'high', label: Text('High')),
              ButtonSegment(value: 'medium', label: Text('Medium')),
              ButtonSegment(value: 'low', label: Text('Low')),
            ],
            selected: {sensitivity},
            onSelectionChanged: (values) {
              ref
                  .read(userProfileProvider.notifier)
                  .updateSafetySettings(
                    crashSensitivity: values.first,
                    phoneMountType: mount,
                  );
            },
          ),
        ),
        const SizedBox(height: 16),
        ListTile(
          title: const Text('Phone Mount'),
          subtitle: Text(_mountLabel(mount)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'handlebar', label: Text('Bar')),
              ButtonSegment(value: 'pocket', label: Text('Pocket')),
              ButtonSegment(value: 'bag', label: Text('Bag')),
              ButtonSegment(value: 'unknown', label: Text('Other')),
            ],
            selected: {mount},
            onSelectionChanged: (values) {
              ref
                  .read(userProfileProvider.notifier)
                  .updateSafetySettings(
                    crashSensitivity: sensitivity,
                    phoneMountType: values.first,
                  );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildTrackingSection(UserProfile profile) {
    final enabled = profile.nonArrivalEnabled ?? true;
    final delayMin = profile.nonArrivalDelayMin ?? 15;

    return _Section(
      title: 'Tracking',
      children: [
        SwitchListTile(
          title: const Text('Non-Arrival Alerts'),
          subtitle: const Text('Alert contacts if you don\'t arrive'),
          value: enabled,
          onChanged: (value) {
            ref
                .read(userProfileProvider.notifier)
                .updateNonArrivalSettings(enabled: value, delayMin: delayMin);
          },
        ),
        if (enabled)
          ListTile(
            title: const Text('Alert Delay'),
            subtitle: Text('$delayMin minutes after expected arrival'),
            trailing: DropdownButton<int>(
              value: delayMin,
              items: const [
                DropdownMenuItem(value: 5, child: Text('5 min')),
                DropdownMenuItem(value: 10, child: Text('10 min')),
                DropdownMenuItem(value: 15, child: Text('15 min')),
                DropdownMenuItem(value: 20, child: Text('20 min')),
                DropdownMenuItem(value: 30, child: Text('30 min')),
              ],
              onChanged: (value) {
                if (value != null) {
                  ref
                      .read(userProfileProvider.notifier)
                      .updateNonArrivalSettings(
                        enabled: enabled,
                        delayMin: value,
                      );
                }
              },
            ),
          ),
      ],
    );
  }

  Widget _buildEmergencyProfileSection(UserProfile profile) {
    final bloodGroup = profile.bloodGroup;

    return _Section(
      title: 'Emergency Profile',
      children: [
        ListTile(
          title: const Text('Blood Group'),
          trailing: DropdownButton<String>(
            value: bloodGroup,
            hint: const Text('Select'),
            items: const [
              DropdownMenuItem(value: 'A+', child: Text('A+')),
              DropdownMenuItem(value: 'A-', child: Text('A-')),
              DropdownMenuItem(value: 'B+', child: Text('B+')),
              DropdownMenuItem(value: 'B-', child: Text('B-')),
              DropdownMenuItem(value: 'AB+', child: Text('AB+')),
              DropdownMenuItem(value: 'AB-', child: Text('AB-')),
              DropdownMenuItem(value: 'O+', child: Text('O+')),
              DropdownMenuItem(value: 'O-', child: Text('O-')),
            ],
            onChanged: (value) {
              ref
                  .read(userProfileProvider.notifier)
                  .updateEmergencyProfile(
                    bloodGroup: value,
                    medicalNotes: profile.medicalNotes,
                  );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _medicalNotesController,
            focusNode: _medicalNotesFocusNode,
            decoration: const InputDecoration(
              labelText: 'Medical Notes',
              hintText: 'Allergies, conditions, medications...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            textInputAction: TextInputAction.done,
            onSubmitted: (value) {
              ref
                  .read(userProfileProvider.notifier)
                  .updateEmergencyProfile(
                    bloodGroup: profile.bloodGroup,
                    medicalNotes: value,
                  );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildAccountSection(UserProfile profile) {
    return _Section(
      title: 'Account',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              ref.read(userProfileProvider.notifier).updateName(value);
            },
          ),
        ),
        const SizedBox(height: 8),
        ListTile(
          title: const Text('Vehicle'),
          subtitle: Text(
            [
              profile.vehicleType,
              profile.vehicleReg,
            ].where((s) => s != null && s.isNotEmpty).join(' - '),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                ref.read(clerkAuthProvider.notifier).signOut();
              },
              child: const Text('Sign Out'),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  String _sensitivityLabel(String sensitivity) {
    return switch (sensitivity) {
      'high' => 'High - More sensitive, may have more false alerts',
      'low' => 'Low - Less sensitive, fewer false alerts',
      _ => 'Medium - Balanced (recommended)',
    };
  }

  String _mountLabel(String mount) {
    return switch (mount) {
      'handlebar' => 'Handlebar mount (most sensitive)',
      'pocket' => 'In pocket',
      'bag' => 'In bag (least sensitive)',
      _ => 'Other / Unknown',
    };
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        ...children,
        const Divider(),
      ],
    );
  }
}
