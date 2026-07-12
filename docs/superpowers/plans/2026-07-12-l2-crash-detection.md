# L2: Crash Detection — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On-device crash detection via accelerometer/gyroscope threshold heuristic with 30s countdown, false-positive reason picker, and integration into existing SOS dispatch pipeline.

**Architecture:** Sensor data flows through a ring buffer into an impact detector. When a crash signature is detected (high-g impact + speed drop + rotation + stillness), a 30-second countdown starts. If not cancelled, the crash is dispatched via the existing incident-receive edge function (expanded to accept `crash_detected` type) which triggers alert-cascade with crash-specific messages. The crash detection state machine is separate from but parallel to the existing SOS state machine.

**Tech Stack:** Flutter + Riverpod (manual providers), sensors_plus 6.1.1, freezed for state classes, existing Supabase Edge Functions (Deno/TypeScript)

## Global Constraints

- Manual Riverpod providers only (no @riverpod codegen)
- freezed for immutable state classes (run `build_runner build` after creating .freezed.dart files)
- sensors_plus ^6.1.1 already in pubspec
- `CrashSensitivity` enum already in `shared/constants/event_types.dart`
- `AppConstants.crashCountdownDuration = Duration(seconds: 30)` already defined
- `IncidentType.crashDetected` already defined in shared event_types.dart
- Incident table already has: `confidence`, `severity`, `sensor_data`, `cancelled_reason`, `speed_at_event`
- Users table already has: `crash_sensitivity`, `phone_mount`
- Follow existing SOS overlay pattern (Stack-based, in app.dart builder)
- All .freezed.dart and .g.dart files are gitignored — CI regenerates them

## File Structure

```
app/lib/features/crash_detection/
  models/
    models.dart                    -- barrel
    impact_event.dart              -- AccelSample, GyroSample, ImpactEvent
    crash_state.dart               -- CrashDetectionStatus enum, CrashDetectionState (freezed)
  services/
    services.dart                  -- barrel
    ring_buffer.dart               -- generic RingBuffer<T>
    crash_sensor_service.dart      -- accel/gyro stream management + impact detection
    crash_detection_service.dart   -- scoring algorithm + state machine
  providers/
    providers.dart                 -- barrel
    crash_detection_provider.dart  -- StateNotifier wiring everything together
  screens/
    screens.dart                   -- barrel
    crash_countdown_screen.dart    -- 30s countdown UI
  widgets/
    widgets.dart                   -- barrel
    crash_reason_picker.dart       -- bottom sheet for false positive reasons
    crash_overlay.dart             -- Stack overlay wired into app
  crash_detection.dart             -- top-level barrel

app/test/features/crash_detection/
  services/
    ring_buffer_test.dart
    crash_detection_service_test.dart
  providers/
    crash_detection_provider_test.dart

backend/supabase/functions/
  incident-receive/index.ts        -- MODIFY: accept crash_detected type
  _shared/channels.ts              -- MODIFY: differentiate crash vs SOS messages

app/lib/features/sos/services/sos_service.dart         -- MODIFY: add dispatchCrash method
app/lib/features/tracking/services/tracking_service.dart -- MODIFY: wire _onActivityChange
app/lib/app.dart                                        -- MODIFY: add CrashOverlay
```

---

### Task 1: Crash Detection Models

**Files:**
- Create: `app/lib/features/crash_detection/models/impact_event.dart`
- Create: `app/lib/features/crash_detection/models/crash_state.dart`
- Create: `app/lib/features/crash_detection/models/models.dart`

**Interfaces:**
- Produces: `AccelSample`, `GyroSample`, `ImpactEvent` classes used by Tasks 2-4
- Produces: `CrashDetectionStatus` enum, `CrashDetectionState` freezed class used by Tasks 4-6, 8

- [ ] **Step 1: Create impact_event.dart**

```dart
import 'dart:math';

class AccelSample {
  AccelSample({
    required this.x,
    required this.y,
    required this.z,
    required this.timestamp,
  }) : magnitude = sqrt(x * x + y * y + z * z);

  final double x;
  final double y;
  final double z;
  final double magnitude;
  final DateTime timestamp;

  double get magnitudeInG => magnitude / 9.81;
}

class GyroSample {
  GyroSample({
    required this.x,
    required this.y,
    required this.z,
    required this.timestamp,
  }) : magnitude = sqrt(x * x + y * y + z * z);

  final double x;
  final double y;
  final double z;
  final double magnitude;
  final DateTime timestamp;

  double get magnitudeInDegS => magnitude * (180 / pi);
}

class ImpactEvent {
  ImpactEvent({
    required this.peakG,
    required this.peakRotationDegS,
    required this.accelWindow,
    required this.gyroWindow,
    required this.timestamp,
    required this.speedBeforeKmh,
  });

  final double peakG;
  final double peakRotationDegS;
  final List<AccelSample> accelWindow;
  final List<GyroSample> gyroWindow;
  final DateTime timestamp;
  final double speedBeforeKmh;
}
```

- [ ] **Step 2: Create crash_state.dart**

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../sos/models/incident.dart';
import 'impact_event.dart';

part 'crash_state.freezed.dart';

enum CrashDetectionStatus {
  disabled,
  monitoring,
  detected,
  countdown,
  dispatching,
  active,
  resolved,
  cancelled,
}

@freezed
class CrashDetectionState with _$CrashDetectionState {
  const CrashDetectionState._();

  const factory CrashDetectionState({
    @Default(CrashDetectionStatus.disabled) CrashDetectionStatus status,
    @Default(30) int countdownRemaining,
    ImpactEvent? impactEvent,
    Incident? activeIncident,
    String? cancelledReason,
    String? errorMessage,
  }) = _CrashDetectionState;

  bool get isMonitoring => status == CrashDetectionStatus.monitoring;
  bool get isCountingDown => status == CrashDetectionStatus.countdown;
  bool get canCancel =>
      status == CrashDetectionStatus.countdown ||
      status == CrashDetectionStatus.detected;
}
```

- [ ] **Step 3: Create barrel file**

```dart
// models.dart
export 'crash_state.dart';
export 'impact_event.dart';
```

- [ ] **Step 4: Run build_runner to generate freezed code**

Run: `cd app && dart run build_runner build --delete-conflicting-outputs`
Expected: `crash_state.freezed.dart` generated successfully

- [ ] **Step 5: Verify no analyze errors**

Run: `cd app && flutter analyze lib/features/crash_detection/models/`
Expected: No issues found

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/crash_detection/models/
git commit -m "feat(crash): add crash detection models (ImpactEvent, CrashDetectionState)"
```

---

### Task 2: Ring Buffer + Tests

**Files:**
- Create: `app/lib/features/crash_detection/services/ring_buffer.dart`
- Create: `app/test/features/crash_detection/services/ring_buffer_test.dart`

**Interfaces:**
- Produces: `RingBuffer<T>` with `add()`, `toList()`, `window()`, `clear()`, `isFull`, `length` — used by Task 3

- [ ] **Step 1: Write ring buffer tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/crash_detection/services/ring_buffer.dart';

void main() {
  group('RingBuffer', () {
    test('adds items up to capacity', () {
      final buffer = RingBuffer<int>(3);
      buffer.add(1);
      buffer.add(2);
      buffer.add(3);
      expect(buffer.toList(), [1, 2, 3]);
      expect(buffer.isFull, true);
      expect(buffer.length, 3);
    });

    test('overwrites oldest on overflow', () {
      final buffer = RingBuffer<int>(3);
      buffer.add(1);
      buffer.add(2);
      buffer.add(3);
      buffer.add(4);
      expect(buffer.toList(), [2, 3, 4]);
      expect(buffer.length, 3);
    });

    test('window returns last N items', () {
      final buffer = RingBuffer<int>(5);
      for (var i = 1; i <= 5; i++) {
        buffer.add(i);
      }
      expect(buffer.window(3), [3, 4, 5]);
      expect(buffer.window(1), [5]);
      expect(buffer.window(10), [1, 2, 3, 4, 5]);
    });

    test('window works after overflow', () {
      final buffer = RingBuffer<int>(3);
      for (var i = 1; i <= 7; i++) {
        buffer.add(i);
      }
      expect(buffer.toList(), [5, 6, 7]);
      expect(buffer.window(2), [6, 7]);
    });

    test('clear resets buffer', () {
      final buffer = RingBuffer<int>(3);
      buffer.add(1);
      buffer.add(2);
      buffer.clear();
      expect(buffer.length, 0);
      expect(buffer.isFull, false);
      expect(buffer.toList(), isEmpty);
    });

    test('empty buffer returns empty list', () {
      final buffer = RingBuffer<int>(5);
      expect(buffer.toList(), isEmpty);
      expect(buffer.window(3), isEmpty);
      expect(buffer.length, 0);
    });

    test('single capacity buffer', () {
      final buffer = RingBuffer<int>(1);
      buffer.add(1);
      expect(buffer.toList(), [1]);
      buffer.add(2);
      expect(buffer.toList(), [2]);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd app && flutter test test/features/crash_detection/services/ring_buffer_test.dart`
Expected: FAIL — cannot find `ring_buffer.dart`

- [ ] **Step 3: Implement RingBuffer**

```dart
class RingBuffer<T> {
  RingBuffer(this.capacity) : _buffer = List<T?>.filled(capacity, null);

  final int capacity;
  final List<T?> _buffer;
  int _head = 0;
  int _count = 0;

  int get length => _count;
  bool get isFull => _count == capacity;
  bool get isEmpty => _count == 0;

  void add(T item) {
    _buffer[_head] = item;
    _head = (_head + 1) % capacity;
    if (_count < capacity) _count++;
  }

  List<T> toList() {
    if (_count == 0) return [];
    final result = <T>[];
    final start = _count < capacity ? 0 : _head;
    for (var i = 0; i < _count; i++) {
      result.add(_buffer[(start + i) % capacity] as T);
    }
    return result;
  }

  List<T> window(int n) {
    final items = toList();
    if (n >= items.length) return items;
    return items.sublist(items.length - n);
  }

  void clear() {
    _head = 0;
    _count = 0;
    _buffer.fillRange(0, capacity, null);
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd app && flutter test test/features/crash_detection/services/ring_buffer_test.dart`
Expected: All 7 tests pass

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/crash_detection/services/ring_buffer.dart app/test/features/crash_detection/services/ring_buffer_test.dart
git commit -m "feat(crash): add generic RingBuffer with tests"
```

---

### Task 3: Crash Sensor Service

**Files:**
- Create: `app/lib/features/crash_detection/services/crash_sensor_service.dart`

**Interfaces:**
- Consumes: `RingBuffer<T>` from Task 2, `AccelSample`, `GyroSample`, `ImpactEvent` from Task 1
- Produces: `CrashSensorService` with `start()`, `stop()`, `impactStream`, `lastSpeed` — used by Task 4

- [ ] **Step 1: Implement CrashSensorService**

```dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/impact_event.dart';
import 'ring_buffer.dart';

class CrashSensorService {
  CrashSensorService({
    required double impactThresholdG,
    this.debounceMs = 20,
  }) : _impactThresholdG = impactThresholdG;

  final double _impactThresholdG;
  final int debounceMs;

  final RingBuffer<AccelSample> _accelBuffer = RingBuffer(500);
  final RingBuffer<GyroSample> _gyroBuffer = RingBuffer(250);

  final _impactController = StreamController<ImpactEvent>.broadcast();
  Stream<ImpactEvent> get impactStream => _impactController.stream;

  StreamSubscription? _accelSub;
  StreamSubscription? _gyroSub;

  double _lastSpeedKmh = 0;
  bool _running = false;
  DateTime? _lastImpactTime;

  double get lastSpeedKmh => _lastSpeedKmh;

  void updateSpeed(double speedKmh) {
    _lastSpeedKmh = speedKmh;
  }

  void start() {
    if (_running) return;
    _running = true;
    _accelBuffer.clear();
    _gyroBuffer.clear();

    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 10),
    ).listen(_onAccel);

    _gyroSub = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 20),
    ).listen(_onGyro);

    debugPrint('[CrashSensor] Started (threshold: ${_impactThresholdG}g)');
  }

  void stop() {
    if (!_running) return;
    _running = false;
    _accelSub?.cancel();
    _accelSub = null;
    _gyroSub?.cancel();
    _gyroSub = null;
    debugPrint('[CrashSensor] Stopped');
  }

  void _onAccel(AccelerometerEvent event) {
    final sample = AccelSample(
      x: event.x,
      y: event.y,
      z: event.z,
      timestamp: DateTime.now(),
    );
    _accelBuffer.add(sample);

    if (sample.magnitudeInG >= _impactThresholdG) {
      _checkImpact(sample);
    }
  }

  void _onGyro(GyroscopeEvent event) {
    final sample = GyroSample(
      x: event.x,
      y: event.y,
      z: event.z,
      timestamp: DateTime.now(),
    );
    _gyroBuffer.add(sample);
  }

  void _checkImpact(AccelSample trigger) {
    final now = trigger.timestamp;
    if (_lastImpactTime != null &&
        now.difference(_lastImpactTime!).inMilliseconds < debounceMs) {
      return;
    }

    if (_lastSpeedKmh < 10) return;

    _lastImpactTime = now;

    final accelWindow = _accelBuffer.toList();
    final gyroWindow = _gyroBuffer.toList();

    double peakG = 0;
    for (final s in accelWindow) {
      if (s.magnitudeInG > peakG) peakG = s.magnitudeInG;
    }

    double peakRotation = 0;
    for (final s in gyroWindow) {
      final degS = s.magnitudeInDegS;
      if (degS > peakRotation) peakRotation = degS;
    }

    final impact = ImpactEvent(
      peakG: peakG,
      peakRotationDegS: peakRotation,
      accelWindow: List.unmodifiable(accelWindow),
      gyroWindow: List.unmodifiable(gyroWindow),
      timestamp: now,
      speedBeforeKmh: _lastSpeedKmh,
    );

    _impactController.add(impact);
    debugPrint('[CrashSensor] Impact detected: ${peakG.toStringAsFixed(1)}g');
  }

  void dispose() {
    stop();
    _impactController.close();
  }
}
```

- [ ] **Step 2: Create services barrel**

```dart
// services.dart
export 'crash_detection_service.dart';
export 'crash_sensor_service.dart';
export 'ring_buffer.dart';
```

Note: `crash_detection_service.dart` doesn't exist yet. Create the barrel with only the existing files for now. We'll add it in Task 4.

Temporary barrel:
```dart
export 'crash_sensor_service.dart';
export 'ring_buffer.dart';
```

- [ ] **Step 3: Verify no analyze errors**

Run: `cd app && flutter analyze lib/features/crash_detection/`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add app/lib/features/crash_detection/services/
git commit -m "feat(crash): add CrashSensorService with accel/gyro sampling"
```

---

### Task 4: Crash Detection Service + Tests

**Files:**
- Create: `app/lib/features/crash_detection/services/crash_detection_service.dart`
- Create: `app/test/features/crash_detection/services/crash_detection_service_test.dart`
- Modify: `app/lib/features/crash_detection/services/services.dart` — add export

**Interfaces:**
- Consumes: `ImpactEvent` from Task 1, `CrashSensorService` from Task 3
- Produces: `CrashDetectionService` with `evaluateImpact()`, `calculateCrashScore()` — used by Task 5
- Produces: `getImpactThresholdForMount()`, `getSensitivityThreshold()` — pure functions

- [ ] **Step 1: Write scoring + threshold tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/crash_detection/models/impact_event.dart';
import 'package:roadpack/features/crash_detection/services/crash_detection_service.dart';

void main() {
  group('getImpactThresholdForMount', () {
    test('handlebar returns 4g', () {
      expect(getImpactThresholdForMount('handlebar'), 4.0);
    });

    test('pocket returns 6g', () {
      expect(getImpactThresholdForMount('pocket'), 6.0);
    });

    test('bag returns 7g', () {
      expect(getImpactThresholdForMount('bag'), 7.0);
    });

    test('unknown returns 5g default', () {
      expect(getImpactThresholdForMount(null), 5.0);
      expect(getImpactThresholdForMount('unknown'), 5.0);
    });
  });

  group('getSensitivityThreshold', () {
    test('high sensitivity returns 0.45', () {
      expect(getSensitivityThreshold('high'), 0.45);
    });

    test('medium sensitivity returns 0.60', () {
      expect(getSensitivityThreshold('medium'), 0.60);
    });

    test('low sensitivity returns 0.75', () {
      expect(getSensitivityThreshold('low'), 0.75);
    });

    test('null defaults to medium', () {
      expect(getSensitivityThreshold(null), 0.60);
    });
  });

  group('calculateCrashScore', () {
    ImpactEvent makeImpact({double peakG = 6.0}) {
      return ImpactEvent(
        peakG: peakG,
        peakRotationDegS: 0,
        accelWindow: [],
        gyroWindow: [],
        timestamp: DateTime(2026),
        speedBeforeKmh: 40,
      );
    }

    test('full crash signature scores high', () {
      final score = calculateCrashScore(
        impact: makeImpact(peakG: 8.0),
        mountThreshold: 5.0,
        currentSpeedKmh: 40,
        speedAfterKmh: 5,
        peakRotationDegS: 400,
        isStillAfterImpact: true,
      );
      expect(score, greaterThan(0.8));
    });

    test('impact only without speed drop scores low', () {
      final score = calculateCrashScore(
        impact: makeImpact(peakG: 6.0),
        mountThreshold: 5.0,
        currentSpeedKmh: 40,
        speedAfterKmh: 38,
        peakRotationDegS: 50,
        isStillAfterImpact: false,
      );
      expect(score, lessThan(0.5));
    });

    test('zero speed before gives zero speed score', () {
      final score = calculateCrashScore(
        impact: makeImpact(peakG: 6.0),
        mountThreshold: 5.0,
        currentSpeedKmh: 0,
        speedAfterKmh: 0,
        peakRotationDegS: 400,
        isStillAfterImpact: true,
      );
      expect(score, lessThan(0.7));
    });

    test('score clamps to 0-1 range', () {
      final score = calculateCrashScore(
        impact: makeImpact(peakG: 20.0),
        mountThreshold: 4.0,
        currentSpeedKmh: 80,
        speedAfterKmh: 0,
        peakRotationDegS: 1000,
        isStillAfterImpact: true,
      );
      expect(score, lessThanOrEqualTo(1.0));
      expect(score, greaterThanOrEqualTo(0.0));
    });

    test('moderate rotation gives 0.5 rotation score', () {
      final score = calculateCrashScore(
        impact: makeImpact(peakG: 6.0),
        mountThreshold: 5.0,
        currentSpeedKmh: 40,
        speedAfterKmh: 5,
        peakRotationDegS: 200,
        isStillAfterImpact: true,
      );
      final scoreHighRotation = calculateCrashScore(
        impact: makeImpact(peakG: 6.0),
        mountThreshold: 5.0,
        currentSpeedKmh: 40,
        speedAfterKmh: 5,
        peakRotationDegS: 400,
        isStillAfterImpact: true,
      );
      expect(scoreHighRotation, greaterThan(score));
    });
  });

  group('deriveSeverity', () {
    test('under 5g is low', () {
      expect(deriveSeverity(4.5), 'low');
    });

    test('5-8g is medium', () {
      expect(deriveSeverity(6.0), 'medium');
    });

    test('8-12g is high', () {
      expect(deriveSeverity(10.0), 'high');
    });

    test('over 12g is critical', () {
      expect(deriveSeverity(15.0), 'critical');
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd app && flutter test test/features/crash_detection/services/crash_detection_service_test.dart`
Expected: FAIL — cannot find `crash_detection_service.dart`

- [ ] **Step 3: Implement crash detection service**

```dart
import 'dart:math';

import '../models/impact_event.dart';

double getImpactThresholdForMount(String? mount) {
  return switch (mount) {
    'handlebar' => 4.0,
    'pocket' => 6.0,
    'bag' => 7.0,
    _ => 5.0,
  };
}

double getSensitivityThreshold(String? sensitivity) {
  return switch (sensitivity) {
    'high' => 0.45,
    'low' => 0.75,
    _ => 0.60,
  };
}

double calculateCrashScore({
  required ImpactEvent impact,
  required double mountThreshold,
  required double currentSpeedKmh,
  required double speedAfterKmh,
  required double peakRotationDegS,
  required bool isStillAfterImpact,
}) {
  final impactScore = min(
    1.0,
    (impact.peakG / mountThreshold - 1.0) * 0.5 + 0.5,
  );

  final double speedScore;
  if (currentSpeedKmh > 0) {
    final speedDrop =
        (currentSpeedKmh - speedAfterKmh) / currentSpeedKmh;
    speedScore = min(1.0, speedDrop / 0.5);
  } else {
    speedScore = 0.0;
  }

  final double rotationScore;
  if (peakRotationDegS > 300) {
    rotationScore = 1.0;
  } else if (peakRotationDegS > 150) {
    rotationScore = 0.5;
  } else {
    rotationScore = 0.0;
  }

  final stillnessScore = isStillAfterImpact ? 1.0 : 0.0;

  return impactScore * 0.4 +
      speedScore * 0.3 +
      rotationScore * 0.15 +
      stillnessScore * 0.15;
}

String deriveSeverity(double peakG) {
  if (peakG >= 12) return 'critical';
  if (peakG >= 8) return 'high';
  if (peakG >= 5) return 'medium';
  return 'low';
}
```

- [ ] **Step 4: Update services barrel**

```dart
export 'crash_detection_service.dart';
export 'crash_sensor_service.dart';
export 'ring_buffer.dart';
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd app && flutter test test/features/crash_detection/services/crash_detection_service_test.dart`
Expected: All 12 tests pass

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/crash_detection/services/ app/test/features/crash_detection/services/crash_detection_service_test.dart
git commit -m "feat(crash): add crash scoring algorithm + thresholds with tests"
```

---

### Task 5: Expand incident-receive Edge Function

**Files:**
- Modify: `backend/supabase/functions/incident-receive/index.ts:19` — accept `crash_detected` type
- Modify: `backend/supabase/functions/incident-receive/index.ts:119-126` — use packet type, add crash fields

**Interfaces:**
- Consumes: existing `IncidentPacket` interface
- Produces: expanded endpoint accepting `type: 'crash_detected'` — used by Task 7

- [ ] **Step 1: Expand IncidentPacket interface**

In `backend/supabase/functions/incident-receive/index.ts`, change the interface at line 5:

```typescript
interface IncidentPacket {
  type: string
  lat: number
  lng: number
  speed: number | null
  heading: number | null
  ts: number
  battery: number | null
  // Crash-specific (optional)
  confidence?: number
  severity?: string
  peak_g?: number
  sensor_window?: Record<string, unknown>
  phone_mount?: string
}
```

- [ ] **Step 2: Change type validation at line 19**

Replace:
```typescript
  if (p.type !== 'sos') return { valid: false, error: 'type must be sos' }
```

With:
```typescript
  const validTypes = ['sos', 'crash_detected']
  if (typeof p.type !== 'string' || !validTypes.includes(p.type)) {
    return { valid: false, error: `type must be one of: ${validTypes.join(', ')}` }
  }
```

- [ ] **Step 3: Add crash fields to validated packet (line 28-38)**

After the existing packet fields in the `return` statement, add the optional crash fields:

```typescript
  return {
    valid: true,
    packet: {
      type: p.type as string,
      lat: p.lat as number,
      lng: p.lng as number,
      speed: typeof p.speed === 'number' ? p.speed : null,
      heading: typeof p.heading === 'number' ? p.heading : null,
      ts: p.ts as number,
      battery: typeof p.battery === 'number' ? Math.min(100, Math.max(0, p.battery)) : null,
      confidence: typeof p.confidence === 'number' ? p.confidence : undefined,
      severity: typeof p.severity === 'string' ? p.severity : undefined,
      peak_g: typeof p.peak_g === 'number' ? p.peak_g : undefined,
      sensor_window: typeof p.sensor_window === 'object' ? p.sensor_window as Record<string, unknown> : undefined,
      phone_mount: typeof p.phone_mount === 'string' ? p.phone_mount : undefined,
    },
  }
```

- [ ] **Step 4: Use packet.type in INSERT (line 119-126)**

Replace the hardcoded insert:
```typescript
  const { data: incident, error: insertError } = await serviceClient
    .from('incidents')
    .insert({
      user_id: userId,
      type: 'sos',
      location: `POINT(${packet.lng} ${packet.lat})`,
      speed_at_event: packet.speed,
      status: 'dispatched',
      sensor_data: { heading: packet.heading, battery: packet.battery },
    })
```

With:
```typescript
  const sensorData: Record<string, unknown> = {
    heading: packet.heading,
    battery: packet.battery,
  }
  if (packet.sensor_window) {
    sensorData.sensor_window = packet.sensor_window
  }
  if (packet.peak_g !== undefined) {
    sensorData.peak_g = packet.peak_g
  }
  if (packet.phone_mount) {
    sensorData.phone_mount = packet.phone_mount
  }

  const { data: incident, error: insertError } = await serviceClient
    .from('incidents')
    .insert({
      user_id: userId,
      type: packet.type,
      location: `POINT(${packet.lng} ${packet.lat})`,
      speed_at_event: packet.speed,
      status: 'dispatched',
      confidence: packet.confidence ?? null,
      severity: packet.severity ?? null,
      sensor_data: sensorData,
    })
```

- [ ] **Step 5: Commit**

```bash
git add backend/supabase/functions/incident-receive/index.ts
git commit -m "feat(crash): expand incident-receive to accept crash_detected type"
```

---

### Task 6: Differentiate Alert Messages

**Files:**
- Modify: `backend/supabase/functions/_shared/channels.ts` — add incident_type to AlertPayload, differentiate messages
- Modify: `backend/supabase/functions/alert-cascade/index.ts:123` — pass incident type to buildAlertPayload
- Modify: `backend/supabase/functions/incident-receive/index.ts:184` — pass incident type to cascade invocation

**Interfaces:**
- Consumes: `AlertPayload` interface
- Produces: type-aware alert messages for crash vs SOS

- [ ] **Step 1: Add incident_type to AlertPayload in channels.ts**

Add to the `AlertPayload` interface (after `incident_id`):
```typescript
export interface AlertPayload {
  recipient_phone: string
  recipient_name: string
  victim_name: string
  victim_phone: string
  location: { lat: number; lng: number; address?: string }
  maps_link: string
  incident_id: string
  incident_type: string
}
```

- [ ] **Step 2: Update FcmChannel messages**

```typescript
export class FcmChannel implements AlertChannel {
  async send(payload: AlertPayload): Promise<ChannelResult> {
    const isCrash = payload.incident_type === 'crash_detected'
    const title = isCrash
      ? 'CRASH DETECTED - RoadPack'
      : 'EMERGENCY ALERT - RoadPack'
    const body = isCrash
      ? `${payload.victim_name} may have been in a crash. Impact detected.`
      : `${payload.victim_name} triggered an emergency SOS alert.`

    console.log('[FCM] Would send push:', JSON.stringify({
      title,
      body,
      data: {
        incident_id: payload.incident_id,
        lat: payload.location.lat,
        lng: payload.location.lng,
        victim_name: payload.victim_name,
        victim_phone: payload.victim_phone,
        incident_type: payload.incident_type,
      },
    }))
    return { success: true, provider_id: `fcm_mock_${Date.now()}` }
  }
}
```

- [ ] **Step 3: Update MockSmsChannel messages**

```typescript
export class MockSmsChannel implements AlertChannel {
  async send(payload: AlertPayload): Promise<ChannelResult> {
    const isCrash = payload.incident_type === 'crash_detected'
    const alertType = isCrash ? 'CRASH DETECTED' : 'SOS ALERT'
    const detail = isCrash
      ? `${payload.victim_name} may have crashed`
      : `${payload.victim_name} triggered SOS`
    const message = `ROADPACK ${alertType}: ${detail} at ${payload.location.lat},${payload.location.lng}. Map: ${payload.maps_link}. Call 112. Call ${payload.victim_name}: ${payload.victim_phone}. Reply OK.`
    console.log(`[MockSMS] To: ${payload.recipient_phone} | ${message}`)
    return { success: true, provider_id: `sms_mock_${Date.now()}` }
  }
}
```

- [ ] **Step 4: Update MockVoiceChannel messages**

```typescript
export class MockVoiceChannel implements AlertChannel {
  async send(payload: AlertPayload): Promise<ChannelResult> {
    const isCrash = payload.incident_type === 'crash_detected'
    const detail = isCrash
      ? `${payload.victim_name} may have been in a crash`
      : `${payload.victim_name} has triggered an emergency SOS alert`
    const script = `This is an emergency alert from RoadPack. ${detail} at ${payload.location.lat},${payload.location.lng}. Press 1 to acknowledge. Press 2 to call 112.`
    console.log(`[MockVoice] To: ${payload.recipient_phone} | ${script}`)
    return { success: true, provider_id: `voice_mock_${Date.now()}` }
  }
}
```

- [ ] **Step 5: Update buildAlertPayload to accept incident_type**

```typescript
export function buildAlertPayload(
  contact: { name: string; phone: string },
  userProfile: { name: string; phone: string },
  location: { lat: number; lng: number },
  incidentId: string,
  incidentType: string = 'sos',
): AlertPayload {
  return {
    recipient_phone: contact.phone,
    recipient_name: contact.name,
    victim_name: userProfile.name,
    victim_phone: userProfile.phone,
    location,
    maps_link: `https://maps.google.com/?q=${location.lat},${location.lng}`,
    incident_id: incidentId,
    incident_type: incidentType,
  }
}
```

- [ ] **Step 6: Update alert-cascade/index.ts to pass incident type**

In `alert-cascade/index.ts`, add `incident_type` to CascadeInput interface:
```typescript
interface CascadeInput {
  incident_id: string
  incident_type?: string
  contacts: Array<{...}>
  user_profile: { name: string; phone: string }
  location: { lat: number; lng: number }
}
```

Update the `buildAlertPayload` call at line 123:
```typescript
    const payload = buildAlertPayload(
      { name: contact.name, phone: contact.phone },
      user_profile,
      location,
      incident_id,
      incident_type ?? 'sos',
    )
```

- [ ] **Step 7: Update incident-receive to pass type to cascade invocation**

In `incident-receive/index.ts`, at the `EdgeRuntime.waitUntil` fetch body (line 184), add `incident_type`:
```typescript
      body: JSON.stringify({
        incident_id: incidentId,
        incident_type: packet.type,
        contacts,
        user_profile: profile ?? { name: 'Unknown', phone: '' },
        location: { lat: packet.lat, lng: packet.lng },
      }),
```

- [ ] **Step 8: Commit**

```bash
git add backend/supabase/functions/_shared/channels.ts backend/supabase/functions/alert-cascade/index.ts backend/supabase/functions/incident-receive/index.ts
git commit -m "feat(crash): differentiate crash vs SOS alert messages in cascade"
```

---

### Task 7: SosService.dispatchCrash

**Files:**
- Modify: `app/lib/features/sos/services/sos_service.dart` — add `dispatchCrash()` method

**Interfaces:**
- Consumes: `ImpactEvent` from Task 1, existing `SosService` class
- Produces: `SosService.dispatchCrash()` method — used by Task 8

- [ ] **Step 1: Add dispatchCrash method to SosService**

Add after `dispatchSos()` method (after line 107):

```dart
  Future<Incident> dispatchCrash({
    required double peakG,
    required double confidence,
    required double speedAtEvent,
    required Map<String, dynamic> sensorWindow,
    String? phoneMount,
  }) async {
    final position = await _captureLocation();
    final token = await _clerkService.getSupabaseToken();
    if (token == null) throw Exception('No auth token');

    final severity = _deriveSeverity(peakG);

    final packet = {
      'type': 'crash_detected',
      'lat': position?.latitude,
      'lng': position?.longitude,
      'speed': position?.speed ?? speedAtEvent,
      'heading': position?.heading,
      'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'battery': null,
      'confidence': confidence,
      'severity': severity,
      'peak_g': peakG,
      'sensor_window': sensorWindow,
      'phone_mount': phoneMount,
    };

    final url = Uri.parse(
      '${AppConstants.supabaseUrl}/functions/v1/incident-receive',
    );

    http.Response? response;
    Exception? lastError;

    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(packet),
        );
        if (response.statusCode == 201) break;
        lastError = Exception('HTTP ${response.statusCode}: ${response.body}');
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
      }

      if (attempt < 2) {
        await Future.delayed(const Duration(seconds: 5));
      }
    }

    if (response == null || response.statusCode != 201) {
      throw lastError ?? Exception('Failed to dispatch crash alert');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return Incident(
      id: body['incident_id'] as String,
      userId: '',
      type: IncidentType.crashDetected,
      status: IncidentStatus.values.firstWhere(
        (e) => e.value == body['status'],
      ),
      confidence: confidence,
      speedAtEvent: speedAtEvent,
      createdAt: DateTime.now(),
    );
  }

  static String _deriveSeverity(double peakG) {
    if (peakG >= 12) return 'critical';
    if (peakG >= 8) return 'high';
    if (peakG >= 5) return 'medium';
    return 'low';
  }
```

- [ ] **Step 2: Verify no analyze errors**

Run: `cd app && flutter analyze lib/features/sos/services/sos_service.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add app/lib/features/sos/services/sos_service.dart
git commit -m "feat(crash): add dispatchCrash method to SosService"
```

---

### Task 8: Crash Detection Provider + Tests

**Files:**
- Create: `app/lib/features/crash_detection/providers/crash_detection_provider.dart`
- Create: `app/lib/features/crash_detection/providers/providers.dart`
- Create: `app/test/features/crash_detection/providers/crash_detection_provider_test.dart`

**Interfaces:**
- Consumes: `CrashDetectionState`/`CrashDetectionStatus` from Task 1, `CrashSensorService` from Task 3, `CrashDetectionService` functions from Task 4, `SosService.dispatchCrash()` from Task 7
- Produces: `crashDetectionProvider` StateNotifierProvider — used by Tasks 9-11

- [ ] **Step 1: Implement CrashDetectionNotifier**

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../auth/services/clerk_service.dart';
import '../../sos/services/sos_service.dart';
import '../../tracking/services/tracking_service.dart';
import '../models/crash_state.dart';
import '../models/impact_event.dart';
import '../services/crash_detection_service.dart';
import '../services/crash_sensor_service.dart';

final crashSensorServiceProvider = Provider<CrashSensorService?>((ref) {
  final clerkService = ref.watch(clerkServiceProvider);
  if (!clerkService.isSignedIn) return null;

  // TODO: read phone_mount from user profile when available
  final threshold = getImpactThresholdForMount(null);
  final service = CrashSensorService(impactThresholdG: threshold);
  ref.onDispose(() => service.dispose());
  return service;
});

final crashDetectionProvider =
    StateNotifierProvider<CrashDetectionNotifier, CrashDetectionState>(
  (ref) => CrashDetectionNotifier(ref),
);

class CrashDetectionNotifier extends StateNotifier<CrashDetectionState> {
  CrashDetectionNotifier(this._ref) : super(const CrashDetectionState());

  final Ref _ref;
  Timer? _countdownTimer;
  StreamSubscription<ImpactEvent>? _impactSub;
  DateTime? _lastDetectionTime;

  static const _cooldownDuration = Duration(seconds: 60);

  CrashSensorService? get _sensorService =>
      _ref.read(crashSensorServiceProvider);
  SosService? get _sosService => _ref.read(sosServiceProvider);
  TrackingService? get _trackingService =>
      _ref.read(trackingServiceProvider);

  void startMonitoring() {
    if (state.status == CrashDetectionStatus.monitoring) return;

    final sensor = _sensorService;
    if (sensor == null) return;

    _impactSub?.cancel();
    _impactSub = sensor.impactStream.listen(_onImpact);
    sensor.start();

    state = state.copyWith(status: CrashDetectionStatus.monitoring);
    debugPrint('[CrashDetection] Monitoring started');
  }

  void stopMonitoring() {
    if (state.status == CrashDetectionStatus.disabled) return;
    if (state.status == CrashDetectionStatus.countdown ||
        state.status == CrashDetectionStatus.dispatching ||
        state.status == CrashDetectionStatus.active) {
      return;
    }

    _impactSub?.cancel();
    _impactSub = null;
    _sensorService?.stop();

    state = const CrashDetectionState();
    debugPrint('[CrashDetection] Monitoring stopped');
  }

  void _onImpact(ImpactEvent impact) {
    if (state.status != CrashDetectionStatus.monitoring) return;

    if (_lastDetectionTime != null &&
        DateTime.now().difference(_lastDetectionTime!) < _cooldownDuration) {
      debugPrint('[CrashDetection] In cooldown, ignoring impact');
      return;
    }

    final sensitivity = getSensitivityThreshold(null);
    final mountThreshold = getImpactThresholdForMount(null);

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

  void _startCountdown(ImpactEvent impact) {
    _lastDetectionTime = DateTime.now();
    _trackingService?.setSOSMode(true);

    state = state.copyWith(
      status: CrashDetectionStatus.countdown,
      countdownRemaining: AppConstants.crashCountdownDuration.inSeconds,
      impactEvent: impact,
    );

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  void _tick(Timer timer) {
    final remaining = state.countdownRemaining - 1;
    if (remaining <= 0) {
      timer.cancel();
      _countdownTimer = null;
      _dispatch();
    } else {
      state = state.copyWith(countdownRemaining: remaining);
    }
  }

  void cancel(String reason) {
    if (!state.canCancel) return;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _trackingService?.setSOSMode(false);

    state = state.copyWith(
      status: CrashDetectionStatus.cancelled,
      cancelledReason: reason,
    );

    debugPrint('[CrashDetection] Cancelled: $reason');

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        state = state.copyWith(
          status: CrashDetectionStatus.monitoring,
          cancelledReason: null,
          impactEvent: null,
        );
        _sensorService?.start();
      }
    });
  }

  Future<void> _dispatch() async {
    state = state.copyWith(status: CrashDetectionStatus.dispatching);
    final impact = state.impactEvent;
    if (impact == null) return;

    try {
      final service = _sosService;
      if (service == null) {
        state = state.copyWith(
          status: CrashDetectionStatus.monitoring,
          errorMessage: 'Not signed in',
        );
        return;
      }

      final sensorWindow = {
        'accel_samples': impact.accelWindow.length,
        'gyro_samples': impact.gyroWindow.length,
        'peak_g': impact.peakG,
        'peak_rotation_deg_s': impact.peakRotationDegS,
      };

      final incident = await service.dispatchCrash(
        peakG: impact.peakG,
        confidence: calculateCrashScore(
          impact: impact,
          mountThreshold: getImpactThresholdForMount(null),
          currentSpeedKmh: impact.speedBeforeKmh,
          speedAfterKmh: _sensorService?.lastSpeedKmh ?? 0,
          peakRotationDegS: impact.peakRotationDegS,
          isStillAfterImpact: (_sensorService?.lastSpeedKmh ?? 0) < 5,
        ),
        speedAtEvent: impact.speedBeforeKmh,
        sensorWindow: sensorWindow,
      );

      state = state.copyWith(
        status: CrashDetectionStatus.active,
        activeIncident: incident,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        status: CrashDetectionStatus.monitoring,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> resolve() async {
    final incident = state.activeIncident;
    if (incident == null) return;
    try {
      await _sosService?.resolveIncident(incident.id);
      state = state.copyWith(status: CrashDetectionStatus.resolved);
      _trackingService?.setSOSMode(false);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  void reset() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _trackingService?.setSOSMode(false);
    state = state.copyWith(
      status: CrashDetectionStatus.monitoring,
      impactEvent: null,
      activeIncident: null,
      cancelledReason: null,
      errorMessage: null,
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _impactSub?.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 2: Create providers barrel**

```dart
// providers.dart
export 'crash_detection_provider.dart';
```

- [ ] **Step 3: Write provider tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/crash_detection/models/crash_state.dart';
import 'package:roadpack/features/crash_detection/providers/crash_detection_provider.dart';

// Minimal validation: the notifier instantiates and has correct defaults
void main() {
  group('CrashDetectionState', () {
    test('default state is disabled', () {
      const state = CrashDetectionState();
      expect(state.status, CrashDetectionStatus.disabled);
      expect(state.countdownRemaining, 30);
      expect(state.impactEvent, isNull);
      expect(state.activeIncident, isNull);
    });

    test('isMonitoring returns true when monitoring', () {
      const state = CrashDetectionState(
        status: CrashDetectionStatus.monitoring,
      );
      expect(state.isMonitoring, true);
    });

    test('canCancel returns true during countdown', () {
      const state = CrashDetectionState(
        status: CrashDetectionStatus.countdown,
      );
      expect(state.canCancel, true);
    });

    test('canCancel returns false when active', () {
      const state = CrashDetectionState(
        status: CrashDetectionStatus.active,
      );
      expect(state.canCancel, false);
    });
  });
}
```

- [ ] **Step 4: Run tests**

Run: `cd app && flutter test test/features/crash_detection/providers/crash_detection_provider_test.dart`
Expected: All 4 tests pass

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/crash_detection/providers/ app/test/features/crash_detection/providers/
git commit -m "feat(crash): add CrashDetectionNotifier with countdown + dispatch"
```

---

### Task 9: Crash Countdown Screen

**Files:**
- Create: `app/lib/features/crash_detection/screens/crash_countdown_screen.dart`
- Create: `app/lib/features/crash_detection/screens/screens.dart`

**Interfaces:**
- Consumes: `crashDetectionProvider` from Task 8
- Produces: `CrashCountdownScreen` widget — used by Task 11

- [ ] **Step 1: Implement CrashCountdownScreen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/crash_state.dart';
import '../providers/crash_detection_provider.dart';
import '../widgets/crash_reason_picker.dart';

class CrashCountdownScreen extends ConsumerWidget {
  const CrashCountdownScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(crashDetectionProvider);

    return Material(
      color: Colors.black.withValues(alpha: 0.95),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'CRASH DETECTED',
              style: TextStyle(
                color: Colors.red,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Alerting your emergency contacts in '
              '${state.countdownRemaining} seconds',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            Text(
              '${state.countdownRemaining}',
              style: const TextStyle(
                color: Colors.red,
                fontSize: 120,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 240,
              height: 64,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  HapticFeedback.heavyImpact();
                  showModalBottomSheet<String>(
                    context: context,
                    isDismissible: false,
                    builder: (_) => const CrashReasonPicker(),
                  ).then((reason) {
                    if (reason != null) {
                      ref
                          .read(crashDetectionProvider.notifier)
                          .cancel(reason);
                    }
                  });
                },
                child: const Text("I'M OKAY"),
              ),
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                state.errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Create screens barrel**

```dart
// screens.dart
export 'crash_countdown_screen.dart';
```

- [ ] **Step 3: Verify no analyze errors**

Run: `cd app && flutter analyze lib/features/crash_detection/screens/`
Expected: No issues (CrashReasonPicker is created in Task 10 — if this fails, create a stub first, or create Task 10 before this step)

Note: This step depends on CrashReasonPicker from Task 10. If building in order, create both files in sequence before running analyze.

- [ ] **Step 4: Commit** (combine with Task 10)

---

### Task 10: Crash Reason Picker + Active Screen

**Files:**
- Create: `app/lib/features/crash_detection/widgets/crash_reason_picker.dart`
- Create: `app/lib/features/crash_detection/widgets/crash_overlay.dart`
- Create: `app/lib/features/crash_detection/widgets/widgets.dart`

**Interfaces:**
- Consumes: `crashDetectionProvider` from Task 8
- Produces: `CrashReasonPicker` widget — used by Task 9
- Produces: `CrashOverlay` widget — used by Task 11

- [ ] **Step 1: Implement CrashReasonPicker**

```dart
import 'package:flutter/material.dart';

class CrashReasonPicker extends StatefulWidget {
  const CrashReasonPicker({super.key});

  @override
  State<CrashReasonPicker> createState() => _CrashReasonPickerState();
}

class _CrashReasonPickerState extends State<CrashReasonPicker> {
  String? _selectedReason;
  final _otherController = TextEditingController();

  static const _reasons = [
    'Pothole / speed bump',
    'Phone dropped',
    'Sudden braking',
  ];

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What happened?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ..._reasons.map(
            (reason) => RadioListTile<String>(
              title: Text(reason),
              value: reason,
              groupValue: _selectedReason,
              onChanged: (v) => setState(() => _selectedReason = v),
            ),
          ),
          RadioListTile<String>(
            title: const Text('Other'),
            value: 'other',
            groupValue: _selectedReason,
            onChanged: (v) => setState(() => _selectedReason = v),
          ),
          if (_selectedReason == 'other')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _otherController,
                decoration: const InputDecoration(
                  hintText: 'Describe what happened',
                ),
                maxLines: 2,
              ),
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _selectedReason != null
                  ? () {
                      final reason = _selectedReason == 'other'
                          ? _otherController.text.isNotEmpty
                              ? _otherController.text
                              : 'Other'
                          : _selectedReason!;
                      Navigator.of(context).pop(reason);
                    }
                  : null,
              child: const Text("Confirm - I'm Fine"),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Implement CrashOverlay**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/clerk_auth_provider.dart';
import '../models/crash_state.dart';
import '../providers/crash_detection_provider.dart';
import '../screens/crash_countdown_screen.dart';

class CrashOverlay extends ConsumerWidget {
  const CrashOverlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(clerkAuthProvider).valueOrNull;
    final crashState = ref.watch(crashDetectionProvider);

    final isAuthenticated = authState?.isAuthenticated ?? false;

    return Stack(
      children: [
        child,
        if (isAuthenticated) ...[
          if (crashState.status == CrashDetectionStatus.countdown ||
              crashState.status == CrashDetectionStatus.dispatching)
            const CrashCountdownScreen(),
          if (crashState.status == CrashDetectionStatus.active ||
              crashState.status == CrashDetectionStatus.resolved)
            _CrashActiveScreen(),
        ],
      ],
    );
  }
}

class _CrashActiveScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(crashDetectionProvider);
    final isResolved = state.status == CrashDetectionStatus.resolved;

    return Material(
      color: Colors.black.withValues(alpha: 0.95),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isResolved ? Icons.check_circle : Icons.car_crash,
                color: isResolved ? Colors.green : Colors.orange,
                size: 80,
              ),
              const SizedBox(height: 24),
              Text(
                isResolved ? 'Incident Resolved' : 'CRASH ALERT SENT',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isResolved
                    ? 'Your contacts have been notified that you are safe.'
                    : 'Your emergency contacts have been notified of a possible crash.',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              if (state.activeIncident != null) ...[
                const SizedBox(height: 24),
                Text(
                  'Incident: ${state.activeIncident!.id.substring(0, 8)}...',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
              const SizedBox(height: 48),
              if (!isResolved)
                SizedBox(
                  width: 200,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      ref.read(crashDetectionProvider.notifier).resolve();
                    },
                    child: const Text("I'M OKAY"),
                  ),
                ),
              if (isResolved)
                SizedBox(
                  width: 200,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () {
                      ref.read(crashDetectionProvider.notifier).reset();
                    },
                    child: const Text('CLOSE'),
                  ),
                ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  state.errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Create widgets barrel**

```dart
// widgets.dart
export 'crash_overlay.dart';
export 'crash_reason_picker.dart';
```

- [ ] **Step 4: Verify no analyze errors for crash_detection feature**

Run: `cd app && flutter analyze lib/features/crash_detection/`
Expected: No issues found

- [ ] **Step 5: Commit (combined with Task 9)**

```bash
git add app/lib/features/crash_detection/screens/ app/lib/features/crash_detection/widgets/
git commit -m "feat(crash): add crash countdown screen, reason picker, and overlay"
```

---

### Task 11: Wire CrashOverlay into App + Top-Level Barrel

**Files:**
- Modify: `app/lib/app.dart:28` — wrap with CrashOverlay
- Create: `app/lib/features/crash_detection/crash_detection.dart` — top-level barrel

**Interfaces:**
- Consumes: `CrashOverlay` from Task 10
- Produces: Crash detection UI visible in app during crash events

- [ ] **Step 1: Create top-level barrel**

```dart
// crash_detection.dart
export 'models/models.dart';
export 'providers/providers.dart';
export 'screens/screens.dart';
export 'services/services.dart';
export 'widgets/widgets.dart';
```

- [ ] **Step 2: Wire CrashOverlay into app.dart**

In `app/lib/app.dart`, add import:
```dart
import 'features/crash_detection/widgets/crash_overlay.dart';
```

Change line 28 from:
```dart
          SosOverlay(child: child ?? const SizedBox.shrink()),
```
To:
```dart
          CrashOverlay(
            child: SosOverlay(child: child ?? const SizedBox.shrink()),
          ),
```

CrashOverlay wraps SosOverlay so crash detection renders on top. If user manually triggers SOS during a crash, SOS overlay appears below crash overlay — both can be active simultaneously.

- [ ] **Step 3: Verify no analyze errors**

Run: `cd app && flutter analyze lib/app.dart`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add app/lib/features/crash_detection/crash_detection.dart app/lib/app.dart
git commit -m "feat(crash): wire CrashOverlay into app, add top-level barrel"
```

---

### Task 12: Wire TrackingService Activity Change

**Files:**
- Modify: `app/lib/features/tracking/services/tracking_service.dart:139-141` — wire _onActivityChange to crash detection

**Interfaces:**
- Consumes: `crashDetectionProvider` from Task 8, `CrashSensorService` from Task 3
- Produces: Activity-gated crash detection start/stop

- [ ] **Step 1: Add crash detection wiring to TrackingService**

In `tracking_service.dart`, add imports:
```dart
import '../../crash_detection/providers/crash_detection_provider.dart';
```

Modify the `TrackingService` constructor to accept a callback:
```dart
class TrackingService {
  TrackingService({
    required TrackingDatabase db,
    required ClerkService clerkService,
    this.onActivityChanged,
  })  : _clerkService = clerkService,
        _tripDetector = TripDetector(db),
        _routeLearner = RouteLearner(db);

  final void Function(String activity, int confidence)? onActivityChanged;
```

Update `_onActivityChange` (line 139):
```dart
  void _onActivityChange(bg.ActivityChangeEvent event) {
    debugPrint('[Tracking] Activity: ${event.activity} (${event.confidence}%)');
    onActivityChanged?.call(event.activity, event.confidence);
  }
```

- [ ] **Step 2: Update trackingServiceProvider to wire activity callback**

In `tracking_service.dart`, update the provider (line 21):
```dart
final trackingServiceProvider = Provider<TrackingService?>((ref) {
  final clerkService = ref.watch(clerkServiceProvider);
  if (!clerkService.isSignedIn) return null;

  final db = ref.watch(trackingDatabaseProvider);
  final crashNotifier = ref.read(crashDetectionProvider.notifier);
  final crashSensor = ref.read(crashSensorServiceProvider);

  final service = TrackingService(
    db: db,
    clerkService: clerkService,
    onActivityChanged: (activity, confidence) {
      final isInVehicle = activity == 'in_vehicle' || activity == 'on_bicycle';
      if (isInVehicle && confidence >= 50) {
        crashNotifier.startMonitoring();
      } else {
        crashNotifier.stopMonitoring();
      }
    },
  );
  ref.onDispose(() => service.dispose());
  return service;
});
```

- [ ] **Step 3: Wire speed updates to CrashSensorService**

In `_onLocation` (line 119), add speed forwarding. Update the method:
```dart
  void _onLocation(bg.Location location) {
    final point = LocationPoint(
      latitude: location.coords.latitude,
      longitude: location.coords.longitude,
      speed: location.coords.speed.toDouble(),
      timestamp: DateTime.parse(location.timestamp),
    );
    _tripDetector.onLocationUpdate(point);
    _onSpeedUpdate?.call(point.speed * 3.6); // m/s to km/h
  }
```

Add the callback field:
```dart
  final void Function(double speedKmh)? _onSpeedUpdate;
```

Actually, simpler approach: pass the crash sensor service directly and call updateSpeed:

Update provider:
```dart
final trackingServiceProvider = Provider<TrackingService?>((ref) {
  final clerkService = ref.watch(clerkServiceProvider);
  if (!clerkService.isSignedIn) return null;

  final db = ref.watch(trackingDatabaseProvider);
  final crashNotifier = ref.read(crashDetectionProvider.notifier);
  final crashSensor = ref.read(crashSensorServiceProvider);

  final service = TrackingService(
    db: db,
    clerkService: clerkService,
    onActivityChanged: (activity, confidence) {
      final isInVehicle = activity == 'in_vehicle' || activity == 'on_bicycle';
      if (isInVehicle && confidence >= 50) {
        crashNotifier.startMonitoring();
      } else {
        crashNotifier.stopMonitoring();
      }
    },
    onSpeedUpdate: (speedKmh) {
      crashSensor?.updateSpeed(speedKmh);
    },
  );
  ref.onDispose(() => service.dispose());
  return service;
});
```

Update constructor:
```dart
class TrackingService {
  TrackingService({
    required TrackingDatabase db,
    required ClerkService clerkService,
    this.onActivityChanged,
    this.onSpeedUpdate,
  })  : _clerkService = clerkService,
        _tripDetector = TripDetector(db),
        _routeLearner = RouteLearner(db);

  final void Function(String activity, int confidence)? onActivityChanged;
  final void Function(double speedKmh)? onSpeedUpdate;
```

Update `_onLocation`:
```dart
  void _onLocation(bg.Location location) {
    final point = LocationPoint(
      latitude: location.coords.latitude,
      longitude: location.coords.longitude,
      speed: location.coords.speed.toDouble(),
      timestamp: DateTime.parse(location.timestamp),
    );
    _tripDetector.onLocationUpdate(point);
    onSpeedUpdate?.call(point.speed * 3.6);
  }
```

- [ ] **Step 4: Verify no analyze errors**

Run: `cd app && flutter analyze lib/features/tracking/services/tracking_service.dart`
Expected: No issues found

- [ ] **Step 5: Run full test suite**

Run: `cd app && flutter test`
Expected: All tests pass (tracking tests should still pass — callbacks are optional)

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/tracking/services/tracking_service.dart
git commit -m "feat(crash): wire activity + speed changes from tracking to crash detection"
```

---

### Task 13: Final Integration Test + Cleanup

**Files:**
- Verify: all tests pass
- Verify: all analyze checks pass
- Remove: unused SosActiveScreen import in crash_overlay.dart (if present)

- [ ] **Step 1: Run full analyze**

Run: `cd app && flutter analyze`
Expected: No issues found

- [ ] **Step 2: Run full test suite**

Run: `cd app && flutter test`
Expected: All tests pass

- [ ] **Step 3: Fix any issues found**

Address any remaining lint warnings or test failures.

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat(crash): L2 crash detection complete - sensor engine, detection algorithm, countdown UI, server integration"
```
