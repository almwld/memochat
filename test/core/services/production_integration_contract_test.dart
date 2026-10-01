import 'package:flutter_test/flutter_test.dart';
import 'package:memochat/core/services/call_session_service.dart';
import 'package:memochat/core/ui/memo_chat_ui_tokens.dart';

void main() {
  test('call terminal states remain closed', () {
    final service = CallSessionService();
    expect(service.isTerminal('ended'), isTrue);
    expect(service.isTerminal('rejected'), isTrue);
    expect(service.isTerminal('connected'), isFalse);
  });

  test('call status contract contains production states', () {
    expect(
      CallSessionService.allowedStatuses,
      containsAll(<String>['calling', 'ringing', 'connected', 'ended']),
    );
  });

  test('UI token contract remains stable', () {
    expect(MemoChatUiTokens.radiusSm, 10);
    expect(MemoChatUiTokens.radiusMd, 16);
    expect(MemoChatUiTokens.radiusLg, 22);
    expect(MemoChatUiTokens.durationFast.inMilliseconds, 160);
  });
}
