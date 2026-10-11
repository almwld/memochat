import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../chat/services/nextcloud_service.dart';

/// Owns the canonical account avatar lifecycle.
///
/// The binary is stored in Nextcloud; Firestore stores only the public share
/// URL and provider metadata used by the rest of the application.
class AvatarService {
  AvatarService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    NextcloudService? nextcloud,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _nextcloud = nextcloud ?? NextcloudService();

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final NextcloudService _nextcloud;

  Future<AvatarUpdateResult> uploadAndSetOfficialAvatar({
    required String uid,
    required File file,
  }) async {
    final current = _auth.currentUser;
    if (current == null || current.uid != uid) {
      return const AvatarUpdateResult(error: 'يجب تسجيل الدخول لتغيير صورة الحساب');
    }
    if (!await file.exists()) {
      return const AvatarUpdateResult(error: 'الصورة المحددة غير موجودة على الجهاز');
    }

    final size = await file.length();
    if (size <= 0) {
      return const AvatarUpdateResult(error: 'ملف الصورة فارغ');
    }
    if (size > 10 * 1024 * 1024) {
      return const AvatarUpdateResult(error: 'حجم الصورة أكبر من الحد المسموح');
    }

    try {
      await _nextcloud.loadConfig();
      final extension = _extension(file.path);
      final result = await _nextcloud.uploadFile(
        file: file,
        path: 'avatars',
        fileName: 'avatar_${uid}_${DateTime.now().millisecondsSinceEpoch}$extension',
        mimeType: _mimeType(extension),
        createShare: true,
      );

      if (!result.success || result.url == null || result.url!.isEmpty) {
        return AvatarUpdateResult(
          error: result.error ?? 'تعذر رفع صورة الحساب إلى Nextcloud',
          path: result.path,
        );
      }

      final now = FieldValue.serverTimestamp();
      await _db.collection('users').doc(uid).set({
        'photoUrl': result.url,
        'photoURL': result.url,
        'avatar': {
          'provider': 'nextcloud',
          'path': result.path,
          'fileName': result.fileName,
          'updatedAt': now,
        },
        'updatedAt': now,
      }, SetOptions(merge: true));

      await current.updatePhotoURL(result.url);
      await current.reload();

      // Propagate the canonical avatar to cached participant metadata in every
      // conversation. This keeps chat lists, rooms, calls, groups and contacts
      // consistent instead of leaving the new image visible only on /profile.
      await _propagateAvatarToConversations(uid, result.url!);

      return AvatarUpdateResult(url: result.url, path: result.path);
    } catch (e) {
      return AvatarUpdateResult(error: e.toString());
    }
  }

  Future<AvatarUpdateResult> uploadAndSetCover({
    required String uid,
    required File file,
  }) async {
    final current = _auth.currentUser;
    if (current == null || current.uid != uid) return const AvatarUpdateResult(error: 'يجب تسجيل الدخول لتغيير الغلاف');
    if (!await file.exists()) return const AvatarUpdateResult(error: 'صورة الغلاف غير موجودة');
    if (await file.length() > 15 * 1024 * 1024) return const AvatarUpdateResult(error: 'حجم الغلاف أكبر من الحد المسموح');
    try {
      await _nextcloud.loadConfig();
      final extension = _extension(file.path);
      final result = await _nextcloud.uploadFile(
        file: file,
        path: 'profile-covers',
        fileName: 'cover_' + uid + extension,
        mimeType: _mimeType(extension),
        createShare: true,
      );
      if (!result.success || result.url == null || result.url!.isEmpty) {
        return AvatarUpdateResult(error: result.error ?? 'تعذر رفع الغلاف', path: result.path);
      }
      await _db.collection('users').doc(uid).set({
        'coverUrl': result.url,
        'cover': {
          'provider': 'nextcloud',
          'path': result.path,
          'fileName': result.fileName,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return AvatarUpdateResult(url: result.url, path: result.path);
    } catch (e) {
      return AvatarUpdateResult(error: e.toString());
    }
  }

  Future<void> _propagateAvatarToConversations(String uid, String url) async {
    // Update the active status document first so the status row/story header
    // receives the new avatar immediately through its existing Firestore stream.
    final statusRef = _db.collection('statuses').doc(uid);
    final status = await statusRef.get();
    if (status.exists) {
      try {
        await statusRef.update({
          'userImage': url,
          'avatarUpdatedAt': FieldValue.serverTimestamp(),
        });
      } catch (error) {
        // Avatar upload/profile update has already succeeded. A denied status
        // mirror must not report the whole avatar change as failed.
        debugPrint('status avatar refresh failed: $error');
      }
    }

    // Keep independent refreshes best-effort so a legacy document/rule mismatch
    // in one collection does not prevent chat avatars from updating.
    await Future.wait([
      _updateOwnedContentPhotos('socialPosts', uid, url, 'authorPhoto')
          .catchError((Object error) => debugPrint('post avatar refresh failed: $error')),
      _updateOwnedContentPhotos('socialReels', uid, url, 'authorPhoto')
          .catchError((Object error) => debugPrint('reel avatar refresh failed: $error')),
      _updateOwnedContentPhotos('chats', uid, url, null)
          .catchError((Object error) => debugPrint('chat avatar refresh failed: $error')),
    ]);
  }

  Future<void> _updateOwnedContentPhotos(
    String collection,
    String uid,
    String url,
    String? photoField,
  ) async {
    final query = collection == 'chats'
        ? _db.collection(collection).where('participants', arrayContains: uid)
        : _db.collection(collection).where('authorId', isEqualTo: uid);
    final snapshot = await query.get();
    if (snapshot.docs.isEmpty) return;

    WriteBatch batch = _db.batch();
    var count = 0;
    for (final doc in snapshot.docs) {
      if (collection == 'chats') {
        batch.update(doc.reference, {
          'participantDetails.$uid.photoUrl': url,
          'participantPhotos.$uid': url,
        });
      } else {
        batch.update(doc.reference, {
          photoField!: url,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      count++;
      if (count == 450) {
        await batch.commit();
        batch = _db.batch();
        count = 0;
      }
    }
    if (count > 0) await batch.commit();
  }

  String _extension(String path) {
    final name = path.split(Platform.pathSeparator).last.toLowerCase();
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '.jpg';
    final value = name.substring(dot);
    return const {'.jpg', '.jpeg', '.png', '.webp'}.contains(value)
        ? value
        : '.jpg';
  }

  String _mimeType(String extension) {
    switch (extension) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}

class AvatarUpdateResult {
  const AvatarUpdateResult({this.url, this.path, this.error});
  final String? url;
  final String? path;
  final String? error;

  bool get success => url?.isNotEmpty == true;
}
