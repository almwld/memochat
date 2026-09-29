import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'app/app.dart';
import 'core/services/firebase_bootstrap.dart';
import 'core/notifications/notification_service.dart';
import 'core/notifications/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Render Flutter immediately. Firebase/network initialization must never
  // keep the native launch screen black.
  runApp(const MemoChatApp());

  // Notifications are secondary startup work and must not block first paint.
  final initialized = await FirebaseBootstrap.initialize();
  if (!initialized || Firebase.apps.isEmpty) return;

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await PushNotificationService(
    localNotifications: NotificationService(),
  ).initialize();
}
