import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../config/secrets.dart';

class LiveKitTokenService {
  const LiveKitTokenService();
  Future<LiveKitToken> issue({required String roomName, required String participantName}) async {
    final base = Secrets.livekitTokenServerUrl.trim().replaceFirst(RegExp(r'/$'), '');
    if (base.isEmpty) throw StateError('خادم LiveKit Token غير مهيأ');
    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (idToken == null || idToken.isEmpty) throw StateError('جلسة Firebase غير صالحة');
    final response = await http.post(Uri.parse('$base/token'), headers:{'Authorization':'Bearer $idToken','Content-Type':'application/json'}, body:jsonEncode({'roomName':roomName,'participantName':participantName}));
    if (response.statusCode < 200 || response.statusCode >= 300) throw StateError('تعذر إصدار توكن المكالمة: HTTP ${response.statusCode}');
    final data=jsonDecode(response.body) as Map<String,dynamic>; final payload=data['data'] as Map<String,dynamic>?;
    final jwt=payload?['token']?.toString() ?? ''; final url=payload?['url']?.toString() ?? Secrets.livekitUrl;
    if(jwt.isEmpty || url.isEmpty) throw StateError('استجابة LiveKit غير مكتملة');
    return LiveKitToken(token:jwt, serverUrl:url);
  }
}
class LiveKitToken { const LiveKitToken({required this.token,required this.serverUrl}); final String token; final String serverUrl; }