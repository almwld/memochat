import 'exceptions.dart';
import 'failures.dart';

abstract final class ErrorHandler {
  static Failure toFailure(Object error) {
    if (error is NetworkException) return NetworkFailure(error.message, code: error.code);
    if (error is AuthenticationException) return AuthFailure(error.message, code: error.code);
    if (error is StorageException) return StorageFailure(error.message, code: error.code);
    if (error is ServiceException) return ServiceFailure(error.message, code: error.code);
    if (error is AppException) return UnknownFailure(error.message, code: error.code);
    return const UnknownFailure('حدث خطأ غير متوقع');
  }
}
