import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationPreferences {
  NotificationPreferences({SharedPreferences? preferences}) : _preferences = preferences;
  SharedPreferences? _preferences;
  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  static const List<String> _keys = <String>[
    'notification_message_sounds',
    'notification_message_vibration',
    'notification_call_sounds',
    'notification_call_vibration',
    'notification_call_enabled',
    'notification_message_enabled',
    'notification_message_preview',
    'notification_other_enabled',
    'notification_other_sounds',
    'notification_other_vibration',
  ];

  Future<void> _setBool(String key, bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(key, value);
    // Keep server-visible preferences in sync so APNs/server-side alerts do
    // not bypass a preference that was previously stored only on this device.
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        <String, dynamic>{
          'notificationPreferences': <String, dynamic>{key: value},
          'notificationPreferencesUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Local preferences remain usable if the user is offline or cloud sync
      // is unavailable; the next initialization attempts reconciliation.
    }
  }

  Future<void> syncWithCloud() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final prefs = await _prefs;
      final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final snapshot = await ref.get();
      final raw = snapshot.data()?['notificationPreferences'];
      final remote = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};

      if (remote.isNotEmpty) {
        // Migrate older servers that saved preferences by notification type
        // before reconciling canonical keys.
        const legacy = <String, String>{
          'new_message': 'notification_message_enabled',
          'text_message': 'notification_message_enabled',
          'image_message': 'notification_message_enabled',
          'video_message': 'notification_message_enabled',
          'file_message': 'notification_message_enabled',
          'audio_message': 'notification_message_enabled',
          'reply': 'notification_message_enabled',
          'call': 'notification_call_enabled',
          'incoming_call': 'notification_call_enabled',
          'incoming_video_call': 'notification_call_enabled',
        };
        final effectiveRemote = Map<String, dynamic>.from(remote);
        for (final entry in legacy.entries) {
          if (!effectiveRemote.containsKey(entry.value) &&
              remote[entry.key] is bool) {
            effectiveRemote[entry.value] = remote[entry.key];
          }
        }

        final missingLocalValues = <String, bool>{};
        for (final key in _keys) {
          if (effectiveRemote[key] is bool) {
            await prefs.setBool(key, effectiveRemote[key] as bool);
          } else if (prefs.containsKey(key)) {
            // Preserve explicit settings from an older local-only install
            // when the cloud document contains only a partial preference set.
            missingLocalValues[key] = prefs.getBool(key) ?? true;
          }
        }
        if (missingLocalValues.isNotEmpty) {
          await ref.set(
            <String, dynamic>{
              'notificationPreferences': missingLocalValues,
              'notificationPreferencesUpdatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
        return;
      }

      // First-run migration: only upload explicitly stored local values;
      // never upload getter defaults and overwrite another device's settings.
      final local = <String, bool>{};
      for (final key in _keys) {
        if (prefs.containsKey(key)) local[key] = prefs.getBool(key) ?? true;
      }
      if (local.isNotEmpty) {
        await ref.set(
          <String, dynamic>{
            'notificationPreferences': local,
            'notificationPreferencesUpdatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    } catch (_) {
      // Push notifications must still initialize when cloud preference sync
      // is temporarily unavailable.
    }
  }

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

  Future<void> setMessageSounds(bool value) => _setBool('notification_message_sounds', value);
  Future<void> setMessageVibration(bool value) => _setBool('notification_message_vibration', value);
  Future<void> setCallSounds(bool value) => _setBool('notification_call_sounds', value);
  Future<void> setCallVibration(bool value) => _setBool('notification_call_vibration', value);
  Future<void> setCallNotifications(bool value) => _setBool('notification_call_enabled', value);
  Future<void> setMessageNotifications(bool value) => _setBool('notification_message_enabled', value);
  Future<void> setMessagePreview(bool value) => _setBool('notification_message_preview', value);
  Future<void> setOtherNotifications(bool value) => _setBool('notification_other_enabled', value);
  Future<void> setOtherSounds(bool value) => _setBool('notification_other_sounds', value);
  Future<void> setOtherVibration(bool value) => _setBool('notification_other_vibration', value);
}
