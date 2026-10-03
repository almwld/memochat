import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

class MemoSignalIdentityStore implements IdentityKeyStore {
  MemoSignalIdentityStore({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _identityKey = 'memochat.signal.identity.v1';
  static const _registrationKey = 'memochat.signal.registration.v1';
  static const _trustedPrefix = 'memochat.signal.trusted.v1.';

  Future<IdentityKeyPair> _identity() async {
    final encoded = await _storage.read(key: _identityKey);
    if (encoded != null && encoded.isNotEmpty) {
      return IdentityKeyPair.fromSerialized(base64Decode(encoded));
    }

    final identity = generateIdentityKeyPair();
    await _storage.write(
      key: _identityKey,
      value: base64Encode(identity.serialize()),
    );
    return identity;
  }

  Future<int> _registrationId() async {
    final encoded = await _storage.read(key: _registrationKey);
    if (encoded != null && encoded.isNotEmpty) {
      return int.parse(encoded);
    }

    final registrationId = generateRegistrationId(false);
    await _storage.write(
      key: _registrationKey,
      value: registrationId.toString(),
    );
    return registrationId;
  }

  String _trustedKey(SignalProtocolAddress address) {
    final name = base64UrlEncode(utf8.encode(address.getName()));
    return '$_trustedPrefix$name.\$\{address.getDeviceId()\}';
  }

  @override
  Future<IdentityKey?> getIdentity(SignalProtocolAddress address) async {
    final encoded = await _storage.read(key: _trustedKey(address));
    if (encoded == null || encoded.isEmpty) return null;
    return IdentityKey.fromBytes(base64Decode(encoded), 0);
  }

  @override
  Future<IdentityKeyPair> getIdentityKeyPair() => _identity();

  @override
  Future<int> getLocalRegistrationId() => _registrationId();

  @override
  Future<bool> isTrustedIdentity(
    SignalProtocolAddress address,
    IdentityKey? identityKey,
    Direction? direction,
  ) async {
    if (identityKey == null) return false;

    final existing = await getIdentity(address);
    if (existing == null) return true;

    return _sameBytes(existing.serialize(), identityKey.serialize());
  }

  @override
  Future<bool> saveIdentity(
    SignalProtocolAddress address,
    IdentityKey? identityKey,
  ) async {
    if (identityKey == null) return false;

    final existing = await getIdentity(address);
    if (existing != null &&
        !_sameBytes(existing.serialize(), identityKey.serialize())) {
      return false;
    }

    await _storage.write(
      key: _trustedKey(address),
      value: base64Encode(identityKey.serialize()),
    );
    return existing == null;
  }

  bool _sameBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }

  Future<String> fingerprint() async {
    final identity = await _identity();
    return identity.getPublicKey().getFingerprint();
  }

  Future<Uint8List> exportEncryptedIdentity() async {
    final identity = await _identity();
    final registrationId = await _registrationId();
    final payload = jsonEncode({
      'version': 1,
      'registrationId': registrationId,
      'identity': base64Encode(identity.serialize()),
    });
    return Uint8List.fromList(utf8.encode(payload));
  }
}
