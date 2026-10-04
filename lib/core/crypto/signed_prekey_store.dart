import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

class MemoSignalSignedPreKeyStore implements SignedPreKeyStore {
  MemoSignalSignedPreKeyStore({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _prefix = 'memochat.signal.signedprekey.v1.';

  String _key(int id) => '$_prefix$id';

  @override
  Future<bool> containsSignedPreKey(int signedPreKeyId) async =>
      (await _storage.read(key: _key(signedPreKeyId))) != null;

  @override
  Future<SignedPreKeyRecord> loadSignedPreKey(int signedPreKeyId) async {
    final encoded = await _storage.read(key: _key(signedPreKeyId));
    if (encoded == null || encoded.isEmpty) {
      throw StateError('Signal signed pre-key $signedPreKeyId is unavailable');
    }
    return SignedPreKeyRecord.fromSerialized(base64Decode(encoded));
  }

  @override
  Future<List<SignedPreKeyRecord>> loadSignedPreKeys() async {
    final all = await _storage.readAll();
    final records = <SignedPreKeyRecord>[];

    for (final entry in all.entries) {
      if (!entry.key.startsWith(_prefix) || entry.value.isEmpty) continue;
      records.add(
        SignedPreKeyRecord.fromSerialized(base64Decode(entry.value)),
      );
    }

    records.sort((a, b) => a.id.compareTo(b.id));
    return records;
  }

  @override
  Future<void> removeSignedPreKey(int signedPreKeyId) =>
      _storage.delete(key: _key(signedPreKeyId));

  @override
  Future<void> storeSignedPreKey(
    int signedPreKeyId,
    SignedPreKeyRecord record,
  ) {
    return _storage.write(
      key: _key(signedPreKeyId),
      value: base64Encode(record.serialize()),
    );
  }
}
