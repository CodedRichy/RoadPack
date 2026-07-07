/// Error codes shared between app and backend.
/// Use these in API responses and local error handling.

abstract final class ErrorCodes {
  static const String authInvalidOtp = 'AUTH_INVALID_OTP';
  static const String authExpiredOtp = 'AUTH_EXPIRED_OTP';
  static const String authMinorNoConsent = 'AUTH_MINOR_NO_CONSENT';
  static const String circleMaxMembers = 'CIRCLE_MAX_MEMBERS';
  static const String circleDuplicateMember = 'CIRCLE_DUPLICATE_MEMBER';
  static const String circleInvalidInvite = 'CIRCLE_INVALID_INVITE';
  static const String contactMaxReached = 'CONTACT_MAX_REACHED';
  static const String contactMinRequired = 'CONTACT_MIN_REQUIRED';
  static const String incidentAlreadyResolved = 'INCIDENT_ALREADY_RESOLVED';
  static const String locationPermissionDenied = 'LOCATION_PERMISSION_DENIED';
  static const String locationServiceDisabled = 'LOCATION_SERVICE_DISABLED';
  static const String networkOffline = 'NETWORK_OFFLINE';
  static const String rateLimited = 'RATE_LIMITED';
}
