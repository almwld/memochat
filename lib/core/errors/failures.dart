sealed class Failure {
  const Failure(this.message, {this.code});
  final String message;
  final String? code;
}
final class NetworkFailure extends Failure { const NetworkFailure(super.message, {super.code}); }
final class AuthFailure extends Failure { const AuthFailure(super.message, {super.code}); }
final class StorageFailure extends Failure { const StorageFailure(super.message, {super.code}); }
final class ServiceFailure extends Failure { const ServiceFailure(super.message, {super.code}); }
final class UnknownFailure extends Failure { const UnknownFailure(super.message, {super.code}); }
