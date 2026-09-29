import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../config/secrets.dart';

class CallNotificationService {
  const CallNotificationService();
  Future<void> send(String callId) async {
    final base=Secrets.livekitTokenServerUrl.trim().replaceFirst(RegExp(r'/$'),'');
    final token=await FirebaseAuth.instance.currentUser?.getIdToken();
    if(base.isEmpty||token==null||token.isEmpty)return;
    await http.post(Uri.parse('$base/call-notification'),headers:{'Authorization':'Bearer $token','Content-Type':'application/json'},body:jsonEncode({'callId':callId}));
  }
}