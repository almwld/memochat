import 'package:flutter_test/flutter_test.dart';
import 'package:memochat/core/offline/pending_message_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('deduplicates queued messages', () async {
    SharedPreferences.setMockInitialValues({});
    final queue = PendingMessageQueue();
    final item = PendingMessage(
      id: 'm1',
      conversationId: 'c1',
      text: 'hello',
      createdAt: DateTime(2026, 1, 1),
    );
    await queue.enqueue(item);
    await queue.enqueue(item);
    expect((await queue.read()).length, 1);
  });
}
