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
        SnackBar(content: Text('تم تطبيق $\{level.label\}')),
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
            child: Column(
              children: [
                _levelTile(
                  SecurityLevel.standard,
                  'Standard',
                  'E2EE الأساسي فقط — الإعداد الافتراضي.',
                ),
                _levelTile(
                  SecurityLevel.enhanced,
                  'Enhanced',
                  'E2EE مع حماية إضافية للبيانات الوصفية.',
                ),
                _levelTile(
                  SecurityLevel.maximum,
                  'Maximum',
                  'E2EE مع الطبقات المتقدمة المتاحة.',
                ),
                _levelTile(
                  SecurityLevel.custom,
                  'Custom',
                  'اختر كل بروتوكول بشكل مستقل.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'النقل',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          _protocolSwitch(
            SecurityProtocol.quicTransport,
            'QUIC',
            'نقل سريع عند توفره.',
          ),
          _protocolSwitch(
            SecurityProtocol.websocketFallback,
            'WebSocket',
            'مسار بديل عند تعذر QUIC.',
          ),
          _protocolSwitch(
            SecurityProtocol.httpsFallback,
            'HTTPS',
            'مسار توافق احتياطي.',
          ),
          const SizedBox(height: 12),
          const Text(
            'الخصوصية المتقدمة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          _protocolSwitch(
            SecurityProtocol.metadataProtection,
            'حماية البيانات الوصفية',
            'تقليل المعلومات غير الضرورية حول الرسائل.',
          ),
          _protocolSwitch(
            SecurityProtocol.onionRouting,
            'Onion Routing',
            'توجيه متعدد القفزات عبر مرحلات مستقلة.',
          ),
          _protocolSwitch(
            SecurityProtocol.sealedSender,
            'Sealed Sender',
            'تقليل كشف هوية المرسل للمرحلات.',
          ),
          _protocolSwitch(
            SecurityProtocol.postQuantumHybrid,
            'Post-Quantum Hybrid',
            'مسار تبادل مفاتيح هجين عند دعمه.',
          ),
          _protocolSwitch(
            SecurityProtocol.matrixBridge,
            'Matrix Bridge',
            'ربط اختياري مع شبكة Matrix.',
          ),
          _protocolSwitch(
            SecurityProtocol.dhtDiscovery,
            'DHT Discovery',
            'اكتشاف الأجهزة فقط، دون تخزين الرسائل.',
          ),
          _protocolSwitch(
            SecurityProtocol.meshOffline,
            'Mesh / BLE',
            'نقل اختياري دون إنترنت عبر الأجهزة القريبة.',
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
        onChanged: _saving ? null : (value) => _toggle(protocol, value),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
      ),
    );
  }
}
