import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

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
    baseUrl = (await _storage.read(key: 'sehatak.nextcloud.base_url') ?? '')
        .trim()
        .replaceFirst(RegExp(r'/$'), '');
    username = (await _storage.read(key: 'sehatak.nextcloud.username') ?? '').trim();
    password = await _storage.read(key: 'sehatak.nextcloud.app_password') ?? '';
    debugPrint('📡 NC config: baseUrl=$baseUrl user=$username hasPass=${password.isNotEmpty}');
  }

  Future<void> updateConfig({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    this.baseUrl = baseUrl.trim().replaceFirst(RegExp(r'/$'), '');
    this.username = username.trim();
    this.password = password;
    await _storage.write(key: 'sehatak.nextcloud.base_url', value: this.baseUrl);
    await _storage.write(key: 'sehatak.nextcloud.username', value: this.username);
    await _storage.write(key: 'sehatak.nextcloud.app_password', value: this.password);
  }

  Future<void> clearConfig() async {
    baseUrl = '';
    username = '';
    password = '';
    await Future.wait([
      _storage.delete(key: 'sehatak.nextcloud.base_url'),
      _storage.delete(key: 'sehatak.nextcloud.username'),
      _storage.delete(key: 'sehatak.nextcloud.app_password'),
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
    if (clean.isEmpty) return 'Sehatak';
    return clean == 'Sehatak' || clean.startsWith('Sehatak/') ? clean : 'Sehatak/$clean';
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
      final response = await _dio.request<void>(
        _davUrl(current),
        options: Options(
          method: 'MKCOL',
          headers: {'Authorization': 'Basic ${_authToken()}'},
          validateStatus: (status) => status != null,
        ),
      );
      final status = response.statusCode ?? 0;
      debugPrint('📁 MKCOL response: $status');
      if (status != 201 && status != 405) {
        throw StateError('فشل إنشاء مجلد الوسائط في Nextcloud: HTTP $status');
      }
    }
  }

  Future<NextcloudUploadResult> uploadFile({
    required File file,
    required String path,
    String? fileName,
    void Function(int, int)? onProgress,
    bool createShare = true,
    CancelToken? cancelToken,
  }) async {
    try {
      _ensureConfigured();
      if (!await file.exists()) {
        return const NextcloudUploadResult(success: false, error: 'الملف المحلي غير موجود');
      }
      final name = _cleanPart(fileName ?? file.path.split(Platform.pathSeparator).last);
      if (name.isEmpty) return const NextcloudUploadResult(success: false, error: 'اسم الملف غير صالح');
      final logicalDirectory = _platformPath(path);
      final remotePath = '$logicalDirectory/$name';
      final davUrl = _davUrl(remotePath);
      final fileLength = await file.length();
      debugPrint('📤 PUT: $davUrl');
      debugPrint('📤 file size: $fileLength');

      await _ensureDirectories(logicalDirectory);

      final response = await _dio.put<void>(
        davUrl,
        data: file.openRead(),
        options: Options(
          headers: {
            'Authorization': 'Basic ${_authToken()}',
            'Content-Type': 'application/octet-stream',
            'Content-Length': fileLength.toString(),
          },
          contentType: 'application/octet-stream',
          validateStatus: (status) => status != null,
        ),
        onSendProgress: onProgress,
      );
      final status = response.statusCode ?? 0;
      debugPrint('📤 PUT status: $status');
      if (status != 201 && status != 204) {
        return NextcloudUploadResult(success: false, path: remotePath, fileName: name, error: 'فشل رفع الملف إلى Nextcloud: HTTP $status');
      }
      if (!createShare) return NextcloudUploadResult(success: true, path: remotePath, fileName: name);

      String? publicUrl;
      String? shareError;
      try {
        publicUrl = await createPublicShare(remotePath);
        if (publicUrl == null || publicUrl.isEmpty) shareError = 'تم رفع الملف بنجاح، لكن رابط الوصول لم يجهز بعد';
      } catch (e, st) {
        debugPrint('❌ createPublicShare failed: $e');
        debugPrint('❌ stack: $st');
        shareError = 'تم رفع الملف بنجاح، وتعذر تجهيز رابط الوصول: $e';
      }
      return NextcloudUploadResult(success: true, url: publicUrl, path: remotePath, fileName: name, error: shareError, shareReady: publicUrl != null && publicUrl.isNotEmpty);
    } catch (e, st) {
      debugPrint('❌ uploadFile failed: $e');
      debugPrint('❌ stack: $st');
      return NextcloudUploadResult(success: false, error: e.toString());
    }
  }

  Future<String?> createPublicShare(String remotePath) async {
    _ensureConfigured();
    try {
      final response = await http.post(
        Uri.parse('${_normalizedBase()}/ocs/v2.php/apps/files_sharing/api/v1/shares?format=json'),
        headers: _headers(),
        body: {'path': '/${_cleanLogicalPath(remotePath)}', 'shareType': '3'},
      );
      debugPrint('🔗 Share status: ${response.statusCode}');
      final bodyPreview = response.body.substring(0, response.body.length > 200 ? 200 : response.body.length);
      debugPrint('🔗 Share body: $bodyPreview');
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final ocs = body['ocs'] as Map<String, dynamic>?;
      final data = ocs?['data'] as Map<String, dynamic>?;
      final shareUrl = data?['url']?.toString();
      if (shareUrl == null || shareUrl.isEmpty) return null;
      return '${shareUrl.replaceFirst(RegExp(r'/$'), '')}/download';
    } catch (e, st) {
      debugPrint('❌ createPublicShare failed: $e');
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
