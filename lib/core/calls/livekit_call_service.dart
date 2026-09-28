import 'package:livekit_client/livekit_client.dart';

class LiveKitCallService {
  Future<Room> connect({
    required String serverUrl,
    required String token,
    RoomOptions? options,
  }) async {
    final room = Room();
    await room.connect(serverUrl, token, roomOptions: options);
    return room;
  }

  Future<void> disconnect(Room room) => room.disconnect();
}
