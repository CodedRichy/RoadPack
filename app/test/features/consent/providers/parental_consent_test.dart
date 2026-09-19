import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadpack/features/auth/models/auth_state.dart';
import 'package:roadpack/features/auth/providers/clerk_auth_provider.dart';
import 'package:roadpack/features/auth/providers/user_profile_provider.dart';
import 'package:roadpack/features/consent/models/consent_type.dart';
import 'package:roadpack/features/consent/providers/consent_provider.dart';
import 'package:roadpack/features/consent/providers/sharing_review_provider.dart';
import 'package:roadpack/features/consent/services/consent_repository.dart';
import 'package:roadpack/features/consent/services/parental_verification.dart';
import 'package:roadpack/features/consent/services/sharing_review_store.dart';

import '../fakes.dart';

const _declaration = ParentalDeclaration(
  parentName: 'Latha',
  parentPhone: '+919876500001',
  relationship: 'Mother',
);

Future<ProviderContainer> _container({
  required FakeConsentGateway gateway,
  ParentalVerifier? verifier,
}) async {
  final container = ProviderContainer(
    overrides: [
      userProfileProvider.overrideWith(
        () => FakeProfileNotifier(
          UserProfile(
            userId: 'u1',
            name: 'Asha',
            dateOfBirth: DateTime(DateTime.now().year - 16, 1, 1),
          ),
        ),
      ),
      clerkAuthProvider.overrideWith(
        () => FakeAuthNotifier(
          const AuthState(
            status: AuthStatus.authenticated,
            userId: 'u1',
            phone: '+919876500000',
          ),
        ),
      ),
      consentGatewayProvider.overrideWithValue(gateway),
      if (verifier != null)
        parentalVerifierProvider.overrideWithValue(verifier),
    ],
  );
  addTearDown(container.dispose);
  await container.read(clerkAuthProvider.future);
  await container.read(consentRecordsProvider.future);
  return container;
}

void main() {
  group('parental consent - the shipped default refuses', () {
    test('UnavailableParentalVerifier never verifies', () async {
      final result = await const UnavailableParentalVerifier().verify(
        _declaration,
      );
      expect(result.isVerified, isFalse);
      expect(result.failure, ParentalVerificationFailure.notConfigured);
    });

    test(
      'no consent row is written when verification is unavailable',
      () async {
        final gw = FakeConsentGateway();
        final c = await _container(gateway: gw);

        final result = await c
            .read(consentRecordsProvider.notifier)
            .requestParentalConsent(_declaration);

        expect(result.isVerified, isFalse);
        expect(gw.grantCalls, 0);
        expect(gw.records, isEmpty);
        expect(
          c.read(consentLedgerProvider).isGranted(ConsentType.parental),
          isFalse,
        );
      },
    );
  });

  group('parental consent - with an approved verifier plugged in', () {
    test('writes exactly one parental row, attributed to the parent', () async {
      final gw = FakeConsentGateway();
      final c = await _container(
        gateway: gw,
        verifier: const FakeApprovedVerifier(),
      );

      final result = await c
          .read(consentRecordsProvider.notifier)
          .requestParentalConsent(_declaration);

      expect(result.isVerified, isTrue);
      expect(gw.records, hasLength(1));
      final row = gw.records.single;
      expect(row.type, ConsentType.parental);
      expect(
        row.grantedBy,
        'parent1',
        reason: 'a parental consent granted by the child is not one',
      );
      expect(row.method, ConsentMethod.parentOtp);
      expect(row.version, kConsentWordingVersion);
      expect(
        c.read(consentLedgerProvider).isGranted(ConsentType.parental),
        isTrue,
      );
    });

    test('an incomplete declaration never reaches the verifier', () async {
      final gw = FakeConsentGateway();
      final c = await _container(
        gateway: gw,
        verifier: const FakeApprovedVerifier(),
      );

      final result = await c
          .read(consentRecordsProvider.notifier)
          .requestParentalConsent(
            const ParentalDeclaration(
              parentName: 'L',
              parentPhone: '',
              relationship: '',
            ),
          );

      expect(result.failure, ParentalVerificationFailure.incompleteDeclaration);
      expect(gw.grantCalls, 0);
    });

    test('a verifier that throws fails closed, writing nothing', () async {
      final gw = FakeConsentGateway();
      final c = await _container(
        gateway: gw,
        verifier: const ThrowingVerifier(),
      );

      final result = await c
          .read(consentRecordsProvider.notifier)
          .requestParentalConsent(_declaration);

      expect(result.failure, ParentalVerificationFailure.unavailable);
      expect(gw.records, isEmpty);
    });
  });

  group('sharing review reminder (FR-014)', () {
    test('a user who has never reviewed is due immediately', () {
      expect(sharingReviewDue(null), isTrue);
    });

    test('due again 30 days after the last review', () {
      final now = DateTime(2026, 9, 8);
      expect(
        sharingReviewDue(now.subtract(const Duration(days: 29)), now: now),
        isFalse,
      );
      expect(
        sharingReviewDue(now.subtract(const Duration(days: 30)), now: now),
        isTrue,
      );
    });

    test('marking reviewed clears the prompt and persists', () async {
      final store = FakeSharingReviewStore();
      final container = ProviderContainer(
        overrides: [sharingReviewStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      await container.read(lastSharingReviewProvider.future);
      expect(container.read(sharingReviewDueProvider), isTrue);

      await container.read(lastSharingReviewProvider.notifier).markReviewed();

      expect(container.read(sharingReviewDueProvider), isFalse);
      expect(store.value, isNotNull);
    });

    test('the prompt stays hidden while the last-review date is loading', () {
      final container = ProviderContainer(
        overrides: [
          sharingReviewStoreProvider.overrideWithValue(
            FakeSharingReviewStore(),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(sharingReviewDueProvider), isFalse);
    });
  });
}
