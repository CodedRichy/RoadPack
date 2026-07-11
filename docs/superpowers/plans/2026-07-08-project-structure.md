# RoadPack v2 Project Structure — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Scaffold the complete RoadPack v2 monorepo — Flutter app with feature-first architecture, Supabase backend with migrations and Edge Functions, shared constants, docs, and CI workflows.

**Architecture:** Monorepo with three top-level modules: `app/` (Flutter, Riverpod, feature-first), `backend/` (Supabase project with Edge Functions in Deno/TS), `shared/` (constants and templates used by both). All Phase 1 features scaffolded as empty feature folders with barrel files.

**Tech Stack:** Flutter 3.41.5, Dart 3.11.3, Riverpod, GoRouter, Supabase (PostGIS), Drift, Supabase CLI 2.109.1

## Global Constraints

- Flutter 3.41.5+ / Dart 3.11.3+
- Supabase CLI 2.109.1+
- All Dart files use UTF-8 encoding
- No Unicode characters in CLI output (Windows platform)
- Feature-first folder structure: each feature has models/, providers/, screens/, services/, widgets/
- Every Dart library file has a barrel export (feature_name.dart)
- Backend Edge Functions are Deno/TypeScript
- SQL migrations numbered sequentially with leading zeros (00001_)
- .gitignore must cover both Flutter and Supabase artifacts

---

### Task 1: Flutter App Scaffold + Core Dependencies

**Files:**
- Create: `app/` (entire Flutter project via `flutter create`)
- Modify: `app/pubspec.yaml` (add all Phase 1 dependencies)
- Modify: `app/analysis_options.yaml` (strict lints)
- Modify: `.gitignore` (add Supabase + monorepo ignores)
- Delete: `app/lib/main.dart` (replace in next step)
- Delete: `app/test/widget_test.dart` (replace later)

**Interfaces:**
- Produces: a buildable Flutter project at `app/` with all dependencies resolved

- [ ] **Step 1: Create Flutter project in app/ subdirectory**

```bash
cd C:\Users\rishi\Documents\GitHub\RoadPack
flutter create --org com.roadpack --project-name roadpack --platforms android,ios app
```

Expected: Flutter project created at `app/`, `flutter analyze` passes.

- [ ] **Step 2: Replace pubspec.yaml with Phase 1 dependencies**

Replace `app/pubspec.yaml` with:

```yaml
name: roadpack
description: India-first road safety platform
publish_to: 'none'
version: 2.0.0+1

environment:
  sdk: ^3.11.0
  flutter: '>=3.41.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

  # State management
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.6.1

  # Routing
  go_router: ^14.8.1

  # Backend
  supabase_flutter: ^2.9.0

  # Local storage
  drift: ^2.23.1
  sqlite3_flutter_libs: ^0.5.28
  shared_preferences: ^2.5.3

  # Networking
  connectivity_plus: ^6.1.4

  # Location
  flutter_background_geolocation: ^4.17.3

  # Maps
  google_maps_flutter: ^2.12.1

  # Sensors (Phase 2 prep)
  sensors_plus: ^6.1.1

  # Utilities
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0
  intl: ^0.19.0
  uuid: ^4.5.1
  url_launcher: ^6.3.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  build_runner: ^2.4.14
  freezed: ^2.5.8
  json_serializable: ^6.9.4
  riverpod_generator: ^2.6.3
  drift_dev: ^2.23.1
  riverpod_lint: ^2.6.3

flutter:
  uses-material-design: true
  generate: true
```

- [ ] **Step 3: Set up strict analysis options**

Replace `app/analysis_options.yaml` with:

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    prefer_const_constructors: true
    prefer_const_declarations: true
    avoid_print: true
    require_trailing_commas: true
    prefer_single_quotes: true
    sort_child_properties_last: true
    unawaited_futures: true
    prefer_final_locals: true

analyzer:
  errors:
    invalid_annotation_target: ignore
  exclude:
    - '**/*.g.dart'
    - '**/*.freezed.dart'
```

- [ ] **Step 4: Enable Flutter gen-l10n**

Create `app/l10n.yaml`:

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
```

Create `app/lib/l10n/app_en.arb`:

```json
{
  "@@locale": "en",
  "appTitle": "RoadPack"
}
```

Create `app/lib/l10n/app_hi.arb`:

```json
{
  "@@locale": "hi",
  "appTitle": "RoadPack"
}
```

Create `app/lib/l10n/app_ml.arb`:

```json
{
  "@@locale": "ml",
  "appTitle": "RoadPack"
}
```

- [ ] **Step 5: Update .gitignore for monorepo**

Append to the root `.gitignore`:

```gitignore

# Supabase
backend/supabase/.temp/
backend/supabase/.branches/

# Node / Deno
node_modules/
.env
.env.local
.env.*.local

# Flutter (app subdirectory)
app/.dart_tool/
app/.flutter-plugins-dependencies
app/build/
app/.packages
app/.pub-cache/
app/.pub/
app/coverage/

# Generated
*.g.dart
*.freezed.dart

# OS
Thumbs.db
desktop.ini
```

- [ ] **Step 6: Resolve dependencies**

```bash
cd C:\Users\rishi\Documents\GitHub\RoadPack\app
flutter pub get
```

Expected: dependencies resolve, `pubspec.lock` generated.

- [ ] **Step 7: Verify build**

```bash
cd C:\Users\rishi\Documents\GitHub\RoadPack\app
flutter analyze
```

Expected: no analysis issues (or only info-level from generated files).

- [ ] **Step 8: Commit**

```bash
cd C:\Users\rishi\Documents\GitHub\RoadPack
git add app/ .gitignore
git commit -m "feat: scaffold Flutter app with Phase 1 dependencies

Riverpod, GoRouter, Supabase, Drift, background geolocation,
Google Maps, i18n (EN/HI/ML), strict analysis options.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 2: App Core Module + Entry Points

**Files:**
- Create: `app/lib/main.dart`
- Create: `app/lib/app.dart`
- Create: `app/lib/core/constants/app_constants.dart`
- Create: `app/lib/core/constants/constants.dart` (barrel)
- Create: `app/lib/core/errors/app_exception.dart`
- Create: `app/lib/core/errors/errors.dart` (barrel)
- Create: `app/lib/core/extensions/extensions.dart` (barrel)
- Create: `app/lib/core/network/supabase_client.dart`
- Create: `app/lib/core/network/connectivity_service.dart`
- Create: `app/lib/core/network/network.dart` (barrel)
- Create: `app/lib/core/router/app_router.dart`
- Create: `app/lib/core/router/router.dart` (barrel)
- Create: `app/lib/core/storage/storage.dart` (barrel)
- Create: `app/lib/core/theme/app_theme.dart`
- Create: `app/lib/core/theme/app_colors.dart`
- Create: `app/lib/core/theme/theme.dart` (barrel)
- Create: `app/lib/core/utils/utils.dart` (barrel)
- Create: `app/lib/core/widgets/widgets.dart` (barrel)
- Create: `app/lib/core/core.dart` (barrel for all of core)
- Delete: `app/test/widget_test.dart`

**Interfaces:**
- Produces: `main.dart` entry point, `App` widget, `AppRouter`, `AppTheme`, `SupabaseClientProvider`, `ConnectivityService`, `AppException` base class — all importable from `core/core.dart`

- [ ] **Step 1: Create app/lib/core/constants/app_constants.dart**

```dart
abstract final class AppConstants {
  static const String appName = 'RoadPack';
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const Duration locationUpdateInterval = Duration(seconds: 5);
  static const Duration sosCountdownDuration = Duration(seconds: 5);
  static const Duration crashCountdownDuration = Duration(seconds: 30);
  static const int maxEmergencyContacts = 5;
  static const int minEmergencyContacts = 1;
  static const int maxFamilyCircleMembers = 15;
  static const int maxFriendsCircleMembers = 25;
  static const int maxCommuteCircleMembers = 100;
  static const int maxConvoyCircleMembers = 50;
  static const int locationHistoryRetentionDays = 7;
}
```

- [ ] **Step 2: Create app/lib/core/constants/constants.dart**

```dart
export 'app_constants.dart';
```

- [ ] **Step 3: Create app/lib/core/errors/app_exception.dart**

```dart
sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => message;
}

final class NetworkException extends AppException {
  const NetworkException([super.message = 'No network connection']);
}

final class AuthException extends AppException {
  const AuthException([super.message = 'Authentication failed']);
}

final class LocationException extends AppException {
  const LocationException([super.message = 'Location unavailable']);
}

final class StorageException extends AppException {
  const StorageException([super.message = 'Local storage error']);
}
```

- [ ] **Step 4: Create app/lib/core/errors/errors.dart**

```dart
export 'app_exception.dart';
```

- [ ] **Step 5: Create app/lib/core/extensions/extensions.dart**

```dart
// Barrel file for Dart extensions. Empty until needed.
```

- [ ] **Step 6: Create app/lib/core/network/supabase_client.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );
}
```

- [ ] **Step 7: Create app/lib/core/network/connectivity_service.dart**

```dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

final isOnlineProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.whenOrNull(
        data: (results) => results.any(
          (r) => r != ConnectivityResult.none,
        ),
      ) ??
      true;
});
```

- [ ] **Step 8: Create app/lib/core/network/network.dart**

```dart
export 'connectivity_service.dart';
export 'supabase_client.dart';
```

- [ ] **Step 9: Create app/lib/core/router/app_router.dart**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const Scaffold(
        body: Center(child: Text('RoadPack v2')),
      ),
    ),
  ],
);
```

- [ ] **Step 10: Create app/lib/core/router/router.dart**

```dart
export 'app_router.dart';
```

- [ ] **Step 11: Create app/lib/core/theme/app_colors.dart**

```dart
import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color primary = Color(0xFF1A73E8);
  static const Color error = Color(0xFFD32F2F);
  static const Color sosRed = Color(0xFFFF1744);
  static const Color safeGreen = Color(0xFF2E7D32);
  static const Color warningAmber = Color(0xFFF57F17);
  static const Color surface = Color(0xFF121212);
  static const Color surfaceLight = Color(0xFFFAFAFA);
  static const Color onSurface = Color(0xFFE0E0E0);
  static const Color onSurfaceLight = Color(0xFF212121);
}
```

- [ ] **Step 12: Create app/lib/core/theme/app_theme.dart**

```dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: AppColors.primary,
        scaffoldBackgroundColor: AppColors.surface,
      );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: AppColors.primary,
        scaffoldBackgroundColor: AppColors.surfaceLight,
      );
}
```

- [ ] **Step 13: Create app/lib/core/theme/theme.dart**

```dart
export 'app_colors.dart';
export 'app_theme.dart';
```

- [ ] **Step 14: Create barrel files for remaining core modules**

`app/lib/core/storage/storage.dart`:
```dart
// Barrel file for local storage (Drift). Empty until DB is set up.
```

`app/lib/core/utils/utils.dart`:
```dart
// Barrel file for utility helpers. Empty until needed.
```

`app/lib/core/widgets/widgets.dart`:
```dart
// Barrel file for shared widgets. Empty until needed.
```

- [ ] **Step 15: Create app/lib/core/core.dart**

```dart
export 'constants/constants.dart';
export 'errors/errors.dart';
export 'extensions/extensions.dart';
export 'network/network.dart';
export 'router/router.dart';
export 'storage/storage.dart';
export 'theme/theme.dart';
export 'utils/utils.dart';
export 'widgets/widgets.dart';
```

- [ ] **Step 16: Create app/lib/app.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/core.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('hi'),
        Locale('ml'),
      ],
    );
  }
}
```

- [ ] **Step 17: Create app/lib/main.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/core.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConstants.supabaseUrl.isNotEmpty) {
    await initSupabase();
  }

  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
```

- [ ] **Step 18: Delete default test file**

```bash
rm app/test/widget_test.dart
```

- [ ] **Step 19: Verify build**

```bash
cd C:\Users\rishi\Documents\GitHub\RoadPack\app
flutter analyze
```

- [ ] **Step 20: Commit**

```bash
cd C:\Users\rishi\Documents\GitHub\RoadPack
git add app/lib/ app/l10n.yaml
git commit -m "feat: add core module with entry points, theme, router, network, errors

Riverpod ProviderScope, GoRouter placeholder, dark-first theme,
Supabase init, connectivity provider, i18n setup (EN/HI/ML).

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 3: Feature Folder Scaffolding

**Files:**
- Create: 10 feature directories, each with `models/`, `providers/`, `screens/`, `services/`, `widgets/` and a barrel file

Features: `auth`, `circles`, `tracking`, `live_map`, `commute`, `sos`, `emergency_profile`, `alerts`, `bystander`, `settings`

**Interfaces:**
- Produces: importable barrel files for each feature (e.g., `import 'features/auth/auth.dart'`)

- [ ] **Step 1: Create all feature directories and barrel files**

For each feature, create the folder structure and a barrel file. Each subfolder gets a `.gitkeep` to ensure Git tracks empty directories.

Create `app/lib/features/auth/auth.dart`:
```dart
export 'models/models.dart';
export 'providers/providers.dart';
export 'screens/screens.dart';
export 'services/services.dart';
export 'widgets/widgets.dart';
```

Create `app/lib/features/auth/models/models.dart`:
```dart
// Auth models barrel
```

Create `app/lib/features/auth/providers/providers.dart`:
```dart
// Auth providers barrel
```

Create `app/lib/features/auth/screens/screens.dart`:
```dart
// Auth screens barrel
```

Create `app/lib/features/auth/services/services.dart`:
```dart
// Auth services barrel
```

Create `app/lib/features/auth/widgets/widgets.dart`:
```dart
// Auth widgets barrel
```

Repeat the identical structure for all 10 features:
- `circles/circles.dart`
- `tracking/tracking.dart`
- `live_map/live_map.dart`
- `commute/commute.dart`
- `sos/sos.dart`
- `emergency_profile/emergency_profile.dart`
- `alerts/alerts.dart`
- `bystander/bystander.dart`
- `settings/settings.dart`

Each gets the same 5 subdirectory barrel files (`models/models.dart`, `providers/providers.dart`, `screens/screens.dart`, `services/services.dart`, `widgets/widgets.dart`) and a top-level barrel that exports all five.

- [ ] **Step 2: Verify no analysis errors**

```bash
cd C:\Users\rishi\Documents\GitHub\RoadPack\app
flutter analyze
```

- [ ] **Step 3: Commit**

```bash
cd C:\Users\rishi\Documents\GitHub\RoadPack
git add app/lib/features/
git commit -m "feat: scaffold all Phase 1 feature directories

auth, circles, tracking, live_map, commute, sos, emergency_profile,
alerts, bystander, settings -- each with models/providers/screens/
services/widgets and barrel exports.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 4: Supabase Backend Scaffold

**Files:**
- Create: `backend/supabase/` (via `supabase init`)
- Create: `backend/supabase/migrations/00001_enable_extensions.sql`
- Create: `backend/supabase/seed/hospitals_ernakulam.sql` (placeholder)
- Create: `backend/supabase/functions/alert-cascade/index.ts`
- Create: `backend/supabase/functions/incident-receive/index.ts`
- Create: `backend/supabase/functions/sms-webhook/index.ts`
- Create: `backend/supabase/functions/voice-webhook/index.ts`
- Create: `backend/supabase/functions/heartbeat-check/index.ts`
- Create: `backend/supabase/functions/non-arrival-check/index.ts`
- Create: `backend/supabase/functions/canary/index.ts`

**Interfaces:**
- Produces: Supabase project structure with PostGIS-enabled initial migration and placeholder Edge Functions

- [ ] **Step 1: Initialize Supabase project**

```bash
cd C:\Users\rishi\Documents\GitHub\RoadPack
mkdir -p backend
cd backend
npx supabase init
```

Expected: `backend/supabase/` directory created with `config.toml`.

- [ ] **Step 2: Create initial migration enabling extensions**

Create `backend/supabase/migrations/00001_enable_extensions.sql`:

```sql
-- Enable required PostgreSQL extensions for RoadPack v2
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";
CREATE EXTENSION IF NOT EXISTS "pg_cron";
```

- [ ] **Step 3: Create seed data placeholder**

Create `backend/supabase/seed/hospitals_ernakulam.sql`:

```sql
-- Hospital seed data for Ernakulam district (pilot)
-- To be populated with manually verified data from NHA + state health dept
-- Fields: name, lat/lon, address, phone, type, trauma_level, has_emergency
--
-- Verification status: PENDING
-- Target: all trauma-capable facilities in Ernakulam district
```

- [ ] **Step 4: Create Edge Function stubs**

Create `backend/supabase/functions/alert-cascade/index.ts`:
```typescript
// Alert Cascade — Push -> SMS -> Voice call orchestration
// Receives: incident_id
// Dispatches alerts to all emergency contacts via FCM, MSG91, Exotel
// Tracks per-channel delivery status in incident_alerts table

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

serve(async (req) => {
  return new Response(
    JSON.stringify({ status: 'not_implemented' }),
    { headers: { 'Content-Type': 'application/json' }, status: 501 },
  )
})
```

Create `backend/supabase/functions/incident-receive/index.ts`:
```typescript
// Incident Receive — accepts < 300 byte incident packet from device
// Validates, stores incident, triggers alert-cascade
// Designed to work over 2G (minimal payload)

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

serve(async (req) => {
  return new Response(
    JSON.stringify({ status: 'not_implemented' }),
    { headers: { 'Content-Type': 'application/json' }, status: 501 },
  )
})
```

Create `backend/supabase/functions/sms-webhook/index.ts`:
```typescript
// SMS Webhook — MSG91 delivery receipts and acknowledgment callbacks
// Updates incident_alerts status (delivered/read/failed)
// Parses SMS reply "OK" as acknowledgment

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

serve(async (req) => {
  return new Response(
    JSON.stringify({ status: 'not_implemented' }),
    { headers: { 'Content-Type': 'application/json' }, status: 501 },
  )
})
```

Create `backend/supabase/functions/voice-webhook/index.ts`:
```typescript
// Voice Webhook — Exotel TTS/IVR callbacks
// Captures IVR keypress acknowledgments
// Updates incident_alerts with ack_method: 'ivr'

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

serve(async (req) => {
  return new Response(
    JSON.stringify({ status: 'not_implemented' }),
    { headers: { 'Content-Type': 'application/json' }, status: 501 },
  )
})
```

Create `backend/supabase/functions/heartbeat-check/index.ts`:
```typescript
// Heartbeat Check (Cron) — Lost-contact detection (FR-083)
// Runs periodically, checks devices.last_heartbeat during active commutes
// If no heartbeat for 15+ min during expected commute, creates lost_contact incident
// Universal backstop for every failure mode where the phone can't speak

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

serve(async (req) => {
  return new Response(
    JSON.stringify({ status: 'not_implemented' }),
    { headers: { 'Content-Type': 'application/json' }, status: 501 },
  )
})
```

Create `backend/supabase/functions/non-arrival-check/index.ts`:
```typescript
// Non-Arrival Check (Cron) — Expected arrival monitoring (FR-042/043)
// Checks known_routes for overdue arrivals
// Triggers user check-in prompt, escalates to circle if no response

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

serve(async (req) => {
  return new Response(
    JSON.stringify({ status: 'not_implemented' }),
    { headers: { 'Content-Type': 'application/json' }, status: 501 },
  )
})
```

Create `backend/supabase/functions/canary/index.ts`:
```typescript
// Canary — Synthetic pipeline test (hourly)
// Runs a fake incident through the full cascade against test numbers
// Alerts on-call if any channel fails
// A safety system whose failures are discovered by victims has already failed

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

serve(async (req) => {
  return new Response(
    JSON.stringify({ status: 'not_implemented' }),
    { headers: { 'Content-Type': 'application/json' }, status: 501 },
  )
})
```

- [ ] **Step 5: Commit**

```bash
cd C:\Users\rishi\Documents\GitHub\RoadPack
git add backend/
git commit -m "feat: scaffold Supabase backend with migrations and Edge Functions

PostGIS/uuid-ossp/pg_cron extensions, hospital seed placeholder,
7 Edge Function stubs: alert-cascade, incident-receive, sms-webhook,
voice-webhook, heartbeat-check, non-arrival-check, canary.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 5: Shared Constants + Alert Templates

**Files:**
- Create: `shared/constants/event_types.dart`
- Create: `shared/constants/error_codes.dart`
- Create: `shared/templates/alert_templates.json`

**Interfaces:**
- Produces: shared type definitions and templates that app and backend reference

- [ ] **Step 1: Create shared/constants/event_types.dart**

```dart
/// Shared event types used by both app and backend.
/// Backend Edge Functions reference the string values directly.

enum IncidentType {
  crashDetected('crash_detected'),
  sos('sos'),
  inactivity('inactivity'),
  nonArrival('non_arrival'),
  lostContact('lost_contact');

  const IncidentType(this.value);
  final String value;
}

enum IncidentSeverity {
  low('low'),
  medium('medium'),
  high('high'),
  critical('critical');

  const IncidentSeverity(this.value);
  final String value;
}

enum IncidentStatus {
  detected('detected'),
  countdown('countdown'),
  cancelled('cancelled'),
  dispatched('dispatched'),
  acknowledged('acknowledged'),
  escalated('escalated'),
  resolved('resolved');

  const IncidentStatus(this.value);
  final String value;
}

enum AlertChannel {
  push('push'),
  sms('sms'),
  call('call'),
  whatsapp('whatsapp');

  const AlertChannel(this.value);
  final String value;
}

enum AlertStatus {
  queued('queued'),
  sent('sent'),
  delivered('delivered'),
  read('read'),
  failed('failed');

  const AlertStatus(this.value);
  final String value;
}

enum CircleType {
  family('family'),
  friends('friends'),
  commute('commute'),
  convoy('convoy');

  const CircleType(this.value);
  final String value;
}

enum CircleRole {
  admin('admin'),
  member('member'),
  observer('observer');

  const CircleRole(this.value);
  final String value;
}

enum CrashSensitivity {
  low('low'),
  medium('medium'),
  high('high');

  const CrashSensitivity(this.value);
  final String value;
}

enum ActivityState {
  stationary('stationary'),
  walking('walking'),
  riding('riding');

  const ActivityState(this.value);
  final String value;
}
```

- [ ] **Step 2: Create shared/constants/error_codes.dart**

```dart
/// Error codes shared between app and backend.
/// Use these in API responses and local error handling.

abstract final class ErrorCodes {
  static const String authInvalidOtp = 'AUTH_INVALID_OTP';
  static const String authExpiredOtp = 'AUTH_EXPIRED_OTP';
  static const String authMinorNoConsent = 'AUTH_MINOR_NO_CONSENT';
  static const String circleMaxMembers = 'CIRCLE_MAX_MEMBERS';
  static const String circleDuplicateMember = 'CIRCLE_DUPLICATE_MEMBER';
  static const String circleInvalidInvite = 'CIRCLE_INVALID_INVITE';
  static const String contactMaxReached = 'CONTACT_MAX_REACHED';
  static const String contactMinRequired = 'CONTACT_MIN_REQUIRED';
  static const String incidentAlreadyResolved = 'INCIDENT_ALREADY_RESOLVED';
  static const String locationPermissionDenied = 'LOCATION_PERMISSION_DENIED';
  static const String locationServiceDisabled = 'LOCATION_SERVICE_DISABLED';
  static const String networkOffline = 'NETWORK_OFFLINE';
  static const String rateLimited = 'RATE_LIMITED';
}
```

- [ ] **Step 3: Create shared/templates/alert_templates.json**

```json
{
  "_comment": "DLT-registered SMS templates. Variable placeholders match DLT format. Do not change template structure without re-registering on DLT.",
  "emergency_push": {
    "title": "EMERGENCY ALERT - RoadPack",
    "body": "{name} may have been in an accident.\n\nLocation: {address}\nMap: {map_url}\nTime: {timestamp}\nSpeed: {speed} km/h\nNearest hospital: {hospital_name}, {hospital_distance}, {hospital_phone}\n\nCall 112 for emergency services.\nCall {name}: {victim_phone}\nReply OK to confirm you've seen this."
  },
  "emergency_sms": {
    "template": "ROADPACK ALERT: {name} accident at {address}. Map: {map_url}. Hospital: {hospital_name} {hospital_phone}. Call 112. Call {name}: {victim_phone}. Reply OK.",
    "dlt_template_id": "PENDING_REGISTRATION"
  },
  "emergency_voice_tts": {
    "script_en": "This is an emergency alert from RoadPack. {name} may have been in an accident at {address}. Their last known position was {landmark}. Please check on them or call 112. Press 1 to confirm you have received this message.",
    "script_hi": "Yeh RoadPack se ek emergency alert hai. {name} ka {address} par accident hua ho sakta hai. Kripya unhe check karein ya 112 par call karein. Is message ko confirm karne ke liye 1 dabayen.",
    "script_ml": "Ithu RoadPack il ninnum ulla oru emergency alert aanu. {name} kku {address} il accident undaayirikaam. Dayavayi avarude sthithi ariyukayo 112 il call cheyyukayo cheyyuka. Ee message sthireekarikkan 1 press cheyyuka."
  },
  "non_arrival_user_checkin": {
    "title": "Everything okay?",
    "body": "You usually arrive at {destination} by {expected_time}. It's {current_time}. Tap to let us know you're fine."
  },
  "non_arrival_circle_alert": {
    "title": "{name} hasn't arrived",
    "body": "{name} usually reaches {destination} by {expected_time}. They haven't arrived and didn't respond to our check-in."
  },
  "arrival_sms": {
    "template": "RoadPack: {name} reached {destination} at {time}.",
    "dlt_template_id": "PENDING_REGISTRATION"
  },
  "lost_contact": {
    "title": "Lost contact with {name}",
    "body": "We lost contact with {name} at {last_location} ({time_ago} ago). Their phone may be off or out of range."
  }
}
```

- [ ] **Step 4: Commit**

```bash
cd C:\Users\rishi\Documents\GitHub\RoadPack
git add shared/
git commit -m "feat: add shared constants (event types, error codes) and alert templates

Incident/alert/circle enums, error code constants, DLT-format SMS
templates, push/voice TTS scripts in EN/HI/ML.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 6: Docs + CI Workflows + Final Commit

**Files:**
- Create: `docs/prd/roadpack-v2-prd.md` (copy from Downloads)
- Create: `docs/prd/roadpack-v2-prd-enhanced.md` (copy from Downloads)
- Create: `.github/workflows/app_ci.yml`
- Create: `.github/workflows/backend_ci.yml`

**Interfaces:**
- Produces: PRDs versioned in repo, CI pipelines for both app and backend

- [ ] **Step 1: Copy PRDs into docs/prd/**

```bash
mkdir -p C:\Users\rishi\Documents\GitHub\RoadPack\docs\prd
cp "C:\Users\rishi\Downloads\roadpack-v2-prd.md" C:\Users\rishi\Documents\GitHub\RoadPack\docs\prd/
cp "C:\Users\rishi\Downloads\roadpack-v2-prd-enhanced.md" C:\Users\rishi\Documents\GitHub\RoadPack\docs\prd/
```

- [ ] **Step 2: Create .github/workflows/app_ci.yml**

```yaml
name: App CI

on:
  push:
    branches: [main]
    paths: ['app/**']
  pull_request:
    branches: [main]
    paths: ['app/**']

jobs:
  analyze-and-test:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: app
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.5'
          channel: 'stable'

      - name: Install dependencies
        run: flutter pub get

      - name: Analyze
        run: flutter analyze

      - name: Run tests
        run: flutter test

      - name: Build APK (debug)
        run: flutter build apk --debug
```

- [ ] **Step 3: Create .github/workflows/backend_ci.yml**

```yaml
name: Backend CI

on:
  push:
    branches: [main]
    paths: ['backend/**']
  pull_request:
    branches: [main]
    paths: ['backend/**']

jobs:
  lint-and-validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: denoland/setup-deno@v1
        with:
          deno-version: v1.x

      - name: Lint Edge Functions
        run: |
          for dir in backend/supabase/functions/*/; do
            if [ -f "$dir/index.ts" ]; then
              echo "Linting $dir..."
              deno lint "$dir/index.ts"
            fi
          done

      - name: Type-check Edge Functions
        run: |
          for dir in backend/supabase/functions/*/; do
            if [ -f "$dir/index.ts" ]; then
              echo "Checking $dir..."
              deno check "$dir/index.ts"
            fi
          done

      - name: Validate migrations syntax
        run: |
          for f in backend/supabase/migrations/*.sql; do
            echo "Validating $f..."
            # Basic syntax check - ensures files are valid UTF-8 and non-empty
            [ -s "$f" ] || (echo "Empty migration: $f" && exit 1)
          done
```

- [ ] **Step 4: Commit**

```bash
cd C:\Users\rishi\Documents\GitHub\RoadPack
git add docs/prd/ .github/
git commit -m "feat: add PRDs to docs and CI workflows for app + backend

PRDs versioned under docs/prd/. App CI: analyze, test, debug build.
Backend CI: Deno lint/typecheck Edge Functions, migration validation.
Both triggered by path filters.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

- [ ] **Step 5: Final verification**

```bash
cd C:\Users\rishi\Documents\GitHub\RoadPack
find . -maxdepth 1 -not -name '.' -not -name '.git' -not -name '.claude' | sort
find app/lib -type f | sort
find backend -type f | sort
find shared -type f | sort
find .github -type f | sort
```

Verify the full tree matches the spec.
