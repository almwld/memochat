import 'package:flutter_test/flutter_test.dart';
import 'package:memochat/app/app.dart';

void main() {
  testWidgets('MemoChat launches with the conversations shell', (tester) async {
    await tester.pumpWidget(const MemoChatApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('المحادثات'), findsOneWidget);
    expect(find.text('تواصل'), findsOneWidget);
    expect(find.text('المكالمات'), findsOneWidget);
    expect(find.text('الإعدادات'), findsOneWidget);
  });
}
