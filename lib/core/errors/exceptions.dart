sealed class AppException implements Exception {
  const AppException(this.message, {this.code});
  final String message;
  final String? code;
}
final class NetworkException extends AppException { const NetworkException(super.message, {super.code}); }
final class AuthenticationException extends AppException { const AuthenticationException(super.message, {super.code}); }
final class StorageException extends AppException { const StorageException(super.message, {super.code}); }
final class ServiceException extends AppException { const ServiceException(super.message, {super.code}); }
