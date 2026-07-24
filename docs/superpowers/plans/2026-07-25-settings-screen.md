# Settings Screen + Crash Config Wiring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Settings screen exposing crash sensitivity, phone mount, non-arrival config, emergency profile, and account settings. Wire crash detection to read user preferences instead of hardcoded nulls.

**Architecture:** Expand existing `UserProfile` model with 6 new fields from the `users` table. Create a `SettingsScreen` with grouped sections. Wire `CrashDetectionNotifier` and `CrashSensorService` to read mount/sensitivity from the user profile.

**Tech Stack:** Flutter, Riverpod (manual providers), Supabase, GoRouter, Material3

## Global Constraints

- Riverpod manual providers (NOT codegen)
- No SharedPreferences -- all settings persisted to Supabase `users` table
- UserProfile is NOT a Freezed class -- it's a plain Dart class with manual fromJson, equality, and toString
- UserProfileNotifier extends AsyncNotifier<UserProfile?> (NOT StateNotifier)
- Mutation methods in UserProfileNotifier follow existing pattern: update Supabase first, then optimistically update local state via `state = AsyncData(UserProfile(...))`
- Dark-first Material3 theme (`ThemeMode.dark` in app.dart)
- flutter_test + mocktail for tests
- `feat(settings)` commit prefix
- Crash sensitivity values: `'high'`, `'medium'`, `'low'` (strings, matching DB column)
- Phone mount values: `'handlebar'`, `'pocket'`, `'bag'`, `'unknown'` (strings, matching DB column)

---

### Task 1: Expand UserProfile model with settings fields

**Files:**
- Modify: `app/lib/features/auth/providers/user_profile_provider.dart`

**Interfaces:**
- Consumes: Supabase `users` table columns: `crash_sensitivity`, `phone_mount`, `non_arrival_delay_min`, `non_arrival_enabled`, `blood_group`, `medical_notes`
- Produces: Expanded `UserProfile` class with 6 new fields, expanded `fromJson`, `==`, `hashCode`, `toString`. Three new update methods on `UserProfileNotifier`: `updateSafetySettings()`, `updateNonArrivalSettings()`, `updateEmergencyProfile()`.

- [ ] **Step 1: Add fields to UserProfile class**

Add these fields to `UserProfile`:

```dart
class UserProfile {
  const UserProfile({
    required this.userId,
    this.name,
    this.dateOfBirth,
    this.vehicleType,
    this.vehicleReg,
    this.crashSensitivity,
    this.phoneMountType,
    this.nonArrivalDelayMin,
    this.nonArrivalEnabled,
    this.bloodGroup,
    this.medicalNotes,
  });

  final String userId;
  final String? name;
  final DateTime? dateOfBirth;
  final String? vehicleType;
  final String? vehicleReg;
  final String? crashSensitivity;
  final String? phoneMountType;
  final int? nonArrivalDelayMin;
  final bool? nonArrivalEnabled;
  final String? bloodGroup;
  final String? medicalNotes;

  bool get isOnboarded => dateOfBirth != null;
}
```

- [ ] **Step 2: Update fromJson**

```dart
factory UserProfile.fromJson(Map<String, dynamic> json) {
  return UserProfile(
    userId: json['id'] as String,
    name: json['name'] as String?,
    dateOfBirth: json['date_of_birth'] != null
        ? DateTime.parse(json['date_of_birth'] as String)
        : null,
    vehicleType: json['vehicle_type'] as String?,
    vehicleReg: json['vehicle_reg'] as String?,
    crashSensitivity: json['crash_sensitivity'] as String?,
    phoneMountType: json['phone_mount'] as String?,
    nonArrivalDelayMin: json['non_arrival_delay_min'] as int?,
    nonArrivalEnabled: json['non_arrival_enabled'] as bool?,
    bloodGroup: json['blood_group'] as String?,
    medicalNotes: json['medical_notes'] as String?,
  );
}
```

- [ ] **Step 3: Update equality, hashCode, and toString**

```dart
@override
bool operator ==(Object other) =>
    identical(this, other) ||
    other is UserProfile &&
        runtimeType == other.runtimeType &&
        userId == other.userId &&
        name == other.name &&
        dateOfBirth == other.dateOfBirth &&
        vehicleType == other.vehicleType &&
        vehicleReg == other.vehicleReg &&
        crashSensitivity == other.crashSensitivity &&
        phoneMountType == other.phoneMountType &&
        nonArrivalDelayMin == other.nonArrivalDelayMin &&
        nonArrivalEnabled == other.nonArrivalEnabled &&
        bloodGroup == other.bloodGroup &&
        medicalNotes == other.medicalNotes;

@override
int get hashCode => Object.hash(
      userId,
      name,
      dateOfBirth,
      vehicleType,
      vehicleReg,
      crashSensitivity,
      phoneMountType,
      nonArrivalDelayMin,
      nonArrivalEnabled,
      bloodGroup,
      medicalNotes,
    );

@override
String toString() =>
    'UserProfile(userId: $userId, name: $name, dateOfBirth: $dateOfBirth, '
    'vehicleType: $vehicleType, vehicleReg: $vehicleReg, '
    'crashSensitivity: $crashSensitivity, phoneMountType: $phoneMountType, '
    'nonArrivalDelayMin: $nonArrivalDelayMin, nonArrivalEnabled: $nonArrivalEnabled, '
    'bloodGroup: $bloodGroup, medicalNotes: $medicalNotes)';
```

- [ ] **Step 4: Add a copyWith method to UserProfile**

Since the existing mutation methods manually reconstruct UserProfile with all fields, a `copyWith` will prevent field-dropping bugs:

```dart
UserProfile copyWith({
  String? userId,
  String? name,
  DateTime? dateOfBirth,
  String? vehicleType,
  String? vehicleReg,
  String? crashSensitivity,
  String? phoneMountType,
  int? nonArrivalDelayMin,
  bool? nonArrivalEnabled,
  String? bloodGroup,
  String? medicalNotes,
}) {
  return UserProfile(
    userId: userId ?? this.userId,
    name: name ?? this.name,
    dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    vehicleType: vehicleType ?? this.vehicleType,
    vehicleReg: vehicleReg ?? this.vehicleReg,
    crashSensitivity: crashSensitivity ?? this.crashSensitivity,
    phoneMountType: phoneMountType ?? this.phoneMountType,
    nonArrivalDelayMin: nonArrivalDelayMin ?? this.nonArrivalDelayMin,
    nonArrivalEnabled: nonArrivalEnabled ?? this.nonArrivalEnabled,
    bloodGroup: bloodGroup ?? this.bloodGroup,
    medicalNotes: medicalNotes ?? this.medicalNotes,
  );
}
```

- [ ] **Step 5: Refactor existing mutation methods to use copyWith**

Replace the manual UserProfile reconstruction in `updateName`, `updateDateOfBirth`, and `updateVehicle` with `copyWith`:

```dart
Future<void> updateName(String name) async {
  final userId = _userId;
  final supabase = _supabase;
  if (userId == null || supabase == null) return;

  await supabase.from('users').update({'name': name}).eq('id', userId);

  final current = state.value;
  if (current != null) {
    state = AsyncData(current.copyWith(name: name));
  }
}
```

Apply the same pattern to `updateDateOfBirth` and `updateVehicle`.

- [ ] **Step 6: Add new mutation methods**

```dart
Future<void> updateSafetySettings({
  required String crashSensitivity,
  required String phoneMountType,
}) async {
  final userId = _userId;
  final supabase = _supabase;
  if (userId == null || supabase == null) return;

  await supabase.from('users').update({
    'crash_sensitivity': crashSensitivity,
    'phone_mount': phoneMountType,
  }).eq('id', userId);

  final current = state.value;
  if (current != null) {
    state = AsyncData(current.copyWith(
      crashSensitivity: crashSensitivity,
      phoneMountType: phoneMountType,
    ));
  }
}

Future<void> updateNonArrivalSettings({
  required bool enabled,
  required int delayMin,
}) async {
  final userId = _userId;
  final supabase = _supabase;
  if (userId == null || supabase == null) return;

  await supabase.from('users').update({
    'non_arrival_enabled': enabled,
    'non_arrival_delay_min': delayMin,
  }).eq('id', userId);

  final current = state.value;
  if (current != null) {
    state = AsyncData(current.copyWith(
      nonArrivalEnabled: enabled,
      nonArrivalDelayMin: delayMin,
    ));
  }
}

Future<void> updateEmergencyProfile({
  String? bloodGroup,
  String? medicalNotes,
}) async {
  final userId = _userId;
  final supabase = _supabase;
  if (userId == null || supabase == null) return;

  await supabase.from('users').update({
    'blood_group': bloodGroup,
    'medical_notes': medicalNotes,
  }).eq('id', userId);

  final current = state.value;
  if (current != null) {
    state = AsyncData(current.copyWith(
      bloodGroup: bloodGroup,
      medicalNotes: medicalNotes,
    ));
  }
}
```

- [ ] **Step 7: Update existing tests**

The test file `app/test/features/auth/providers/user_profile_provider_test.dart` has tests for `UserProfile.fromJson`. Update them to verify the new fields parse correctly. Add a test case:

```dart
test('UserProfile fromJson parses safety and tracking settings', () {
  final profile = UserProfile.fromJson({
    'id': 'user_1',
    'name': 'Test',
    'date_of_birth': '2000-01-01',
    'vehicle_type': 'motorcycle',
    'vehicle_reg': 'KL-01-AB-1234',
    'crash_sensitivity': 'high',
    'phone_mount': 'handlebar',
    'non_arrival_delay_min': 10,
    'non_arrival_enabled': true,
    'blood_group': 'O+',
    'medical_notes': 'Asthma',
  });

  expect(profile.crashSensitivity, 'high');
  expect(profile.phoneMountType, 'handlebar');
  expect(profile.nonArrivalDelayMin, 10);
  expect(profile.nonArrivalEnabled, true);
  expect(profile.bloodGroup, 'O+');
  expect(profile.medicalNotes, 'Asthma');
});

test('UserProfile fromJson tolerates null settings', () {
  final profile = UserProfile.fromJson({
    'id': 'user_2',
    'name': null,
    'date_of_birth': null,
    'vehicle_type': null,
    'vehicle_reg': null,
    'crash_sensitivity': null,
    'phone_mount': null,
    'non_arrival_delay_min': null,
    'non_arrival_enabled': null,
    'blood_group': null,
    'medical_notes': null,
  });

  expect(profile.crashSensitivity, isNull);
  expect(profile.phoneMountType, isNull);
  expect(profile.nonArrivalDelayMin, isNull);
  expect(profile.nonArrivalEnabled, isNull);
});
```

- [ ] **Step 8: Run tests**

Run: `cd app && flutter test test/features/auth/providers/user_profile_provider_test.dart`
Expected: All tests pass.

- [ ] **Step 9: Run flutter analyze**

Run: `cd app && flutter analyze --no-fatal-infos`
Expected: No errors.

- [ ] **Step 10: Commit**

```bash
git add app/lib/features/auth/providers/user_profile_provider.dart app/test/features/auth/providers/user_profile_provider_test.dart
git commit -m "feat(settings): expand UserProfile with safety, tracking, and emergency fields"
```

---

### Task 2: Wire crash detection to read user preferences

**Files:**
- Modify: `app/lib/features/crash_detection/providers/crash_detection_provider.dart`

**Interfaces:**
- Consumes: `userProfileProvider` for `crashSensitivity` and `phoneMountType`
- Produces: `crashSensorServiceProvider` and `CrashDetectionNotifier` that use real user preferences instead of hardcoded `null`

- [ ] **Step 1: Update crashSensorServiceProvider to read phone mount from profile**

```dart
final crashSensorServiceProvider = Provider<CrashSensorService?>((ref) {
  final clerkService = ref.watch(clerkServiceProvider);
  if (!clerkService.isSignedIn) return null;

  final profile = ref.watch(userProfileProvider).valueOrNull;
  final threshold = getImpactThresholdForMount(profile?.phoneMountType);
  final service = CrashSensorService(impactThresholdG: threshold);
  ref.onDispose(() => service.dispose());
  return service;
});
```

Add import at top of file:
```dart
import '../../auth/providers/user_profile_provider.dart';
```

- [ ] **Step 2: Update _onImpact to read user preferences**

In `CrashDetectionNotifier._onImpact()`, replace the two `null` calls:

```dart
void _onImpact(ImpactEvent impact) {
  if (state.status != CrashDetectionStatus.monitoring) return;

  if (_lastDetectionTime != null &&
      DateTime.now().difference(_lastDetectionTime!) < _cooldownDuration) {
    debugPrint('[CrashDetection] In cooldown, ignoring impact');
    return;
  }

  final profile = _ref.read(userProfileProvider).valueOrNull;
  final sensitivity = getSensitivityThreshold(profile?.crashSensitivity);
  final mountThreshold = getImpactThresholdForMount(profile?.phoneMountType);

  final score = calculateCrashScore(
    impact: impact,
    mountThreshold: mountThreshold,
    currentSpeedKmh: impact.speedBeforeKmh,
    speedAfterKmh: _sensorService?.lastSpeedKmh ?? 0,
    peakRotationDegS: impact.peakRotationDegS,
    isStillAfterImpact: (_sensorService?.lastSpeedKmh ?? 0) < 5,
  );

  debugPrint(
    '[CrashDetection] Impact score: ${score.toStringAsFixed(2)} '
    '(threshold: $sensitivity)',
  );

  if (score >= sensitivity) {
    _startCountdown(impact);
  }
}
```

- [ ] **Step 3: Update _dispatch to read user preferences**

In `CrashDetectionNotifier._dispatch()`, replace the `null` calls (lines ~182-185):

```dart
final profile = _ref.read(userProfileProvider).valueOrNull;

final incident = await service.dispatchCrash(
  peakG: impact.peakG,
  confidence: calculateCrashScore(
    impact: impact,
    mountThreshold: getImpactThresholdForMount(profile?.phoneMountType),
    currentSpeedKmh: impact.speedBeforeKmh,
    speedAfterKmh: _sensorService?.lastSpeedKmh ?? 0,
    peakRotationDegS: impact.peakRotationDegS,
    isStillAfterImpact: (_sensorService?.lastSpeedKmh ?? 0) < 5,
  ),
  speedAtEvent: impact.speedBeforeKmh,
  sensorWindow: sensorWindow,
  phoneMount: profile?.phoneMountType,
);
```

- [ ] **Step 4: Run flutter analyze**

Run: `cd app && flutter analyze --no-fatal-infos`
Expected: No errors.

- [ ] **Step 5: Run tests**

Run: `cd app && flutter test`
Expected: All tests pass (existing crash detection tests may need minor adjustment if they were reading null).

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/crash_detection/providers/crash_detection_provider.dart
git commit -m "feat(settings): wire crash detection to read user profile preferences"
```

---

### Task 3: Create SettingsScreen

**Files:**
- Create: `app/lib/features/settings/screens/settings_screen.dart`
- Modify: `app/lib/features/settings/screens/screens.dart` (update barrel)
- Modify: `app/lib/core/router/app_router.dart` (add route)

**Interfaces:**
- Consumes: `userProfileProvider` for reading current settings, `UserProfileNotifier` mutation methods for saving
- Produces: `SettingsScreen` widget, GoRoute `/settings`

- [ ] **Step 1: Write SettingsScreen**

Create `app/lib/features/settings/screens/settings_screen.dart`:

```dart
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
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _medicalNotesController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _medicalNotesController.dispose();
    super.dispose();
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
              ref.read(userProfileProvider.notifier).updateSafetySettings(
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
              ref.read(userProfileProvider.notifier).updateSafetySettings(
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
            ref.read(userProfileProvider.notifier).updateNonArrivalSettings(
                  enabled: value,
                  delayMin: delayMin,
                );
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
              ref.read(userProfileProvider.notifier).updateEmergencyProfile(
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
            decoration: const InputDecoration(
              labelText: 'Medical Notes',
              hintText: 'Allergies, conditions, medications...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            onChanged: (value) {
              ref.read(userProfileProvider.notifier).updateEmergencyProfile(
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
            [profile.vehicleType, profile.vehicleReg]
                .where((s) => s != null && s.isNotEmpty)
                .join(' - '),
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
```

- [ ] **Step 2: Update barrel export**

Replace `app/lib/features/settings/screens/screens.dart` with:

```dart
export 'settings_screen.dart';
```

- [ ] **Step 3: Add /settings route to GoRouter**

In `app/lib/core/router/app_router.dart`, add import and route:

```dart
// Add import at top:
import '../../features/settings/screens/settings_screen.dart';

// Add route after /trips:
GoRoute(
  path: '/settings',
  builder: (context, state) => const SettingsScreen(),
),
```

- [ ] **Step 4: Run flutter analyze**

Run: `cd app && flutter analyze --no-fatal-infos`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/settings/screens/ app/lib/core/router/app_router.dart
git commit -m "feat(settings): add SettingsScreen with safety, tracking, and account sections"
```

---

### Task 4: Add settings entry point to home screen

**Files:**
- Modify: `app/lib/core/router/app_router.dart` (update home route)

**Interfaces:**
- Consumes: GoRouter for navigation
- Produces: Home screen with gear icon navigating to `/settings`, and quick-nav tiles for existing features

- [ ] **Step 1: Replace home stub with a real home screen**

In `app/lib/core/router/app_router.dart`, replace the home route stub:

```dart
GoRoute(
  path: '/home',
  builder: (context, state) => const _HomeScreen(),
),
```

Add the `_HomeScreen` class as a private widget in the same file (keeps it simple, avoids new files for a minimal home screen):

```dart
class _HomeScreen extends StatelessWidget {
  const _HomeScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RoadPack'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _NavTile(
            icon: Icons.group,
            label: 'Safety Circles',
            route: '/circles',
          ),
          _NavTile(
            icon: Icons.route,
            label: 'Known Routes',
            route: '/routes',
          ),
          _NavTile(
            icon: Icons.history,
            label: 'Trip History',
            route: '/trips',
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(route),
      ),
    );
  }
}
```

Add `import 'package:go_router/go_router.dart';` if not already imported (it likely is, since GoRoute is used).

- [ ] **Step 2: Run flutter analyze**

Run: `cd app && flutter analyze --no-fatal-infos`
Expected: No errors.

- [ ] **Step 3: Run full test suite**

Run: `cd app && flutter test`
Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add app/lib/core/router/app_router.dart
git commit -m "feat(settings): add home screen with settings nav and feature tiles"
```

---

### Task 5: Integration verification

**Files:**
- No new files. Verify everything compiles and tests pass.

**Interfaces:**
- Consumes: All prior tasks
- Produces: Clean compile, passing tests

- [ ] **Step 1: Run build_runner**

Run: `cd app && dart run build_runner build --delete-conflicting-outputs`
Expected: Clean build.

- [ ] **Step 2: Run flutter analyze**

Run: `cd app && flutter analyze --no-fatal-infos`
Expected: No errors.

- [ ] **Step 3: Run all tests**

Run: `cd app && flutter test`
Expected: All tests pass.

- [ ] **Step 4: Dart format**

Run: `cd app && dart format --set-exit-if-changed .`
If changes needed, commit:
```bash
cd app && dart format .
git add -u
git commit -m "style(settings): apply dart format"
```

---
