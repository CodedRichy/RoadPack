# Development timeline

Chronological view of notable development events for **RoadPack**, derived from commit history (messages and change scope).

---

## Summary by type

- **feature**: 2 notable commit(s)
- **refactor**: 1 notable commit(s)
- **fix**: 1 notable commit(s)
- **doc**: 1 notable commit(s)
- **test**: 1 notable commit(s)
- **other**: 2 notable commit(s)

---

## Timeline (newest first)

### 2025-12-15 — 6a7b606 **[feature]**

Migrate to Google Maps with dark style support

Scope: 7 files, +480 -342

<details>
<summary>Commit body</summary>

Replaces flutter_map and latlong2 with google_maps_flutter for map rendering. Adds a custom dark map style (assets/map_style.json) and dynamic theme switching based on time of day. Updates Android and iOS to provide Google Maps API keys, removes unused map dependencies, and cleans up related platfor

</details>

---

### 2025-12-14 — 9d9d1a8 **[test]**

Update theme colors and adjust UI spacing/text

Scope: 3 files, +8 -8

<details>
<summary>Commit body</summary>

Changed the app's color palette in app_colors.dart to new shades of pink and purple. Updated home_screen.dart to reduce the bottom spacing from 100 to 50 for the BottomNavBar. Modified login_screen.dart to update the tagline from 'convoy' to 'pack' for consistency.

</details>

---

### 2025-12-13 — c0a975d **[feature]**

Add main app screens, theming, and navigation

Scope: 13 files, +1301 -18

<details>
<summary>Commit body</summary>

Implemented core screens: splash, login, OTP, home (with map), convoys, and profile. Added bottom navigation bar, app color theme, and updated main.dart to use the new navigation flow. Integrated flutter_map, latlong2, and lucide_icons dependencies. Updated pubspec files and registered required plug

</details>

---

### 2025-12-12 — 0dad2ec **[refactor]**

Remove License badge from README

Scope: 1 files, +0 -1

<details>
<summary>Commit body</summary>

Removed the License badge from the README.

</details>

---

### 2025-12-11 — d8d81cf **[other]**

Rename app package to com.roadpack.app

Scope: 5 files, +28 -9

<details>
<summary>Commit body</summary>

Updated applicationId, manifest package, app label, and MainActivity location to use the new package name com.roadpack.app. Also added corresponding entry in google-services.json for the new package.

</details>

---

### 2025-11-05 — 2a12030 **[fix]**

Fix formatting in LICENSE file

Scope: 0 files, +0 -0

---

### 2025-11-05 — 2d7f7fc **[doc]**

Revise README for RoadPack project

Scope: 1 files, +50 -10

<details>
<summary>Commit body</summary>

Updated project name and expanded README with features and details.

</details>

---

### 2025-10-27 — 45f245f **[other]**

Initial Flutter project setup

Scope: 130 files, +4893 -0

<details>
<summary>Commit body</summary>

Add base files for a new Flutter application, including platform-specific configuration and assets for Android, iOS, Linux, macOS, Windows, and web. Includes project metadata, README, analysis options, and initial source code.

</details>

---

*Generated from Git commits. Deterministic; no LLM inference.*
