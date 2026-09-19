import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roadpack/features/auth/models/auth_state.dart';
import 'package:roadpack/features/auth/providers/clerk_auth_provider.dart';
import 'package:roadpack/features/auth/providers/user_profile_provider.dart';
import 'package:roadpack/features/consent/models/consent_record.dart';
import 'package:roadpack/features/consent/models/consent_type.dart';
import 'package:roadpack/features/consent/services/consent_repository.dart';
import 'package:roadpack/features/consent/services/parental_verification.dart';
import 'package:roadpack/features/consent/services/sharing_review_store.dart';

ConsentRecord fakeConsent(
  ConsentType type, {
  String id = 'c1',
  String userId = 'u1',
  String? grantedBy = 'u1',
  ConsentMethod method = ConsentMethod.inApp,
  DateTime? grantedAt,
  DateTime? revokedAt,
  String version = kConsentWordingVersion,
}) => ConsentRecord(
  id: id,
  userId: userId,
  type: type,
  grantedBy: grantedBy,
  method: method,
  grantedAt: grantedAt ?? DateTime(2026, 1, 1),
  revokedAt: revokedAt,
  version: version,
);

/// In-memory `consents` table that behaves the way migration 00009 does:
/// insert-only, and the single permitted update is `revoked_at`.
class FakeConsentGateway implements ConsentGateway {
  FakeConsentGateway({List<ConsentRecord>? records, this.failFetch = false})
    : records = [...?records];

  final List<ConsentRecord> records;

  /// Simulates an unreadable ledger (offline, RLS failure, server error).
  final bool failFetch;

  int grantCalls = 0;
  int revokeCalls = 0;

  @override
  Future<List<ConsentRecord>> fetchConsents() async {
    if (failFetch) throw StateError('consents unreadable');
    return [...records];
  }

  @override
  Future<ConsentRecord> grant({
    required ConsentType type,
    required ConsentMethod method,
    required String grantedBy,
    String version = kConsentWordingVersion,
  }) async {
    grantCalls++;
    final record = ConsentRecord(
      id: 'gen${records.length + 1}',
      userId: 'u1',
      type: type,
      grantedBy: grantedBy,
      method: method,
      grantedAt: DateTime.now(),
      version: version,
    );
    records.add(record);
    return record;
  }

  @override
  Future<void> revoke(String consentId) async {
    revokeCalls++;
    for (var i = 0; i < records.length; i++) {
      if (records[i].id == consentId) {
        records[i] = records[i].revoked(DateTime.now());
        return;
      }
    }
  }
}

/// A verifier that succeeds. Stands in for a counsel-approved method that
/// this build does not ship.
class FakeApprovedVerifier implements ParentalVerifier {
  const FakeApprovedVerifier({this.parentUserId = 'parent1'});

  final String parentUserId;

  @override
  Future<ParentalVerificationResult> verify(
    ParentalDeclaration declaration,
  ) async => ParentalVerificationResult.verified(
    method: ConsentMethod.parentOtp,
    parentUserId: parentUserId,
  );

  @override
  String get methodDescription => 'Test verifier';
}

/// A verifier that throws, standing in for a network failure mid-flow.
class ThrowingVerifier implements ParentalVerifier {
  const ThrowingVerifier();

  @override
  Future<ParentalVerificationResult> verify(ParentalDeclaration d) async =>
      throw StateError('network down');

  @override
  String get methodDescription => 'Throwing verifier';
}

class FakeSharingReviewStore implements SharingReviewStore {
  FakeSharingReviewStore([this.value]);

  DateTime? value;

  @override
  Future<DateTime?> lastReviewedAt() async => value;

  @override
  Future<void> markReviewed(DateTime at) async => value = at;
}

class FakeProfileNotifier extends AsyncNotifier<UserProfile?>
    implements UserProfileNotifier {
  FakeProfileNotifier(this.profile);

  final UserProfile? profile;

  @override
  Future<UserProfile?> build() async => profile;
  @override
  Future<void> fetchProfile() async {}
  @override
  Future<void> updateName(String name) async {}
  @override
  Future<void> updateDateOfBirth(DateTime dob) async {}
  @override
  Future<void> updateVehicle(String? type, String? reg) async {}
  @override
  Future<void> updateSafetySettings({
    required String crashSensitivity,
    required String phoneMountType,
  }) async {}
  @override
  Future<void> updateNonArrivalSettings({
    required bool enabled,
    required int delayMin,
  }) async {}
  @override
  Future<void> updateEmergencyProfile({
    String? bloodGroup,
    String? medicalNotes,
  }) async {}
  @override
  Future<void> addEmergencyContact({
    required String name,
    required String phone,
    required String relationship,
  }) async {}
}

class FakeAuthNotifier extends AsyncNotifier<AuthState>
    implements ClerkAuthNotifier {
  FakeAuthNotifier(this.authState);

  final AuthState authState;

  @override
  Future<AuthState> build() async => authState;

  @override
  Future<void> startPhoneSignIn(String phone) async {}
  @override
  Future<void> startEmailSignIn(String email) async {}
  @override
  Future<void> verifyCode(String code) async {}
  @override
  Future<void> signInWithGoogle() async {}
  @override
  Future<void> signOut() async {}
}
