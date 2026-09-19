import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../auth/services/clerk_service.dart';
import '../../consent/models/tracking_gate.dart';
import '../../consent/providers/tracking_gate_provider.dart';
import '../../crash_detection/providers/crash_detection_provider.dart';
import '../db/tracking_database.dart';
import '../models/tracking_state.dart';
import 'route_learner.dart';
import 'trip_detector.dart';

final trackingDatabaseProvider = Provider<TrackingDatabase>((ref) {
  throw UnimplementedError(
    'trackingDatabaseProvider must be overridden at app startup',
  );
});

final trackingServiceProvider = Provider<TrackingService?>((ref) {
  final clerkService = ref.watch(clerkServiceProvider);
  if (!clerkService.isSignedIn) return null;

  final db = ref.watch(trackingDatabaseProvider);
  final crashNotifier = ref.read(crashDetectionProvider.notifier);
  final crashSensor = ref.read(crashSensorServiceProvider);

  final service = TrackingService(
    db: db,
    clerkService: clerkService,
    // FR-003/FR-004: the one gate. Read (not captured) so the answer is
    // current at the moment `start()` runs, not at the moment the service
    // was constructed.
    gate: () => ref.read(trackingGateProvider),
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
  // A consent withdrawn mid-ride has to stop collection, not merely block
  // the next start. FR-003's acceptance criterion allows 24 hours; there is
  // no reason to use them.
  ref.listen<bool>(mayStartTrackingProvider, (_, mayStart) {
    if (!mayStart) unawaited(service.stop());
  }, fireImmediately: false);

  ref.onDispose(() => service.dispose());
  return service;
});

class TrackingService {
  TrackingService({
    required TrackingDatabase db,
    required ClerkService clerkService,
    required TrackingGate Function() gate,
    this.onActivityChanged,
    this.onSpeedUpdate,
  }) : _gate = gate,
       _clerkService = clerkService,
       _tripDetector = TripDetector(db),
       _routeLearner = RouteLearner(db);

  final ClerkService _clerkService;

  /// FR-004's single gate. Consulted inside [start] rather than by callers,
  /// so a new call site cannot forget it.
  final TrackingGate Function() _gate;
  final TripDetector _tripDetector;
  final RouteLearner _routeLearner;
  final void Function(String activity, int confidence)? onActivityChanged;
  final void Function(double speedKmh)? onSpeedUpdate;
  StreamSubscription<Trip>? _tripCompletedSub;
  bool _started = false;

  TripState get currentTripState => _tripDetector.currentState;
  Stream<TripState> get tripStateStream => _tripDetector.stateStream;
  TripDetector get tripDetector => _tripDetector;

  /// Starts background location collection, or refuses.
  ///
  /// The gate check lives here, not at the call sites: FR-004 exists because
  /// several places each deciding for themselves is how a minor ends up
  /// tracked. Returns false when it refused, so a caller that wants to show
  /// the user why can ask the gate itself.
  Future<bool> start() async {
    final gate = _gate();
    if (!gate.mayStart) {
      debugPrint(
        '[Tracking] refused to start: ${gate.blockers.map((b) => b.name)}',
      );
      return false;
    }

    if (_started) return true;
    _started = true;

    _tripCompletedSub = _tripDetector.tripCompletedStream.listen((trip) async {
      final result = await _routeLearner.processCompletedTrip(trip);
      if (result.promoted) {
        debugPrint('[Tracking] Route promoted: ${result.routeId}');
      }
    });

    final token = await _clerkService.getSupabaseToken();

    await bg.BackgroundGeolocation.ready(
      bg.Config(
        desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
        distanceFilter: 10,
        stopOnTerminate: false,
        startOnBoot: true,
        foregroundService: true,
        notification: bg.Notification(
          title: 'RoadPack',
          text: 'Keeping you safe',
        ),
        url: '${AppConstants.supabaseUrl}/functions/v1/location-ingest',
        autoSync: true,
        batchSync: true,
        maxBatchSize: 50,
        headers: {'Authorization': 'Bearer ${token ?? ''}'},
        heartbeatInterval: 900, // 15 min
        activityRecognitionInterval: 10000,
        geofenceProximityRadius: 1000,
      ),
    );

    bg.BackgroundGeolocation.onLocation(_onLocation);
    bg.BackgroundGeolocation.onGeofence(_onGeofence);
    bg.BackgroundGeolocation.onActivityChange(_onActivityChange);
    bg.BackgroundGeolocation.onHeartbeat(_onHeartbeat);

    await bg.BackgroundGeolocation.start();
    return true;
  }

  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    await bg.BackgroundGeolocation.stop();
  }

  Future<void> setSOSMode(bool active) async {
    if (active) {
      await bg.BackgroundGeolocation.setConfig(
        bg.Config(
          desiredAccuracy: bg.Config.DESIRED_ACCURACY_NAVIGATION,
          distanceFilter: 1,
          locationUpdateInterval: 1000,
        ),
      );
    } else {
      await bg.BackgroundGeolocation.setConfig(
        bg.Config(
          desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
          distanceFilter: 10,
        ),
      );
    }
  }

  Future<void> updateAuthToken(String token) async {
    await bg.BackgroundGeolocation.setConfig(
      bg.Config(headers: {'Authorization': 'Bearer $token'}),
    );
  }

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

  void _onGeofence(bg.GeofenceEvent event) {
    if (event.action == 'EXIT') {
      _tripDetector.onGeofenceEvent(
        GeofenceExitEvent(
          identifier: event.identifier,
          timestamp: DateTime.parse(event.location.timestamp),
          latitude: event.location.coords.latitude,
          longitude: event.location.coords.longitude,
        ),
      );
    }
  }

  void _onActivityChange(bg.ActivityChangeEvent event) {
    debugPrint('[Tracking] Activity: ${event.activity} (${event.confidence}%)');
    onActivityChanged?.call(event.activity, event.confidence);
  }

  void _onHeartbeat(bg.HeartbeatEvent event) {
    debugPrint('[Tracking] Heartbeat at ${event.location?.timestamp}');
  }

  void dispose() {
    _tripCompletedSub?.cancel();
    _tripDetector.dispose();
  }
}
