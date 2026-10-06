import 'package:flutter/material.dart';

import '../../../core/security/security_level.dart';
import '../../../core/security/security_settings_service.dart';

class AdvancedPrivacyScreen extends StatefulWidget {
  const AdvancedPrivacyScreen({super.key});

  @override
  State<AdvancedPrivacyScreen> createState() => _AdvancedPrivacyScreenState();
}

class _AdvancedPrivacyScreenState extends State<AdvancedPrivacyScreen> {
  final _settings = SecuritySettingsService.instance;
  SecurityLevel _level = SecurityLevel.standard;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onChanged);
    _load();
  }

  Future<void> _load() async {
    await _settings.load();
    if (!mounted) return;
    setState(() => _level = _settings.level);
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() => _level = _settings.level);
  }

  @override
  void dispose() {
    _settings.removeListener(_onChanged);
    super.dispose();
  }

  Future<void> _applyLevel(SecurityLevel level) async {
    setState(() => _saving = true);
    try {
      await _settings.setLevel(level);
      if (!mounted) return;
      setState(() => _level = level);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تطبيق ' + level.label)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggle(SecurityProtocol protocol, bool value) async {
    await _settings.setProtocol(protocol, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'الخصوصية المتقدمة',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const Text(
            'مستوى الأمان',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.verified_user_rounded),
              title: const Text(
                'تشفير الرسائل الفعلي',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: const Text(
                'الرسائل تستخدم Signal E2EE فعليًا. لا نعرض طبقات Onion أو Post-Quantum أو Mesh كميزات جاهزة ما لم يكن لها تنفيذ حقيقي داخل التطبيق.',
              ),
              trailing: IconButton(
                tooltip: 'تبديل مستوى الحماية',
                onPressed: _saving
                    ? null
                    : () => _applyLevel(
                          _level == SecurityLevel.standard
                              ? SecurityLevel.enhanced
                              : _level == SecurityLevel.enhanced
                                  ? SecurityLevel.maximum
                                  : SecurityLevel.standard,
                        ),
                icon: Icon(
                  _level == SecurityLevel.maximum
                      ? Icons.lock_rounded
                      : Icons.lock_open_rounded,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'مستوى الحماية',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _levelTile(SecurityLevel.standard, 'قياسي', 'حماية أساسية مع التشفير الفعلي.'),
                _levelTile(SecurityLevel.enhanced, 'متقدم', 'يفعّل قدرات الحماية الفعلية المتاحة فقط.'),
                _levelTile(SecurityLevel.maximum, 'أقصى', 'أقصى إعدادات الحماية المتاحة حاليًا دون تفعيل ميزات وهمية.'),
                _levelTile(SecurityLevel.custom, 'مخصص', 'إعدادات يدوية للبروتوكولات المتاحة.'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'حالة الطبقات المتقدمة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _protocolSwitch(SecurityProtocol.metadataProtection, 'حماية البيانات الوصفية', 'جاهزة: بيانات الرسالة الحساسة تبقى داخل حمولة E2EE.'),
                _protocolSwitch(SecurityProtocol.onionRouting, 'Onion Routing', 'يتطلب مرحّل Onion/Tor فعليًا؛ لا يُفعّل دون خدمة مرحّل.'),
                _protocolSwitch(SecurityProtocol.sealedSender, 'Sealed Sender', 'يتطلب بوابة إرسال مختومة وقواعد مصادقة؛ لا يُفعّل دونها.'),
                _protocolSwitch(SecurityProtocol.postQuantumHybrid, 'Post-Quantum Hybrid', 'يتطلب تنفيذ ML-KEM/PQC متوافقًا على العميل والخادم.'),
                _protocolSwitch(SecurityProtocol.matrixBridge, 'Matrix Bridge', 'يتطلب Homeserver وBridge مُكوّنين فعليًا.'),
                _protocolSwitch(SecurityProtocol.dhtDiscovery, 'DHT Discovery', 'يتطلب شبكة DHT/Bootstrap حقيقية.'),
                _protocolSwitch(SecurityProtocol.meshOffline, 'Mesh / BLE', 'يتطلب طبقة BLE Mesh ونقلًا محليًا حقيقيًا.'),
                _protocolSwitch(SecurityProtocol.quicTransport, 'QUIC', 'يتطلب ناقل QUIC فعليًا؛ Firestore لا يتحول إلى QUIC من هذا المفتاح وحده.'),
                _protocolSwitch(SecurityProtocol.websocketFallback, 'WebSocket', 'جاهز كخيار نقل عندما يوفّر المسار WebSocket فعليًا.'),
                _protocolSwitch(SecurityProtocol.httpsFallback, 'HTTPS', 'جاهز كمسار النقل الآمن الأساسي.'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : () => _applyLevel(_level),
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: const Text('تطبيق'),
          ),
        ],
      ),
    );
  }

  Widget _levelTile(
    SecurityLevel level,
    String title,
    String subtitle,
  ) {
    return RadioListTile<SecurityLevel>(
      value: level,
      groupValue: _level,
      onChanged: _saving ? null : (value) {
        if (value != null) _applyLevel(value);
      },
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
    );
  }

  Widget _protocolSwitch(
    SecurityProtocol protocol,
    String title,
    String subtitle,
  ) {
    return AnimatedBuilder(
      animation: _settings,
      builder: (context, _) => SwitchListTile(
        value: _settings.isEnabled(protocol),
        onChanged: (_saving || !_settings.isOperational(protocol))
            ? null
            : (value) => _toggle(protocol, value),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          _settings.isOperational(protocol)
              ? subtitle + ' • جاهز'
              : subtitle + ' • غير متاح حتى اكتمال المكوّن المطلوب',
        ),
      ),
    );
  }
}
