import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/livekit_config.dart';

/// Explicit Railway bridge used by the caller to deliver the incoming-call
/// FCM event after the canonical Firestore call document has been created.
class CallNotificationService {
  const CallNotificationService();

  Future<void> send(String callId) async {
    final normalized = callId.trim();
    if (normalized.isEmpty) {
      throw StateError('معرّف المكالمة غير صالح');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('يجب تسجيل الدخول لإرسال إشعار المكالمة');
    }

    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw StateError('جلسة Firebase غير صالحة');
    }

    final base = LiveKitConfig.tokenServerUrl
        .trim()
        .replaceFirst(RegExp(r'/$'), '');
    if (base.isEmpty) {
      throw StateError('خادم إشعارات المكالمات غير مهيأ');
    }

    final response = await http
        .post(
          Uri.parse('$base/call-notification'),
          headers: <String, String>{
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, dynamic>{'callId': normalized}),
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'فشل إرسال إشعار المكالمة: HTTP ${response.statusCode}',
      );
    }
  }
}
