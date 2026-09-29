class Secrets {
  Secrets._();
  static const String livekitUrl = String.fromEnvironment('LIVEKIT_URL');
  static const String livekitTokenServerUrl = String.fromEnvironment('LIVEKIT_TOKEN_SERVER_URL');
  static const String nextcloudUrl = String.fromEnvironment('NEXTCLOUD_URL');
  static const String nextcloudUser = String.fromEnvironment('NEXTCLOUD_USER');
  static const String nextcloudPassword = String.fromEnvironment('NEXTCLOUD_PASSWORD');
}
