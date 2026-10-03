import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

class MemoSignalPreKeyStore implements PreKeyStore {
  MemoSignalPreKeyStore({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _prefix = 'memochat.signal.prekey.v1.';

  String _key(int id) => '$_prefix$id';

  @override
  Future<bool> containsPreKey(int preKeyId) async =>
      (await _storage.read(key: _key(preKeyId))) != null;

  @override
  Future<PreKeyRecord> loadPreKey(int preKeyId) async {
    final encoded = await _storage.read(key: _key(preKeyId));
    if (encoded == null || encoded.isEmpty) {
      throw StateError('Signal pre-key $preKeyId is unavailable');
    }
    return PreKeyRecord.fromBuffer(base64Decode(encoded));
  }

  @override
  Future<void> removePreKey(int preKeyId) =>
      _storage.delete(key: _key(preKeyId));

  @override
  Future<void> storePreKey(int preKeyId, PreKeyRecord record) {
    return _storage.write(
      key: _key(preKeyId),
      value: base64Encode(record.serialize()),
    );
  }
}
