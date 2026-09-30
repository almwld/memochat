import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CommunityService {
  CommunityService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _uid => _auth.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> get _communities =>
      _firestore.collection('communities');

  Future<String> createCommunity({
    required String name,
    String description = '',
  }) async {
    _requireUser();
    final cleanName = name.trim();
    if (cleanName.length < 2 || cleanName.length > 80) {
      throw ArgumentError.value(name, 'name', 'اسم المجتمع غير صالح');
    }
    if (description.trim().length > 500) {
      throw ArgumentError.value(description, 'description', 'الوصف طويل');
    }

    final community = _communities.doc();
    final member = community.collection('members').doc(_uid);
    final batch = _firestore.batch();
    batch.set(community, {
      'name': cleanName,
      'description': description.trim(),
      'ownerId': _uid,
      'visibility': 'public',
      'membersCount': 1,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(member, {
      'userId': _uid,
      'role': 'owner',
      'joinedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return community.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchPublicCommunities({
    int limit = 30,
  }) {
    return _communities
        .where('visibility', isEqualTo: 'public')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  Future<bool> isMember(String communityId) async {
    _requireUser();
    final doc = await _communities
        .doc(communityId)
        .collection('members')
        .doc(_uid)
        .get();
    return doc.exists;
  }

  Future<void> joinCommunity(String communityId) async {
    _requireUser();
    final ref = _communities.doc(communityId);
    final member = ref.collection('members').doc(_uid);
    final existing = await member.get();
    if (existing.exists) return;
    await member.set({
      'userId': _uid,
      'role': 'member',
      'joinedAt': FieldValue.serverTimestamp(),
    });
    await ref.update({
      'membersCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> leaveCommunity(String communityId) async {
    _requireUser();
    final ref = _communities.doc(communityId);
    final community = await ref.get();
    if (!community.exists || community.data()?['ownerId'] == _uid) return;
    final member = ref.collection('members').doc(_uid);
    final existing = await member.get();
    if (!existing.exists) return;
    await member.delete();
    await ref.update({
      'membersCount': FieldValue.increment(-1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> createChannel({
    required String communityId,
    required String name,
    String description = '',
  }) async {
    _requireUser();
    final cleanName = name.trim();
    if (cleanName.length < 2 || cleanName.length > 80) {
      throw ArgumentError.value(name, 'name', 'اسم القناة غير صالح');
    }
    final channel = _communities.doc(communityId).collection('channels').doc();
    await channel.set({
      'communityId': communityId,
      'name': cleanName,
      'description': description.trim(),
      'ownerId': _uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return channel.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchChannels(String communityId) {
    return _communities
        .doc(communityId)
        .collection('channels')
        .orderBy('createdAt')
        .snapshots();
  }

  Future<void> sendChannelPost({
    required String communityId,
    required String channelId,
    required String text,
  }) async {
    _requireUser();
    final cleanText = text.trim();
    if (cleanText.isEmpty || cleanText.length > 4000) {
      throw ArgumentError.value(text, 'text', 'المنشور غير صالح');
    }
    await _communities
        .doc(communityId)
        .collection('channels')
        .doc(channelId)
        .collection('posts')
        .add({
      'authorId': _uid,
      'text': cleanText,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchPosts({
    required String communityId,
    required String channelId,
  }) {
    return _communities
        .doc(communityId)
        .collection('channels')
        .doc(channelId)
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();
  }

  void _requireUser() {
    if (_uid.isEmpty) throw StateError('يرجى تسجيل الدخول');
  }
}
