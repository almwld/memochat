import 'security_level.dart';
import 'security_settings_service.dart';

enum TransportKind {
  quic,
  webSocket,
  https,
}

class TransportSelector {
  TransportSelector({
    SecuritySettingsService? settings,
    Future<bool> Function()? quicAvailable,
    Future<bool> Function()? webSocketAvailable,
  })  : _settings = settings ?? SecuritySettingsService.instance,
        _quicAvailable = quicAvailable ?? (() async => false),
        _webSocketAvailable = webSocketAvailable ?? (() async => true);

  final SecuritySettingsService _settings;
  final Future<bool> Function() _quicAvailable;
  final Future<bool> Function() _webSocketAvailable;

  Future<TransportKind> select() async {
    await _settings.load();

    if (_settings.isEnabled(SecurityProtocol.quicTransport) &&
        await _quicAvailable()) {
      return TransportKind.quic;
    }

    if (_settings.isEnabled(SecurityProtocol.websocketFallback) &&
        await _webSocketAvailable()) {
      return TransportKind.webSocket;
    }

    if (_settings.isEnabled(SecurityProtocol.httpsFallback)) {
      return TransportKind.https;
    }

    // HTTPS is the safe compatibility floor for the transport selector.
    // The selector never enables a protocol setting on behalf of the user.
    return TransportKind.https;
  }

  Future<List<TransportKind>> availableOrder() async {
    await _settings.load();
    final result = <TransportKind>[];

    if (_settings.isEnabled(SecurityProtocol.quicTransport) &&
        await _quicAvailable()) {
      result.add(TransportKind.quic);
    }

    if (_settings.isEnabled(SecurityProtocol.websocketFallback) &&
        await _webSocketAvailable()) {
      result.add(TransportKind.webSocket);
    }

    if (_settings.isEnabled(SecurityProtocol.httpsFallback)) {
      result.add(TransportKind.https);
    }

    if (result.isEmpty) result.add(TransportKind.https);
    return result;
  }
}
