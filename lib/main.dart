import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'app/app.dart';
import 'core/services/firebase_bootstrap.dart';
import 'core/notifications/notification_service.dart';
import 'core/notifications/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.initialize();
  if (Firebase.apps.isNotEmpty) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await PushNotificationService(
      localNotifications: NotificationService(),
    ).initialize();
  }
  runApp(const MemoChatApp());
}
