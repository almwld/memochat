import 'package:flutter_test/flutter_test.dart';
import 'package:memochat/app/app.dart';

void main() {
  testWidgets('MemoChat launches', (tester) async {
    await tester.pumpWidget(const MemoChatApp());
    await tester.pump();
    expect(find.text('MemoChat'), findsAtLeastNWidgets(1));
    expect(find.text('ابدأ محادثة جديدة'), findsOneWidget);
  });
}
