import 'package:flutter/services.dart';

class QuickActionService {
  QuickActionService._();

  static const _channel = MethodChannel('com.memo.app/quick_actions');

  static Future<String?> consume() async {
    try {
      final value = await _channel.invokeMethod<String>('getPendingAction');
      return value?.trim().isEmpty == true ? null : value?.trim();
    } on PlatformException {
      return null;
    }
  }
}
