import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../app/app.dart';
import '../services/firebase_bootstrap.dart';
import '../services/fcm_token_service.dart';
import 'notification_inbox.dart';
import 'notification_models.dart';
import '../services/notification_history_service.dart';
import '../../features/chat/services/notification_service.dart';
import '../../features/chat/services/call_service.dart';
import '../../features/chat/presentation/chat_navigation.dart';
import '../../features/notifications/presentation/notification_center_screen.dart';
import '../../features/chat/services/call_sound_coordinator.dart';
import 'ringtone_service.dart';
import 'notification_preferences.dart';

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
      final launchPayload = await _localNotifications.getLaunchPayload();
      if (launchPayload != null) await _handleLocalTap(launchPayload);
    } catch (error) {
      debugPrint('Local notification launch routing skipped: $error');
    }
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
  bool _isMessageType(NotificationType type) => const {
        NotificationType.textMessage,
        NotificationType.imageMessage,
        NotificationType.videoMessage,
        NotificationType.fileMessage,
        NotificationType.audioMessage,
        NotificationType.reply,
      }.contains(type);

  Future<void> _recordHistory(AppNotification notification) async {
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

  Future<void> _handleMessage(RemoteMessage message) async {
    final notification = _parse(message);
    if (notification.senderId != null &&
        notification.senderId == FirebaseAuth.instance.currentUser?.uid) {
      return;
    }
    if (!await _inbox.addNotification(notification)) return;

    final preferences = NotificationPreferences();
    final isCall = notification.isCall;
    final isMessage = _isMessageType(notification.type);
    final enabled = isCall
        ? await preferences.callNotifications
        : isMessage
            ? await preferences.messageNotifications
            : await preferences.otherNotifications;
    final soundEnabled = isCall
        ? await preferences.callSounds
        : isMessage
            ? await preferences.messageSounds
            : await preferences.otherSounds;
    final vibrationEnabled = isCall
        ? await preferences.callVibration
        : isMessage
            ? await preferences.messageVibration
            : await preferences.otherVibration;
    final playSound = notification.sound && soundEnabled;
    final vibrate = notification.vibration && vibrationEnabled;

    if (isCall && notification.callId?.trim().isNotEmpty == true) {
      // A disabled external-alert preference must not prevent the actual
      // incoming call screen from opening while the app is in the foreground.
      await CallSoundCoordinator.instance.presentIncomingCallById(
        notification.callId!,
        playSound: enabled && playSound,
      );
      if (enabled) {
        await _localNotifications.showIncomingCallNotification(
          callerName: message.data['callerName']?.toString() ?? notification.title,
          callId: notification.callId!,
          isVideo: message.data['isVideo']?.toString().toLowerCase() == 'true' ||
              message.data['callType']?.toString().toLowerCase() == 'video',
          playSound: false,
          vibrate: vibrate,
        );
      }
    } else if (enabled) {
      await _localNotifications.showTypedNotification(
        type: notification.type.wireName,
        title: notification.title,
        body: notification.body,
        data: {
          ...notification.toJson(),
          ...message.data,
        },
        payload: jsonEncode(<String, dynamic>{
          'type': notification.type.wireName,
          'data': <String, dynamic>{...notification.toJson(), ...message.data},
        }),
        playSound: playSound,
        vibrate: vibrate,
      );
    }
    await _recordHistory(notification);
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

    final envelope = decoded!;
    final data = envelope['data'] is Map
        ? Map<String, dynamic>.from(envelope['data'] as Map)
        : envelope;
    final type = envelope['type']?.toString() ?? data['type']?.toString() ?? '';
    final callId = data['callId']?.toString().trim() ?? '';
    final navigator = memoNavigatorKey.currentState;
    if (callId.isNotEmpty &&
        (NotificationTypeCodec.parse(type) == NotificationType.call ||
            type == 'incoming_call' ||
            type == 'incoming_video_call')) {
      if (navigator != null) {
        await CallService().handleIncomingCallById(navigator.context, callId);
      }
      return;
    }

    final chatId = data['chatId']?.toString().trim() ?? '';
    final senderId = data['senderId']?.toString().trim() ?? '';
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final route = data['route']?.toString() ?? '';
    if (navigator != null &&
        chatId.isNotEmpty &&
        senderId.isNotEmpty &&
        currentUid.isNotEmpty &&
        senderId != currentUid &&
        !route.startsWith('community:') &&
        !route.startsWith('voice_room:') &&
        !route.startsWith('contacts:')) {
      await ChatNavigation.openRoom(
        navigator.context,
        chatId: chatId,
        otherUserId: senderId,
        otherUserName: data['senderName']?.toString() ??
            data['title']?.toString() ??
            'مستخدم',
        otherUserImage: data['senderPhotoUrl']?.toString() ??
            data['photoUrl']?.toString(),
      );
      return;
    }
    if (navigator != null) {
      await navigator.push(MaterialPageRoute<void>(
        builder: (_) => const NotificationCenterScreen(),
      ));
    }
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

  final preferences = NotificationPreferences();
  final isCall = notification.isCall;
  final isMessage = const {
    NotificationType.textMessage,
    NotificationType.imageMessage,
    NotificationType.videoMessage,
    NotificationType.fileMessage,
    NotificationType.audioMessage,
    NotificationType.reply,
  }.contains(notification.type);
  final enabled = isCall
      ? await preferences.callNotifications
      : isMessage
          ? await preferences.messageNotifications
          : await preferences.otherNotifications;
  if (enabled && message.notification == null) {
    final soundEnabled = isCall
        ? await preferences.callSounds
        : isMessage
            ? await preferences.messageSounds
            : await preferences.otherSounds;
    final vibrationEnabled = isCall
        ? await preferences.callVibration
        : isMessage
            ? await preferences.messageVibration
            : await preferences.otherVibration;
    final playSound = notification.sound && soundEnabled;
    final vibrate = notification.vibration && vibrationEnabled;
    final local = NotificationService();
    await local.initialize();
    if (isCall && notification.callId?.trim().isNotEmpty == true) {
      await local.showIncomingCallNotification(
        callerName: message.data['callerName']?.toString() ?? notification.title,
        callId: notification.callId!,
        isVideo: message.data['isVideo']?.toString().toLowerCase() == 'true' ||
            message.data['callType']?.toString().toLowerCase() == 'video',
        playSound: playSound,
        vibrate: vibrate,
      );
    } else {
      await local.showTypedNotification(
        type: notification.type.wireName,
        title: notification.title,
        body: notification.body,
        data: {
          ...notification.toJson(),
          ...message.data,
        },
        payload: jsonEncode(<String, dynamic>{
          'type': notification.type.wireName,
          'data': <String, dynamic>{...notification.toJson(), ...message.data},
        }),
        playSound: playSound,
        vibrate: vibrate,
      );
    }
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
