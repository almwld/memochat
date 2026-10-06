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
        fileName: 'avatar$extension',
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

      return AvatarUpdateResult(url: result.url, path: result.path);
    } catch (e) {
      return AvatarUpdateResult(error: e.toString());
    }
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
