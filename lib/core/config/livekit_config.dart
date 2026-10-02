/// Public LiveKit connection configuration.
///
/// The LiveKit URL and token-server URL are routing information, not
/// credentials. API keys/secrets stay exclusively on the trusted backend.
class LiveKitConfig {
  const LiveKitConfig._();

  static const String serverUrl = String.fromEnvironment(
    'LIVEKIT_URL',
    defaultValue: 'wss://memo-2jv45qyl.livekit.cloud',
  );

  static const String tokenServerUrl = String.fromEnvironment(
    'LIVEKIT_TOKEN_SERVER_URL',
    defaultValue: 'https://memochat-production-451e.up.railway.app',
  );

  static const int connectionTimeoutSeconds = 25;
  static const int tokenTimeoutSeconds = 15;
  static const int reconnectAttempts = 3;

  static bool get isValid =>
      serverUrl.startsWith('wss://') &&
      tokenServerUrl.startsWith('https://');
}
