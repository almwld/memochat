import 'secrets.dart';

class LiveKitConfig {
  const LiveKitConfig._();
  static const String url = Secrets.livekitUrl;
  static const String tokenServerUrl = Secrets.livekitTokenServerUrl;
}
