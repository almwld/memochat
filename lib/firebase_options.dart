import 'package:firebase_core/firebase_core.dart';
import 'core/config/secrets.dart';

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: Secrets.firebaseApiKey,
    appId: Secrets.firebaseAppId,
    messagingSenderId: '448753275014',
    projectId: Secrets.firebaseProjectId,
    storageBucket: Secrets.firebaseStorageBucket,
  );

  static FirebaseOptions get currentPlatform => android;
}
