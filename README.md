# 🛣️ RoadPack

![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?logo=firebase&logoColor=black)
![Google Maps](https://img.shields.io/badge/Maps%20API-4285F4?logo=googlemaps&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Android-green)

## Overview

**RoadPack** is a high-performance, real-time convoy tracking and coordination application designed specifically for bikers and car enthusiasts. It addresses the challenges of group navigation by providing a unified live interface where every member's location is synchronized on a shared map, ensuring no rider or driver is left behind.

## Features

*   📍 **Live Convoy Map**: Real-time position tracking of all participants on a high-fidelity Google Map.
*   🔑 **Secure OTP Login**: Seamless phone-based authentication powered by Firebase.
*   🧭 **Convoy Management**: Dynamic controls to create, join, and manage group rides with ease.
*   🌓 **Dynamic Map Theming**: Custom dark-mode styles that automatically adapt based on the time of day.
*   🏁 **Session Tracking**: Start and end convoy sessions with a single tap, managing group state effectively.
*   ⚡ **Instant Sync**: Sub-second synchronization of location data across all devices.

## Architecture

RoadPack follows a modern, reactive architecture built on the Flutter framework.

*   **Frontend**: A responsive Flutter UI utilizing a stateful management approach for markers and map transitions.
*   **Data Flow**: 
    1.  Location data is polled from the device GPS.
    2.  Updates are pushed to **Firebase Firestore**.
    3.  Connected clients subscribe to Firestore streams to receive real-time coordinate updates.
*   **Key Services**:
    *   **Auth Service**: Handles Firebase Phone Authentication.
    *   **Map Controller**: Manages camera positioning, custom styling, and marker clustering.

## Tech Stack

*   **Language**: Dart
*   **Framework**: Flutter
*   **Mapping**: Google Maps Flutter SDK
*   **Backend**: Firebase (Authentication & Cloud Firestore)
*   **Icons**: Lucide Icons & Cupertino Icons
*   **Design**: Custom design system with glassmorphic elements and curated pink/purple palette.

## Repository Structure

```text
/lib
  /screens    → Main application views (Home, Login, OTP, Profile, Convoys)
  /theme      → Global design system, color tokens, and theme definitions
  /widgets    → Reusable UI components (custom navigation bars, action buttons)
/assets       → Configuration files and custom map style JSON
/docs         → Auto-generated architecture logs and development timelines
/test         → Widget and unit testing suite
```

## Installation

### Prerequisites
*   Flutter SDK (stable channel)
*   A Google Cloud Project with Maps SDK for Android/iOS enabled
*   A Firebase Project with Phone Auth and Firestore enabled

### Steps
1.  **Clone the Repository**:
    ```bash
    git clone https://github.com/CodedRichy/RoadPack.git
    cd RoadPack
    ```
2.  **Install Dependencies**:
    ```bash
    flutter pub get
    ```
3.  **Platform Configuration**:
    *   **Android**: Place your `google-services.json` in `android/app/`.
    *   **iOS**: Place your `GoogleService-Info.plist` in `ios/Runner/`.
4.  **API Keys**:
    *   Add your Google Maps API key to the `AndroidManifest.xml` (Android) and `AppDelegate` (iOS).

## Usage

### Running Locally
```bash
flutter run
```

### Core Interactions
*   **Authentication**: Enter your phone number on the login screen and verify via the OTP screen.
*   **Map Mode**: Tap the map area on the Home Screen to toggle between "Card View" and "Full Screen" mode.
*   **Sessions**: Use the **Start Convoy** button to initiate a new session or **Join Convoy** to enter an existing group.

## Configuration

*   **Map Style**: Modify `assets/map_style.json` to customize the Google Maps visual layers (roads, landmarks, water bodies).
*   **Colors**: Global brand colors are centralized in `lib/theme/app_colors.dart`.

## Development

*   **Linting**: The project uses `flutter_lints`. Run `flutter analyze` before committing.
*   **Themes**: Adhere to the `AppColors` and `AppTheme` definitions to maintain visual consistency.

## Testing

The project includes widget tests to verify UI integrity. Run them using:
```bash
flutter test
```

## Deployment

To build the application for production:

### Android
```bash
flutter build apk --release
```

### iOS
```bash
flutter build ipa --release
```

## Roadmap

*   [ ] **Background Geolocation**: Persistent tracking even when the device is locked or the app is in the background.
*   [ ] **Route Overlays**: Leaderboard sharing of the intended navigation route.
*   [ ] **Emergency Alerts**: Rapid notification system for mishaps or mechanical failures.
*   [ ] **Voice Integration**: Push-to-talk features for real-time rider communication.

## Contributing

This project is currently **proprietary**. Contributions, forks, or redistribution are only permitted with express written consent from the author.

## License

**All Rights Reserved**  
Copyright (c) 2025 Rishi Praseeth. 

This code is proprietary and confidential. No part of this repository may be copied, modified, distributed, or used in any form without express written permission from the author.
