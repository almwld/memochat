import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../app/app.dart';
import '../../features/calls/presentation/call_screen.dart';
import '../services/firebase_bootstrap.dart';
import 'notification_inbox.dart';
import 'notification_models.dart';
import 'notification_service.dart';
import 'ringtone_service.dart';

class PushNotificationService {
  PushNotificationService({FirebaseMessaging? messaging, required NotificationService localNotifications, RingtoneService? ringtone})
      : _messaging = messaging ?? FirebaseMessaging.instance,
        _localNotifications = localNotifications,
        _ringtone = ringtone ?? RingtoneService();
  final FirebaseMessaging _messaging;
  final NotificationService _localNotifications;
  final NotificationInbox _inbox = NotificationInbox();
  final RingtoneService _ringtone;

  Future<void> initialize() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    await _localNotifications.initialize(onTap: _handleLocalTap);
    FirebaseMessaging.onMessage.listen(_handleMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpened);
    final initial = await _messaging.getInitialMessage();
    if (initial != null) await _handleOpened(initial);
  }
  Future<String?> getToken() => _messaging.getToken();
  AppNotification _parse(RemoteMessage message) => AppNotification.fromRemote(
    {...message.data, if (message.notification?.title != null) 'title': message.notification!.title, if (message.notification?.body != null) 'body': message.notification!.body},
    fallbackId: message.messageId,
  );
  Future<void> _handleMessage(RemoteMessage message) async {
    final notification = _parse(message);
    if (notification.senderId != null && notification.senderId == FirebaseAuth.instance.currentUser?.uid) return;
    if (!await _inbox.addNotification(notification)) return;
    await _localNotifications.show(notification);
    if (notification.isCall) {
      await _ringtone.startIncomingCallRingtone(vibrate: notification.vibration);
    } else if (notification.sound) {
      await _ringtone.playMessageSound(vibrate: notification.vibration);
    }
  }
  Future<void> _handleOpened(RemoteMessage message) async {
    final notification = _parse(message);
    await _inbox.markRead(notification.id);
    if (notification.callId != null) await _openIncomingCall(notification.callId!);
  }
  Future<void> _handleLocalTap(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null) return;
    final decoded = jsonDecode(payload);
    if (decoded is! Map) return;
    final notification = AppNotification.fromRemote(Map<String, dynamic>.from(decoded));
    await _ringtone.stopIncomingCallRingtone();
    if (notification.callId != null) await _openIncomingCall(notification.callId!);
  }
  Future<void> _openIncomingCall(String callId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final navigator = memoNavigatorKey.currentState;
    if (uid == null || navigator == null) return;
    final snap = await FirebaseFirestore.instance.collection('calls').doc(callId).get();
    final data = snap.data();
    if (!snap.exists || data == null || data['receiverId'] != uid || data['status'] == 'ended') return;
    await _ringtone.stopIncomingCallRingtone();
    navigator.push(MaterialPageRoute(builder: (_) => CallScreen(
      chatId: data['chatId']?.toString() ?? '', otherUserId: data['callerId']?.toString() ?? '',
      otherUserName: data['callerName']?.toString() ?? 'مستخدم', otherUserImage: data['callerPhotoUrl']?.toString(),
      isVideo: data['isVideo'] == true, incomingCallId: callId,
    )));
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
  await NotificationInbox().addNotification(notification);
}
