import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memochat/app/app.dart';

void main() {
  testWidgets('MemoChat launches with the conversations shell', (tester) async {
    await tester.pumpWidget(const MemoChatApp());
    await tester.pump(const Duration(milliseconds: 100));

    final navigationBar = find.byType(NavigationBar);
    expect(find.descendant(of: navigationBar, matching: find.text('المحادثات')), findsOneWidget);
    expect(find.descendant(of: navigationBar, matching: find.text('تواصل')), findsOneWidget);
    expect(find.descendant(of: navigationBar, matching: find.text('المكالمات')), findsOneWidget);
    expect(find.descendant(of: navigationBar, matching: find.text('الإعدادات')), findsOneWidget);
  });
}
