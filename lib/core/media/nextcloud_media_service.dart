import 'dart:convert';
import 'dart:io';

class NextcloudMediaService {
  NextcloudMediaService({required this.uploadEndpoint, this.bearerToken});

  final Uri uploadEndpoint;
  final String? bearerToken;

  Future<Uri> upload({
    required List<int> bytes,
    required String filename,
    String contentType = 'application/octet-stream',
  }) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(uploadEndpoint);
      request.headers.contentType = ContentType.parse(contentType);
      if (bearerToken != null && bearerToken!.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearerToken');
      }
      request.headers.set('X-MemoChat-Filename', base64Url.encode(utf8.encode(filename)));
      request.add(bytes);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Media upload failed: HTTP ' + response.statusCode.toString());
      }
      final location = response.headers.value(HttpHeaders.locationHeader);
      if (location == null) throw const HttpException('Upload succeeded without a Location header');
      return Uri.parse(location);
    } finally {
      client.close(force: true);
    }
  }
}
