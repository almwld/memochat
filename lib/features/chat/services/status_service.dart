import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'nextcloud_service.dart';
import '../models/status_model.dart';

class StatusService {
  StatusService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final NextcloudService _nextcloud = NextcloudService();

  CollectionReference<Map<String, dynamic>> get _statuses => _firestore.collection('statuses');

  Stream<List<UserStatusModel>> streamActiveStatuses() {
    return _statuses
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(DateTime.now()))
        .snapshots()
        .asyncMap(_withViewState)
        .map((items) {
      items.removeWhere((item) => !item.isValid || item.stories.isEmpty);
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  /// Active status for a single user, used by the avatar in ChatRoomScreen.
  /// It reads the same Firestore status document used by the global status row,
  /// so the conversation never has a second/duplicate story source.
  Stream<UserStatusModel?> streamUserStatus(String userId) {
    if (userId.trim().isEmpty) return Stream.value(null);
    return _statuses.doc(userId).snapshots().map((document) {
      if (!document.exists) return null;
      final status = UserStatusModel.fromDocument(document);
      if (!status.isValid || status.stories.isEmpty) return null;
      return status;
    });
  }

  Future<UserStatusModel?> getUserStatus(String userId) async {
    final cleanId = userId.trim();
    if (cleanId.isEmpty) return null;
    final document = await _statuses.doc(cleanId).get();
    if (!document.exists) return null;
    final status = UserStatusModel.fromDocument(document);
    if (!status.isValid || status.stories.isEmpty) return null;
    return status;
  }

  Future<List<UserStatusModel>> _withViewState(QuerySnapshot<Map<String, dynamic>> snapshot) async {
    final uid = _auth.currentUser?.uid;
    final items = <UserStatusModel>[];
    for (final document in snapshot.docs) {
      final viewed = uid == null ? false : (await document.reference.collection('views').doc(uid).get()).exists;
      items.add(UserStatusModel.fromDocument(document, isViewed: viewed));
    }
    return items;
  }

  Future<String> createStatus({
    required List<StoryItem> stories,
    String? userName,
    String? userImage,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('يجب تسجيل الدخول لإضافة حالة.');
    if (stories.isEmpty) throw StateError('أضف محتوى واحداً على الأقل.');

    // A status is published only after all media stories have already been
    // uploaded and verified by uploadMediaStory. Firestore is the source of
    // truth that makes the completed status visible to other users.
    final ref = _statuses.doc(user.uid);
    final existing = await ref.get();
    final existingModel = existing.exists ? UserStatusModel.fromDocument(existing) : null;
    final now = DateTime.now();
    final activeStories = existingModel != null && existingModel.isValid ? existingModel.stories : <StoryItem>[];
    final allStories = [...activeStories, ...stories];

    await ref.set({
      'userId': user.uid,
      'userName': (userName ?? user.displayName ?? 'مستخدم').trim(),
      'userImage': userImage ?? user.photoURL,
      'stories': allStories.map((story) => story.toMap()).toList(),
      'createdAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(now.add(const Duration(hours: 24))),
      'ready': true,
      'createdBy': user.uid,
    }, SetOptions(merge: true));
    return ref.id;
  }

  Future<StoryItem> uploadMediaStory({
    required File file,
    required String type,
    Duration duration = const Duration(seconds: 5),
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('يجب تسجيل الدخول لإضافة حالة.');

    await _nextcloud.loadConfig();
    final extension = file.path.contains('.') ? file.path.split('.').last : 'bin';
    final name = 'story_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final result = await _nextcloud.uploadFile(
      file: file,
      path: 'stories/${user.uid}',
      fileName: name,
      createShare: true,
    );
    if (!result.success || result.url == null || result.url!.isEmpty) {
      throw StateError(result.error ?? 'تعذر رفع الحالة.');
    }

    // Do not publish the Firestore status until the Nextcloud public URL is
    // reachable. This prevents broken media stories from becoming visible.
    final verified = await _nextcloud.verifyPublicUrl(result.url!);
    if (!verified) {
      throw StateError('تعذر تجهيز الوسائط للنشر.');
    }

    return StoryItem(type: type, url: result.url!, duration: duration);
  }

  Future<void> markViewed(UserStatusModel status) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid == status.userId) return;
    await _statuses.doc(status.id).collection('views').doc(uid).set({
      'userId': uid,
      'viewedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> addReaction({required UserStatusModel status, required String emoji}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _statuses.doc(status.id).collection('reactions').doc(uid).set({
      'userId': uid,
      'emoji': emoji,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addReply({required UserStatusModel status, required String text}) async {
    final uid = _auth.currentUser?.uid;
    final clean = text.trim();
    if (uid == null || clean.isEmpty) return;
    final user = _auth.currentUser;
    await _statuses.doc(status.id).collection('replies').add({
      'userId': uid,
      'userName': user?.displayName ?? 'مستخدم',
      'text': clean,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
