import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'app/app.dart';
import 'core/services/firebase_bootstrap.dart';
import 'core/notifications/notification_service.dart';
import 'core/notifications/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebaseReady = await FirebaseBootstrap.initialize();
  if (!firebaseReady) {
    runApp(const MemoChatStartupErrorApp());
    return;
  }

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(const MemoChatApp());

  // Secondary services start after the first Flutter frame.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      await PushNotificationService(
        localNotifications: NotificationService(),
      ).initialize();
    } catch (_) {
      // Notification failure must never prevent the chat UI from starting.
    }
  });
}

class MemoChatStartupErrorApp extends StatelessWidget {
  const MemoChatStartupErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text(
            'تعذر تشغيل التطبيق بسبب خطأ في تهيئة Firebase.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
