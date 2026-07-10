import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/auth/models/auth_state.dart';
import 'package:roadpack/features/auth/providers/clerk_auth_provider.dart';
import 'package:roadpack/features/circles/models/circle.dart';
import 'package:roadpack/features/circles/models/circle_member.dart';
import 'package:roadpack/features/circles/providers/circle_detail_provider.dart';
import 'package:roadpack/features/circles/screens/circle_detail_screen.dart';

void main() {
  final testDetail = CircleDetail(
    circle: Circle(
      id: 'c1',
      name: 'My Family',
      type: CircleType.family,
      createdBy: 'user_1',
      inviteCode: 'abc123',
      maxMembers: 15,
      createdAt: DateTime(2026, 7, 11),
    ),
    members: [
      CircleMember(
        circleId: 'c1',
        userId: 'user_1',
        role: CircleRole.admin,
        joinedAt: DateTime(2026, 7, 11),
        userName: 'Alice',
      ),
    ],
    observers: [],
  );

  testWidgets('shows circle name and invite code', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          circleDetailProvider('c1')
              .overrideWith((ref) async => testDetail),
          clerkAuthProvider.overrideWith(
            () => _FakeAuthNotifier(const AuthState(
              status: AuthStatus.authenticated,
              userId: 'user_1',
            )),
          ),
        ],
        child: const MaterialApp(
          home: CircleDetailScreen(circleId: 'c1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My Family'), findsOneWidget);
    expect(find.text('ABC123'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
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
