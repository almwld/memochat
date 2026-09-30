import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/livekit_config.dart';

/// Client-side facade for the trusted LiveKit token endpoint.
///
/// No LiveKit API key or API secret is ever embedded in the APK.
class LiveKitTokenService {
  const LiveKitTokenService();

  Future<LiveKitToken> issue({
    required String roomName,
    required String participantName,
  }) async {
    final normalizedRoom = roomName.trim();
    if (normalizedRoom.isEmpty || normalizedRoom.length > 200) {
      throw StateError('اسم غرفة المكالمة غير صالح');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('يجب تسجيل الدخول قبل إجراء المكالمة');
    }

    final idToken = await user.getIdToken(true);
    if (idToken == null || idToken.isEmpty) {
      throw StateError('جلسة Firebase غير صالحة');
    }

    final base = LiveKitConfig.tokenServerUrl
        .trim()
        .replaceFirst(RegExp(r'/$'), '');
    if (base.isEmpty) {
      throw StateError('خادم LiveKit Token غير مهيأ');
    }

    final response = await http
        .post(
          Uri.parse('$base/token'),
          headers: <String, String>{
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, dynamic>{
            'roomName': normalizedRoom,
            'participantName': participantName.trim().isEmpty
                ? (user.displayName?.trim().isNotEmpty == true
                    ? user.displayName!.trim()
                    : 'مستخدم')
                : participantName.trim(),
            'participantIdentity': user.uid,
          }),
        )
        .timeout(
          const Duration(seconds: LiveKitConfig.tokenTimeoutSeconds),
        );

    Map<String, dynamic> payload = <String, dynamic>{};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        payload = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        payload['success'] != true) {
      throw StateError(
        payload['message']?.toString().trim().isNotEmpty == true
            ? payload['message'].toString()
            : 'تعذر إنشاء توكن LiveKit (${response.statusCode})',
      );
    }

    final data = payload['data'];
    if (data is! Map) {
      throw StateError('بيانات LiveKit غير صالحة');
    }

    final token = data['token']?.toString() ?? '';
    final serverUrl = data['url']?.toString().trim().isNotEmpty == true
        ? data['url'].toString().trim()
        : LiveKitConfig.serverUrl;

    if (token.isEmpty || !serverUrl.startsWith('wss://')) {
      throw StateError('استجابة LiveKit غير مكتملة');
    }

    return LiveKitToken(
      token: token,
      serverUrl: serverUrl,
    );
  }
}

class LiveKitToken {
  const LiveKitToken({
    required this.token,
    required this.serverUrl,
  });

  final String token;
  final String serverUrl;
}
