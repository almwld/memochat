import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PrivacyService {
  PrivacyService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _uid => _auth.currentUser?.uid ?? '';

  DocumentReference<Map<String, dynamic>> _blockRef(String userId) {
    return _firestore
        .collection('users')
        .doc(_uid)
        .collection('private')
        .doc('blocks');
  }

  Future<Set<String>> getBlockedUserIds() async {
    if (_uid.isEmpty) return <String>{};
    final snapshot = await _blockRef(_uid).get();
    final raw = snapshot.data()?['userIds'];
    if (raw is! List) return <String>{};
    return raw.map((value) => value.toString()).where((id) => id.isNotEmpty).toSet();
  }

  Future<bool> isBlocked(String userId) async {
    if (_uid.isEmpty || userId.isEmpty || userId == _uid) return false;
    return (await getBlockedUserIds()).contains(userId);
  }

  Future<void> blockUser(String userId) async {
    _requireUser(userId);
    await _blockRef(userId).set({
      'userIds': FieldValue.arrayUnion([userId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> unblockUser(String userId) async {
    _requireUser(userId);
    await _blockRef(userId).set({
      'userIds': FieldValue.arrayRemove([userId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> reportUser({
    required String userId,
    required String reason,
  }) async {
    _requireUser(userId);
    final cleanReason = reason.trim();
    if (cleanReason.isEmpty || cleanReason.length > 500) {
      throw ArgumentError.value(reason, 'reason', 'سبب البلاغ غير صالح');
    }
    await _firestore.collection('reports').add({
      'reporterId': _uid,
      'targetUserId': userId,
      'reason': cleanReason,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  void _requireUser(String userId) {
    if (_uid.isEmpty) throw StateError('يرجى تسجيل الدخول');
    if (userId.trim().isEmpty || userId == _uid) {
      throw ArgumentError.value(userId, 'userId', 'معرّف المستخدم غير صالح');
    }
  }
}
