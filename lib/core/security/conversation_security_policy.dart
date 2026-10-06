import 'security_level.dart';
import 'security_settings_service.dart';

/// Applies conversation-level security metadata without changing the legacy
/// chat transport. Encryption layers remain suspended until a complete,
/// interoperable encrypted transport is explicitly re-enabled.
class ConversationSecurityPolicy {
  ConversationSecurityPolicy({
    SecuritySettingsService? settings,
  }) : _settings = settings ?? SecuritySettingsService.instance;

  final SecuritySettingsService _settings;

  Future<void> ensureReady() => _settings.load();

  bool metadataProtectionEnabled(String chatId) =>
      _settings.isEnabledForChat(chatId, SecurityProtocol.metadataProtection);

  Map<String, dynamic> messageSecurity(String chatId) => {
        'version': 1,
        'payload': 'legacy-plaintext',
        'metadataProtection': metadataProtectionEnabled(chatId),
      };

  String? summarySenderId(String chatId, String senderId) =>
      senderId;
}
