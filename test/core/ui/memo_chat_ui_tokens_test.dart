import 'package:flutter_test/flutter_test.dart';
import 'package:memochat/core/ui/memo_chat_ui_tokens.dart';

void main() {
  test('UI tokens expose stable production design values', () {
    expect(MemoChatUiTokens.radiusSm, 10);
    expect(MemoChatUiTokens.radiusMd, 16);
    expect(MemoChatUiTokens.radiusLg, 22);
    expect(MemoChatUiTokens.durationFast.inMilliseconds, 160);
    expect(MemoChatUiTokens.durationNormal.inMilliseconds, 240);
  });
}
