import 'package:livekit_client/livekit_client.dart';

class LiveKitCallService {
  Future<Room> connect({
    required String serverUrl,
    required String token,
    RoomOptions? options,
  }) async {
    final room = Room(roomOptions: options ?? const RoomOptions());
    await room.connect(serverUrl, token);
    return room;
  }

  Future<void> disconnect(Room room) => room.disconnect();
}
