import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../app/app.dart';
import '../../features/chat/services/call_service.dart';
import '../services/firebase_bootstrap.dart';
import 'notification_inbox.dart';
import 'notification_models.dart';
import '../../features/chat/services/notification_service.dart';
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
    _localNotifications.setNotificationTapHandler(_handleLocalTap);
    await _localNotifications.initialize();
    await _syncToken(await _messaging.getToken());
    FirebaseMessaging.instance.onTokenRefresh.listen(_syncToken);
    FirebaseMessaging.onMessage.listen(_handleMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpened);
    final initial = await _messaging.getInitialMessage();
    if (initial != null) await _handleOpened(initial);
  }
  Future<String?> getToken() async {
    final token = await _messaging.getToken();
    await _syncToken(token);
    return token;
  }

  Future<void> _syncToken(String? token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final normalized = token?.trim() ?? '';
    if (uid == null || uid.isEmpty || normalized.isEmpty) return;
    final tokenId = _tokenId(normalized);
    await FirebaseFirestore.instance
        .collection('users').doc(uid)
        .collection('private').doc('tokens')
        .collection('fcm').doc(tokenId)
        .set({
          'token': normalized,
          'platform': 'android',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
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
    if (notification.isCall) {
      await _localNotifications.showIncomingCallNotification(
        callerName: notification.title,
        callId: notification.callId ?? notification.id,
        isVideo: notification.type == NotificationType.incomingVideoCall ||
            notification.type == NotificationType.missedVideoCall,
      );
      await _ringtone.startIncomingCallRingtone(vibrate: notification.vibration);
    } else {
      await _localNotifications.showTypedNotification(
        type: notification.type.wireName,
        title: notification.title,
        body: notification.body,
        data: notification.toJson(),
        payload: notification.encode(),
        playSound: notification.sound,
      );
      if (notification.sound) await _ringtone.playMessageSound(vibrate: notification.vibration);
    }
  }
  Future<void> _handleOpened(RemoteMessage message) async {
    final notification = _parse(message);
    await _inbox.markRead(notification.id);
    if (notification.callId != null) await _openIncomingCall(notification.callId!);
  }
  Future<void> _handleLocalTap(String? payload) async {
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
    if (!snap.exists || data == null || data['receiverId'] != uid) return;
    final status = data['status']?.toString();
    if (status != 'calling' && status != 'ringing') return;
    await _ringtone.stopIncomingCallRingtone();
    await CallService().handleIncomingCallById(navigator.context, callId);
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
    await local.initialize(startCallCoordinator: false);
    if (notification.isCall) {
      await local.showIncomingCallNotification(
        callerName: notification.title,
        callId: notification.callId ?? notification.id,
        isVideo: notification.type == NotificationType.incomingVideoCall ||
            notification.type == NotificationType.missedVideoCall,
      );
    } else {
      await local.showTypedNotification(
        type: notification.type.wireName,
        title: notification.title,
        body: notification.body,
        data: notification.toJson(),
        payload: notification.encode(),
        playSound: notification.sound,
      );
    }
  }
}