import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../../app/app.dart';
import '../services/firebase_bootstrap.dart';
import '../services/fcm_token_service.dart';
import 'notification_inbox.dart';
import 'notification_models.dart';
import '../services/notification_history_service.dart';
import '../../features/chat/services/notification_service.dart';
import '../../features/chat/services/call_service.dart';
import 'ringtone_service.dart';

class PushNotificationService {
  PushNotificationService({FirebaseMessaging? messaging, required NotificationService localNotifications})
      : _messaging = messaging ?? FirebaseMessaging.instance,
        _localNotifications = localNotifications;
  final FirebaseMessaging _messaging;
  final NotificationService _localNotifications;
  final NotificationInbox _inbox = NotificationInbox();
  final NotificationHistoryService _history = NotificationHistoryService();
  final RingtoneService _ringtone = RingtoneService();

  Future<void> initialize() async {
    _localNotifications.setNotificationTapHandler(_handleLocalTap);
    await _localNotifications.initialize();
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true).timeout(const Duration(seconds: 8));
    } catch (error) {
      debugPrint('FCM permission request skipped: $error');
    }
    try {
      await FcmTokenService.instance.start().timeout(const Duration(seconds: 8));
      await FcmTokenService.instance.syncCurrentToken().timeout(const Duration(seconds: 8));
    } catch (error) {
      debugPrint('FCM token setup skipped: $error');
    }
    FirebaseMessaging.onMessage.listen(_handleMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpened);
    final initial = await _messaging.getInitialMessage();
    if (initial != null) await _handleOpened(initial);
  }
  Future<String?> getToken() async {
    final token = await _messaging.getToken();
    if (token != null && token.trim().isNotEmpty) {
      await FcmTokenService.instance.syncToken(token);
    }
    return token;
  }

  int _tokenId(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }
  AppNotification _parse(RemoteMessage message) => AppNotification.fromRemote(
    {...message.data, if (message.notification?.title != null) 'title': message.notification!.title, if (message.notification?.body != null) 'body': message.notification!.body},
    fallbackId: message.messageId,
  );
  Future<void> _handleMessage(RemoteMessage message) async {
    final notification = _parse(message);
    if (notification.senderId != null && notification.senderId == FirebaseAuth.instance.currentUser?.uid) return;
    if (!await _inbox.addNotification(notification)) return;
    await _localNotifications.showTypedNotification(
      type: notification.type.wireName,
      title: notification.title,
      body: notification.body,
      data: notification.toJson(),
      payload: notification.encode(),
      playSound: notification.sound,
    );
    try {
      await _history.add(
        notification.type.wireName,
        notification.title,
        notification.body,
        route: notification.route,
        data: notification.toJson(),
        id: notification.id,
      );
    } catch (error) {
      debugPrint('notification history unavailable: $error');
    }
  }
  Future<void> _handleOpened(RemoteMessage message) async {
    final notification = _parse(message);
    await _inbox.markRead(notification.id);
  }
  Future<void> _handleLocalTap(String? payload) async {
    if (payload == null || payload.trim().isEmpty) return;
    Map<String, dynamic>? decoded;
    try {
      final raw = payload.startsWith('notification_action:')
          ? payload.substring('notification_action:'.length)
          : payload;
      final value = jsonDecode(raw);
      if (value is Map) decoded = Map<String, dynamic>.from(value);
    } catch (_) {
      return;
    }
    if (decoded == null) return;

    final action = decoded!['action']?.toString().trim() ?? '';
    final actionPayload = decoded!['payload']?.toString();
    if (action == 'call_answer' || action == 'call_reject') {
      Map<String, dynamic>? envelope;
      try {
        final value = actionPayload == null ? null : jsonDecode(actionPayload);
        if (value is Map) envelope = Map<String, dynamic>.from(value);
      } catch (_) {}
      final data = envelope?['data'] is Map
          ? Map<String, dynamic>.from(envelope!['data'])
          : <String, dynamic>{};
      final callId = data['callId']?.toString().trim() ?? '';
      await _ringtone.stopIncomingCallRingtone();
      if (callId.isEmpty) return;
      if (action == 'call_reject') {
        await CallService().rejectCall(callId);
      } else {
        final navigator = memoNavigatorKey.currentState;
        if (navigator != null) {
          await CallService().answerIncomingCallById(navigator.context, callId);
        }
      }
      return;
    }

    final notification = AppNotification.fromRemote(decoded!);
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await FirebaseBootstrap.initialize();
  if (Firebase.apps.isEmpty) return;
  final notification = AppNotification.fromRemote(
    {...message.data, if (message.notification?.title != null) 'title': message.notification!.title, if (message.notification?.body != null) 'body': message.notification!.body},
    fallbackId: message.messageId,
  );
  if (notification.senderId == FirebaseAuth.instance.currentUser?.uid) return;
  final inbox = NotificationInbox();
  if (!await inbox.addNotification(notification)) return;
  if (message.notification == null) {
    final local = NotificationService();
    await local.initialize();
    await local.showTypedNotification(
      type: notification.type.wireName,
      title: notification.title,
      body: notification.body,
      data: notification.toJson(),
      payload: notification.encode(),
      playSound: notification.sound,
    );
  }
  try {
    await NotificationHistoryService().add(
      notification.type.wireName,
      notification.title,
      notification.body,
      route: notification.route,
      data: notification.toJson(),
      id: notification.id,
    );
  } catch (error) {
    debugPrint('background notification history unavailable: $error');
  }
}
