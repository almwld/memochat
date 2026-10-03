import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'core/notifications/push_notification_service.dart';
import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(
    const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
  );

  Object? lastError;
  for (var attempt = 1; attempt <= 3; attempt++) {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      lastError = null;
      debugPrint('MemoChat: Firebase initialized on attempt $attempt');
      break;
    } catch (error, stackTrace) {
      lastError = error;
      debugPrint('MemoChat: Firebase initialization attempt $attempt failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (attempt < 3) {
        await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
  }

  // If compile-time Dart defines are unavailable, let Android use the
  // google-services.json-backed native Firebase configuration as a final fallback.
  if (lastError != null && Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp();
      lastError = null;
      debugPrint('MemoChat: Firebase initialized from native Android config');
    } catch (error, stackTrace) {
      lastError = error;
      debugPrint('MemoChat: native Firebase initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  if (lastError != null) {
    runApp(_StartupErrorApp(error: lastError));
    return;
  }

  try {
    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );
  } catch (error) {
    debugPrint('MemoChat: FCM background handler registration failed: $error');
  }

  runApp(const MemoChatApp());
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 52),
                const SizedBox(height: 16),
                const Text(
                  'تعذر تشغيل MemoChat',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'تعذر تهيئة خدمات التطبيق الأساسية. تحقق من إعدادات Firebase ثم أعد المحاولة.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(error.toString(), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
