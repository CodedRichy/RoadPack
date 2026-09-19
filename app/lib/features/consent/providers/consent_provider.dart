import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/clerk_auth_provider.dart';
import '../models/consent_ledger.dart';
import '../models/consent_record.dart';
import '../models/consent_type.dart';
import '../services/consent_repository.dart';
import '../services/parental_verification.dart';

/// The signed-in user's consent ledger.
///
/// Errors surface as an error state rather than an empty list, because
/// [consentLedgerProvider] must be able to tell "nothing granted" apart
/// from "we could not find out" — the two look identical to a gate that
/// only sees a list.
final consentRecordsProvider =
    AsyncNotifierProvider<ConsentRecordsNotifier, List<ConsentRecord>>(
      ConsentRecordsNotifier.new,
    );

class ConsentRecordsNotifier extends AsyncNotifier<List<ConsentRecord>> {
  @override
  Future<List<ConsentRecord>> build() async {
    final gateway = ref.watch(consentGatewayProvider);
    if (gateway == null) {
      // No session. Not an error, but definitely not a grant either — the
      // ledger provider below turns this into `unknown`.
      throw const ConsentUnavailable();
    }
    return gateway.fetchConsents();
  }

  Future<void> refresh() async {
    final gateway = ref.read(consentGatewayProvider);
    if (gateway == null) return;
    state = await AsyncValue.guard(gateway.fetchConsents);
  }

  /// Records a consent the user gave for themselves.
  Future<void> grantSelf(ConsentType type) async {
    final gateway = ref.read(consentGatewayProvider);
    final userId = ref.read(clerkAuthProvider).valueOrNull?.userId;
    if (gateway == null || userId == null) return;

    await gateway.grant(
      type: type,
      method: ConsentMethod.inApp,
      grantedBy: userId,
    );
    await refresh();
  }

  /// Withdraws every live consent of [type].
  ///
  /// Plural on purpose: a re-grant after a withdrawal appends a second row,
  /// so more than one can be live if a write raced. Revoking one and
  /// leaving the other would leave tracking running after the user said no.
  Future<void> revokeAll(ConsentType type) async {
    final gateway = ref.read(consentGatewayProvider);
    if (gateway == null) return;

    final current = state.valueOrNull ?? const <ConsentRecord>[];
    for (final record in current) {
      if (record.type == type && record.isActive) {
        await gateway.revoke(record.id);
      }
    }
    await refresh();
  }

  /// Runs the pluggable parental verification step and, only if it
  /// succeeds, appends the `parental` consent record.
  ///
  /// Returns the verification result either way so the UI can say what
  /// actually happened. No consent row is written on any failure path.
  Future<ParentalVerificationResult> requestParentalConsent(
    ParentalDeclaration declaration,
  ) async {
    if (!declaration.isComplete) {
      return const ParentalVerificationResult.failed(
        ParentalVerificationFailure.incompleteDeclaration,
      );
    }

    final gateway = ref.read(consentGatewayProvider);
    if (gateway == null) {
      return const ParentalVerificationResult.failed(
        ParentalVerificationFailure.unavailable,
      );
    }

    final verifier = ref.read(parentalVerifierProvider);
    late final ParentalVerificationResult result;
    try {
      result = await verifier.verify(declaration);
    } catch (_) {
      return const ParentalVerificationResult.failed(
        ParentalVerificationFailure.unavailable,
      );
    }
    if (!result.isVerified) return result;

    await gateway.grant(
      type: ConsentType.parental,
      method: result.method ?? ConsentMethod.parentInApp,
      grantedBy: result.parentUserId!,
    );
    await refresh();
    return result;
  }
}

/// Raised when there is no authenticated session to read consents for.
class ConsentUnavailable implements Exception {
  const ConsentUnavailable();

  @override
  String toString() => 'ConsentUnavailable: no authenticated session';
}

/// The consent state, with "we do not know" modelled explicitly.
///
/// Loading and error both collapse to [ConsentLedger.unknown], and every
/// query on an unknown ledger answers "not granted". This is the fail-closed
/// hinge of FR-003: a minor is never tracked on an optimistic default.
final consentLedgerProvider = Provider<ConsentLedger>((ref) {
  final async = ref.watch(consentRecordsProvider);
  return async.maybeWhen(
    data: ConsentLedger.new,
    orElse: () => const ConsentLedger.unknown(),
  );
});
