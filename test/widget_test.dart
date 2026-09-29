import 'package:flutter_test/flutter_test.dart';
import 'package:memochat/features/auth/presentation/auth_screen.dart';

void main() {
  testWidgets('MemoChat exposes the production authentication entry point', (tester) async {
    await tester.pumpWidget(const AuthScreen());
    await tester.pump();

    expect(find.text('MemoChat'), findsOneWidget);
    expect(find.text('البريد الإلكتروني'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.text('إنشاء حساب جديد'), findsOneWidget);
  });
}
