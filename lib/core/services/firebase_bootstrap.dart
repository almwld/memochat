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
    try {
      if (Firebase.apps.isNotEmpty) return true;
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      return true;
    } on FirebaseException catch (error) {
      _lastFirebaseError = error;
      _lastError = error;
      _initialization = null;
      return false;
    } catch (error) {
      _lastError = error;
      _initialization = null;
      return false;
    }
  }
}
