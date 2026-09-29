import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http';
import '../config/secrets.dart';

class NextcloudMediaService {
  const NextcloudMediaService();
  Future<MediaUploadResult> upload({required Uint8List bytes, required String filename, required String mimeType, required String chatId}) async {
    final endpoint = Secrets.nextcloudUrl.trim().replaceFirst(RegExp(r'/$'), '');
    if (endpoint.isEmpty) throw StateError('خادم الوسائط غير مهيأ');
    final user = Secrets.nextcloudUser, pass = Secrets.nextcloudPassword;
    final uri = Uri.parse('$endpoint/remote.php/dav/files/${Uri.encodeComponent(user)}/MemoChat/$chatId/${Uri.encodeComponent(filename)}');
    final auth = base64Encode(utf8.encode('$user:$pass'));
    final response = await http.put(uri, headers: {'Authorization': 'Basic $auth', 'Content-Type': mimeType, 'Content-Length': '${bytes.length}'}, body: bytes);
    if (response.statusCode != 201 && response.statusCode != 204) throw StateError('فشل رفع الملف: HTTP ${response.statusCode}');
    final publicUrl = await _createShare(endpoint, auth, '/MemoChat/$chatId/$filename');
    return MediaUploadResult(url: publicUrl ?? uri.toString(), filename: filename, mimeType: mimeType, size: bytes.length);
  }
  Future<String?> _createShare(String endpoint, String auth, String path) async {
    try {
      final response = await http.post(Uri.parse('$endpoint/ocs/v2.php/apps/files_sharing/api/v1/shares?format=json'), headers: {'Authorization': 'Basic $auth', 'OCS-APIRequest': 'true', 'Content-Type': 'application/x-www-form-urlencoded'}, body: {'path': path, 'shareType': '3'});
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final ocs = data['ocs']; final payload = ocs is Map ? ocs['data'] : null;
      final url = payload is Map ? payload['url']?.toString() : null;
      return url == null ? null : '${url.replaceFirst(RegExp(r'/$'), '')}/download';
    } catch (_) { return null; }
  }
}
class MediaUploadResult {
  const MediaUploadResult({required this.url, required this.filename, required this.mimeType, required this.size});
  final String url; final String filename; final String mimeType; final int size;
}