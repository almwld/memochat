import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'security_level.dart';

class SecuritySettingsService extends ChangeNotifier {
  SecuritySettingsService._();

  static final instance = SecuritySettingsService._();

  static const _levelKey = 'security.level';
  static const _initializedKey = 'security.settings.initialized';

  SharedPreferences? _prefs;
  SecurityLevel _level = SecurityLevel.standard;
  final Map<SecurityProtocol, bool> _protocols = {
    for (final protocol in SecurityProtocol.values) protocol: false,
  };
  final Map<String, Map<SecurityProtocol, bool>> _chatOverrides = {};
  bool _ready = false;

  SecurityLevel get level => _level;
  bool get isReady => _ready;

  bool isEnabled(SecurityProtocol protocol) => _protocols[protocol] ?? false;

  Map<SecurityProtocol, bool> get protocols =>
      Map.unmodifiable(_protocols);

  Future<void> load() async {
    if (_ready) return;

    _prefs = await SharedPreferences.getInstance();
    final prefs = _prefs!;
    final rawLevel = prefs.getString(_levelKey);
    _level = SecurityLevel.values.firstWhere(
      (value) => value.name == rawLevel,
      orElse: () => SecurityLevel.standard,
    );

    for (final protocol in SecurityProtocol.values) {
      _protocols[protocol] = prefs.getBool(protocol.storageKey) ?? false;
    }

    if (prefs.getBool(_initializedKey) != true) {
      _applyPresetInMemory(SecurityLevel.standard);
      await _persist();
    }

    _ready = true;
    notifyListeners();
  }

  Future<void> setLevel(SecurityLevel level) async {
    await _ensureReady();
    _level = level;

    switch (level) {
      case SecurityLevel.standard:
        _applyPresetInMemory(level);
      case SecurityLevel.enhanced:
        _applyPresetInMemory(level);
      case SecurityLevel.maximum:
        _applyPresetInMemory(level);
      case SecurityLevel.custom:
        break;
    }

    await _persist();
    notifyListeners();
  }

  Future<void> setProtocol(
    SecurityProtocol protocol,
    bool enabled,
  ) async {
    await _ensureReady();
    _protocols[protocol] = enabled;
    _level = SecurityLevel.custom;
    await _persist();
    notifyListeners();
  }

  bool isEnabledForChat(String chatId, SecurityProtocol protocol) {
    final override = _chatOverrides[chatId]?[protocol];
    return override ?? isEnabled(protocol);
  }

  Future<void> setChatProtocol(
    String chatId,
    SecurityProtocol protocol,
    bool enabled,
  ) async {
    await _ensureReady();
    final values = _chatOverrides.putIfAbsent(chatId, () => {});
    values[protocol] = enabled;
    notifyListeners();
  }

  Future<void> resetChatOverrides(String chatId) async {
    _chatOverrides.remove(chatId);
    notifyListeners();
  }

  Future<void> _ensureReady() async {
    if (!_ready) await load();
  }

  void _applyPresetInMemory(SecurityLevel level) {
    for (final protocol in SecurityProtocol.values) {
      _protocols[protocol] = false;
    }

    if (level == SecurityLevel.enhanced || level == SecurityLevel.maximum) {
      _protocols[SecurityProtocol.metadataProtection] = true;
      _protocols[SecurityProtocol.websocketFallback] = true;
      _protocols[SecurityProtocol.httpsFallback] = true;
    }

    if (level == SecurityLevel.maximum) {
      _protocols[SecurityProtocol.onionRouting] = true;
      _protocols[SecurityProtocol.sealedSender] = true;
      _protocols[SecurityProtocol.postQuantumHybrid] = true;
      _protocols[SecurityProtocol.quicTransport] = true;
      _protocols[SecurityProtocol.websocketFallback] = true;
      _protocols[SecurityProtocol.httpsFallback] = true;
    }
  }

  Future<void> _persist() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.setString(_levelKey, _level.name);
    await prefs.setBool(_initializedKey, true);
    for (final entry in _protocols.entries) {
      await prefs.setBool(entry.key.storageKey, entry.value);
    }
  }
}
