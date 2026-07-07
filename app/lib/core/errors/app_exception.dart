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
