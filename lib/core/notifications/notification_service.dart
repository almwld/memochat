import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notification_models.dart';

class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin}) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();
  final FlutterLocalNotificationsPlugin _plugin;

  static const _messageChannel = AndroidNotificationChannel(
    'memochat_messages_v2', 'Messages', description: 'New MemoChat messages.',
    importance: Importance.high, playSound: true,
    sound: RawResourceAndroidNotificationSound('message_tone'),
  );
  static const _callsChannel = AndroidNotificationChannel(
    'memochat_calls_v2', 'Calls', description: 'Incoming MemoChat calls.',
    importance: Importance.max, playSound: true,
    sound: RawResourceAndroidNotificationSound('call_ringtone'),
  );
  static const _missedCallsChannel = AndroidNotificationChannel(
    'memochat_missed_calls_v1', 'Missed calls', description: 'Missed MemoChat calls.',
    importance: Importance.defaultImportance, playSound: true,
    sound: RawResourceAndroidNotificationSound('message_tone'),
  );
  static const _systemChannel = AndroidNotificationChannel(
    'memochat_system_v1', 'System', description: 'MemoChat system notifications.',
    importance: Importance.defaultImportance,
  );

  Future<void> initialize({void Function(NotificationResponse response)? onTap}) async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@drawable/memochat_notification'),
    );
    await _plugin.initialize(settings, onDidReceiveNotificationResponse: onTap);
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    for (final channel in [_messageChannel, _callsChannel, _missedCallsChannel, _systemChannel]) {
      await android?.createNotificationChannel(channel);
    }
    await android?.requestNotificationsPermission();
  }

  Future<void> show(AppNotification notification) {
    final channelId = switch (notification.channel) {
      NotificationChannel.messages => _messageChannel.id,
      NotificationChannel.calls => _callsChannel.id,
      NotificationChannel.missedCalls => _missedCallsChannel.id,
      NotificationChannel.system => _systemChannel.id,
    };
    final importance = notification.isCall ? Importance.max : Importance.high;
    final priority = notification.isCall ? Priority.max : Priority.high;
    final vibration = notification.vibration ? Int64List.fromList(notification.isCall ? [0, 700, 500] : [0, 100]) : null;
    final details = NotificationDetails(android: AndroidNotificationDetails(
      channelId, notification.isCall ? 'Calls' : 'Messages',
      channelDescription: 'MemoChat notification', importance: importance, priority: priority,
      icon: '@drawable/memochat_notification', playSound: notification.sound,
      sound: notification.isCall ? const RawResourceAndroidNotificationSound('call_ringtone') : const RawResourceAndroidNotificationSound('message_tone'),
      vibrationPattern: vibration,
      actions: notification.isCall ? const [
        AndroidNotificationAction('accept_call', 'قبول', showsUserInterface: true),
        AndroidNotificationAction('reject_call', 'رفض', cancelNotification: true),
      ] : null,
    ));
    return _plugin.show(notification.id.hashCode & 0x7fffffff, notification.title, notification.body, details, payload: notification.encode());
  }

  Future<void> cancel(String id) => _plugin.cancel(id.hashCode & 0x7fffffff);
}
