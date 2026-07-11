import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/app_constants.dart';
import '../../auth/services/clerk_service.dart';

final alertServiceProvider = Provider<AlertService?>((ref) {
  final clerkService = ref.read(clerkServiceProvider);
  if (!clerkService.isSignedIn) return null;
  return AlertService(clerkService);
});

class AlertService {
  AlertService(this._clerkService);

  final ClerkService _clerkService;

  Future<void> acknowledgeIncident(String incidentId) async {
    final token = await _clerkService.getSupabaseToken();
    if (token == null) throw Exception('No auth token');

    final url = Uri.parse(
      '${AppConstants.supabaseUrl}/functions/v1/acknowledge-incident',
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
      throw Exception('Failed to acknowledge: ${response.body}');
    }
  }
}
