import 'security_level.dart';
import 'security_settings_service.dart';

/// Applies conversation-level security policy to the non-secret Firestore
/// envelope. Message content remains protected by the Signal E2EE layer.
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
        'payload': 'signal-e2ee',
        'metadataProtection': metadataProtectionEnabled(chatId),
      };

  String? summarySenderId(String chatId, String senderId) =>
      metadataProtectionEnabled(chatId) ? null : senderId;
}
