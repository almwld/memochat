import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'security_level.dart';

class SecuritySettingsService extends ChangeNotifier {
  SecuritySettingsService._();

  static final instance = SecuritySettingsService._();

  static const _levelKey = 'security.level';
  static const _initializedKey = 'security.settings.initialized';
  static const _chatIndexKey = 'security.chat.override.ids';
  static const _encryptionIndexKey = 'security.chat.encryption.ids';
  static const _encryptionEnabledKey = 'security.e2ee.enabled';

  SharedPreferences? _prefs;
  SecurityLevel _level = SecurityLevel.standard;
  final Map<SecurityProtocol, bool> _protocols = {
    for (final protocol in SecurityProtocol.values) protocol: false,
  };
  final Map<String, Map<SecurityProtocol, bool>> _chatOverrides = {};
  final Set<String> _encryptedChats = {};
  bool _encryptionEnabled = false;

  String _chatKey(String chatId, SecurityProtocol protocol) =>
      'security.chat.$chatId.${protocol.name}';
  bool _ready = false;

  SecurityLevel get level => _level;
  bool get isReady => _ready;

  bool isEnabled(SecurityProtocol protocol) => _protocols[protocol] ?? false;

  /// Reports whether the protocol has a concrete in-app implementation.
  bool isOperational(SecurityProtocol protocol) {
    switch (protocol) {
      case SecurityProtocol.metadataProtection:
      case SecurityProtocol.onionRouting:
      case SecurityProtocol.sealedSender:
      case SecurityProtocol.postQuantumHybrid:
      case SecurityProtocol.matrixBridge:
      case SecurityProtocol.dhtDiscovery:
      case SecurityProtocol.meshOffline:
      case SecurityProtocol.quicTransport:
      case SecurityProtocol.websocketFallback:
      case SecurityProtocol.httpsFallback:
        return false;
    }
  }

  String status(SecurityProtocol protocol) =>
      isOperational(protocol) ? 'جاهز' : 'يتطلب مكوّنًا/خادمًا خارجيًا';

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

    _encryptionEnabled = prefs.getBool(_encryptionEnabledKey) ?? false;
    final encryptedIds = prefs.getStringList(_encryptionIndexKey) ?? const <String>[];
    _encryptedChats.addAll(encryptedIds);

    final chatIds = prefs.getStringList(_chatIndexKey) ?? const <String>[];
    for (final chatId in chatIds) {
      final values = <SecurityProtocol, bool>{};
      for (final protocol in SecurityProtocol.values) {
        final value = prefs.getBool(_chatKey(chatId, protocol));
        if (value != null) values[protocol] = value;
      }
      if (values.isNotEmpty) _chatOverrides[chatId] = values;
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
    if (!isOperational(protocol)) {
      throw StateError(
        'لا يمكن تفعيل البروتوكول قبل توفير التنفيذ والخدمة المطلوبة.',
      );
    }
    _protocols[protocol] = enabled;
    _level = SecurityLevel.custom;
    await _persist();
    notifyListeners();
  }

  /// E2EE is opt-in. A chat is plaintext unless the user explicitly enables it.
  bool get encryptionEnabled => _encryptionEnabled;

  bool isEncryptionEnabledForChat(String chatId) =>
      _encryptedChats.contains(chatId) || _encryptionEnabled;

  Future<void> setEncryptionEnabled(bool enabled) async {
    await _ensureReady();
    _encryptionEnabled = enabled;
    await _prefs!.setBool(_encryptionEnabledKey, enabled);
    notifyListeners();
  }

  Future<void> setChatEncryption(String chatId, bool enabled) async {
    await _ensureReady();
    if (enabled) {
      _encryptedChats.add(chatId);
    } else {
      _encryptedChats.remove(chatId);
    }
    await _prefs!.setStringList(_encryptionIndexKey, _encryptedChats.toList());
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
    if (!isOperational(protocol)) {
      throw StateError(
        'لا يمكن تفعيل البروتوكول قبل توفير التنفيذ والخدمة المطلوبة.',
      );
    }
    final values = _chatOverrides.putIfAbsent(chatId, () => {});
    values[protocol] = enabled;
    await _prefs!.setBool(_chatKey(chatId, protocol), enabled);
    final ids = _prefs!.getStringList(_chatIndexKey) ?? <String>[];
    if (!ids.contains(chatId)) {
      ids.add(chatId);
      await _prefs!.setStringList(_chatIndexKey, ids);
    }
    notifyListeners();
  }

  Future<void> resetChatOverrides(String chatId) async {
    final removed = _chatOverrides.remove(chatId);
    if (removed != null) {
      for (final protocol in removed.keys) {
        await _prefs?.remove(_chatKey(chatId, protocol));
      }
    }
    notifyListeners();
  }

  Future<void> _ensureReady() async {
    if (!_ready) await load();
  }

  void _applyPresetInMemory(SecurityLevel level) {
    for (final protocol in SecurityProtocol.values) {
      _protocols[protocol] = false;
    }

    // Default presets never enable experimental/crypto metadata behavior.
    // Every security protocol is opt-in and must have a complete implementation.

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
