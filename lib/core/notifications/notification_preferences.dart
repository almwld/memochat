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
  Future<bool> get messagePreview async => (await _prefs).getBool('notification_message_preview') ?? true;
  Future<bool> get otherNotifications async => (await _prefs).getBool('notification_other_enabled') ?? true;
  Future<bool> get otherSounds async => (await _prefs).getBool('notification_other_sounds') ?? true;
  Future<bool> get otherVibration async => (await _prefs).getBool('notification_other_vibration') ?? true;

  Future<void> setMessageSounds(bool value) async => (await _prefs).setBool('notification_message_sounds', value);
  Future<void> setMessageVibration(bool value) async => (await _prefs).setBool('notification_message_vibration', value);
  Future<void> setCallSounds(bool value) async => (await _prefs).setBool('notification_call_sounds', value);
  Future<void> setCallVibration(bool value) async => (await _prefs).setBool('notification_call_vibration', value);
  Future<void> setCallNotifications(bool value) async => (await _prefs).setBool('notification_call_enabled', value);
  Future<void> setMessageNotifications(bool value) async => (await _prefs).setBool('notification_message_enabled', value);
  Future<void> setMessagePreview(bool value) async => (await _prefs).setBool('notification_message_preview', value);
  Future<void> setOtherNotifications(bool value) async => (await _prefs).setBool('notification_other_enabled', value);
  Future<void> setOtherSounds(bool value) async => (await _prefs).setBool('notification_other_sounds', value);
  Future<void> setOtherVibration(bool value) async => (await _prefs).setBool('notification_other_vibration', value);
}
