import 'package:firebase_core/firebase_core.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static Future<bool> initialize() async {
    if (Firebase.apps.isNotEmpty) return true;
    try {
      await Firebase.initializeApp();
      return true;
    } on FirebaseException {
      return false;
    }
  }
}
