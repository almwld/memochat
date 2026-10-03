/// Nextcloud configuration.
///
/// Credentials are supplied at build time with --dart-define in CI.
/// User-entered credentials remain stored in FlutterSecureStorage.
class NextcloudConfig {
  NextcloudConfig._();

  static const String url = String.fromEnvironment(
    'NEXTCLOUD_URL',
    defaultValue: 'https://noa.it.tabdigital.cloud',
  );

  static const String user = String.fromEnvironment(
    'NEXTCLOUD_USER',
    defaultValue: '',
  );

  static const String password = String.fromEnvironment(
    'NEXTCLOUD_PASSWORD',
    defaultValue: '',
  );

  static bool get isConfigured =>
      url.isNotEmpty && user.isNotEmpty && password.isNotEmpty;
}
