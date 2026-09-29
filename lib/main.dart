import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'app/app.dart';
import 'core/services/firebase_bootstrap.dart';
import 'core/notifications/notification_service.dart';
import 'core/notifications/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase must be ready before screens that query Auth/Firestore are mounted.
  await FirebaseBootstrap.initialize().timeout(
    const Duration(seconds: 8),
    onTimeout: () => false,
  );

  runApp(const MemoChatApp());
  unawaited(_startSecondaryServices());
}

Future<void> _startSecondaryServices() async {
  if (Firebase.apps.isEmpty) return;

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  try {
    await PushNotificationService(
      localNotifications: NotificationService(),
    ).initialize().timeout(const Duration(seconds: 8));
  } catch (_) {
    // Notifications are optional and must never prevent the chat UI from starting.
  }
}
