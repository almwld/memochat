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
    if (uid == null || uid.isEmpty) {
      throw StateError('Authentication required');
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _requests =>
      db.collection('friendRequests');

  CollectionReference<Map<String, dynamic>> get _friendships =>
      db.collection('friendships');

  String _friendshipId(String a, String b) {
    final ids = [a, b]..sort();
    return '${ids[0]}_${ids[1]}';
  }

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
    final senderId = data['senderId']?.toString();
    if (senderId == null || senderId.isEmpty) {
      throw StateError('Invalid friend request sender');
    }

    final friendship = _friendships.doc(_friendshipId(senderId, uid));
    await db.runTransaction((transaction) async {
      transaction.update(ref, {
        'state': FriendRequestState.accepted.name,
        'updatedAt': FieldValue.serverTimestamp(),
        'respondedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(
        friendship,
        {
          'participants': [senderId, uid],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'status': 'active',
          'requestId': requestId,
          'memberIds': [senderId, uid],
        },
        SetOptions(merge: true),
      );
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
    return _requests.where('recipientId', isEqualTo: _uid).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchOutgoing() {
    return _requests.where('senderId', isEqualTo: _uid).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchFriends() {
    return _friendships.where('participants', arrayContains: _uid).snapshots();
  }

  Stream<Set<String>> watchActiveFriendIds() {
    return watchFriends().map((snapshot) {
      final uid = _uid;
      final ids = <String>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['status']?.toString() != 'active') continue;
        final participants = List<String>.from(
          (data['participants'] as List?)
                  ?.map((value) => value.toString()) ??
              const <String>[],
        );
        final others = participants.where((id) => id != uid).toList(growable: false);
        if (others.isNotEmpty && others.first.isNotEmpty) ids.add(others.first);
      }
      return ids;
    });
  }

  Future<bool> isFriend(String otherUserId) async {
    final uid = _uid;
    final target = otherUserId.trim();
    if (target.isEmpty || target == uid) return false;
    final snap = await _friendships.doc(_friendshipId(uid, target)).get();
    if (!snap.exists || snap.data()?['status']?.toString() != 'active') {
      return false;
    }
    final participants = List<String>.from(
      (snap.data()?['participants'] as List?)
              ?.map((value) => value.toString()) ??
          const <String>[],
    );
    return participants.contains(uid) && participants.contains(target);
  }

  Future<void> removeFriend(String otherUserId) async {
    final uid = _uid;
    final target = otherUserId.trim();
    if (target.isEmpty || target == uid) return;

    final ref = _friendships.doc(_friendshipId(uid, target));
    final snap = await ref.get();
    if (!snap.exists) return;

    final participants = List<String>.from(
      (snap.data()?['participants'] as List?)
              ?.map((e) => e.toString()) ??
          const <String>[],
    );
    if (!participants.contains(uid)) {
      throw StateError('Not a friendship participant');
    }

    await ref.update({
      'status': 'removed',
      'updatedAt': FieldValue.serverTimestamp(),
      'removedBy': uid,
    });
  }
}
