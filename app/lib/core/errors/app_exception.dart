sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => message;
}

final class NetworkException extends AppException {
  const NetworkException([super.message = 'No network connection']);
}

final class AuthException extends AppException {
  const AuthException([super.message = 'Authentication failed']);
}

final class LocationException extends AppException {
  const LocationException([super.message = 'Location unavailable']);
}

final class StorageException extends AppException {
  const StorageException([super.message = 'Local storage error']);
}

/// The server understood the request and refused it on business grounds --
/// "this ride has ended", "only the leader can end the ride".
///
/// Distinct from [NetworkException] and [AuthException] because the caller must
/// not retry: retrying a domain refusal just repeats it. [code] carries the
/// Postgres SQLSTATE or RPC error code where one is available, so call sites
/// can branch without string-matching a message that may be localised later.
final class DomainException extends AppException {
  const DomainException(super.message, {this.code});
  final String? code;
}
