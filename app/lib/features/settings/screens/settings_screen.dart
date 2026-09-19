import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';
import '../../auth/providers/clerk_auth_provider.dart';
import '../../auth/providers/user_profile_provider.dart';
import '../../emergency_profile/providers/emergency_contacts_provider.dart';
import '../../emergency_profile/providers/ice_gate_provider.dart';
import 'bystander_preview_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  /// The FR-094 commute-exposure opt-in, keyed so its fail-closed default can
  /// be asserted without depending on where it sits in the list.
  static const iceExposureToggleKey = ValueKey('ice-commute-exposure-toggle');

  /// The FR-005 language picker, keyed for the same reason.
  static const languagePickerKey = ValueKey('language-picker');

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
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.commonSettings)),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.commonError('$e'))),
        data: (profile) {
          if (profile == null) {
            return Center(child: Text(l10n.commonNotSignedIn));
          }
          _initFromProfile(profile);
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _buildSafetySection(profile, l10n),
              _buildTrackingSection(profile, l10n),
              _buildEmergencySection(l10n),
              _buildEmergencyProfileSection(profile, l10n),
              _buildMapsSection(l10n),
              _buildLanguageSection(l10n),
              _buildAccountSection(profile, l10n),
            ],
          );
        },
      ),
    );
  }

  /// FR-005. The language a rider reads an emergency screen in is a safety
  /// setting, not a cosmetic one, so it sits in the list rather than behind a
  /// separate screen. "Match my phone" is the default and stays selectable —
  /// a rider who changes their handset language should not have to come back
  /// here to keep the two in step.
  Widget _buildLanguageSection(AppLocalizations l10n) {
    final selected = ref.watch(appLocaleProvider)?.languageCode;

    return _Section(
      title: l10n.settingsSectionLanguage,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            l10n.settingsLanguageSub,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        RadioGroup<String?>(
          key: SettingsScreen.languagePickerKey,
          groupValue: selected,
          onChanged: (value) =>
              ref.read(appLocaleProvider.notifier).set(
                value == null ? null : Locale(value),
              ),
          child: Column(
            children: [
              for (final option in _languageOptions(l10n))
                RadioListTile<String?>(
                  key: ValueKey('language-${option.$1 ?? 'system'}'),
                  // Malayalam and Hindi labels run longer than English.
                  // A three-line title on a glove-sized row is fine; a
                  // clipped one is not.
                  title: Text(option.$2),
                  value: option.$1,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<(String?, String)> _languageOptions(AppLocalizations l10n) => [
    (null, l10n.languageSystemDefault),
    ('en', l10n.languageEnglish),
    ('hi', l10n.languageHindi),
    ('ml', l10n.languageMalayalam),
  ];

  Widget _buildSafetySection(UserProfile profile, AppLocalizations l10n) {
    final sensitivity = profile.crashSensitivity ?? 'medium';
    final mount = profile.phoneMountType ?? 'unknown';

    return _Section(
      title: l10n.settingsSectionSafety,
      children: [
        ListTile(
          title: Text(l10n.settingsCrashSensitivity),
          subtitle: Text(_sensitivityLabel(sensitivity, l10n)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'high',
                label: Text(l10n.settingsSensitivityHigh),
              ),
              ButtonSegment(
                value: 'medium',
                label: Text(l10n.settingsSensitivityMedium),
              ),
              ButtonSegment(
                value: 'low',
                label: Text(l10n.settingsSensitivityLow),
              ),
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
          title: Text(l10n.settingsPhoneMount),
          subtitle: Text(_mountLabel(mount, l10n)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'handlebar',
                label: Text(l10n.settingsMountBar),
              ),
              ButtonSegment(
                value: 'pocket',
                label: Text(l10n.settingsMountPocket),
              ),
              ButtonSegment(value: 'bag', label: Text(l10n.settingsMountBag)),
              ButtonSegment(
                value: 'unknown',
                label: Text(l10n.settingsMountOther),
              ),
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

  Widget _buildTrackingSection(UserProfile profile, AppLocalizations l10n) {
    final enabled = profile.nonArrivalEnabled ?? true;
    final delayMin = profile.nonArrivalDelayMin ?? 15;

    return _Section(
      title: l10n.settingsSectionTracking,
      children: [
        SwitchListTile(
          title: Text(l10n.settingsNonArrivalAlerts),
          subtitle: Text(l10n.settingsNonArrivalAlertsSub),
          value: enabled,
          onChanged: (value) {
            ref
                .read(userProfileProvider.notifier)
                .updateNonArrivalSettings(enabled: value, delayMin: delayMin);
          },
        ),
        if (enabled)
          ListTile(
            title: Text(l10n.settingsAlertDelay),
            subtitle: Text(l10n.settingsAlertDelaySub(delayMin)),
            trailing: DropdownButton<int>(
              value: delayMin,
              items: [
                for (final m in const [5, 10, 15, 20, 30])
                  DropdownMenuItem(value: m, child: Text(l10n.minutesShort(m))),
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
        _NavTile(
          title: l10n.settingsCommuteRoutes,
          subtitle: l10n.settingsCommuteRoutesSub,
          route: '/commute',
        ),
      ],
    );
  }

  /// The people and the card that make the cascade mean something.
  Widget _buildEmergencySection(AppLocalizations l10n) {
    final ready = ref.watch(emergencyProfileReadyProvider);
    final optIn = ref.watch(iceCommuteExposureOptInProvider);

    return _Section(
      title: l10n.settingsSectionEmergency,
      children: [
        _NavTile(
          title: l10n.settingsEmergencyContacts,
          // Never dress an empty contact list up as configured.
          subtitle: ready
              ? l10n.settingsEmergencyContactsReady
              : l10n.settingsEmergencyContactsEmpty,
          route: '/emergency-contacts',
        ),
        _NavTile(
          title: l10n.settingsIceCard,
          subtitle: l10n.settingsIceCardSub,
          route: '/ice',
        ),
        _NavTile(
          title: l10n.settingsBystanderPreview,
          subtitle: l10n.settingsBystanderPreviewSub,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const BystanderPreviewScreen(),
            ),
          ),
        ),
        SwitchListTile(
          key: SettingsScreen.iceExposureToggleKey,
          minTileHeight: AppSpace.gloveTarget,
          title: Text(l10n.settingsIceCommuteToggle),
          subtitle: Text(l10n.settingsIceCommuteToggleSub),
          value: optIn,
          onChanged: (value) {
            ref.read(iceCommuteExposurePrefProvider.notifier).set(value);
          },
        ),
      ],
    );
  }

  Widget _buildMapsSection(AppLocalizations l10n) {
    return _Section(
      title: l10n.settingsSectionMaps,
      children: [
        _NavTile(
          title: l10n.settingsOfflineMaps,
          subtitle: l10n.settingsOfflineMapsSub,
          route: '/settings/offline-maps',
        ),
      ],
    );
  }

  Widget _buildEmergencyProfileSection(
    UserProfile profile,
    AppLocalizations l10n,
  ) {
    final bloodGroup = profile.bloodGroup;

    return _Section(
      title: l10n.settingsSectionEmergencyProfile,
      children: [
        ListTile(
          title: Text(l10n.settingsBloodGroup),
          trailing: DropdownButton<String>(
            value: bloodGroup,
            hint: Text(l10n.commonSelect),
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
            decoration: InputDecoration(
              labelText: l10n.settingsMedicalNotes,
              hintText: l10n.settingsMedicalNotesHint,
              border: const OutlineInputBorder(),
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

  Widget _buildAccountSection(UserProfile profile, AppLocalizations l10n) {
    return _Section(
      title: l10n.settingsSectionAccount,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: l10n.commonName,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              ref.read(userProfileProvider.notifier).updateName(value);
            },
          ),
        ),
        const SizedBox(height: 8),
        ListTile(
          title: Text(l10n.settingsVehicle),
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
              // Destructive, but not an incident: the emergency tier stays
              // reserved for a live crash or SOS.
              style: OutlinedButton.styleFrom(
                foregroundColor: context.semantics.attentionAccent,
                minimumSize: const Size.fromHeight(AppSpace.gloveTarget),
              ),
              onPressed: () {
                ref.read(clerkAuthProvider.notifier).signOut();
              },
              child: Text(l10n.settingsSignOut),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  String _sensitivityLabel(String sensitivity, AppLocalizations l10n) {
    return switch (sensitivity) {
      'high' => l10n.settingsSensitivityHighDetail,
      'low' => l10n.settingsSensitivityLowDetail,
      _ => l10n.settingsSensitivityMediumDetail,
    };
  }

  String _mountLabel(String mount, AppLocalizations l10n) {
    return switch (mount) {
      'handlebar' => l10n.settingsMountBarDetail,
      'pocket' => l10n.settingsMountPocketDetail,
      'bag' => l10n.settingsMountBagDetail,
      _ => l10n.settingsMountUnknownDetail,
    };
  }
}

/// A settings row that goes somewhere. Glove-sized, because settings get
/// changed at the roadside as often as at the kitchen table.
class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.title,
    required this.subtitle,
    this.route,
    this.onTap,
  }) : assert(
         (route == null) != (onTap == null),
         'a nav tile goes to exactly one place',
       );

  final String title;
  final String subtitle;

  /// A registered go_router path.
  final String? route;

  /// For destinations that are not routes — the bystander preview needs a
  /// scoped override the route table cannot supply.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: AppSpace.gloveTarget,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward, size: 18),
      onTap: onTap ?? () => context.push(route!),
    );
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
