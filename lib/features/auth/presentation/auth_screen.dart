import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/services/firebase_bootstrap.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _register = false, _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  String _publicId(String uid) => 'memo_' + uid.substring(0, 8).toLowerCase();

  Future<bool> _ensureFirebase() async {
    if (Firebase.apps.isNotEmpty) return true;
    final ready = await FirebaseBootstrap.initialize();
    if (!ready && mounted) {
      setState(() => _error = 'الخدمة غير جاهزة بعد. حاول مرة أخرى.');
    }
    return ready;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      if (!await _ensureFirebase()) return;
      final auth = FirebaseAuth.instance;
      if (_register) {
        final c = await auth.createUserWithEmailAndPassword(
          email: _email.text.trim(), password: _password.text);
        final u = c.user!;
        final name = _name.text.trim();
        final id = _publicId(u.uid);
        await u.updateDisplayName(name);
        await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
          'displayName': name, 'username': id, 'publicId': id, 'photoUrl': '',
          'isOnline': true, 'lastSeen': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        final c = await auth.signInWithEmailAndPassword(
          email: _email.text.trim(), password: _password.text);
        final u = c.user!;
        final id = _publicId(u.uid);
        await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
          'displayName': u.displayName ?? 'مستخدم MemoChat',
          'username': id, 'publicId': id, 'photoUrl': u.photoURL ?? '',
          'isOnline': true, 'lastSeen': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = switch (e.code) {
        'invalid-credential' || 'wrong-password' || 'user-not-found' =>
          'البريد أو كلمة المرور غير صحيحة.',
        'email-already-in-use' => 'هذا البريد مستخدم بالفعل.',
        'weak-password' => 'كلمة المرور ضعيفة.',
        'invalid-email' => 'أدخل بريداً صحيحاً.',
        _ => e.message ?? 'تعذر إكمال العملية.',
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر حفظ بيانات الحساب. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'اكتب بريدك الإلكتروني أولاً.');
      return;
    }
    try {
      if (!await _ensureFirebase()) return;
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال رابط إعادة تعيين كلمة المرور.')));
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر إرسال رابط إعادة التعيين.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const primary = Color(0xFF0A8F83);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Stack(children: [
            Positioned(top: -130, right: -100,
              child: _AuthOrb(size: 300, color: primary)),
            Positioned(bottom: -170, left: -120,
              child: _AuthOrb(size: 340, color: const Color(0xFF1C8770))),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 72, height: 72,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: primary,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [BoxShadow(
                              color: primary.withOpacity(.16),
                              blurRadius: 28, offset: const Offset(0, 12))],
                          ),
                          child: SvgPicture.asset('assets/icon/icon_app.svg'),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _register ? 'إنشاء حساب' : 'مرحباً بك في MemoChat',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(
                          _register
                              ? 'أنشئ حسابك وابدأ التواصل بأمان.'
                              : 'سجّل الدخول للعودة إلى محادثاتك.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(.62))),
                        const SizedBox(height: 28),
                        if (_register) ...[
                          TextFormField(
                            controller: _name,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'الاسم',
                              prefixIcon: Icon(Icons.person_outline_rounded)),
                            validator: (v) => v == null || v.trim().length < 2
                                ? 'أدخل اسمك.' : null),
                          const SizedBox(height: 14),
                        ],
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'البريد الإلكتروني',
                            prefixIcon: Icon(Icons.email_outlined)),
                          validator: (v) => v == null || !v.contains('@')
                              ? 'أدخل بريداً صحيحاً.' : null),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _password,
                          obscureText: true,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: const InputDecoration(
                            labelText: 'كلمة المرور',
                            prefixIcon: Icon(Icons.lock_outline_rounded)),
                          validator: (v) => v == null || v.length < 6
                              ? '6 أحرف على الأقل.' : null),
                        if (!_register)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: _busy ? null : _reset,
                              child: const Text('نسيت كلمة المرور؟'))),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(_error!, textAlign: TextAlign.center,
                              style: TextStyle(color: theme.colorScheme.error))),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: _busy
                                ? const SizedBox(width: 22, height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : Text(_register ? 'إنشاء الحساب' : 'تسجيل الدخول'))),
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: _busy ? null : () => setState(() {
                            _register = !_register; _error = null;
                          }),
                          child: Text(_register ? 'لدي حساب بالفعل' : 'إنشاء حساب جديد')),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _AuthOrb extends StatelessWidget {
  const _AuthOrb({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(.08), color.withOpacity(0)]),
      ),
    ),
  );
}
