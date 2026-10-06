import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/crypto/signal_session_manager.dart';

class GameChallengeInvitation {
  const GameChallengeInvitation({required this.id, required this.fromUid, required this.toUid, required this.status, required this.payload, this.createdAt});
  final String id;
  final String fromUid;
  final String toUid;
  final String status;
  final Map<String, dynamic> payload;
  final DateTime? createdAt;

  String get gameId => payload['gameId']?.toString() ?? '';
  String get chatId => payload['chatId']?.toString() ?? '';
  String get gameType => payload['gameType']?.toString() ?? '';
}

/// Direct friend challenges. Game metadata is never stored in plaintext: the
/// invitation payload is encrypted with the existing libsignal session.
class GameChallengeService {
  GameChallengeService._();
  static final instance = GameChallengeService._();
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _signal = SignalSessionManager.instance;

  Future<String?> create({required String gameId, required String opponentUid, required String chatId, required String gameType}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || opponentUid.isEmpty || opponentUid == uid) return null;
    await _signal.ensureReady();
    final clear = jsonEncode({'gameId': gameId, 'chatId': chatId, 'gameType': gameType, 'issuedAt': DateTime.now().toUtc().toIso8601String()});
    final cipher = await _signal.encryptFor(opponentUid, utf8.encode(clear));
    final ref = _db.collection('gameChallenges').doc();
    await ref.set({'id': ref.id, 'fromUid': uid, 'toUid': opponentUid, 'status': 'pending', 'signalProtocol': 'libsignal', 'signalPayload': base64Encode(cipher), 'createdAt': FieldValue.serverTimestamp()});
    return ref.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchIncoming() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _db.collection('gameChallenges').where('toUid', isEqualTo: uid).where('status', isEqualTo: 'pending').orderBy('createdAt', descending: true).snapshots();
  }

  Future<GameChallengeInvitation?> decrypt(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    if (data == null) return null;
    final sender = data['fromUid']?.toString() ?? '';
    final encoded = data['signalPayload']?.toString() ?? '';
    if (sender.isEmpty || encoded.isEmpty) return null;
    final clear = await _signal.decryptFrom(sender, Uint8List.fromList(base64Decode(encoded)));
    final decoded = jsonDecode(utf8.decode(clear));
    if (decoded is! Map) return null;
    final created = (data['createdAt'] as Timestamp?)?.toDate();
    return GameChallengeInvitation(id: doc.id, fromUid: sender, toUid: data['toUid']?.toString() ?? '', status: data['status']?.toString() ?? 'pending', payload: Map<String, dynamic>.from(decoded), createdAt: created);
  }

  Future<void> respond({required String challengeId, required bool accept}) async {
    await _db.collection('gameChallenges').doc(challengeId).update({'status': accept ? 'accepted' : 'declined', 'respondedAt': FieldValue.serverTimestamp()});
  }
}
