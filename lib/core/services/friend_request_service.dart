import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum FriendRequestState { pending, accepted, rejected, cancelled }

class FriendRequestService {
  final FirebaseFirestore db;
  final FirebaseAuth auth;

  FriendRequestService({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
      : db = firestore ?? FirebaseFirestore.instance,
        auth = firebaseAuth ?? FirebaseAuth.instance;

  String get _uid {
    final uid = auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) throw StateError('Authentication required');
    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _requests =>
      db.collection('friendRequests');

  Future<String> send({
    required String recipientId,
    String? recipientName,
  }) async {
    final senderId = _uid;
    final target = recipientId.trim();
    if (target.isEmpty || target == senderId) {
      throw ArgumentError('Invalid recipient');
    }

    final existing = await _requests
        .where('senderId', isEqualTo: senderId)
        .where('recipientId', isEqualTo: target)
        .where('state', isEqualTo: FriendRequestState.pending.name)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return existing.docs.first.id;

    final reverse = await _requests
        .where('senderId', isEqualTo: target)
        .where('recipientId', isEqualTo: senderId)
        .where('state', isEqualTo: FriendRequestState.pending.name)
        .limit(1)
        .get();
    if (reverse.docs.isNotEmpty) {
      await accept(reverse.docs.first.id);
      return reverse.docs.first.id;
    }

    final ref = _requests.doc();
    await ref.set({
      'senderId': senderId,
      'recipientId': target,
      'senderName': auth.currentUser?.displayName,
      'recipientName': recipientName,
      'state': FriendRequestState.pending.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> accept(String requestId) async {
    final uid = _uid;
    final ref = _requests.doc(requestId);
    final snap = await ref.get();
    if (!snap.exists) throw StateError('Friend request not found');
    final data = snap.data()!;
    if (data['recipientId']?.toString() != uid) {
      throw StateError('Not the request recipient');
    }
    if (data['state'] != FriendRequestState.pending.name) {
      throw StateError('Request is no longer pending');
    }
    await ref.update({
      'state': FriendRequestState.accepted.name,
      'updatedAt': FieldValue.serverTimestamp(),
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reject(String requestId) async {
    final uid = _uid;
    final ref = _requests.doc(requestId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final data = snap.data()!;
    if (data['recipientId']?.toString() != uid) {
      throw StateError('Not the request recipient');
    }
    await ref.update({
      'state': FriendRequestState.rejected.name,
      'updatedAt': FieldValue.serverTimestamp(),
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancel(String requestId) async {
    final uid = _uid;
    final ref = _requests.doc(requestId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final data = snap.data()!;
    if (data['senderId']?.toString() != uid) {
      throw StateError('Not the request sender');
    }
    await ref.update({
      'state': FriendRequestState.cancelled.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchIncoming() {
    return _requests
        .where('recipientId', isEqualTo: _uid)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchOutgoing() {
    return _requests
        .where('senderId', isEqualTo: _uid)
        .snapshots();
  }
}
