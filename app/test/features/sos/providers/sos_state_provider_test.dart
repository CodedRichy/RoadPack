import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roadpack/features/sos/models/event_types.dart';
import 'package:roadpack/features/sos/models/incident.dart';
import 'package:roadpack/features/sos/models/sos_state.dart';
import 'package:roadpack/features/sos/providers/sos_state_provider.dart';
import 'package:roadpack/features/sos/services/sos_service.dart';

class MockSosService extends Mock implements SosService {}

void main() {
  late ProviderContainer container;
  late MockSosService mockService;

  final testIncident = Incident(
    id: 'inc_123',
    userId: 'user_1',
    type: IncidentType.sos,
    status: IncidentStatus.dispatched,
    createdAt: DateTime(2026, 7, 11),
  );

  setUp(() {
    mockService = MockSosService();
    container = ProviderContainer(
      overrides: [sosServiceProvider.overrideWithValue(mockService)],
    );
  });

  tearDown(() => container.dispose());

  group('SosStateNotifier', () {
    test('initial state is idle', () {
      final state = container.read(sosStateProvider);
      expect(state.status, SosStatus.idle);
      expect(state.countdownRemaining, 5);
    });

    test('arm transitions to armed', () {
      container.read(sosStateProvider.notifier).arm();
      expect(container.read(sosStateProvider).status, SosStatus.armed);
    });

    test('cancel from countdown returns to idle', () {
      final notifier = container.read(sosStateProvider.notifier);
      notifier.arm();
      notifier.startCountdown();
      notifier.cancel();

      final state = container.read(sosStateProvider);
      expect(state.status, SosStatus.cancelled);
    });

    test('cancel from idle is no-op', () {
      container.read(sosStateProvider.notifier).cancel();
      expect(container.read(sosStateProvider).status, SosStatus.idle);
    });

    test('resolve calls service and transitions to resolved', () async {
      when(
        () => mockService.dispatchSos(),
      ).thenAnswer((_) async => testIncident);
      when(
        () => mockService.resolveIncident('inc_123'),
      ).thenAnswer((_) async {});

      final notifier = container.read(sosStateProvider.notifier);
      // Simulate dispatched state
      notifier.arm();
      notifier.state = notifier.state.copyWith(
        status: SosStatus.active,
        activeIncident: testIncident,
      );

      await notifier.resolve();

      expect(container.read(sosStateProvider).status, SosStatus.resolved);
      verify(() => mockService.resolveIncident('inc_123')).called(1);
    });
  });
}
