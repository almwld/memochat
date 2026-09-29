import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../../app/app.dart';
import '../../features/calls/presentation/call_screen.dart';
import 'dart:convert';
import 'notification_inbox.dart';
import 'notification_service.dart';

class PushNotificationService {
  PushNotificationService({FirebaseMessaging? messaging, required NotificationService localNotifications})
      : _messaging = messaging ?? FirebaseMessaging.instance,
        _localNotifications = localNotifications;

  final FirebaseMessaging _messaging;
  final NotificationService _localNotifications;
  final NotificationInbox _inbox = NotificationInbox();

  Future<void> initialize() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    await _localNotifications.initialize(onTap: _handleLocalTap);
    FirebaseMessaging.onMessage.listen(_handleMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpened);
    final initial = await _messaging.getInitialMessage();
    if (initial != null) await _handleOpened(initial);
  }

  Future<String?> getToken() => _messaging.getToken();

  Future<void> _handleMessage(RemoteMessage message) async {
    final title = message.notification?.title ?? message.data['title']?.toString() ?? 'MemoChat';
    final body = message.notification?.body ?? message.data['body']?.toString() ?? '';
    final id = message.messageId ?? DateTime.now().microsecondsSinceEpoch.toString();
    final route = message.data['route']?.toString() ?? (message.data['callId'] == null ? null : 'call:' + message.data['callId'].toString());
    await _inbox.add(NotificationInboxItem(
      id: id, title: title, body: body, createdAt: DateTime.now(), route: route,
    ));
    await _localNotifications.showMessage(
      id: id.hashCode & 0x7fffffff, title: title, body: body, payload: route,
    );
  }

  Future<void> _handleOpened(RemoteMessage message) async {
    final id = message.messageId;
    if (id == null) return;
    await _inbox.markRead(id);
  }
  Future<void> _handleLocalTap(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null || !payload.startsWith('call:')) return;
    await _openIncomingCall(payload.substring(5));
  }

  Future<void> _openIncomingCall(String callId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final navigator = memoNavigatorKey.currentState;
    if (uid == null || navigator == null) return;
    final snap = await FirebaseFirestore.instance.collection('calls').doc(callId).get();
    final data = snap.data();
    if (!snap.exists || data == null || data['receiverId'] != uid || data['status'] == 'ended') return;
    navigator.push(MaterialPageRoute(builder: (_) => CallScreen(
      chatId: data['chatId']?.toString() ?? '',
      otherUserId: data['callerId']?.toString() ?? '',
      otherUserName: data['callerName']?.toString() ?? 'مستخدم',
      otherUserImage: data['callerPhotoUrl']?.toString(),
      isVideo: data['isVideo'] == true,
      incomingCallId: callId,
    )));
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final inbox = NotificationInbox();
  final title = message.notification?.title ?? message.data['title']?.toString() ?? 'MemoChat';
  final body = message.notification?.body ?? message.data['body']?.toString() ?? '';
  final id = message.messageId ?? DateTime.now().microsecondsSinceEpoch.toString();
  await inbox.add(NotificationInboxItem(
    id: id, title: title, body: body, createdAt: DateTime.now(),
    route: message.data['route']?.toString(),
  ));
}
