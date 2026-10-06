import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum SignalTrustState {
  unverified,
  verified,
  changed,
}

class SignalConversationTrustStore {
  SignalConversationTrustStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _prefix = 'memochat.signal.conversation-trust.v1.';

  String _key(String chatId, String remoteUid, int deviceId) {
    final encodedChat = base64UrlEncode(utf8.encode(chatId));
    final encodedUser = base64UrlEncode(utf8.encode(remoteUid));
    return '${_prefix}${encodedChat}.${encodedUser}.$deviceId';
  }

  Future<SignalTrustState> state(String chatId, String remoteUid, {int deviceId = 1}) async {
    final value = await _storage.read(key: _key(chatId, remoteUid, deviceId));
    return SignalTrustState.values.firstWhere(
      (item) => item.name == value,
      orElse: () => SignalTrustState.unverified,
    );
  }

  Future<String?> fingerprint(String chatId, String remoteUid, {int deviceId = 1}) =>
      _storage.read(key: '${_key(chatId, remoteUid, deviceId)}.fp');

  Future<void> observe(String chatId, String remoteUid, String fingerprint, {int deviceId = 1}) async {
    final key = _key(chatId, remoteUid, deviceId);
    final previous = await this.fingerprint(chatId, remoteUid, deviceId: deviceId);
    if (previous != null && previous != fingerprint) {
      await _storage.write(key: key, value: SignalTrustState.changed.name);
      return;
    }
    if (await _storage.read(key: key) == null) {
      await _storage.write(key: key, value: SignalTrustState.unverified.name);
    }
    await _storage.write(key: '$key.fp', value: fingerprint);
  }

  Future<void> markVerified(String chatId, String remoteUid, String fingerprint, {int deviceId = 1}) async {
    await observe(chatId, remoteUid, fingerprint, deviceId: deviceId);
    final key = _key(chatId, remoteUid, deviceId);
    if (await state(chatId, remoteUid, deviceId: deviceId) == SignalTrustState.changed) {
      throw StateError('هوية جهة الاتصال تغيّرت؛ لا يمكن اعتمادها تلقائيًا');
    }
    await _storage.write(key: key, value: SignalTrustState.verified.name);
  }

  Future<void> markChanged(String chatId, String remoteUid, {int deviceId = 1}) =>
      _storage.write(key: _key(chatId, remoteUid, deviceId), value: SignalTrustState.changed.name);
}
