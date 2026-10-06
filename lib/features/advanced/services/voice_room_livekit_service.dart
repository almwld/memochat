import 'package:livekit_client/livekit_client.dart';
import '../../chat/services/livekit_service.dart';

/// Voice-room adapter kept separate from the call UI while sharing the
/// authenticated LiveKit transport used by MemoChat calls.
class VoiceRoomLiveKitService {
  final LiveKitService _liveKit = LiveKitService();

  Room? get room => _liveKit.room;
  bool get isConnected => _liveKit.isConnected;
  bool get isMicrophoneEnabled => _liveKit.isMicrophoneEnabled;
  bool get isSpeakerOn => _liveKit.isSpeakerOn;

  Future<void> ensureMediaPermissions() => _liveKit.ensureMediaPermissions(video: false);

  Future<Room> connectVoiceRoom({
    required String roomId,
    required String roomName,
    String? participantName,
  }) => _liveKit.connectVoiceRoom(
        roomId: roomId,
        roomName: roomName,
        participantName: participantName,
      );

  Future<bool> toggleMicrophone() => _liveKit.toggleMicrophone();

  Future<void> setSpeakerphone(bool on) => _liveKit.setSpeakerphone(on);

  Future<void> endRoom() => _liveKit.endCall();
}
