import 'package:firebase_core/firebase_core.dart';
import '../../firebase_options.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static Future<bool> initialize() async {
    if (Firebase.apps.isNotEmpty) return true;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      return true;
    } on FirebaseException {
      return false;
    }
  }
}
