import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/tracking_database.dart';
import '../models/tracking_state.dart';

class LocationPoint {
  const LocationPoint({
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.timestamp,
  });
  final double latitude;
  final double longitude;
  final double speed; // m/s
  final DateTime timestamp;
}

class GeofenceExitEvent {
  const GeofenceExitEvent({
    required this.identifier,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
  });
  final String identifier;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
}

class TripDetector {
  TripDetector(this._db);

  final TrackingDatabase _db;
  final _stateController = StreamController<TripState>.broadcast();
  final _tripCompletedController = StreamController<Trip>.broadcast();

  TripState _currentState = TripState.idle;
  String? _activeTripId;
  Trip? _activeTrip;

  DateTime? _motionStartTime;
  DateTime? _stopStartTime;
  final List<LocationPoint> _locationBuffer = [];
  double _totalDistance = 0;

  TripState get currentState => _currentState;
  Trip? get activeTrip => _activeTrip;
  Stream<TripState> get stateStream => _stateController.stream;
  Stream<Trip> get tripCompletedStream => _tripCompletedController.stream;

  static const _minTripDistanceM = 500.0;
  static const _motionThresholdSec = 60;
  static const _speedThresholdMs = 1.39; // ~5 km/h
  static const _stopThresholdMs = 0.56; // ~2 km/h
  static const _stopDurationSec = 180; // 3 min

  void onLocationUpdate(LocationPoint loc) {
    switch (_currentState) {
      case TripState.idle:
        _handleIdleLocation(loc);
      case TripState.recording:
        _handleRecordingLocation(loc);
      case TripState.completed:
      case TripState.discarded:
        break;
    }
  }

  void onGeofenceEvent(GeofenceExitEvent event) {
    if (_currentState == TripState.idle) {
      _startTrip(event.latitude, event.longitude, event.timestamp);
    }
  }

  void _handleIdleLocation(LocationPoint loc) {
    if (loc.speed >= _speedThresholdMs) {
      _motionStartTime ??= loc.timestamp;
      final motionDuration =
          loc.timestamp.difference(_motionStartTime!).inSeconds;
      if (motionDuration >= _motionThresholdSec) {
        _startTrip(loc.latitude, loc.longitude, _motionStartTime!);
        _handleRecordingLocation(loc);
      }
    } else {
      _motionStartTime = null;
    }
  }

  void _handleRecordingLocation(LocationPoint loc) {
    if (_locationBuffer.isNotEmpty) {
      _totalDistance += _distanceBetween(
        _locationBuffer.last.latitude,
        _locationBuffer.last.longitude,
        loc.latitude,
        loc.longitude,
      );
    }
    _locationBuffer.add(loc);

    if (loc.speed <= _stopThresholdMs) {
      _stopStartTime ??= loc.timestamp;
      final stopDuration =
          loc.timestamp.difference(_stopStartTime!).inSeconds;
      if (stopDuration >= _stopDurationSec) {
        _endTrip();
      }
    } else {
      _stopStartTime = null;
    }
  }

  Future<void> _startTrip(double lat, double lng, DateTime startTime) async {
    _activeTripId = const Uuid().v4();
    _totalDistance = 0;
    _locationBuffer.clear();
    _stopStartTime = null;
    _motionStartTime = null;

    await _db.insertTrip(TripsCompanion.insert(
      id: _activeTripId!,
      startTime: startTime,
      originLat: lat,
      originLng: lng,
      state: 'recording',
    ));

    _activeTrip = await _db.getRecordingTrip();
    _setState(TripState.recording);
  }

  Future<void> _endTrip() async {
    if (_activeTripId == null || _locationBuffer.isEmpty) {
      _reset();
      return;
    }

    final lastLoc = _locationBuffer.last;

    if (_totalDistance < _minTripDistanceM) {
      await _db.updateTrip(TripsCompanion(
        id: Value(_activeTripId!),
        startTime: Value(_locationBuffer.first.timestamp),
        originLat: Value(_locationBuffer.first.latitude),
        originLng: Value(_locationBuffer.first.longitude),
        state: const Value('discarded'),
      ));
      _reset();
      return;
    }

    await _db.updateTrip(TripsCompanion(
      id: Value(_activeTripId!),
      startTime: Value(_locationBuffer.first.timestamp),
      originLat: Value(_locationBuffer.first.latitude),
      originLng: Value(_locationBuffer.first.longitude),
      endTime: Value(lastLoc.timestamp),
      destLat: Value(lastLoc.latitude),
      destLng: Value(lastLoc.longitude),
      distanceMeters: Value(_totalDistance),
      state: const Value('completed'),
    ));

    final completedTrips = await _db.getCompletedTrips();
    if (completedTrips.isNotEmpty) {
      _tripCompletedController.add(completedTrips.first);
    }
    _reset();
  }

  void _reset() {
    _activeTripId = null;
    _activeTrip = null;
    _locationBuffer.clear();
    _totalDistance = 0;
    _stopStartTime = null;
    _motionStartTime = null;
    _setState(TripState.idle);
  }

  void _setState(TripState state) {
    _currentState = state;
    _stateController.add(state);
  }

  void dispose() {
    _stateController.close();
    _tripCompletedController.close();
  }

  static double _distanceBetween(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degrees) => degrees * pi / 180;
}
