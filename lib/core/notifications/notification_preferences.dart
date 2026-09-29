import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferences {
  NotificationPreferences({SharedPreferences? preferences}) : _preferences = preferences;
  SharedPreferences? _preferences;
  Future<SharedPreferences> get _prefs async => _preferences ??= await SharedPreferences.getInstance();

  Future<bool> get messageSounds async => (await _prefs).getBool('notification_message_sounds') ?? true;
  Future<bool> get messageVibration async => (await _prefs).getBool('notification_message_vibration') ?? true;
  Future<bool> get callSounds async => (await _prefs).getBool('notification_call_sounds') ?? true;
  Future<bool> get callVibration async => (await _prefs).getBool('notification_call_vibration') ?? true;
  Future<bool> get callNotifications async => (await _prefs).getBool('notification_call_enabled') ?? true;
  Future<bool> get messageNotifications async => (await _prefs).getBool('notification_message_enabled') ?? true;

  Future<void> setMessageSounds(bool value) async => (await _prefs).setBool('notification_message_sounds', value);
  Future<void> setMessageVibration(bool value) async => (await _prefs).setBool('notification_message_vibration', value);
  Future<void> setCallSounds(bool value) async => (await _prefs).setBool('notification_call_sounds', value);
  Future<void> setCallVibration(bool value) async => (await _prefs).setBool('notification_call_vibration', value);
  Future<void> setCallNotifications(bool value) async => (await _prefs).setBool('notification_call_enabled', value);
  Future<void> setMessageNotifications(bool value) async => (await _prefs).setBool('notification_message_enabled', value);
}
