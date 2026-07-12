# L2: Crash Detection — Design Spec

**Date:** 2026-07-12
**Branch:** `feat/l2-crash-detection`
**Scope:** On-device crash detection via accelerometer/gyroscope + GPS sudden-stop analysis. Threshold heuristic (not ML). Two-wheelers first.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Vehicle scope | Two-wheelers first | India-first, highest crash mortality, cleanest accelerometer signature |
| Detection approach | Threshold heuristic | No training data, simpler to ship/debug, ML deferred to Phase 3 |
| Sensor sampling rate | 100 Hz accel, 50 Hz gyro | Standard for crash detection research, battery-reasonable |
| Sensor gating | Only when activity = in_vehicle AND trip recording | Saves battery -- no sensors while stationary/walking |
| G-force threshold | 4g impact (resultant vector) | Published motorcycle crash detection research |
| Speed correlation | Require speed > 10 km/h before event + speed drop > 50% within 5s after | Eliminates phone drops, walking stumbles |
| Countdown duration | 30 seconds | Longer than SOS (5s) because automated detection has higher false positive risk |
| False positive handling | Cancel with reason picker | Feeds future ML training data via sensor_data JSONB |
| Server integration | Reuse incident-receive + cascade | Expand type validation, otherwise identical pipeline |
| Phone mount | Adjust thresholds per users.phone_mount | Handlebar = direct signal, pocket = dampened + noise |

## 1. Detection Algorithm

### 1.1 Crash Signature (Two-Wheeler)

A motorcycle/scooter crash produces a distinctive pattern:

1. **Impact spike**: Sudden high-g acceleration (4-8g) lasting 50-200ms
2. **Tumble/slide**: Chaotic rotation (gyroscope) for 1-3 seconds
3. **Stillness**: Near-zero motion after impact (rider on ground)
4. **Speed drop**: GPS speed drops from riding speed to near-zero

The algorithm checks for the conjunction of these signals, not any single one.

### 1.2 Detection Pipeline

```
Accelerometer (100 Hz)
    |
    v
Ring Buffer (500 samples = 5 seconds)
    |
    v
Impact Detector: resultant acceleration > threshold?
    |-- No --> continue sampling
    |-- Yes --> capture impact window (200ms before + 500ms after)
          |
          v
    Correlation Checks (within 5 seconds of impact):
      [1] GPS speed before impact > 10 km/h? (was riding)
      [2] GPS speed dropped > 50%? (sudden stop)
      [3] Gyroscope shows rotation > 300 deg/s? (tumble)
      [4] Post-impact stillness for > 3 seconds? (not moving)
          |
          v
    Score = weighted sum of passed checks
      - Impact magnitude (0.4 weight)
      - Speed correlation (0.3 weight)
      - Rotation detected (0.15 weight)
      - Post-impact stillness (0.15 weight)
          |
          v
    Score > sensitivity threshold?
      - High sensitivity: 0.45 (more detections, more false positives)
      - Medium sensitivity: 0.60 (balanced, default)
      - Low sensitivity: 0.75 (fewer false positives, may miss minor crashes)
          |-- No --> log near-miss for future analysis
          |-- Yes --> CRASH DETECTED --> start 30s countdown
```

### 1.3 Threshold Calibration by Phone Mount

| Mount Position | Impact Threshold | Speed Weight | Notes |
|---------------|-----------------|--------------|-------|
| Handlebar | 4g | 0.3 | Direct signal, most reliable |
| Pocket | 6g | 0.35 | Dampened by body, more noise from walking |
| Bag | 7g | 0.35 | Most dampened, highest noise |
| Unknown (default) | 5g | 0.3 | Conservative middle ground |

### 1.4 Anti-False-Positive Measures

- **Activity gate**: Only run detection when FBG reports `in_vehicle` activity AND trip is recording
- **Speed gate**: Require GPS speed > 10 km/h before the event (eliminates phone drops while parked)
- **Cooldown**: After a detection (confirmed or cancelled), suppress new detections for 60 seconds
- **Debounce**: Impact must exceed threshold for at least 2 consecutive samples (20ms at 100 Hz) to filter electrical noise
- **Sensitivity setting**: Per-user `crash_sensitivity` in users table, defaults to `medium`

## 2. State Machine

```
monitoring ──[impact detected + score > threshold]──> detected
     ^                                                     |
     |                                          [30s countdown starts]
     |                                                     |
     |                                                     v
     |                                                countdown
     |                                                /         \
     |                              [user cancels]  /             \ [timer expires]
     |                                            /                 \
     +────────────── cancelled                                   dispatching
                     (with reason)                                   |
                                                            [incident created]
                                                                     |
                                                                     v
                                                                  active
                                                                     |
                                                           [user resolves]
                                                                     |
                                                                     v
                                                                  resolved
```

### 2.1 State Definitions

| State | Sensors | GPS | UI | Duration |
|-------|---------|-----|-----|----------|
| monitoring | Accel 100Hz + Gyro 50Hz | Normal (from FBG) | None visible | Indefinite (while riding) |
| detected | Continue sampling | Switch to SOS mode (1s) | Flash/vibrate alert | < 1 second (auto-transition) |
| countdown | Continue sampling | SOS mode | Full-screen countdown (30s) | 30 seconds |
| cancelled | Stop sampling briefly | Revert to normal | Reason picker dialog | Until reason selected |
| dispatching | Continue sampling | SOS mode | "Alerting contacts..." | Until server responds |
| active | Continue sampling | SOS mode | Active incident screen | Until resolved |
| resolved | Revert to normal | Revert to normal | Confirmation | Until dismissed |

### 2.2 Integration with Existing SOS

The crash detection state machine is **separate from** the SOS state machine but shares the same dispatch pipeline:

- Crash detection has its own `CrashDetectionState` / `CrashDetectionNotifier`
- On dispatch, it calls the same `SosService.dispatchSos()` but with `type: 'crash_detected'` instead of `type: 'sos'`
- The countdown UI is different (30s, shows "Crash Detected", has reason picker on cancel)
- Both can be active simultaneously (user could manually trigger SOS during a crash countdown)

## 3. Sensor Service

### 3.1 Architecture

```
CrashSensorService (singleton)
  |
  |-- AccelerometerStream (sensors_plus, 100 Hz)
  |-- GyroscopeStream (sensors_plus, 50 Hz)
  |-- RingBuffer<AccelSample> (500 samples = 5s window)
  |-- RingBuffer<GyroSample> (250 samples = 5s window)
  |
  |-- start() / stop()  -- gated by activity state
  |-- onImpactDetected: Stream<ImpactEvent>
```

### 3.2 Data Types

```dart
class AccelSample {
  final double x, y, z;      // m/s^2
  final double magnitude;     // sqrt(x^2 + y^2 + z^2)
  final DateTime timestamp;
}

class GyroSample {
  final double x, y, z;      // rad/s
  final double magnitude;     // sqrt(x^2 + y^2 + z^2)
  final DateTime timestamp;
}

class ImpactEvent {
  final double peakG;                 // peak resultant acceleration in g
  final double peakRotation;          // peak rotation rate in deg/s
  final List<AccelSample> window;     // 200ms before + 500ms after impact
  final List<GyroSample> gyroWindow;  // matching gyro window
  final DateTime timestamp;
  final double speedBeforeKmh;        // GPS speed before impact
}
```

### 3.3 Ring Buffer

Fixed-size circular buffer that overwrites oldest samples. Enables capturing the 200ms *before* an impact event (needed for impact shape analysis). At 100 Hz, 500 samples = 5 seconds of history.

### 3.4 Battery Impact

- Accelerometer at 100 Hz: ~2-3% battery per hour
- Gyroscope at 50 Hz: ~1-2% battery per hour
- Total sensor overhead: ~3-5% per hour of active riding
- Mitigated by activity gating: sensors only run during detected vehicle motion

## 4. Crash Detection Service

### 4.1 Architecture

```dart
class CrashDetectionService {
  // Dependencies
  final CrashSensorService sensorService;
  final TrackingService trackingService;
  final SosService sosService;
  
  // Configuration
  final CrashSensitivity sensitivity;
  final String phoneMount;
  
  // State
  CrashDetectionState state = monitoring;
  Timer? countdownTimer;
  int countdownRemaining = 30;
  
  // Methods
  void start();           // begin monitoring (called when trip starts)
  void stop();            // stop monitoring (called when trip ends)
  void cancelDetection(String reason);  // user cancels during countdown
  Future<void> dispatch(ImpactEvent event);  // send to server
}
```

### 4.2 Scoring Function

```dart
double calculateCrashScore(ImpactEvent impact, {
  required double currentSpeedKmh,
  required double speedAfterKmh,
  required double peakRotationDegS,
  required bool isStillAfterImpact,
  required String phoneMount,
}) {
  final threshold = _thresholdForMount(phoneMount);
  
  // Impact magnitude score (0-1): how far above threshold
  final impactScore = min(1.0, (impact.peakG / threshold - 1.0) * 0.5 + 0.5);
  
  // Speed correlation score (0-1): speed drop percentage
  final speedDrop = currentSpeedKmh > 0 
      ? (currentSpeedKmh - speedAfterKmh) / currentSpeedKmh 
      : 0.0;
  final speedScore = min(1.0, speedDrop / 0.5);  // full score at 50% drop
  
  // Rotation score (0-1)
  final rotationScore = peakRotationDegS > 300 ? 1.0 
      : peakRotationDegS > 150 ? 0.5 
      : 0.0;
  
  // Stillness score (0-1)
  final stillnessScore = isStillAfterImpact ? 1.0 : 0.0;
  
  return impactScore * 0.4 
       + speedScore * 0.3 
       + rotationScore * 0.15 
       + stillnessScore * 0.15;
}
```

## 5. Countdown UI

### 5.1 Crash Countdown Screen

Full-screen overlay (same pattern as existing `SosCountdownScreen`) but:

- **Background**: Dark with pulsing red border (danger signal)
- **Center**: Large "30" countdown number
- **Header**: "CRASH DETECTED" in bold red
- **Subtext**: "Alerting your emergency contacts in {N} seconds"
- **Cancel button**: Large "I'M OKAY" button at bottom
- **Audio**: Loud alarm tone (increasing urgency) via device speaker
- **Haptic**: Continuous vibration pattern
- **Screen wake**: Force screen on + prevent sleep during countdown

### 5.2 Cancel Reason Picker

When user taps "I'M OKAY" during countdown:

```
What happened?
  [ ] Pothole / speed bump
  [ ] Phone dropped
  [ ] Sudden braking
  [ ] Other (text field)
  
  [Confirm - I'm Fine]
```

The selected reason is stored in `incidents.cancelled_reason` and the full sensor window is stored in `incidents.sensor_data` for future ML training data.

### 5.3 Active Crash Screen

If countdown expires without cancel, same as existing `SosActiveScreen` but header reads "CRASH ALERT SENT" instead of "SOS ACTIVE". Shows:
- "Your emergency contacts have been notified"
- Location being shared
- "I'M OKAY" resolve button

## 6. Server Changes

### 6.1 Expand incident-receive

Current validation hardcodes `type: 'sos'`. Change to accept `['sos', 'crash_detected']`.

For `crash_detected` type, the incident packet includes additional fields:
```typescript
{
  type: 'crash_detected',
  lat: number,
  lng: number,
  speed: number,
  heading: number,
  ts: string,
  battery: number,
  // Crash-specific:
  confidence: number,      // 0.0 - 1.0 detection score
  severity: string,        // low / medium / high / critical
  peak_g: number,          // peak impact force in g
  sensor_window: object,   // compressed sensor data for analysis
  phone_mount: string,     // pocket / handlebar / bag
}
```

The severity is derived from peak g-force:
- < 5g: low
- 5-8g: medium  
- 8-12g: high
- > 12g: critical

### 6.2 Alert Message Differentiation

The `alert-cascade` function's SMS/push messages should differentiate:
- SOS: "{name} triggered an emergency SOS alert"
- Crash: "{name} may have been in a crash. Impact detected at {location}"

This requires a minor change to message templates in `alert-cascade/index.ts`.

## 7. Flutter File Structure

```
app/lib/features/crash_detection/
  models/
    crash_state.dart           -- CrashDetectionState enum + state class
    impact_event.dart          -- ImpactEvent, AccelSample, GyroSample
  services/
    crash_sensor_service.dart  -- accelerometer/gyro sampling + ring buffer
    crash_detection_service.dart -- detection algorithm + scoring
  providers/
    crash_detection_provider.dart -- Riverpod notifier, wires to tracking
  screens/
    crash_countdown_screen.dart  -- 30s countdown with cancel
    crash_reason_picker.dart     -- false positive reason dialog
  widgets/
    crash_overlay.dart           -- app-level overlay (same pattern as SOS)
```

## 8. Integration Points

### 8.1 With TrackingService

- `TrackingService._onActivityChange` notifies `CrashDetectionService` of activity transitions
- When activity = `in_vehicle` AND trip is recording: `crashDetection.start()`
- When activity != `in_vehicle` OR trip ends: `crashDetection.stop()`
- On crash detected: `trackingService.setSOSMode(true)` for high-frequency GPS

### 8.2 With SOS System

- Crash dispatch calls same `SosService.dispatchSos()` with different type
- Both crash and SOS share `SosOverlay` pattern — crash adds its own overlay layer
- If SOS is manually triggered during crash countdown, crash countdown is cancelled (SOS takes priority)

### 8.3 With Existing Schema

No new migrations needed. All columns exist:
- `incidents.type = 'crash_detected'`
- `incidents.confidence` = detection score
- `incidents.severity` = derived from peak g
- `incidents.sensor_data` = full sensor window JSONB
- `incidents.cancelled_reason` = false positive label
- `incidents.speed_at_event` = GPS speed at impact
- `users.crash_sensitivity` = user's threshold preference
- `users.phone_mount` = mount position for threshold adjustment

## 9. Testing Strategy

- **Unit tests**: Ring buffer (overflow, window extraction), scoring function (all weight combinations), threshold calibration per mount
- **Unit tests**: State machine transitions (monitoring -> detected -> countdown -> cancelled/dispatched)
- **Unit tests**: Anti-false-positive gates (speed gate, activity gate, cooldown, debounce)
- **Integration tests**: Simulated crash sequences — feed synthetic accelerometer data, verify detection fires
- **Manual testing**: Record real accelerometer data from rides, replay through detection engine, tune thresholds

## 10. Privacy & Security

- Raw sensor data stays on device unless user consents to `sensor_upload`
- Sensor window included in incident only for actual detections (not near-misses)
- Cancelled detection sensor data stored locally for opt-in upload
- No continuous sensor data upload — only event-triggered snapshots

## 11. Out of Scope (Deferred)

- ML/TFLite model (Phase 3 — needs training data from cancelled detections)
- Car crash detection (different g-force profiles, airbag deployment signal)
- Bicycle crash detection (much lower thresholds, high false positive risk)
- Audio impact analysis (microphone capture)
- Barometer/pressure change detection
- Multi-device correlation (passenger phones corroborating)
- Automatic emergency services (112) calling
- Post-crash vitals monitoring
