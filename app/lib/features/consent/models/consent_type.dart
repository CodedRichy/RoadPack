import '../../../l10n/l10n.dart';

/// The `consents.consent_type` CHECK values from migration 00009.
///
/// The wire values are the contract with the database — never rename one
/// without a migration, because the CHECK constraint will reject anything
/// it does not recognise and the insert will fail at the exact moment a
/// user is trying to say yes.
enum ConsentType {
  tracking('tracking'),
  dataSharingAnon('data_sharing_anon'),
  sensorUpload('sensor_upload'),
  parental('parental'),
  institutionalCircle('institutional_circle'),
  audioCapture('audio_capture');

  const ConsentType(this.wireValue);

  final String wireValue;

  /// Returns `null` for a value this build does not understand.
  ///
  /// Deliberately not a throw and deliberately not a fallback: an unknown
  /// consent type from a newer server is a consent we cannot reason about,
  /// so it is dropped and every gate that depends on it reads as *not
  /// granted*. Guessing would be the only way to accidentally track someone
  /// on a permission we invented.
  static ConsentType? fromWire(String? value) {
    for (final t in ConsentType.values) {
      if (t.wireValue == value) return t;
    }
    return null;
  }

  /// Plain-language title. Read by a 19-year-old on a 5-inch phone, so no
  /// "data principal", no "processing", no "hereby".
  ///
  /// Takes the localisations rather than reading a context: a consent a
  /// rider cannot read is not informed consent, so this copy has to be
  /// available in all three pilot languages (FR-005).
  String title(AppLocalizations l10n) {
    switch (this) {
      case ConsentType.tracking:
        return l10n.consentTypeTrackingTitle;
      case ConsentType.dataSharingAnon:
        return l10n.consentTypeDataSharingAnonTitle;
      case ConsentType.sensorUpload:
        return l10n.consentTypeSensorUploadTitle;
      case ConsentType.parental:
        return l10n.consentTypeParentalTitle;
      case ConsentType.institutionalCircle:
        return l10n.consentTypeInstitutionalTitle;
      case ConsentType.audioCapture:
        return l10n.consentTypeAudioCaptureTitle;
    }
  }

  /// One sentence, present tense, says what actually happens.
  String plainMeaning(AppLocalizations l10n) {
    switch (this) {
      case ConsentType.tracking:
        return l10n.consentTypeTrackingMeaning;
      case ConsentType.dataSharingAnon:
        return l10n.consentTypeDataSharingAnonMeaning;
      case ConsentType.sensorUpload:
        return l10n.consentTypeSensorUploadMeaning;
      case ConsentType.parental:
        return l10n.consentTypeParentalMeaning;
      case ConsentType.institutionalCircle:
        return l10n.consentTypeInstitutionalMeaning;
      case ConsentType.audioCapture:
        return l10n.consentTypeAudioCaptureMeaning;
    }
  }

  /// True for consents the user may switch off freely without losing the
  /// core safety promise. [tracking] and [parental] are not optional: they
  /// are the thing being consented to.
  bool get isOptional =>
      this != ConsentType.tracking && this != ConsentType.parental;
}

/// How a consent was collected. Stored in `consents.method` (VARCHAR(20)),
/// so every wire value here must stay at 20 characters or fewer.
enum ConsentMethod {
  /// The user themselves tapped a control in the app.
  inApp('in_app'),

  /// A parent or guardian completed the parental flow on this device after
  /// a verification step supplied by a [ParentalVerifier] implementation.
  /// The *strength* of that verification is a property of the verifier, not
  /// of this value.
  parentInApp('parent_in_app'),

  /// A parent or guardian verified control of their own phone number.
  parentOtp('parent_otp');

  const ConsentMethod(this.wireValue);

  final String wireValue;

  static ConsentMethod? fromWire(String? value) {
    for (final m in ConsentMethod.values) {
      if (m.wireValue == value) return m;
    }
    return null;
  }
}
