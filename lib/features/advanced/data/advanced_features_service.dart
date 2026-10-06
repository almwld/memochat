import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdvancedFeaturesService {
  AdvancedFeaturesService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get uid {
    final value = _auth.currentUser?.uid;
    if (value == null || value.isEmpty) throw StateError('يجب تسجيل الدخول أولاً');
    return value;
  }

  CollectionReference<Map<String, dynamic>> get _rooms => _db.collection('voiceRooms');
  CollectionReference<Map<String, dynamic>> get _businesses => _db.collection('businesses');

  Stream<QuerySnapshot<Map<String, dynamic>>> watchVoiceRooms() => _rooms
      .where('active', isEqualTo: true)
      .orderBy('updatedAt', descending: true)
      .limit(50)
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchRoomMembers(String roomId) =>
      _rooms.doc(roomId).collection('members').snapshots();

  Future<String> createVoiceRoom({required String name, String topic = ''}) async {
    final cleanName = name.trim();
    final cleanTopic = topic.trim();
    if (cleanName.length < 2 || cleanName.length > 80) throw ArgumentError('اسم الغرفة غير صالح');
    if (cleanTopic.length > 160) throw ArgumentError('وصف الغرفة طويل');
    final roomRef = _rooms.doc();
    await roomRef.set({
      'ownerId': uid,
      'name': cleanName,
      'topic': cleanTopic,
      'roomName': 'memo_voice_${roomRef.id}',
      'active': true,
      'visibility': 'public',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await roomRef.collection('members').doc(uid).set({
      'userId': uid,
      'role': 'host',
      'joinedAt': FieldValue.serverTimestamp(),
    });
    return roomRef.id;
  }

  Future<void> joinVoiceRoom(String roomId) async {
    final ref = _rooms.doc(roomId);
    final snap = await ref.get();
    if (!snap.exists || snap.data()?['active'] != true) throw StateError('الغرفة غير متاحة');
    await ref.collection('members').doc(uid).set({
      'userId': uid,
      'role': 'listener',
      'joinedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> leaveVoiceRoom(String roomId) async {
    await _rooms.doc(roomId).collection('members').doc(uid).delete();
  }

  Future<void> setVoiceRoomVisibility(String roomId, bool visible) async {
    final ref = _rooms.doc(roomId);
    final snap = await ref.get();
    if (!snap.exists || snap.data()?['ownerId'] != uid) throw StateError('لا تملك صلاحية تعديل الغرفة');
    await ref.update({'visibility': visible ? 'public' : 'hidden', 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> closeVoiceRoom(String roomId) async {
    final ref = _rooms.doc(roomId);
    final snap = await ref.get();
    if (snap.data()?['ownerId'] != uid) throw StateError('لا تملك صلاحية إغلاق الغرفة');
    await ref.update({'active': false, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchBusinesses() => _businesses
      .where('active', isEqualTo: true)
      .orderBy('updatedAt', descending: true)
      .limit(50)
      .snapshots();

  Future<String> createBusiness({
    required String name,
    required String category,
    required String description,
    String? phone,
  }) async {
    final cleanName = name.trim();
    final cleanCategory = category.trim();
    final cleanDescription = description.trim();
    if (cleanName.length < 2 || cleanName.length > 100) throw ArgumentError('اسم النشاط غير صالح');
    if (cleanCategory.length < 2 || cleanCategory.length > 60) throw ArgumentError('تصنيف النشاط غير صالح');
    if (cleanDescription.length > 500) throw ArgumentError('وصف النشاط طويل');
    final ref = _businesses.doc();
    await ref.set({
      'ownerId': uid,
      'name': cleanName,
      'category': cleanCategory,
      'description': cleanDescription,
      'phone': phone?.trim(),
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> deactivateBusiness(String businessId) async {
    final ref = _businesses.doc(businessId);
    final snap = await ref.get();
    if (!snap.exists || snap.data()?['ownerId'] != uid) throw StateError('لا تملك صلاحية تعديل هذا النشاط');
    await ref.update({'active': false, 'updatedAt': FieldValue.serverTimestamp()});
  }
}
