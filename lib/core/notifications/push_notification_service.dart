import 'package:firebase_messaging/firebase_messaging.dart';
import 'notification_service.dart';

class PushNotificationService {
  PushNotificationService({FirebaseMessaging? messaging, required NotificationService localNotifications})
      : _messaging = messaging ?? FirebaseMessaging.instance,
        _localNotifications = localNotifications;

  final FirebaseMessaging _messaging;
  final NotificationService _localNotifications;

  Future<void> initialize() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    await _localNotifications.initialize();
    FirebaseMessaging.onMessage.listen(_handleMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpened);
  }

  Future<String?> getToken() => _messaging.getToken();

  Future<void> _handleMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _localNotifications.showMessage(
      id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title: notification.title ?? 'MemoChat',
      body: notification.body ?? '',
      payload: message.data['route'] as String?,
    );
  }

  void _handleOpened(RemoteMessage message) {}
}
