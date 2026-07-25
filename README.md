<div align="center">

# RoadPack

**Every 4 minutes, someone dies on an Indian road. Most crash victims die waiting for help that arrives too late.**

RoadPack is an India-first road safety platform that combines real-time commute tracking, automatic crash detection, family safety circles, and SOS alert cascades into a single mobile app.

[![Flutter 3.41+](https://img.shields.io/badge/flutter-3.41+-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart 3.11+](https://img.shields.io/badge/dart-3.11+-0175C2?style=flat-square&logo=dart&logoColor=white)](https://dart.dev)
[![Supabase](https://img.shields.io/badge/backend-Supabase-3FCF8E?style=flat-square&logo=supabase&logoColor=white)](https://supabase.com)
[![License](https://img.shields.io/badge/license-Proprietary-red?style=flat-square)](LICENSE)

<!-- TODO: Add app screenshot or GIF demo here -->
<!-- <img src="assets/demo.gif" alt="RoadPack Demo" width="300" /> -->

</div>

---

## The Problem

If your app knows where you are, where you're going, and who cares about you -- it can close the gap between a crash and the moment help arrives, even when the victim can't call for help.

Traditional safety apps require manual SOS triggers. But in a motorcycle crash at 60 km/h, the rider is unconscious in under a second. RoadPack detects the crash automatically and cascades alerts to family, friends, and emergency contacts -- with escalating urgency until someone responds.

## Features

### Crash Detection
Accelerometer + gyroscope engine detects sudden deceleration patterns consistent with vehicle collisions. Automatic alert cascade triggers without user interaction.

### Safety Circles
Create family and friend groups. Members see each other's live location during commutes. When a crash is detected, every circle member is notified simultaneously.

### SOS Alert Cascade
Multi-channel escalation: push notification -> voice call -> SMS. Each contact gets escalating alerts until someone acknowledges. If no one responds, the system keeps escalating.

### Commute Tracking
Background geolocation with trip detection and route learning. Heartbeat and check-in system detects when a rider goes silent. Non-arrival alerts trigger if you don't reach your destination.

### Live Map
Real-time location sharing during active commutes. Circle members can watch your route progress.

### Dual Network Mode
- **Public Wi-Fi** -- Privacy-first, minimal data exposure
- **Trusted Networks** -- Full feature set with continuous tracking

## Architecture

```
  ┌──────────────────────────────────┐
  │         Flutter App (Dart)        │
  │                                   │
  │  11 Feature Modules:              │
  │  alerts, auth, bystander,         │
  │  circles, commute, crash,         │
  │  emergency_profile, live_map,     │
  │  settings, sos, tracking          │
  │                                   │
  │  Riverpod + GoRouter + Drift      │
  └──────────────┬───────────────────┘
                 │ Supabase Client
  ┌──────────────┴───────────────────┐
  │      Supabase Backend             │
  │                                   │
  │  PostgreSQL (16 migrations, RLS)  │
  │  13 Edge Functions (Deno/TS):     │
  │  alert-cascade, heartbeat-check,  │
  │  incident-receive, location-      │
  │  ingest, non-arrival-check,       │
  │  escalation-check, sms/voice      │
  │  webhooks, clerk-webhook...       │
  └──────────────────────────────────┘
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **Mobile** | Flutter 3.41+ / Dart 3.11+ |
| **State** | Riverpod (with code gen) |
| **Routing** | GoRouter |
| **Local DB** | Drift (SQLite) |
| **Auth** | Clerk Flutter SDK + Google Sign-In |
| **Backend** | Supabase (Postgres, Edge Functions, RLS) |
| **Push** | Firebase Cloud Messaging |
| **Maps** | Google Maps Flutter |
| **Sensors** | sensors_plus (accelerometer + gyroscope) |
| **Location** | flutter_background_geolocation |
| **Code Gen** | freezed, json_serializable, drift_dev |

## Quick Start

### Prerequisites

- Flutter SDK >= 3.41.0
- Dart SDK >= 3.11.0
- [Supabase CLI](https://supabase.com/docs/guides/cli)
- Android Studio or VS Code with Flutter extension
- Google Maps API key
- Clerk API keys
- Firebase project (for FCM)

### Setup

```bash
git clone https://github.com/CodedRichy/RoadPack.git
cd RoadPack/app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### Configure Environment

Create `app/lib/core/env.dart` with your API keys (Clerk, Google Maps, Supabase URL/anon key, Firebase).

### Run

```bash
cd app
flutter run
```

### Backend (Local)

```bash
cd backend
supabase start
supabase functions serve
```

### Tests

```bash
cd app
flutter test
```

26 test files covering auth, circles, crash detection, SOS, tracking, and commute features.

## Project Structure

```
RoadPack/
  app/
    lib/
      core/               Router, theme, storage, network, errors, widgets
      features/
        alerts/            Alert display and management
        auth/              Clerk auth + Google Sign-In
        bystander/         Bystander assistance features
        circles/           Family/friend safety groups
        commute/           Trip detection and route learning
        crash_detection/   Accelerometer/gyroscope crash engine
        emergency_profile/ Medical info and emergency contacts
        live_map/          Real-time location sharing
        settings/          App preferences
        sos/               SOS trigger and cascade
        tracking/          Background geolocation
    test/                  26 test files
  backend/
    supabase/
      functions/           13 Deno/TypeScript edge functions
      migrations/          16 SQL migrations
      seed/                Seed data
  shared/
    constants/             Cross-platform event types, error codes
    templates/             Alert message templates (JSON)
  docs/
    prd/                   Product Requirements Document
```

## CI/CD

Two GitHub Actions workflows:
- **App CI** -- Flutter analyze, test, debug APK build (on push to `app/`)
- **Backend CI** -- Deno lint, type-check edge functions, validate SQL migrations (on push to `backend/`)

## Roadmap

- [ ] Bystander mode (nearby users can assist crash victims)
- [ ] Hospital database integration
- [ ] 112 ERSS (Emergency Response Support System) integration
- [ ] Offline SMS fallback for low-connectivity areas
- [ ] Regional language support (Hindi, Tamil, Malayalam, Kannada)
- [ ] Group ride / convoy mode (revival from v1)

## License

Proprietary. All Rights Reserved. See [LICENSE](LICENSE).

---

<div align="center">

Built by [Rishi Praseeth Krishnan](https://rishipraseeth.in)

*Because no one should die waiting for help that never comes.*

</div>
