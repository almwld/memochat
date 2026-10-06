import 'security_level.dart';
import 'security_settings_service.dart';

/// Applies conversation-level security metadata to the Signal transport.
class ConversationSecurityPolicy {
  ConversationSecurityPolicy({
    SecuritySettingsService? settings,
  }) : _settings = settings ?? SecuritySettingsService.instance;

  final SecuritySettingsService _settings;

  Future<void> ensureReady() => _settings.load();

  bool metadataProtectionEnabled(String chatId) =>
      _settings.isEnabledForChat(chatId, SecurityProtocol.metadataProtection);

  /// Single policy-level read for the explicit E2EE opt-in state used by chat.
  bool isEncryptionEnabledForChat(String chatId) =>
      _settings.isEncryptionEnabledForChat(chatId);

  Map<String, dynamic> messageSecurity(String chatId) => {
        'version': 1,
        'payload': 'signal-e2ee',
        'transport': 'signal',
        'metadataProtection': metadataProtectionEnabled(chatId),
      };

  String? summarySenderId(String chatId, String senderId) =>
      metadataProtectionEnabled(chatId) ? null : senderId;
}
