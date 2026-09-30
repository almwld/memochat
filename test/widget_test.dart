import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memochat/features/auth/presentation/auth_screen.dart';

void main() {
  testWidgets('MemoChat exposes the production authentication entry point', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ar'),
        home: AuthScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('MemoChat'), findsOneWidget);
    expect(find.text('البريد الإلكتروني'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.text('إنشاء حساب جديد'), findsOneWidget);
  });
}
