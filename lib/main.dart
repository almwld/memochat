import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'app/app.dart';
import 'core/services/firebase_bootstrap.dart';
import 'core/notifications/notification_service.dart';
import 'core/notifications/push_notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Never block the first Flutter frame on Firebase, FCM, permissions, or audio.
  runApp(const MemoChatApp());
  unawaited(_startSecondaryServices());
}

Future<void> _startSecondaryServices() async {
  final firebaseReady = await FirebaseBootstrap.initialize().timeout(
    const Duration(seconds: 8),
    onTimeout: () => false,
  );
  if (!firebaseReady) return;

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  try {
    await PushNotificationService(
      localNotifications: NotificationService(),
    ).initialize().timeout(const Duration(seconds: 8));
  } catch (_) {
    // Notifications are optional and must never prevent the chat UI from starting.
  }
}
