import 'package:flutter/material.dart';
import '../data/auth_service.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = AuthService();
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل الدخول')),
      body: Center(
        child: FilledButton(
          onPressed: () async {
            await service.signInAnonymously();
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('تسجيل مجهول'),
        ),
      ),
    );
  }
}
