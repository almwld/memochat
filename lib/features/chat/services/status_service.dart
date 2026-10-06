import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/media/media_transfer_engine.dart';
import '../models/status_model.dart';

class StatusService {
  StatusService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final _media = MediaTransferEngine.instance;

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

    // The uploaded avatar is stored in Firestore by AvatarService; FirebaseAuth.photoURL
    // can remain stale or empty. Prefer the canonical profile document when publishing.
    String? resolvedUserImage = userImage?.trim();
    if (resolvedUserImage?.isEmpty != false) {
      try {
        final profile = await _firestore.collection('users').doc(user.uid).get();
        final data = profile.data() ?? const <String, dynamic>{};
        final stored = data['photoUrl']?.toString().trim();
        final legacy = data['photoURL']?.toString().trim();
        resolvedUserImage = stored?.isNotEmpty == true
            ? stored
            : legacy?.isNotEmpty == true
                ? legacy
                : user.photoURL;
      } catch (_) {
        resolvedUserImage = user.photoURL;
      }
    }

    await ref.set({
      'userId': user.uid,
      'userName': (userName ?? user.displayName ?? 'مستخدم').trim(),
      'userImage': resolvedUserImage,
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

    final extension = file.path.contains('.') ? file.path.split('.').last.toLowerCase() : '';
    final mediaType = type == 'video' ? 'video' : 'image';
    final mimeType = mediaType == 'video' ? 'video/mp4' : 'image/jpeg';
    final name = 'story_${DateTime.now().millisecondsSinceEpoch}.${extension}';
    final result = await _media.uploadNow(
      file: file,
      destination: MediaDestination.status,
      type: mediaType,
      folder: 'status',
      fileName: name,
      mimeType: mimeType,
    );
    if (!result.success || result.url == null || result.url!.isEmpty) {
      throw StateError(result.error ?? 'تعذر رفع الحالة.');
    }

    return StoryItem(type: type, url: result.url!, duration: duration);
  }

  Future<void> updateTextStory({
    required String statusId,
    required int storyIndex,
    required String text,
  }) async {
    final uid = _auth.currentUser?.uid;
    final clean = text.trim();
    if (uid == null || uid.isEmpty) throw StateError('يجب تسجيل الدخول');
    if (clean.isEmpty || clean.length > 2000) throw ArgumentError('نص الحالة غير صالح');
    final ref = _statuses.doc(statusId);
    final snap = await ref.get();
    if (!snap.exists || snap.data()?['userId']?.toString() != uid) throw StateError('لا تملك هذه الحالة');
    final stories = List<Map<String, dynamic>>.from(
      (snap.data()?['stories'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
    );
    if (storyIndex < 0 || storyIndex >= stories.length) throw StateError('الحالة غير موجودة');
    stories[storyIndex]['type'] = 'text';
    stories[storyIndex]['text'] = clean;
    stories[storyIndex]['url'] = '';
    await ref.update({'stories': stories, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> deleteStatus(String statusId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) throw StateError('يجب تسجيل الدخول');
    final ref = _statuses.doc(statusId);
    final snap = await ref.get();
    if (!snap.exists || snap.data()?['userId']?.toString() != uid) throw StateError('لا تملك هذه الحالة');
    await ref.delete();
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
