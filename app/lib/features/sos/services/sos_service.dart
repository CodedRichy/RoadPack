import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/app_constants.dart';
import '../../auth/services/clerk_service.dart';
import '../models/event_types.dart';
import '../models/incident.dart';

final sosServiceProvider = Provider<SosService?>((ref) {
  final clerkService = ref.read(clerkServiceProvider);
  if (!clerkService.isSignedIn) return null;
  return SosService(clerkService);
});

class SosService {
  SosService(this._clerkService);

  final ClerkService _clerkService;

  Future<Position?> _captureLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint('Location capture failed: $e');
      return null;
    }
  }

  Future<Incident> dispatchSos() async {
    final position = await _captureLocation();

    final token = await _clerkService.getSupabaseToken();
    if (token == null) throw Exception('No auth token');

    final packet = {
      'type': 'sos',
      'lat': position?.latitude ?? 0.0,
      'lng': position?.longitude ?? 0.0,
      'speed': position?.speed,
      'heading': position?.heading,
      'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'battery': null,
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
      throw lastError ?? Exception('Failed to dispatch SOS');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return Incident(
      id: body['incident_id'] as String,
      userId: '',
      type: IncidentType.sos,
      status: IncidentStatus.values.firstWhere(
        (e) => e.value == body['status'],
      ),
      createdAt: DateTime.now(),
    );
  }

  Future<void> resolveIncident(String incidentId) async {
    final token = await _clerkService.getSupabaseToken();
    if (token == null) throw Exception('No auth token');

    final url = Uri.parse(
      '${AppConstants.supabaseUrl}/functions/v1/resolve-incident',
    );

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'incident_id': incidentId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to resolve: ${response.body}');
    }
  }
}
