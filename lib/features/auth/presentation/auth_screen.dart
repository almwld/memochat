import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';

import '../../../core/services/firebase_bootstrap.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.onFirebaseReady});

  final VoidCallback? onFirebaseReady;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _agreeTerms = false;

  bool _register = false;
  bool _busy = false;
  bool _googleBusy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _publicId(String uid) => 'memo_${uid.substring(0, 8).toLowerCase()}';

  Future<bool> _ensureFirebase() async {
    if (Firebase.apps.isNotEmpty) {
      widget.onFirebaseReady?.call();
      return true;
    }

    for (var attempt = 0; attempt < 4; attempt++) {
      final ready = await FirebaseBootstrap.initialize().timeout(
        const Duration(seconds: 8),
        onTimeout: () => false,
      );
      if (ready || Firebase.apps.isNotEmpty) {
        if (mounted) setState(() => _error = null);
        widget.onFirebaseReady?.call();
        return true;
      }
      if (attempt < 3) {
        await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
      }
    }

    if (mounted) {
      final firebaseError = FirebaseBootstrap.lastFirebaseError;
      final code = firebaseError?.code;
      final detail = code == null || code.isEmpty ? '' : ' (Firebase: $code)';
      setState(() => _error = 'تعذر تهيئة خدمة الحساب$detail. تحقق من إعدادات Firebase والإنترنت ثم حاول مرة أخرى.');
    }
    return false;
  }

  Future<void> _signInWithGoogle() async {
    if (_busy || _googleBusy) {
      return;
    }

    setState(() {
      _googleBusy = true;
      _error = null;
    });

    try {
      if (!await _ensureFirebase()) {
        return;
      }

      final googleSignIn = GoogleSignIn(
        scopes: const <String>['email'],
      );
      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw FirebaseAuthException(
          code: 'google-id-token-missing',
          message: 'لم يتم استلام رمز Google.',
        );
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final result = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = result.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'google-user-missing',
          message: 'تعذر إنشاء جلسة Google.',
        );
      }

      final displayName = user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : 'مستخدم MemoChat';

      try {
        await _writeUserDocument(
          user,
          displayName: displayName,
          publicId: _publicId(user.uid),
          includeCreatedAt: result.additionalUserInfo?.isNewUser == true,
        );
      } catch (_) {}
    } on GoogleSignInException catch (e) {
      if (!mounted) {
        return;
      }
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return;
      }
      setState(() {
        _error = 'تعذر تسجيل الدخول بحساب Google. حاول مرة أخرى.';
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = switch (e.code) {
          'account-exists-with-different-credential' =>
            'هذا البريد مرتبط بطريقة تسجيل دخول أخرى. سجّل الدخول بها أولاً.',
          'network-request-failed' =>
            'تحقق من اتصال الإنترنت ثم حاول مرة أخرى.',
          'operation-not-allowed' =>
            'تسجيل الدخول عبر Google غير مفعّل لهذا المشروع.',
          'google-id-token-missing' =>
            'لم يتم استلام رمز Google. تحقق من إعدادات OAuth ثم حاول مرة أخرى.',
          _ => e.message ?? 'تعذر تسجيل الدخول بحساب Google.',
        };
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر تسجيل الدخول بحساب Google. حاول مرة أخرى.');
      }
    } finally {
      if (mounted) {
        setState(() => _googleBusy = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_register && !_agreeTerms) {
      setState(() => _error = 'يجب الموافقة على الشروط والأحكام لإكمال إنشاء الحساب.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (!await _ensureFirebase()) {
        return;
      }

      final auth = FirebaseAuth.instance;
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (_register) {
        final credentials = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        final user = credentials.user!;
        final name = _nameController.text.trim();
        final publicId = _publicId(user.uid);

        // Keep the account signed in while email verification is completed.
        await user.sendEmailVerification();

        try {
          await user.updateDisplayName(name);
        } catch (_) {}

        try {
          await _writeUserDocument(
            user,
            displayName: name,
            publicId: publicId,
            includeCreatedAt: true,
          );
        } catch (_) {}
      } else {
        final credentials = await auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        final user = credentials.user!;
        try {
          await _writeUserDocument(
            user,
            displayName: user.displayName ?? 'مستخدم MemoChat',
            publicId: _publicId(user.uid),
          );
        } catch (_) {}
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = switch (e.code) {
          'invalid-credential' || 'wrong-password' || 'user-not-found' =>
            'البريد أو كلمة المرور غير صحيحة.',
          'email-already-in-use' => 'هذا البريد مستخدم بالفعل.',
          'weak-password' => 'كلمة المرور ضعيفة.',
          'invalid-email' => 'أدخل بريداً صحيحاً.',
          'too-many-requests' => 'محاولات كثيرة. حاول لاحقاً.',
          'user-disabled' => 'هذا الحساب معطل.',
          _ => e.message ?? 'تعذر إكمال العملية.',
        };
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر حفظ بيانات الحساب. حاول مرة أخرى.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _writeUserDocument(
    User user, {
    required String displayName,
    required String publicId,
    bool includeCreatedAt = false,
  }) async {
    final data = <String, dynamic>{
      'displayName': displayName,
      'username': publicId,
      'publicId': publicId,
      'photoUrl': user.photoURL ?? '',
      'isOnline': true,
      'lastSeen': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (includeCreatedAt) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set(data, SetOptions(merge: true));
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'اكتب بريدك الإلكتروني أولاً.');
      return;
    }

    setState(() => _error = null);

    try {
      if (!await _ensureFirebase()) {
        return;
      }

      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال رابط إعادة تعيين كلمة المرور.'),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = switch (e.code) {
            'invalid-email' => 'أدخل بريداً صحيحاً.',
            'too-many-requests' => 'محاولات كثيرة. حاول لاحقاً.',
            _ => 'تعذر إرسال رابط إعادة التعيين.',
          };
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر إرسال رابط إعادة التعيين.');
      }
    }
  }

  void _toggleMode() {
    if (_busy) {
      return;
    }

    setState(() {
      _register = !_register;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            dark ? const Color(0xFF071A18) : const Color(0xFFF5FAF9),
        body: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: -150,
                right: -110,
                child: _AuthOrb(size: 330, color: scheme.primary),
              ),
              Positioned(
                bottom: -180,
                left: -120,
                child: _AuthOrb(size: 380, color: scheme.secondary),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      children: [
                        _buildBrand(theme, scheme),
                        const SizedBox(height: 28),
                        _buildFormCard(theme, scheme, dark),
                        const SizedBox(height: 18),
                        Text(
                          'معرّفك العام يُنشأ تلقائياً بعد التسجيل ويمكن استخدامه للعثور عليك.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withOpacity(.48),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrand(ThemeData theme, ColorScheme scheme) {
    return Column(
      children: [
        Container(
          width: 86,
          height: 86,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withOpacity(.24),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Image.asset(
            'assets/icon/icon_app.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.forum_rounded,
              color: Colors.white,
              size: 46,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'MemoChat',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -.6,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'تواصل. شارك. ابقَ قريباً.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurface.withOpacity(.56),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard(ThemeData theme, ColorScheme scheme, bool dark) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: dark
          ? const Color(0xFF10201E).withOpacity(.94)
          : Colors.white.withOpacity(.96),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: scheme.primary.withOpacity(.10)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _register ? 'إنشاء حساب جديد' : 'مرحباً بعودتك',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _register
                    ? 'أنشئ هويتك في MemoChat وابدأ التواصل.'
                    : 'سجّل الدخول للوصول إلى محادثاتك.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withOpacity(.62),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              if (_register) ...[
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'الاسم',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 2) {
                      return 'أدخل اسمك.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
              ],
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (value) {
                  if (value == null || !value.contains('@')) {
                    return 'أدخل بريداً صحيحاً.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
                validator: (value) {
                  if (value == null || value.length < 8) {
                    return '8 أحرف على الأقل.';
                  }
                  return null;
                },
              ),
              if (_register) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'تأكيد كلمة المرور',
                    prefixIcon: Icon(Icons.lock_reset_rounded),
                  ),
                  validator: (value) => value != _passwordController.text
                      ? 'كلمتا المرور غير متطابقتين.'
                      : null,
                ),
                CheckboxListTile(
                  value: _agreeTerms,
                  onChanged: _busy ? null : (v) => setState(() => _agreeTerms = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('أوافق على الشروط والأحكام'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ] else
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: _busy ? null : _resetPassword,
                    child: const Text('نسيت كلمة المرور؟'),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: scheme.error.withOpacity(.08),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: scheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              SizedBox(
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: (_busy || _googleBusy) ? null : _signInWithGoogle,
                  icon: _googleBusy
                      ? const SizedBox(
                          width: 21,
                          height: 21,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const _GoogleMark(),
                  label: const Text(
                    'المتابعة باستخدام Google',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: scheme.outline.withOpacity(.35)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Divider(color: scheme.outline.withOpacity(.25))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'أو بالبريد الإلكتروني',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withOpacity(.48),
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: scheme.outline.withOpacity(.25))),
                ],
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 4),
              FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _register ? 'إنشاء الحساب' : 'تسجيل الدخول',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
              const SizedBox(height: 5),
              TextButton(
                onPressed: _toggleMode,
                child: Text(
                  _register ? 'لدي حساب بالفعل' : 'إنشاء حساب جديد',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 24,
      height: 24,
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _AuthOrb extends StatelessWidget {
  const _AuthOrb({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withOpacity(.08),
              color.withOpacity(0),
            ],
          ),
        ),
      ),
    );
  }
}
