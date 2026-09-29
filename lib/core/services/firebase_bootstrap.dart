import 'package:firebase_core/firebase_core.dart';
import '../../firebase_options.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static Future<bool>? _initialization;

  static Future<bool> initialize() {
    if (Firebase.apps.isNotEmpty) return Future.value(true);
    return _initialization ??= _initialize();
  }

  static Future<bool> _initialize() async {
    try {
      if (Firebase.apps.isNotEmpty) return true;
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      return true;
    } on FirebaseException {
      _initialization = null;
      return false;
    } catch (_) {
      _initialization = null;
      return false;
    }
  }
}
