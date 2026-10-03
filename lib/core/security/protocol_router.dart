import 'security_level.dart';
import 'security_settings_service.dart';

abstract interface class SecurityProtocolHandler {
  SecurityProtocol get protocol;

  Future<Object?> process(Object? input);
}

class ProtocolRouter {
  ProtocolRouter({
    SecuritySettingsService? settings,
    Iterable<SecurityProtocolHandler> handlers = const [],
  })  : _settings = settings ?? SecuritySettingsService.instance,
        _handlers = {
          for (final handler in handlers) handler.protocol: handler,
        };

  final SecuritySettingsService _settings;
  final Map<SecurityProtocol, SecurityProtocolHandler> _handlers;

  void register(SecurityProtocolHandler handler) {
    _handlers[handler.protocol] = handler;
  }

  void unregister(SecurityProtocol protocol) {
    _handlers.remove(protocol);
  }

  bool isEnabled(SecurityProtocol protocol) =>
      _settings.isEnabled(protocol);

  Future<Object?> apply(
    SecurityProtocol protocol,
    Object? input,
  ) async {
    if (!isEnabled(protocol)) return input;

    final handler = _handlers[protocol];
    if (handler == null) {
      throw StateError(
        'Protocol $\{protocol.name\} is enabled but has no registered handler.',
      );
    }

    return handler.process(input);
  }

  Future<Object?> applyForChat(
    String chatId,
    SecurityProtocol protocol,
    Object? input,
  ) async {
    if (!_settings.isEnabledForChat(chatId, protocol)) return input;

    final handler = _handlers[protocol];
    if (handler == null) {
      throw StateError(
        'Protocol $\{protocol.name\} is enabled but has no registered handler.',
      );
    }

    return handler.process(input);
  }

  Future<Object?> applyEnabled(
    Object? input, {
    Iterable<SecurityProtocol>? protocols,
  }) async {
    var current = input;

    for (final protocol in protocols ?? SecurityProtocol.values) {
      if (!_settings.isEnabled(protocol)) continue;
      current = await apply(protocol, current);
    }

    return current;
  }
}
