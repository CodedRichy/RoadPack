import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/app_constants.dart';
import '../../auth/services/clerk_service.dart';
import '../models/commute_watch.dart';

/// Supplies the Clerk-templated Supabase JWT. Injected rather than reached for
/// so the service can be tested without a Clerk session.
typedef CommuteTokenProvider = Future<String?> Function();

/// A failed call to the commute backend.
class CommuteServiceException implements Exception {
  const CommuteServiceException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  /// The incident was already cancelled or resolved server-side (409).
  ///
  /// Not an error the rider should see as a failure: it usually means they
  /// answered the same check-in twice, or arrived while the sheet was open.
  bool get alreadyClosed => statusCode == 409;

  @override
  String toString() => 'CommuteServiceException($statusCode): $message';
}

/// The client half of the non-arrival flow.
///
/// It calls exactly one edge function — `check-in-response` — because that is
/// the only endpoint a rider's answer is allowed to reach. Escalation is the
/// server's job (`non-arrival-check` queues `cascade_jobs`); nothing here can
/// start, delay or fail the cascade.
class CommuteService {
  CommuteService(this._token, {http.Client? client})
    : _client = client ?? http.Client();

  final CommuteTokenProvider _token;
  final http.Client _client;

  /// Answers a pending non-arrival check-in.
  ///
  /// * [CheckInResponse.fine] cancels the incident.
  /// * [CheckInResponse.runningLate] cancels it with `user_running_late` and
  ///   notifies nobody — see FR-044.
  /// * [CheckInResponse.needHelp] dispatches the cascade.
  Future<void> respondToCheckIn({
    required String incidentId,
    required CheckInResponse response,
  }) async {
    final token = await _token();
    if (token == null) {
      throw const CommuteServiceException('No auth token');
    }

    final url = Uri.parse(
      '${AppConstants.supabaseUrl}/functions/v1/check-in-response',
    );

    late final http.Response result;
    try {
      result = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'incident_id': incidentId,
          'response': response.wire,
        }),
      );
    } catch (e) {
      throw CommuteServiceException('Check-in response failed: $e');
    }

    if (result.statusCode != 200) {
      throw CommuteServiceException(result.body, statusCode: result.statusCode);
    }
  }

  void dispose() => _client.close();
}

final commuteServiceProvider = Provider<CommuteService?>((ref) {
  final clerkService = ref.watch(clerkServiceProvider);
  if (!clerkService.isSignedIn) return null;
  final service = CommuteService(clerkService.getSupabaseToken);
  ref.onDispose(service.dispose);
  return service;
});
