# RoadPack v2 — Project Structure Design

**Date:** 2026-07-08
**Status:** Draft
**Scope:** Monorepo layout, Flutter app architecture, backend structure, shared modules, CI

---

## Decisions

| Decision | Choice |
|---|---|
| Repo layout | Monorepo (app + backend + shared) |
| Flutter architecture | Feature-first with Riverpod |
| Backend | Supabase Cloud + Edge Functions (Deno) |
| Scaffold scope | Full Phase 1 features |

---

## 1. Top-Level Monorepo

```
roadpack/
  app/                  # Flutter mobile app (flutter create root)
  backend/              # Supabase project + Edge Functions
  shared/               # Shared constants, types, configs
  docs/                 # PRDs, specs, design docs
  .github/              # CI/CD workflows
  .claude/              # Claude Code config (existing)
  .gitignore
  LICENSE
```

---

## 2. Flutter App (`app/lib/`)

```
app/lib/
  main.dart
  app.dart                          # MaterialApp, router, theme setup

  core/
    constants/                      # App-wide constants, enums
    errors/                         # Error types, failure handling
    extensions/                     # Dart extensions
    network/                        # Supabase client, connectivity checker
    router/                         # GoRouter config, route definitions
    storage/                        # Drift DB setup, shared prefs
    theme/                          # AppTheme, colors, typography
    utils/                          # Helpers, formatters
    widgets/                        # Shared widgets (buttons, loaders, etc.)

  features/
    auth/                           # OTP login, age gate, onboarding
      models/
      providers/
      screens/
      services/
      widgets/

    circles/                        # Safety circles (family/friends/commute)
      models/
      providers/
      screens/
      services/
      widgets/

    tracking/                       # Background location engine, duty cycling
      models/
      providers/
      screens/
      services/                     # Location service, activity recognition, geofencing
      widgets/

    live_map/                       # Real-time map with circle members
      models/
      providers/
      screens/
      services/
      widgets/

    commute/                        # Route learning, non-arrival alerts
      models/
      providers/
      screens/
      services/
      widgets/

    sos/                            # Manual SOS trigger, countdown
      models/
      providers/
      screens/
      services/
      widgets/

    emergency_profile/              # Contacts, medical info, ICE card
      models/
      providers/
      screens/
      services/
      widgets/

    alerts/                         # Incoming alert display, incident timeline
      models/
      providers/
      screens/
      services/
      widgets/

    bystander/                      # Bystander mode UI, hospital finder
      models/
      providers/
      screens/
      services/
      widgets/

    settings/                       # App settings, permissions, language, OEM guidance
      models/
      providers/
      screens/
      services/
      widgets/
```

### Cross-Feature Dependencies

- `tracking` exposes a location stream service consumed by `live_map`, `commute`, and `sos`
- `emergency_profile` provides contact data to `sos` and `alerts`
- `circles` provides membership context to `live_map`, `commute`, and `alerts`
- All cross-feature communication via Riverpod providers in `core/` or direct provider dependencies

### Key Dependencies (pubspec.yaml)

| Package | Purpose |
|---|---|
| `flutter_riverpod` | State management + DI |
| `go_router` | Declarative routing |
| `supabase_flutter` | Auth, DB, Realtime, Storage |
| `drift` + `sqlite3_flutter_libs` | Local SQLite (offline buffer, route cache) |
| `connectivity_plus` | Network state detection |
| `flutter_background_geolocation` | Background tracking, geofencing, activity recognition |
| `google_maps_flutter` | Online map display |
| `flutter_localizations` | i18n (EN/HI/ML for Phase 1) |
| `sensors_plus` | Accelerometer/gyroscope (Phase 2 prep, not used in MVP) |

---

## 3. Backend (`backend/`)

```
backend/
  supabase/
    config.toml                     # Supabase project config
    migrations/
      00001_enable_extensions.sql   # PostGIS, uuid-ossp, pg_cron
      00002_create_users.sql
      00003_create_circles.sql
      00004_create_emergency_contacts.sql
      00005_create_location_history.sql
      00006_create_known_routes.sql
      00007_create_incidents.sql
      00008_create_hospitals.sql
      00009_create_consents.sql
      00010_create_devices.sql
      00011_create_audit_log.sql
    seed/
      hospitals_ernakulam.sql       # Manually verified hospital data for pilot district
    functions/
      alert-cascade/index.ts        # Push -> SMS -> voice call orchestration
      incident-receive/index.ts     # Receive incident packet, trigger cascade
      sms-webhook/index.ts          # MSG91 delivery/ack callbacks
      voice-webhook/index.ts        # Exotel TTS/IVR callbacks
      heartbeat-check/index.ts      # Cron: detect lost-contact (FR-083)
      non-arrival-check/index.ts    # Cron: check expected arrivals
      canary/index.ts               # Hourly synthetic test incident
```

### Architecture Notes

- Migrations follow PRD data model (Sections 12.1-12.8) exactly
- PostGIS enabled for geospatial queries (nearest hospital, users in radius)
- `location_history` partitioned by day with retention job
- Edge Functions handle all server-side cascade logic
- Victim's phone sends a < 300 byte incident packet; server does the rest
- Webhook handlers process MSG91/Exotel delivery receipts and acknowledgments
- `heartbeat-check` is the universal backstop for every failure mode where the phone can't speak
- `canary` validates the full pipeline hourly against test numbers

---

## 4. Shared (`shared/`)

```
shared/
  constants/
    event_types.dart                # Incident types, alert channels, circle types, roles
    error_codes.dart                # Shared error codes (app + backend agree on these)
  templates/
    alert_templates.json            # SMS/push/call message templates (DLT-registered formats)
```

Minimal by design. Only things both app and backend must agree on.

---

## 5. Docs (`docs/`)

```
docs/
  prd/
    roadpack-v2-prd.md
    roadpack-v2-prd-enhanced.md
  superpowers/
    specs/
```

PRDs versioned with code. Design specs accumulate in `superpowers/specs/`.

---

## 6. CI/CD (`.github/workflows/`)

```
.github/
  workflows/
    app_ci.yml                      # Flutter analyze, test, build (on app/ changes)
    backend_ci.yml                  # Edge function lint/test, migration validation (on backend/ changes)
```

Separate workflows triggered by path filters. App and backend CI run independently.
