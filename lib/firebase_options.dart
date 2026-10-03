import 'package:firebase_core/firebase_core.dart';

/// Firebase client configuration.
///
/// These values identify the public Android Firebase application; Firebase
/// security is enforced by Auth/Firestore/Storage rules, not by hiding this
/// client configuration. Server credentials must never be placed here.
class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'FIREBASE_ANDROID_API_KEY',
      defaultValue: '',
    ),
    appId: '1:448753275014:android:e4dedb02a3b10cce9f0107',
    messagingSenderId: '448753275014',
    projectId: 'memo-f97b5',
    storageBucket: 'memo-f97b5.firebasestorage.app',
  );

  static FirebaseOptions get currentPlatform => android;
}
