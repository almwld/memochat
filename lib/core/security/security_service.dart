import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography_flutter/cryptography_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Local security layer for sensitive device-side data.
/// This is separate from transport/E2EE and must never be advertised as Signal Protocol.
class SecurityService {
  SecurityService._();
  static final instance = SecurityService._();

  static const _enabledKey = 'security.military.enabled';
  static const _masterKey = 'security.military.master.v1';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final AesGcm _cipher = AesGcm.with256bits();

  bool _enabled = false;
  bool get isMilitaryEncryptionEnabled => _enabled;

  String get endToEndEncryptionStatus =>
      'تشفير الرسائل طرفًا لطرف: غير مفعّل بعد — لا يتم الادعاء بأنه E2EE.';

  Future<void> initialize() async {
    FlutterCryptography.enable();
    _enabled = (await _storage.read(key: _enabledKey)) == '1';
    if (_enabled) await _ensureMasterKey();
  }

  Future<void> setMilitaryEncryptionEnabled(bool enabled) async {
    FlutterCryptography.enable();
    if (enabled) await _ensureMasterKey();
    _enabled = enabled;
    await _storage.write(key: _enabledKey, value: enabled ? '1' : '0');
  }

  Future<void> _ensureMasterKey() async {
    final existing = await _storage.read(key: _masterKey);
    if (existing != null && existing.isNotEmpty) return;
    final key = await _cipher.newSecretKey();
    final bytes = await key.extractBytes();
    await _storage.write(key: _masterKey, value: base64UrlEncode(bytes));
  }

  Future<SecretKey> _key() async {
    await _ensureMasterKey();
    final encoded = await _storage.read(key: _masterKey);
    if (encoded == null || encoded.isEmpty) {
      throw StateError('مفتاح الحماية المحلي غير متاح.');
    }
    return SecretKey(base64Url.decode(encoded));
  }

  Future<String> encryptLocal(String plaintext, {List<int>? associatedData}) async {
    if (!_enabled) return plaintext;
    final secretBox = await _cipher.encrypt(
      utf8.encode(plaintext),
      secretKey: await _key(),
      aad: associatedData ?? const <int>[],
    );
    return jsonEncode(<String, String>{
      'v': '1',
      'alg': 'AES-256-GCM',
      'nonce': base64UrlEncode(secretBox.nonce),
      'ciphertext': base64UrlEncode(secretBox.cipherText),
      'mac': base64UrlEncode(secretBox.mac.bytes),
    });
  }

  Future<String> decryptLocal(String payload, {List<int>? associatedData}) async {
    if (!_enabled) return payload;
    final map = jsonDecode(payload);
    if (map is! Map || map['alg'] != 'AES-256-GCM') {
      throw const FormatException('بيانات التشفير المحلي غير صالحة.');
    }
    final box = SecretBox(
      base64Url.decode(map['ciphertext'].toString()),
      nonce: base64Url.decode(map['nonce'].toString()),
      mac: Mac(base64Url.decode(map['mac'].toString())),
    );
    final clear = await _cipher.decrypt(
      box,
      secretKey: await _key(),
      aad: associatedData ?? const <int>[],
    );
    return utf8.decode(clear);
  }
}
