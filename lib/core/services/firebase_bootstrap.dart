import 'package:firebase_core/firebase_core.dart';
import '../../firebase_options.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static Future<bool>? _initialization;
  static FirebaseException? _lastFirebaseError;
  static Object? _lastError;

  static FirebaseException? get lastFirebaseError => _lastFirebaseError;
  static Object? get lastError => _lastError;

  static Future<bool> initialize() {
    if (Firebase.apps.isNotEmpty) return Future.value(true);
    return _initialization ??= _initialize();
  }

  static Future<bool> _initialize() async {
    _lastFirebaseError = null;
    _lastError = null;

    // On Android, prefer the native resources generated from
    // android/app/google-services.json. This avoids accidentally initializing
    // Firebase with an empty --dart-define API key in local/debug builds.
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      if (Firebase.apps.isNotEmpty) return true;
    } catch (error) {
      _lastError = error;
      if (error is FirebaseException) _lastFirebaseError = error;
    }

    // Fallback for builds where native Firebase resources are unavailable.
    // The caller can show a useful error if both configuration paths fail.
    try {
      if (Firebase.apps.isEmpty) {
        final options = DefaultFirebaseOptions.currentPlatform;
        if (options.apiKey.isEmpty) {
          throw StateError(
            'Firebase Android API key is empty and native Firebase '
            'configuration could not be loaded.',
          );
        }
        await Firebase.initializeApp(options: options);
      }
      return Firebase.apps.isNotEmpty;
    } catch (error) {
      _lastError = error;
      if (error is FirebaseException) _lastFirebaseError = error;
      _initialization = null;
      return false;
    }
  }
}
