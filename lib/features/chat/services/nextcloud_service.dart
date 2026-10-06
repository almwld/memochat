import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/nextcloud_config.dart';
import '../../../core/config/livekit_config.dart';

class NextcloudService {
  static final NextcloudService _instance = NextcloudService._internal();
  factory NextcloudService() => _instance;
  NextcloudService._internal();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
    sendTimeout: const Duration(minutes: 10),
  ));
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String baseUrl = '';
  String username = '';
  String password = '';

  Future<void> loadConfig() async {
    // Prefer user-managed Secure Storage values.
    baseUrl = (await _storage.read(key: 'memochat.nextcloud.base_url') ?? '')
        .trim()
        .replaceFirst(RegExp(r'/$'), '');
    username =
        (await _storage.read(key: 'memochat.nextcloud.username') ?? '').trim();
    password =
        await _storage.read(key: 'memochat.nextcloud.app_password') ?? '';

    // First-run/CI fallback: use build-time configuration when storage is empty.
    if (baseUrl.isEmpty) {
      baseUrl = NextcloudConfig.url.trim().replaceFirst(RegExp(r'/$'), '');
    }
    if (username.isEmpty) {
      username = NextcloudConfig.user.trim();
    }
    if (password.isEmpty) {
      password = NextcloudConfig.password;
    }

    // Persist a complete build-time configuration for subsequent launches.
    if (baseUrl.isNotEmpty && username.isNotEmpty && password.isNotEmpty) {
      await _storage.write(key: 'memochat.nextcloud.base_url', value: baseUrl);
      await _storage.write(key: 'memochat.nextcloud.username', value: username);
      await _storage.write(
        key: 'memochat.nextcloud.app_password',
        value: password,
      );
    }

    debugPrint(
      '📡 NC config: baseUrl=' + baseUrl +
      ' user=' + username +
      ' hasPass=' + password.isNotEmpty.toString(),
    );
  }

  Future<void> updateConfig({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    this.baseUrl = baseUrl.trim().replaceFirst(RegExp(r'/$'), '');
    this.username = username.trim();
    this.password = password;
    await _storage.write(key: 'memochat.nextcloud.base_url', value: this.baseUrl);
    await _storage.write(key: 'memochat.nextcloud.username', value: this.username);
    await _storage.write(key: 'memochat.nextcloud.app_password', value: this.password);
  }

  Future<void> clearConfig() async {
    baseUrl = '';
    username = '';
    password = '';
    await Future.wait([
      _storage.delete(key: 'memochat.nextcloud.base_url'),
      _storage.delete(key: 'memochat.nextcloud.username'),
      _storage.delete(key: 'memochat.nextcloud.app_password'),
    ]);
  }

  void _ensureConfigured() {
    if (baseUrl.isEmpty || username.isEmpty || password.isEmpty) {
      throw StateError('خادم الوسائط غير مهيأ: baseUrl=$baseUrl user=$username hasPass=${password.isNotEmpty}');
    }
  }

  String _authToken() => base64Encode(utf8.encode('$username:$password'));
  String _normalizedBase() => baseUrl.replaceFirst(RegExp(r'/$'), '');

  Map<String, String> _headers() => {
        'OCS-APIRequest': 'true',
        'Authorization': 'Basic ${_authToken()}',
        'Content-Type': 'application/x-www-form-urlencoded',
      };

  String _cleanPart(String value) => value
      .trim()
      .replaceAll('\\', '')
      .replaceAll('/', '')
      .replaceAll('..', '');

  String _cleanLogicalPath(String path) => path
      .split('/')
      .map(_cleanPart)
      .where((part) => part.isNotEmpty && part != '.')
      .join('/');

  String _platformPath(String path) {
    final clean = _cleanLogicalPath(path);
    if (clean.isEmpty) return 'MemoChat';
    return clean == 'MemoChat' || clean.startsWith('MemoChat/') ? clean : 'MemoChat/$clean';
  }

  String _davUrl(String remotePath) {
    final cleanPath = remotePath
        .replaceFirst(RegExp(r'^/+'), '')
        .split('/')
        .where((part) => part.isNotEmpty)
        .map(Uri.encodeComponent)
        .join('/');
    return '${_normalizedBase()}/remote.php/dav/files/${Uri.encodeComponent(username)}/$cleanPath';
  }

  Future<void> _ensureDirectories(String directory) async {
    var current = '';
    for (final part in _cleanLogicalPath(directory).split('/')) {
      if (part.isEmpty) continue;
      current = current.isEmpty ? part : '$current/$part';
      debugPrint('📁 MKCOL: $current');
      var lastStatus = 0;
      for (var attempt = 1; attempt <= 3; attempt++) {
        final response = await _dio.request<void>(
          _davUrl(current),
          options: Options(
            method: 'MKCOL',
            headers: {'Authorization': 'Basic ${_authToken()}'},
            validateStatus: (status) => status != null,
          ),
        );
        lastStatus = response.statusCode ?? 0;
        debugPrint('📁 MKCOL response: $lastStatus attempt=$attempt');
        if (lastStatus == 201 || lastStatus == 405) break;
        if (![502, 503, 504].contains(lastStatus) || attempt == 3) break;
        await Future<void>.delayed(Duration(seconds: attempt * 2));
      }
      if (lastStatus != 201 && lastStatus != 405) {
        final detail = lastStatus == 503
            ? 'خادم Nextcloud غير متاح مؤقتاً (HTTP 503)'
            : 'فشل إنشاء مجلد الوسائط في Nextcloud: HTTP $lastStatus';
        throw StateError(detail);
      }
    }
  }

  Future<NextcloudUploadResult> uploadFile({
    required File file,
    required String path,
    String? fileName,
    String? mimeType,
    String? chatId,
    void Function(int, int)? onProgress,
    bool createShare = true,
    CancelToken? cancelToken,
  }) async {
    try {
      if (!await file.exists()) return const NextcloudUploadResult(success: false, error: 'الملف المحلي غير موجود');
      final name = _cleanPart(fileName ?? file.path.split(Platform.pathSeparator).last);
      if (name.isEmpty) return const NextcloudUploadResult(success: false, error: 'اسم الملف غير صالح');
      final logicalDirectory = _platformPath(path);
      final fileLength = await file.length();
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return const NextcloudUploadResult(success: false, error: 'يجب تسجيل الدخول قبل رفع الوسائط');
      final token = await user.getIdToken();
      if (token == null || token.isEmpty) return const NextcloudUploadResult(success: false, error: 'تعذر الحصول على جلسة Firebase لرفع الوسائط');
      final uri = Uri.parse('${LiveKitConfig.tokenServerUrl}/media/upload').replace(
        queryParameters: <String, String>{
          'path': logicalDirectory,
          'fileName': name,
          'mimeType': mimeType?.trim().isNotEmpty == true ? mimeType!.trim() : 'application/octet-stream',
          'createShare': createShare ? 'true' : 'false',
          if (chatId?.trim().isNotEmpty == true) 'chatId': chatId!.trim(),
        },
      );
      final response = await _dio.post<dynamic>(
        uri.toString(),
        data: file.openRead(),
        options: Options(headers: <String, String>{'Authorization': 'Bearer $token', 'Content-Type': 'application/octet-stream', 'Content-Length': fileLength.toString()}, responseType: ResponseType.json, validateStatus: (status) => status != null),
        onSendProgress: onProgress,
        cancelToken: cancelToken,
      );
      final status = response.statusCode ?? 0;
      final body = response.data is Map ? Map<String, dynamic>.from(response.data as Map) : const <String, dynamic>{};
      if (status < 200 || status >= 300 || body['success'] != true) return NextcloudUploadResult(success: false, error: body['message']?.toString() ?? 'فشل رفع الوسائط عبر خادم الوسائط');
      final rawFile = body['file'];
      final uploaded = rawFile is Map ? Map<String, dynamic>.from(rawFile) : const <String, dynamic>{};
      final remotePath = uploaded['remotePath']?.toString();
      final url = uploaded['url']?.toString();
      if (remotePath == null || remotePath.isEmpty) return const NextcloudUploadResult(success: false, error: 'خادم الوسائط لم يعُد بمسار الملف');
      return NextcloudUploadResult(success: true, url: url?.isNotEmpty == true ? url : null, path: remotePath, fileName: uploaded['fileName']?.toString() ?? name, error: url?.isNotEmpty == true ? null : 'تم رفع الملف، لكن رابط الوصول لم يجهز بعد', shareReady: url?.isNotEmpty == true);
    } catch (e, st) {
      debugPrint('❌ media backend upload failed: $e');
      debugPrint('❌ stack: $st');
      return NextcloudUploadResult(success: false, error: e.toString());
    }
  }
  Future<String?> createPublicShare(String remotePath) async {
    final normalized = remotePath.trim().replaceFirst(RegExp(r'^/+'), '');
    if (normalized.isEmpty) return null;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) return null;
    try {
      final response = await _dio.post<dynamic>('${LiveKitConfig.tokenServerUrl}/media/share', data: <String, dynamic>{'remotePath': normalized}, options: Options(headers: <String, String>{'Authorization': 'Bearer $token'}, responseType: ResponseType.json, validateStatus: (status) => status != null));
      if ((response.statusCode ?? 0) < 200 || (response.statusCode ?? 0) >= 300) return null;
      final body = response.data is Map ? Map<String, dynamic>.from(response.data as Map) : const <String, dynamic>{};
      final url = body['url']?.toString();
      return url?.isNotEmpty == true ? url : null;
    } catch (e, st) {
      debugPrint('❌ media backend share failed: $e');
      debugPrint('❌ stack: $st');
      return null;
    }
  }
  Future<bool> verifyPublicUrl(String url) async {
    final client = http.Client();
    var current = Uri.parse(url);
    try {
      for (var hop = 0; hop <= 5; hop++) {
        final request = http.Request('GET', current)
          ..followRedirects = false
          ..maxRedirects = 0;
        request.headers['Range'] = 'bytes=0-0';
        final response = await client.send(request).timeout(const Duration(seconds: 20));
        final status = response.statusCode;
        final location = response.headers['location'];
        final contentLength = response.contentLength;
        debugPrint('🔗 verifyPublicUrl hop=$hop status=$status url=$current location=${location ?? '(none)'}');
        await response.stream.drain<void>();

        if (status == 200 || status == 206) {
          return contentLength == null || contentLength > 0;
        }

        if (status >= 300 && status < 400 && location != null && location.isNotEmpty) {
          final next = current.resolve(location);
          if (next.host != current.host) {
            debugPrint('❌ verifyPublicUrl rejected cross-host redirect: ${next.host}');
            return false;
          }
          current = next;
          continue;
        }

        return false;
      }
      debugPrint('❌ verifyPublicUrl exceeded redirect limit url=$url');
      return false;
    } catch (e, st) {
      debugPrint('❌ verifyPublicUrl failed for $url: $e');
      debugPrint('❌ stack: $st');
      return false;
    } finally {
      client.close();
    }
  }

  Future<bool> checkServerStatus() async {
    try {
      if (baseUrl.isEmpty) return false;
      final response = await http.get(Uri.parse('${_normalizedBase()}/status.php'));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> testAuth() async {
    try {
      _ensureConfigured();
      final response = await http.get(Uri.parse('${_normalizedBase()}/ocs/v2.php/cloud/user'), headers: _headers());
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

class NextcloudUploadResult {
  final bool success;
  final String? url;
  final String? path;
  final String? fileName;
  final String? error;
  final bool shareReady;

  const NextcloudUploadResult({required this.success, this.url, this.path, this.fileName, this.error, this.shareReady = false});
}
