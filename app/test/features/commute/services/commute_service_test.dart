import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:roadpack/features/commute/models/commute_watch.dart';
import 'package:roadpack/features/commute/services/commute_service.dart';

void main() {
  late List<http.Request> sent;

  CommuteService service({
    int status = 200,
    String body = '{"status":"ok"}',
    Future<String?> Function()? token,
  }) {
    sent = [];
    return CommuteService(
      token ?? () async => 'jwt-token',
      client: MockClient((request) async {
        sent.add(request);
        return http.Response(body, status);
      }),
    );
  }

  group('check-in response (FR-043/044)', () {
    test('running late posts running_late to check-in-response only', () async {
      final s = service();
      await s.respondToCheckIn(
        incidentId: 'inc-1',
        response: CheckInResponse.runningLate,
      );

      expect(sent.length, 1);
      final request = sent.single;
      expect(request.method, 'POST');
      expect(request.url.path, endsWith('/functions/v1/check-in-response'));
      expect(jsonDecode(request.body), {
        'incident_id': 'inc-1',
        'response': 'running_late',
      });
    });

    test(
      'running late never touches the cascade or any circle endpoint',
      () async {
        final s = service();
        await s.respondToCheckIn(
          incidentId: 'inc-1',
          response: CheckInResponse.runningLate,
        );

        final paths = sent.map((r) => r.url.path).toList();
        expect(paths.any((p) => p.contains('alert-cascade')), isFalse);
        expect(paths.any((p) => p.contains('incident-receive')), isFalse);
        expect(paths.any((p) => p.contains('escalation')), isFalse);
        expect(paths.any((p) => p.contains('circle')), isFalse);
      },
    );

    test('sends the Clerk-templated bearer token', () async {
      final s = service();
      await s.respondToCheckIn(
        incidentId: 'inc-1',
        response: CheckInResponse.fine,
      );
      expect(sent.single.headers['Authorization'], 'Bearer jwt-token');
      expect(sent.single.headers['Content-Type'], contains('application/json'));
    });

    test('maps each response to the wire value the edge function accepts', () {
      expect(CheckInResponse.fine.wire, 'fine');
      expect(CheckInResponse.runningLate.wire, 'running_late');
      expect(CheckInResponse.needHelp.wire, 'need_help');
    });

    test('throws without an auth token rather than silently dropping', () {
      final s = service(token: () async => null);
      expect(
        () => s.respondToCheckIn(
          incidentId: 'inc-1',
          response: CheckInResponse.fine,
        ),
        throwsA(isA<CommuteServiceException>()),
      );
    });

    test('surfaces a server rejection', () async {
      final s = service(
        status: 409,
        body: '{"error":"Incident already closed"}',
      );
      await expectLater(
        s.respondToCheckIn(incidentId: 'inc-1', response: CheckInResponse.fine),
        throwsA(isA<CommuteServiceException>()),
      );
      expect(sent.length, 1);
    });

    test(
      'an already-closed incident is reported as closed, not as failure',
      () async {
        final s = service(
          status: 409,
          body: '{"error":"Incident already closed"}',
        );
        try {
          await s.respondToCheckIn(
            incidentId: 'inc-1',
            response: CheckInResponse.fine,
          );
          fail('expected a CommuteServiceException');
        } on CommuteServiceException catch (e) {
          expect(e.alreadyClosed, isTrue);
        }
      },
    );
  });
}
