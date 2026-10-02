import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'core/notifications/push_notification_service.dart';
import 'app/app.dart';
import 'core/security/security_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(
    const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
  );

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('MemoChat: Firebase initialized successfully');
    await SecurityService.instance.initialize();
  } catch (error, stackTrace) {
    debugPrint('MemoChat: Firebase initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    runApp(_StartupErrorApp(error: error));
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
                if (const bool.fromEnvironment('dart.vm.product') == false)
                  Text(error.toString(), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
