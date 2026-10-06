import 'package:flutter_test/flutter_test.dart';
import 'package:memochat/core/config/livekit_config.dart';
import 'package:memochat/features/chat/models/call_model.dart';
import 'package:memochat/features/chat/services/call_service.dart';

void main() {
  group('MemoChat Sehatak call protocol', () {
    test('uses one canonical LiveKit room per call', () {
      expect(LiveKitConfig.canonicalRoomName('abc123'), 'call_abc123');
      expect(LiveKitConfig.canonicalRoomName('call_abc123'), 'call_abc123');
      expect(LiveKitConfig.canonicalRoomName('call_call_abc123'), 'call_abc123');
      expect(LiveKitConfig.normalizeRoomName('abc123'), 'call_abc123');
      expect(LiveKitConfig.normalizeRoomName('call_call_abc123'), 'call_abc123');
    });

    test('allows only the intended call lifecycle transitions', () {
      expect(CallService.isTransitionAllowed(CallStatus.calling, CallStatus.connected), isTrue);
      expect(CallService.isTransitionAllowed(CallStatus.ringing, CallStatus.connected), isTrue);
      expect(CallService.isTransitionAllowed(CallStatus.connected, CallStatus.ended), isTrue);
      expect(CallService.isTransitionAllowed(CallStatus.connected, CallStatus.missed), isFalse);
      expect(CallService.isTransitionAllowed(CallStatus.ended, CallStatus.connected), isFalse);
      expect(CallService.isTransitionAllowed(CallStatus.missed, CallStatus.connected), isFalse);
    });

    test('terminal statuses never become active again', () {
      for (final status in const [
        CallStatus.ended,
        CallStatus.missed,
        CallStatus.rejected,
        CallStatus.busy,
        CallStatus.cancelled,
      ]) {
        expect(status.isActive, isFalse);
      }
      expect(CallStatus.calling.isActive, isTrue);
      expect(CallStatus.ringing.isActive, isTrue);
      expect(CallStatus.connected.isActive, isTrue);
    });
  });
}
