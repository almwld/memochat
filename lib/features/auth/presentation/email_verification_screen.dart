import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({required this.user, super.key});
  final User user;
  @override State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  Timer? _timer;
  bool _checking = false;
  bool _sending = false;
  String? _message;

  @override void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _check());
  }
  @override void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    try {
      await widget.user.reload();
      final user = FirebaseAuth.instance.currentUser;
      if (user?.emailVerified == true && mounted) {
        _timer?.cancel();
        setState(() => _message = 'تم التحقق من بريدك الإلكتروني بنجاح.');
      }
    } catch (_) {} finally { _checking = false; }
  }

  Future<void> _sendAgain() async {
    if (_sending) return;
    setState(() { _sending = true; _message = null; });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await user.sendEmailVerification();
      if (mounted) setState(() => _message = 'تم إرسال رسالة تحقق جديدة إلى بريدك الإلكتروني.');
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _message = e.code == 'too-many-requests' ? 'تم إرسال رسائل كثيرة. حاول بعد قليل.' : 'تعذر إرسال رسالة التحقق الآن.');
    } catch (_) {
      if (mounted) setState(() => _message = 'تعذر إرسال رسالة التحقق الآن.');
    } finally { if (mounted) setState(() => _sending = false); }
  }
  Future<void> _logout() async => FirebaseAuth.instance.signOut();

  @override Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? const Color(0xFF071A18) : const Color(0xFFF5FAF9),
        body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            elevation: 0, color: dark ? const Color(0xFF10201E) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: BorderSide(color: scheme.primary.withOpacity(.12))),
            child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
              Container(width: 78, height: 78, decoration: BoxDecoration(color: scheme.primary.withOpacity(.10), shape: BoxShape.circle), child: Icon(Icons.mark_email_unread_rounded, size: 40, color: scheme.primary)),
              const SizedBox(height: 20),
              const Text('تحقق من بريدك الإلكتروني', textAlign: TextAlign.center, style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Text('أرسلنا رسالة تحقق إلى\n' + (widget.user.email ?? '') + '\nافتح الرسالة واضغط رابط التحقق، ثم عد إلى MemoChat.', textAlign: TextAlign.center, style: TextStyle(height: 1.6, color: scheme.onSurface.withOpacity(.65))),
              const SizedBox(height: 22),
              if (_message != null) ...[Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: scheme.primary.withOpacity(.08), borderRadius: BorderRadius.circular(14)), child: Text(_message!, textAlign: TextAlign.center)), const SizedBox(height: 14)],
              SizedBox(width: double.infinity, height: 52, child: FilledButton.icon(onPressed: _checking ? null : _check, icon: const Icon(Icons.verified_rounded), label: const Text('تحققت من بريدي'))),
              const SizedBox(height: 10),
              TextButton(onPressed: _sending ? null : _sendAgain, child: Text(_sending ? 'جارٍ الإرسال...' : 'إعادة إرسال رسالة التحقق')),
              TextButton(onPressed: _logout, child: const Text('العودة إلى تسجيل الدخول')),
            ])),
          ),
        )))),
      ),
    );
  }
}