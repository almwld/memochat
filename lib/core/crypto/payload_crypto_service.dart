import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Application-level payload protection.
///
/// Firebase/Nextcloud/Railway receive only the resulting envelope. Private
/// identity material never leaves the device. The key-exchange layer is kept
/// behind this service so the chat/media code does not know how encryption
/// works.
class PayloadCryptoService {
  PayloadCryptoService._();
  static final instance = PayloadCryptoService._();

  static const _version = 1;
  static const _privateKey = 'memochat.e2ee.x25519.private.v1';
  static const _publicKey = 'memochat.e2ee.x25519.public.v1';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final X25519 _x25519 = X25519();
  final AesGcm _aes = AesGcm.with256bits();
  final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  Future<SimpleKeyPairData> _localKeyPair() async {
    final privateRaw = await _storage.read(key: _privateKey);
    final publicRaw = await _storage.read(key: _publicKey);

    if (privateRaw != null && publicRaw != null) {
      return SimpleKeyPairData(
        base64Decode(privateRaw),
        publicKey: SimplePublicKey(
          base64Decode(publicRaw),
          type: KeyPairType.x25519,
        ),
        type: KeyPairType.x25519,
        debugLabel: 'MemoChat E2EE identity',
      );
    }

    final generated = await _x25519.newKeyPair();
    final data = await generated.extract();
    final publicKey = await generated.extractPublicKey();
    await _storage.write(
      key: _privateKey,
      value: base64Encode(data.bytes),
    );
    await _storage.write(
      key: _publicKey,
      value: base64Encode(publicKey.bytes),
    );
    return data;
  }

  Future<void> ensureReady() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('يجب تسجيل الدخول لتهيئة التشفير');
    }
    final pair = await _localKeyPair();
    final publicKey = await pair.extractPublicKey();
    await _firestore.collection('users').doc(uid).set({
      'e2ee': {
        'version': _version,
        'algorithm': 'X25519-HKDF-SHA256-AES-256-GCM',
        'encryptionPublicKey': base64Encode(publicKey.bytes),
      },
    }, SetOptions(merge: true));
  }

  Future<String> publicKey() async {
    final pair = await _localKeyPair();
    final publicKey = await pair.extractPublicKey();
    return base64Encode(publicKey.bytes);
  }

  Future<Map<String, dynamic>> encryptForUser({
    required String recipientUid,
    required String kind,
    required List<int> plaintext,
    Map<String, dynamic>? context,
  }) async {
    final senderUid = _auth.currentUser?.uid;
    if (senderUid == null || senderUid.isEmpty) {
      throw StateError('يجب تسجيل الدخول قبل التشفير');
    }
    if (recipientUid.isEmpty) {
      throw ArgumentError('معرّف المستلم غير صالح');
    }

    final localPair = await _localKeyPair();
    final remote = await _firestore.collection('users').doc(recipientUid).get();
    final remoteData = remote.data()?['e2ee'];
    final remotePublic = remoteData is Map
        ? remoteData['encryptionPublicKey']?.toString()
        : null;
    if (remotePublic == null || remotePublic.isEmpty) {
      throw StateError('المستلم لم يجهز التشفير بعد');
    }

    final ephemeral = await _x25519.newKeyPair();
    final ephemeralPublic = await ephemeral.extractPublicKey();
    final remoteKey = SimplePublicKey(
      base64Decode(remotePublic),
      type: KeyPairType.x25519,
    );
    final shared = await _x25519.sharedSecretKey(
      keyPair: ephemeral,
      remotePublicKey: remoteKey,
    );
    final derived = await _hkdf.deriveKey(
      secretKey: shared,
      info: utf8.encode('MemoChat-E2EE-v$_version|$kind|$recipientUid'),
    );
    final aad = utf8.encode(
      jsonEncode({
        'v': _version,
        'kind': kind,
        'senderId': senderUid,
        'recipientId': recipientUid,
        ...?context,
      }),
    );
    final box = await _aes.encrypt(
      plaintext,
      secretKey: derived,
      aad: aad,
    );
    final localPublic = await localPair.extractPublicKey();

    return {
      'v': _version,
      'alg': 'X25519-HKDF-SHA256-AES-256-GCM',
      'kind': kind,
      'senderId': senderUid,
      'recipientId': recipientUid,
      'senderPublicKey': base64Encode(localPublic.bytes),
      'ephemeralPublicKey': base64Encode(ephemeralPublic.bytes),
      'nonce': base64Encode(box.nonce),
      'ciphertext': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
      if (context != null) 'context': context,
    };
  }

  Future<Uint8List> decryptEnvelope(Map<String, dynamic> envelope) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('يجب تسجيل الدخول لفك التشفير');
    }
    if (envelope['v'] != _version) {
      throw StateError('إصدار تشفير غير مدعوم');
    }
    if (envelope['recipientId']?.toString() != uid) {
      throw StateError('هذه الرسالة ليست موجهة لهذا الجهاز');
    }

    final senderUid = envelope['senderId']?.toString() ?? '';
    final senderPublic = envelope['senderPublicKey']?.toString() ?? '';
    final ephemeralPublic = envelope['ephemeralPublicKey']?.toString() ?? '';
    if (senderUid.isEmpty || senderPublic.isEmpty || ephemeralPublic.isEmpty) {
      throw StateError('غلاف تشفير غير مكتمل');
    }

    final senderDoc = await _firestore.collection('users').doc(senderUid).get();
    final expected = senderDoc.data()?['e2ee'];
    final expectedPublic = expected is Map
        ? expected['encryptionPublicKey']?.toString()
        : null;
    if (expectedPublic == null || expectedPublic != senderPublic) {
      throw StateError('مفتاح هوية المرسل غير موثوق أو تغير');
    }

    final kind = envelope['kind']?.toString() ?? 'payload';
    final localPair = await _localKeyPair();
    final remoteEphemeral = SimplePublicKey(
      base64Decode(ephemeralPublic),
      type: KeyPairType.x25519,
    );
    final shared = await _x25519.sharedSecretKey(
      keyPair: localPair,
      remotePublicKey: remoteEphemeral,
    );
    final derived = await _hkdf.deriveKey(
      secretKey: shared,
      info: utf8.encode('MemoChat-E2EE-v$_version|$kind|$uid'),
    );
    final rawContext = envelope['context'];
    final context = rawContext is Map
        ? Map<String, dynamic>.from(rawContext)
        : <String, dynamic>{};
    final aad = utf8.encode(
      jsonEncode({
        'v': _version,
        'kind': kind,
        'senderId': senderUid,
        'recipientId': uid,
        ...context,
      }),
    );
    final box = SecretBox(
      base64Decode(envelope['ciphertext']?.toString() ?? ''),
      nonce: base64Decode(envelope['nonce']?.toString() ?? ''),
      mac: Mac(base64Decode(envelope['mac']?.toString() ?? '')),
    );
    final clear = await _aes.decrypt(box, secretKey: derived, aad: aad);
    return Uint8List.fromList(clear);
  }

  Future<String> encryptText({
    required String recipientUid,
    required String text,
    Map<String, dynamic>? context,
  }) async {
    final envelope = await encryptForUser(
      recipientUid: recipientUid,
      kind: 'text',
      plaintext: utf8.encode(text),
      context: context,
    );
    return jsonEncode(envelope);
  }

  Future<String> decryptText(String encodedEnvelope) async {
    final decoded = jsonDecode(encodedEnvelope);
    if (decoded is! Map) throw StateError('غلاف تشفير غير صالح');
    final clear = await decryptEnvelope(Map<String, dynamic>.from(decoded));
    return utf8.decode(clear);
  }
}
