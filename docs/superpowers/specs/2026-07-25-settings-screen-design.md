---
title: Settings Screen + Crash Config Wiring
date: 2026-07-25
status: approved
---

# Settings Screen + Crash Config Wiring Design

## Goal

Expose user-configurable safety settings (crash sensitivity, phone mount, non-arrival alerts) via a Settings screen, expand UserProfile to include missing DB fields, and wire crash detection to read user preferences instead of hardcoded nulls.

## Architecture

The `users` table already has columns for `crash_sensitivity`, `phone_mount`, `non_arrival_delay_min`, `non_arrival_enabled`, `blood_group`, `medical_notes`, and `language`. The Flutter app ignores all of them. This feature:

1. Expands `UserProfile` model to include these fields
2. Adds update methods to `UserProfileNotifier`
3. Creates a `SettingsScreen` with grouped sections
4. Wires `CrashDetectionNotifier` to read user's mount/sensitivity from profile
5. Adds `/settings` route and a nav entry point from home

## Settings Screen Sections

### Safety
- **Crash Detection** -- toggle (enables/disables crash monitoring)
- **Crash Sensitivity** -- segmented control: High / Medium (default) / Low
  - High: more sensitive, may have more false positives
  - Medium: balanced (default)
  - Low: less sensitive, fewer false positives
- **Phone Mount** -- segmented control: Handlebar / Pocket / Bag / Unknown (default)
  - Affects G-force threshold for crash detection

### Tracking
- **Non-Arrival Alerts** -- toggle (default: on)
- **Non-Arrival Delay** -- dropdown: 5 / 10 / 15 (default) / 20 / 30 minutes
  - Only shown when non-arrival is enabled

### Emergency Profile
- **Blood Group** -- dropdown: A+, A-, B+, B-, AB+, AB-, O+, O-
- **Medical Notes** -- text field (allergies, conditions, medications)

### Account
- **Name** -- editable text (pre-filled from profile)
- **Vehicle** -- type + registration (pre-filled)
- **Sign Out** button

## Data Flow

```
UserProfile (expanded) <-- reads from --> Supabase `users` table
     |
     v
SettingsScreen reads via userProfileProvider
     |
     v (on change)
UserProfileNotifier.updateSafety() / .updateNonArrival() / .updateEmergencyProfile()
     |
     v
Supabase `users` table updated
     |
     v (ref.watch cascade)
CrashDetectionNotifier re-reads mount/sensitivity from UserProfile
```

## Constraints

- Riverpod manual providers (NOT codegen)
- No SharedPreferences -- all settings persisted to Supabase `users` table
- Crash sensitivity/phone_mount stored as strings matching existing DB column values
- Same dark-first Material3 theme
- No new dependencies required
