import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../models/consent_type.dart';

/// What the parental flow collected before a consent record is written.
class ParentalDeclaration {
  const ParentalDeclaration({
    required this.parentName,
    required this.parentPhone,
    required this.relationship,
  });

  final String parentName;
  final String parentPhone;
  final String relationship;

  bool get isComplete =>
      parentName.trim().length >= 2 &&
      parentPhone.trim().length >= 8 &&
      relationship.trim().isNotEmpty;
}

/// Why a verification attempt did not produce a consent.
enum ParentalVerificationFailure {
  /// No verification method is wired into this build. This is the default
  /// and it is deliberate — see [UnavailableParentalVerifier].
  notConfigured,

  /// The parent's details were incomplete.
  incompleteDeclaration,

  /// The parent failed the verification step (wrong code, timeout, ...).
  verificationFailed,

  /// The check could not be completed — offline, server error. Fails closed
  /// exactly like an outright failure.
  unavailable,
}

/// The outcome of attempting to verify a parent or guardian.
class ParentalVerificationResult {
  const ParentalVerificationResult.verified({
    required this.method,
    required this.parentUserId,
  }) : failure = null;

  const ParentalVerificationResult.failed(this.failure)
    : method = null,
      parentUserId = null;

  /// How the parent was verified. Written to `consents.method`.
  final ConsentMethod? method;

  /// The parent's own user id, written to `consents.granted_by`. A parental
  /// consent whose `granted_by` is the child is not a parental consent.
  final String? parentUserId;

  final ParentalVerificationFailure? failure;

  bool get isVerified => failure == null;

  String plainMessage(AppLocalizations l10n) {
    switch (failure) {
      case null:
        return l10n.consentParentalConfirmed;
      case ParentalVerificationFailure.notConfigured:
        return l10n.consentParentalNotConfigured;
      case ParentalVerificationFailure.incompleteDeclaration:
        return l10n.consentParentalIncomplete;
      case ParentalVerificationFailure.verificationFailed:
        return l10n.consentParentalVerificationFailed;
      case ParentalVerificationFailure.unavailable:
        return l10n.consentParentalUnavailable;
    }
  }
}

/// The pluggable verification step for FR-003 / DPDPA C6.
///
/// **This interface is the seam, not the answer.** "Verifiable parental
/// consent" has a specific legal meaning under the DPDPA 2023 and the set
/// of acceptable verification methods is a question for counsel, not for
/// this codebase. What lives here is the mechanism: a well-defined point
/// where an approved method is dropped in, a hard gate in front of it, and
/// an append-only record behind it.
///
/// Implementations must never return [ParentalVerificationResult.verified]
/// on a path they cannot stand behind. Returning a failure costs a minor
/// the tracking feature; returning a false success is unlawful processing
/// of a child's personal data.
abstract interface class ParentalVerifier {
  Future<ParentalVerificationResult> verify(ParentalDeclaration declaration);

  /// Short, honest description of what this verifier actually proves.
  /// Shown to the user and to the parent — a claim we can defend.
  String methodDescription(AppLocalizations l10n);
}

/// The default, and the only one shipped: verification is not available.
///
/// This build has no counsel-approved way to verify that the person tapping
/// "I am the parent" is the parent. Rather than inventing one and calling
/// it compliant, the verifier refuses, no `parental` consent row is ever
/// written, and the age gate stays shut. A minor therefore cannot be
/// tracked by this build at all — which is the correct behaviour until a
/// method is signed off.
///
/// Replace via [parentalVerifierProvider] once counsel approves a method.
class UnavailableParentalVerifier implements ParentalVerifier {
  const UnavailableParentalVerifier();

  @override
  Future<ParentalVerificationResult> verify(
    ParentalDeclaration declaration,
  ) async => const ParentalVerificationResult.failed(
    ParentalVerificationFailure.notConfigured,
  );

  @override
  String methodDescription(AppLocalizations l10n) =>
      l10n.consentVerifierNotAvailable;
}

/// Override this provider to plug in an approved verification method.
final parentalVerifierProvider = Provider<ParentalVerifier>(
  (ref) => const UnavailableParentalVerifier(),
);
