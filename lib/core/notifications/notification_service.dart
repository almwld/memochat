import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _channel = AndroidNotificationChannel(
    'memochat_messages',
    'MemoChat messages',
    description: 'New MemoChat messages and call events.',
    importance: Importance.high,
    playSound: true,
  );

  Future<void> initialize({
    void Function(NotificationResponse response)? onTap,
  }) async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings, onDidReceiveNotificationResponse: onTap);
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channel);
    await androidPlugin?.requestNotificationsPermission();
  }

  Future<void> showMessage({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'memochat_messages',
        'MemoChat messages',
        channelDescription: 'New MemoChat messages and call events.',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
      ),
    );
    return _plugin.show(id: id, title: title, body: body, notificationDetails: details, payload: payload);
  }
}
