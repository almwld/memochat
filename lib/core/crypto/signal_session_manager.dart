import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import 'identity_store.dart';
import 'prekey_store.dart';
import 'session_store.dart';
import 'signed_prekey_store.dart';
import 'signal_trust_store.dart';

class SignalSessionManager {
  SignalSessionManager._();

  static final instance = SignalSessionManager._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final MemoSignalIdentityStore identityStore = MemoSignalIdentityStore();
  final MemoSignalPreKeyStore preKeyStore = MemoSignalPreKeyStore();
  final MemoSignalSignedPreKeyStore signedPreKeyStore =
      MemoSignalSignedPreKeyStore();
  final MemoSignalSessionStore sessionStore = MemoSignalSessionStore();
  final SignalConversationTrustStore trustStore = SignalConversationTrustStore();

  final Map<String, Future<void>> _queues = {};
  Future<void>? _initialization;

  Future<void> initialize() {
    return _initialization ??= _install();
  }

  Future<void> _install() async {
    await identityStore.getIdentityKeyPair();
    await identityStore.getLocalRegistrationId();

    await _ensurePreKeyPool();

    final signed = await signedPreKeyStore.loadSignedPreKeys();
    final now = DateTime.now().millisecondsSinceEpoch;
        final newest = signed.isEmpty ? null : signed.last;
    if (newest == null || now - newest.timestamp.toInt() >= const Duration(days: 7).inMilliseconds) {
      final id = now ~/ 1000;
      final identity = await identityStore.getIdentityKeyPair();
      final record = generateSignedPreKey(identity, id);
      await signedPreKeyStore.storeSignedPreKey(id, record);
    }
    final refreshed = await signedPreKeyStore.loadSignedPreKeys();
    for (final record in refreshed) {
      if (now - record.timestamp.toInt() > const Duration(days: 30).inMilliseconds && record.id != refreshed.last.id) {
        await signedPreKeyStore.removeSignedPreKey(record.id);
      }
    }
  }

  Future<Map<String, dynamic>> publicBundle() async {
    await initialize();
    await _ensurePreKeyPool();

    final identity = await identityStore.getIdentityKeyPair();
    final registrationId = await identityStore.getLocalRegistrationId();
    final signedKeys = await signedPreKeyStore.loadSignedPreKeys();
    if (signedKeys.isEmpty) {
      throw StateError('Signal signed pre-key is unavailable');
    }

    final signed = signedKeys.last;
    final preKey = await _firstAvailablePreKey();

    return {
      'version': 1,
      'deviceId': 1,
      'registrationId': registrationId,
      'identityKey': base64Encode(identity.getPublicKey().serialize()),
      'signedPreKeyId': signed.id,
      'signedPreKeyPublic':
          base64Encode(signed.getKeyPair().publicKey.serialize()),
      'signedPreKeySignature': base64Encode(signed.signature),
      'preKeyId': preKey.id,
      'preKeyPublic': base64Encode(preKey.getKeyPair().publicKey.serialize()),
    };
  }

  Future<void> ensureReady() async {
    await initialize();
    await publishPublicBundle();
  }

  Future<String> localFingerprint() => identityStore.fingerprint();

  Future<String> remoteFingerprint(String remoteUid, {int deviceId = 1}) async {
    final bundle = await _loadBundle(remoteUid, deviceId);
    return bundle.getIdentityKey().getFingerprint();
  }

  Future<SignalTrustState> conversationTrustState(String chatId, String remoteUid, {int deviceId = 1}) =>
      trustStore.state(chatId, remoteUid, deviceId: deviceId);

  Future<void> verifyConversationIdentity(String chatId, String remoteUid, {int deviceId = 1}) async {
    final fingerprint = await remoteFingerprint(remoteUid, deviceId: deviceId);
    await trustStore.markVerified(chatId, remoteUid, fingerprint, deviceId: deviceId);
  }

  Future<void> publishPublicBundle() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('يجب تسجيل الدخول لنشر حزمة Signal');
    }

    final bundle = await publicBundle();
    await _firestore.collection('users').doc(uid).set(
      {'signal': bundle},
      SetOptions(merge: true),
    );
  }

  Future<SessionCipher> cipherFor(
    String remoteUid, {
    int deviceId = 1,
  }) async {
    await initialize();
    final address = SignalProtocolAddress(remoteUid, deviceId);
    return _withAddressLock(address, () async {
      final bundle = await _loadBundle(remoteUid, deviceId);
      await _observeRemoteTrust(chatId, remoteUid, bundle, deviceId);
      await _ensureSession(address, bundle);
      return SessionCipher(
        sessionStore,
        preKeyStore,
        signedPreKeyStore,
        identityStore,
        address,
      );
    });
  }

  Future<PreKeyBundle> _loadBundle(
    String remoteUid,
    int deviceId,
  ) async {
    final remote = await _firestore.collection('users').doc(remoteUid).get();
    final data = remote.data()?['signal'];
    if (data is! Map) {
      throw StateError('حزمة Signal للمستلم غير متاحة');
    }

    return PreKeyBundle(
      _intValue(data['registrationId']),
      _intValue(data['deviceId'], fallback: deviceId),
      _nullableInt(data['preKeyId']),
      _decodePublic(data['preKeyPublic']),
      _intValue(data['signedPreKeyId']),
      _decodePublic(data['signedPreKeyPublic']),
      _decodeBytes(data['signedPreKeySignature']),
      IdentityKey.fromBytes(_decodeBytes(data['identityKey']), 0),
    );
  }

  Future<void> _ensureSession(
    SignalProtocolAddress address,
    PreKeyBundle bundle,
  ) async {
    if (await sessionStore.containsSession(address)) return;
    final builder = SessionBuilder(
      sessionStore,
      preKeyStore,
      signedPreKeyStore,
      identityStore,
      address,
    );
    await builder.processPreKeyBundle(bundle);
  }

  Future<Uint8List> encryptFor(
    String remoteUid,
    List<int> plaintext, {
    String? chatId,
    int deviceId = 1,
  }) async {
    final address = SignalProtocolAddress(remoteUid, deviceId);
    return _withAddressLock(address, () async {
      final bundle = await _loadBundle(remoteUid, deviceId);
      await _ensureSession(address, bundle);
      final cipher = SessionCipher(
        sessionStore,
        preKeyStore,
        signedPreKeyStore,
        identityStore,
        address,
      );
      final message = await cipher.encrypt(Uint8List.fromList(plaintext));
      return message.serialize();
    });
  }

  Future<Uint8List> decryptFrom(
    String remoteUid,
    Uint8List serialized, {
    String? chatId,
    int deviceId = 1,
  }) async {
    final address = SignalProtocolAddress(remoteUid, deviceId);
    return _withAddressLock(address, () async {
      if (chatId != null && chatId.isNotEmpty) {
        try {
          final bundle = await _loadBundle(remoteUid, deviceId);
          await _observeRemoteTrust(chatId, remoteUid, bundle, deviceId);
        } catch (error) {
          if (error is StateError && error.message.contains('هوية جهة الاتصال')) rethrow;
        }
      }
      final cipher = SessionCipher(
        sessionStore,
        preKeyStore,
        signedPreKeyStore,
        identityStore,
        address,
      );

      if (serialized.isEmpty) {
        throw StateError('رسالة Signal فارغة');
      }

      final type = serialized[0] & 0x03;
      final clear = type == CiphertextMessage.prekeyType
          ? await cipher.decrypt(PreKeySignalMessage(serialized))
          : await cipher.decryptFromSignal(SignalMessage.fromSerialized(serialized));
      await _ensurePreKeyPool();
      if (type == CiphertextMessage.prekeyType) await publishPublicBundle();
      return clear;
    });
  }

  Future<void> _ensurePreKeyPool() async {
    const target = 100;
    var available = 0;
    for (var id = 1; id <= target; id++) {
      if (await preKeyStore.containsPreKey(id)) available++;
    }
    for (var id = 1; id <= target && available < target; id++) {
      if (await preKeyStore.containsPreKey(id)) continue;
      await preKeyStore.storePreKey(id, generatePreKeys(id, 1).single);
      available++;
    }
  }

  Future<void> _observeRemoteTrust(String? chatId, String remoteUid, PreKeyBundle bundle, int deviceId) async {
    if (chatId == null || chatId.isEmpty) return;
    final fingerprint = bundle.getIdentityKey().getFingerprint();
    final current = await trustStore.state(chatId, remoteUid, deviceId: deviceId);
    final stored = await trustStore.fingerprint(chatId, remoteUid, deviceId: deviceId);
    if (stored != null && stored != fingerprint) {
      await trustStore.markChanged(chatId, remoteUid, deviceId: deviceId);
      throw StateError('هوية جهة الاتصال تغيّرت؛ تحقّق من رمز الأمان قبل المتابعة');
    }
    if (current == SignalTrustState.changed) {
      throw StateError('هوية جهة الاتصال معلّمة كمتغيّرة؛ تحقّق من رمز الأمان');
    }
    await trustStore.observe(chatId, remoteUid, fingerprint, deviceId: deviceId);
  }

  Future<PreKeyRecord> _firstAvailablePreKey() async {
    for (var id = 1; id <= 100; id++) {
      if (await preKeyStore.containsPreKey(id)) {
        return preKeyStore.loadPreKey(id);
      }
    }
    throw StateError('لا توجد One-Time PreKeys متاحة');
  }

  Future<T> _withAddressLock<T>(
    SignalProtocolAddress address,
    Future<T> Function() operation,
  ) async {
    final key = address.getName() + ':' + address.getDeviceId().toString();
    final previous = (_queues[key] ?? Future<void>.value()).catchError((_) {});
    final gate = Completer<void>();
    final current = previous.then((_) => gate.future);
    _queues[key] = current;

    try {
      await previous;
      return await operation();
    } finally {
      gate.complete();
      if (identical(_queues[key], current)) {
        _queues.remove(key);
      }
    }
  }

  int _intValue(Object? value, {int fallback = 0}) =>
      int.tryParse(value?.toString() ?? '') ?? fallback;

  int? _nullableInt(Object? value) {
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  Uint8List _decodeBytes(Object? value) =>
      Uint8List.fromList(base64Decode(value?.toString() ?? ''));

  ECPublicKey _decodePublic(Object? value) =>
      Curve.decodePoint(_decodeBytes(value), 0);
}
