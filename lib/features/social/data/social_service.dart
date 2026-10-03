import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';

import '../services/social_media_transfer_service.dart';

class SocialService {
  SocialService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    SocialMediaTransferService? media,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _media = media ?? SocialMediaTransferService.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final SocialMediaTransferService _media;

  String get _uid => _auth.currentUser?.uid ?? '';
  String get currentUserId => _uid;

  void _authz() {
    if (_uid.isEmpty) throw StateError('يرجى تسجيل الدخول');
  }

  CollectionReference<Map<String, dynamic>> _c(String name) => _db.collection(name);

  Stream<QuerySnapshot<Map<String, dynamic>>> posts() =>
      _c('socialPosts').orderBy('createdAt', descending: true).limit(50).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> reels() =>
      _c('socialReels').orderBy('createdAt', descending: true).limit(50).snapshots();

  Future<String> createPost({required String text, File? media, bool video = false}) async {
    _authz();
    final body = text.trim();
    if (body.isEmpty && media == null) throw ArgumentError('المنشور فارغ');
    if (body.length > 5000) throw ArgumentError('المنشور طويل');
    final ref = _c('socialPosts').doc();
    if (media != null) {
      return _media.enqueue(
        sourceFile: media,
        collection: 'socialPosts',
        type: video ? 'video' : 'image',
        caption: body,
        fileName: ref.id + _ext(media.path),
      );
    }
    await ref.set({
      'authorId': _uid,
      'text': body,
      'likesCount': 0,
      'commentsCount': 0,
      'sharesCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<String> createReel({required File video, String caption = ''}) async {
    _authz();
    final ref = _c('socialReels').doc();
    return _media.enqueue(
      sourceFile: video,
      collection: 'socialReels',
      type: 'video',
      caption: caption.trim(),
      fileName: ref.id + _ext(video.path),
      mimeType: 'video/mp4',
    );
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchLike(String collection, String contentId) {
    _authz();
    return _c(collection).doc(contentId).collection('likes').doc(_uid).snapshots();
  }

  Future<bool> isLiked(String reelId, String uid) async {
    _authz();
    final snap = await _c('socialReels').doc(reelId).collection('likes').doc(uid).get();
    return snap.exists;
  }

  Stream<int> watchLikesCount(String reelId) =>
      _c('socialReels').doc(reelId).snapshots().map((s) => (s.data()?['likesCount'] as num?)?.toInt() ?? 0);

  Future<void> toggleLike(String reelId) async {
    _authz();
    final content = _c('socialReels').doc(reelId);
    final ref = content.collection('likes').doc(_uid);
    final existing = await ref.get();
    await _db.runTransaction((tx) async {
      if (existing.exists) {
        tx.delete(ref);
        tx.update(content, {
          'likesCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        tx.set(ref, {'userId': _uid, 'likedAt': FieldValue.serverTimestamp()});
        tx.update(content, {
          'likesCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchComments(String reelId) =>
      _c('socialReels').doc(reelId).collection('comments').orderBy('createdAt').limit(100).snapshots();

  Future<void> addComment(String reelId, String text) async {
    _authz();
    final body = text.trim();
    if (body.isEmpty || body.length > 1000) throw ArgumentError('التعليق يجب أن يكون بين 1 و1000 حرف');
    final reel = _c('socialReels').doc(reelId);
    await _db.runTransaction((tx) async {
      tx.set(reel.collection('comments').doc(), {
        'userId': _uid,
        'userName': _auth.currentUser?.displayName ?? 'مستخدم Memo',
        'userPhoto': _auth.currentUser?.photoURL ?? '',
        'text': body,
        'likesCount': 0,
        'repliesCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(reel, {
        'commentsCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> deleteComment(String reelId, String commentId) async {
    _authz();
    final ref = _c('socialReels').doc(reelId).collection('comments').doc(commentId);
    final snap = await ref.get();
    if (!snap.exists || snap.data()?['userId'] != _uid) throw StateError('لا تملك هذا التعليق');
    await _db.runTransaction((tx) async {
      tx.delete(ref);
      tx.update(_c('socialReels').doc(reelId), {
        'commentsCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> recordShare(String reelId) async {
    _authz();
    await _c('socialReels').doc(reelId).update({
      'sharesCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> shareReel(String reelId) async {
    _authz();
    final snap = await _c('socialReels').doc(reelId).get();
    final url = snap.data()?['videoUrl']?.toString() ?? '';
    if (url.isEmpty) throw StateError('رابط الريل غير متاح');
    await Share.share(url);
    await recordShare(reelId);
  }

  Future<void> updateReelCaption(String reelId, String caption) async {
    final body = caption.trim();
    if (body.length > 5000) throw ArgumentError('الوصف طويل');
    await _ownerUpdate(reelId, {'caption': body});
  }

  Future<void> deleteReel(String reelId) async {
    _authz();
    final ref = _c('socialReels').doc(reelId);
    final snap = await ref.get();
    if (snap.data()?['authorId'] != _uid) throw StateError('لا تملك هذا الريل');
    await ref.delete();
  }

  Future<void> setReelVisibility(String reelId, bool isPublished) async =>
      _ownerUpdate(reelId, {'isPublished': isPublished});

  Future<void> setCommentsEnabled(String reelId, bool enabled) async =>
      _ownerUpdate(reelId, {'commentsEnabled': enabled});

  Future<void> pinReel(String reelId, bool pinned) async =>
      _ownerUpdate(reelId, {'isPinned': pinned});

  Future<void> recordView(String reelId) async {
    _authz();
    await _c('socialReels').doc(reelId).update({
      'viewsCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _ownerUpdate(String reelId, Map<String, dynamic> data) async {
    _authz();
    final ref = _c('socialReels').doc(reelId);
    final snap = await ref.get();
    if (snap.data()?['authorId'] != _uid) throw StateError('هذه العملية للمالك فقط');
    await ref.update({...data, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> toggleSave(String collection, String id, bool saved) async {
    _authz();
    final ref = _db.collection('users').doc(_uid).collection('savedSocial').doc(id);
    if (saved) {
      await ref.delete();
    } else {
      await ref.set({
        'collection': collection,
        'contentId': id,
        'savedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchSaved(String id) =>
      _db.collection('users').doc(_uid).collection('savedSocial').doc(id).snapshots();

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchFollowing(String id) =>
      _db.collection('users').doc(_uid).collection('following').doc(id).snapshots();

  Future<void> toggleFollow(String target, bool following) async {
    _authz();
    if (target.isEmpty || target == _uid) return;
    final a = _db.collection('users').doc(_uid).collection('following').doc(target);
    final b = _db.collection('users').doc(target).collection('followers').doc(_uid);
    final batch = _db.batch();
    if (following) {
      batch.delete(a);
      batch.delete(b);
    } else {
      final data = {'userId': _uid, 'targetUserId': target, 'createdAt': FieldValue.serverTimestamp()};
      batch.set(a, data);
      batch.set(b, data);
    }
    await batch.commit();
  }

  String _ext(String path) {
    final i = path.lastIndexOf('.');
    return i < 0 ? '.bin' : path.substring(i).replaceAll(RegExp(r'[^A-Za-z0-9.]'), '');
  }
}
