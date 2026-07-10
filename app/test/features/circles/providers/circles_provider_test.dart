import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:roadpack/features/auth/models/auth_state.dart';
import 'package:roadpack/features/auth/providers/clerk_auth_provider.dart';
import 'package:roadpack/features/circles/models/circle.dart';
import 'package:roadpack/features/circles/providers/circles_provider.dart';
import 'package:roadpack/features/circles/services/circle_repository.dart';

class MockCircleRepository extends Mock implements CircleRepository {}

final _testCircle = Circle(
  id: 'c1',
  name: 'My Family',
  type: CircleType.family,
  createdBy: 'user_1',
  inviteCode: 'abc123',
  maxMembers: 15,
  createdAt: DateTime(2026, 7, 11),
);

void main() {
  group('CirclesNotifier', () {
    late MockCircleRepository mockRepo;
    late ProviderContainer container;

    setUp(() {
      mockRepo = MockCircleRepository();
      container = ProviderContainer(
        overrides: [
          circleRepositoryProvider.overrideWithValue(mockRepo),
          clerkAuthProvider.overrideWith(
            () => _FakeAuthNotifier(
              const AuthState(
                status: AuthStatus.authenticated,
                userId: 'user_1',
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
    });

    test('build fetches circles from repository', () async {
      when(() => mockRepo.fetchCircles())
          .thenAnswer((_) async => [_testCircle]);

      final sub = container.listen(circlesProvider, (_, __) {});
      await container.read(circlesProvider.future);

      expect(sub.read().value, hasLength(1));
      expect(sub.read().value!.first.name, 'My Family');
    });

    test('refresh re-fetches circles', () async {
      when(() => mockRepo.fetchCircles())
          .thenAnswer((_) async => [_testCircle]);

      await container.read(circlesProvider.future);
      await container.read(circlesProvider.notifier).refresh();

      verify(() => mockRepo.fetchCircles()).called(2);
    });
  });
}

class _FakeAuthNotifier extends AsyncNotifier<AuthState>
    implements ClerkAuthNotifier {
  _FakeAuthNotifier(this._state);
  final AuthState _state;

  @override
  Future<AuthState> build() async => _state;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
