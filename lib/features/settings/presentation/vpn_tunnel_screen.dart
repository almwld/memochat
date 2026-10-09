import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class VpnTunnelScreen extends StatefulWidget {
  const VpnTunnelScreen({super.key});
  @override
  State<VpnTunnelScreen> createState() => _VpnTunnelScreenState();
}

class _VpnTunnelScreenState extends State<VpnTunnelScreen> with WidgetsBindingObserver {
  static const _channel = MethodChannel('com.memo.app/vpn_tunnel');
  final _host = TextEditingController();
  final _peerId = TextEditingController();
  final _sharedSecret = TextEditingController();
  final _fingerprint = TextEditingController();
  static const _secureStorage = FlutterSecureStorage();
  bool _waitingForPermission = false;
  final _address = TextEditingController(text: '10.254.0.2/32');
  final _route = TextEditingController(text: '10.254.0.0/24');
  bool _running = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshStatus());
      if (_waitingForPermission) {
        _waitingForPermission = false;
        unawaited(_waitForTunnelState(showFailure: true));
      }
    }
  }

  Future<void> _refreshStatus() async {
    try {
      final running = await _channel.invokeMethod<bool>('status') ?? false;
      if (mounted && running != _running) setState(() => _running = running);
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _host.dispose();
    _peerId.dispose();
    _sharedSecret.dispose();
    _fingerprint.dispose();
    _address.dispose();
    _route.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    _host.text = p.getString('vpn.tunnel.host') ?? '';
    _peerId.text = p.getString('vpn.tunnel.peer_id') ?? '';
    _sharedSecret.text = await _secureStorage.read(key: 'vpn.tunnel.shared_secret') ?? '';
    _fingerprint.text = p.getString('vpn.tunnel.fingerprint') ?? '';
    _address.text = p.getString('vpn.tunnel.address') ?? '10.254.0.2/32';
    _route.text = p.getString('vpn.tunnel.route') ?? '10.254.0.0/24';
    try {
      _running = await _channel.invokeMethod<bool>('status') ?? false;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggle() async {
    if (_running) {
      await _channel.invokeMethod<void>('stop');
      if (mounted) setState(() => _running = false);
      return;
    }
    if (_host.text.trim().isEmpty) {
      _snack('أدخل عنوان بوابة VPN أولاً.');
      return;
    }

    final p = await SharedPreferences.getInstance();
    await p.setString('vpn.tunnel.host', _host.text.trim());
    await p.setString('vpn.tunnel.fingerprint', _fingerprint.text.trim());
    await p.setString('vpn.tunnel.address', _address.text.trim());
    await p.setString('vpn.tunnel.route', _route.text.trim());

    try {
      final prepared = await _channel.invokeMethod<bool>('prepare', {
        'host': _host.text.trim(),
        'fingerprint': _fingerprint.text.trim(),
        'address': _address.text.trim(),
        'route': _route.text.trim(),
      }) ?? false;
      if (!prepared) {
        _snack('تم طلب إذن VPN من النظام؛ بعد الموافقة سيبدأ النفق تلقائيًا.');
        return;
      }

      final started = await _channel.invokeMethod<bool>('start', {
        'host': _host.text.trim(),
        'fingerprint': _fingerprint.text.trim(),
        'address': _address.text.trim(),
        'route': _route.text.trim(),
      });
      if (mounted) {
        setState(() => _running = started == true);
      }
      if (started == true) {
        _snack('جاري إنشاء قناة TLS مع البوابة على المنفذ 4433.');
      } else {
        _snack('تعذر بدء Tunnel.');
      }
    } on PlatformException catch (e) {
      _snack(e.message ?? 'تعذر تشغيل VPN.');
    }
  }

  void _snack(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('VPN Tunnel', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    child: Icon(_running ? Icons.vpn_lock_rounded : Icons.vpn_key_outlined),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _running ? 'النفق نشط' : 'النفق غير نشط',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _running
                              ? 'قناة TUN/TLS متصلة بالبوابة.'
                              : 'ميزة استثنائية للشبكات المعزولة عند انقطاع الإنترنت.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _host,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'بوابة Tunnel',
                      hintText: 'gateway.local أو 10.0.0.1',
                      prefixIcon: Icon(Icons.router_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _fingerprint,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(
                      labelText: 'SHA-256 لشهادة Gateway (اختياري)',
                      hintText: '64 حرفًا سداسيًا عشريًا',
                      prefixIcon: Icon(Icons.verified_user_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      'اتركه فارغًا لشهادة موثوقة من Android. للبوابة الداخلية استخدم بصمة شهادة الخادم بدل تعطيل TLS.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _address,
                    decoration: const InputDecoration(
                      labelText: 'عنوان TUN المحلي',
                      hintText: '10.254.0.2/32',
                      prefixIcon: Icon(Icons.device_hub_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _route,
                    decoration: const InputDecoration(
                      labelText: 'الشبكة عبر النفق',
                      hintText: '10.254.0.0/24',
                      prefixIcon: Icon(Icons.route_outlined),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'النفق الآن يعالج حزم IP بين TUN وبوابة TLS فعلية. يجب تشغيل tunnel-gateway على جهاز Linux متصل بالشبكة المعزولة وضبط التوجيه/الجدار الناري. هذا الوضع لا يصنع الرابط الفيزيائي بين MikroTik تلقائيًا.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _toggle,
            icon: Icon(_running ? Icons.stop_rounded : Icons.vpn_lock_rounded),
            label: Text(_running ? 'إيقاف النفق' : 'تفعيل VPN Tunnel'),
          ),
        ],
      ),
    );
  }
}
