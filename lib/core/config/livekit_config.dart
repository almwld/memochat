// MemoChat LiveKit configuration aligned with the proven Sehatak call profile.
// Credentials remain server-side; only public routing/tuning is kept here.
class LiveKitConfig {
  const LiveKitConfig._();

  // Keep MemoChat's own Firebase-aware token backend. Pointing at Sehatak's
  // token server directly would verify tokens against the Sehatak Firebase
  // project and is therefore unsafe for MemoChat.
  static const String serverUrl = 'wss://memo-2jv45qyl.livekit.cloud';
  static const String tokenServerUrl = String.fromEnvironment(
    'LIVEKIT_TOKEN_SERVER_URL',
    defaultValue: 'https://c3mhwp72itmc-production-ar6e2elm.us-central1.suga.run',
  );

  // Same proven media profile used by Sehatak.
  static const int videoBitrate = 1000000;
  static const int videoFps = 30;
  static const int videoWidth = 640;
  static const int videoHeight = 480;
  static const int audioBitrate = 32000;
  static const int audioSampleRate = 44100;
  static const int roomTimeout = 300;
  static const int maxParticipants = 10;
  static const int connectionTimeout = 30;
  static const int reconnectAttempts = 3;

  static bool get isValid =>
      serverUrl.startsWith('wss://') && tokenServerUrl.startsWith('https://');

  static String canonicalRoomName(String callId) {
    var id = callId.trim();
    if (id.isEmpty) throw ArgumentError('callId is required');
    // Legacy callers sometimes persisted/passed call_call_<id>. Collapse all
    // duplicate prefixes before producing the single canonical room name.
    while (id.startsWith('call_')) {
      id = id.substring('call_'.length);
    }
    if (id.isEmpty) throw ArgumentError('callId is required');
    return 'call_$id';
  }

  static String normalizeRoomName(String roomName) {
    var value = roomName.trim();
    while (value.startsWith('call_call_')) {
      value = value.substring('call_'.length);
    }
    if (value.startsWith('call_')) return value;
    return 'call_$value';
  }
}
