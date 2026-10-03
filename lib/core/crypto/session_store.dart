import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

class MemoSignalSessionStore implements SessionStore {
  MemoSignalSessionStore({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _prefix = 'memochat.signal.session.v1.';

  String _key(SignalProtocolAddress address) {
    final name = base64UrlEncode(utf8.encode(address.getName()));
    return '$_prefix$name.\$\{address.getDeviceId()\}';
  }

  @override
  Future<bool> containsSession(SignalProtocolAddress address) async =>
      (await _storage.read(key: _key(address))) != null;

  @override
  Future<void> deleteAllSessions(String name) async {
    final all = await _storage.readAll();
    final encodedName = base64UrlEncode(utf8.encode(name));

    for (final key in all.keys) {
      if (!key.startsWith('$_prefix$encodedName.')) continue;
      await _storage.delete(key: key);
    }
  }

  @override
  Future<void> deleteSession(SignalProtocolAddress address) =>
      _storage.delete(key: _key(address));

  @override
  Future<List<int>> getSubDeviceSessions(String name) async {
    final all = await _storage.readAll();
    final encodedName = base64UrlEncode(utf8.encode(name));
    final prefix = '$_prefix$encodedName.';
    final result = <int>[];

    for (final key in all.keys) {
      if (!key.startsWith(prefix)) continue;
      final id = int.tryParse(key.substring(prefix.length));
      if (id != null && id != 1) result.add(id);
    }

    result.sort();
    return result;
  }

  @override
  Future<SessionRecord> loadSession(SignalProtocolAddress address) async {
    final encoded = await _storage.read(key: _key(address));
    if (encoded == null || encoded.isEmpty) return SessionRecord();
    return SessionRecord.fromSerialized(base64Decode(encoded));
  }

  @override
  Future<void> storeSession(
    SignalProtocolAddress address,
    SessionRecord record,
  ) {
    return _storage.write(
      key: _key(address),
      value: base64Encode(record.serialize()),
    );
  }
}
