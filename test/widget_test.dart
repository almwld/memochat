import 'package:flutter_test/flutter_test.dart';

import 'package:memochat/app/app.dart';

void main() {
  testWidgets('MemoChat launches', (tester) async {
    await tester.pumpWidget(const MemoChatApp());

    expect(find.text('MemoChat'), findsOneWidget);
    expect(
      find.text('Your conversations will appear here.'),
      findsOneWidget,
    );
  });
}
