import 'dart:async';
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

    final host = _host.text.trim();
    final peerId = _peerId.text.trim();
    final sharedSecret = _sharedSecret.text;
    if (host.isEmpty) {
      _snack('أدخل عنوان بوابة Tunnel أولاً.');
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9_.-]{1,64}$').hasMatch(peerId)) {
      _snack('أدخل معرّف جهاز صالحًا كما هو مسجل في إعدادات البوابة.');
      return;
    }
    if (sharedSecret.length < 24) {
      _snack('المفتاح المشترك يجب أن يحتوي على 24 حرفًا على الأقل.');
      return;
    }

    final p = await SharedPreferences.getInstance();
    await p.setString('vpn.tunnel.host', host);
    await p.setString('vpn.tunnel.peer_id', peerId);
    await _secureStorage.write(key: 'vpn.tunnel.shared_secret', value: sharedSecret);
    await p.setString('vpn.tunnel.fingerprint', _fingerprint.text.trim());
    await p.setString('vpn.tunnel.address', _address.text.trim());
    await p.setString('vpn.tunnel.route', _route.text.trim());

    final arguments = <String, dynamic>{
      'host': host,
      'peerId': peerId,
      'sharedSecret': sharedSecret,
      'fingerprint': _fingerprint.text.trim(),
      'address': _address.text.trim(),
      'route': _route.text.trim(),
    };
    try {
      final prepared = await _channel.invokeMethod<bool>('prepare', arguments) ?? false;
      if (!prepared) {
        _waitingForPermission = true;
        _snack('وافق على طلب VPN من النظام؛ سنتحقق من نجاح المصافحة بعد العودة.');
        return;
      }

      final started = await _channel.invokeMethod<bool>('start', arguments) ?? false;
      if (!started) {
        if (mounted) setState(() => _running = false);
        _snack('تعذر بدء خدمة Tunnel.');
        return;
      }

      _snack('بدأت الخدمة؛ جار التحقق من TLS وهوية الجهاز وواجهة TUN…');
      final connected = await _waitForTunnelState(showFailure: false);
      if (connected) {
        _snack('تم الاتصال ببوابة Tunnel والتحقق من هوية الجهاز.');
      } else {
        _snack('لم يكتمل الاتصال. تحقق من عنوان البوابة والمنفذ 4433 وبصمة الشهادة وبيانات الجهاز.');
      }
    } on PlatformException catch (e) {
      if (mounted) setState(() => _running = false);
      _snack(e.message ?? 'تعذر تشغيل VPN.');
    } catch (_) {
      if (mounted) setState(() => _running = false);
      _snack('تعذر حفظ إعدادات Tunnel أو تشغيله.');
    }
  }

  Future<bool> _waitForTunnelState({required bool showFailure}) async {
    final deadline = DateTime.now().add(const Duration(seconds: 12));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      try {
        final active = await _channel.invokeMethod<bool>('status') ?? false;
        if (active) {
          if (mounted) setState(() => _running = true);
          return true;
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _running = false);
    if (showFailure && mounted) {
      _snack('لم يتصل النفق بعد الموافقة. تحقق من الوصول إلى البوابة وإعدادات TLS.');
    }
    return false;
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
                    controller: _peerId,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'معرّف الجهاز في البوابة',
                      hintText: 'phone-a',
                      prefixIcon: Icon(Icons.devices_other_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _sharedSecret,
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'المفتاح المشترك لهذا الجهاز',
                      hintText: '24 حرفًا عشوائيًا على الأقل',
                      prefixIcon: Icon(Icons.key_rounded),
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
                'الاتصال يتطلب بوابة TLS تدعم تسجيل الأجهزة بالمفتاح المشترك، مع عنوان مختلف لكل جهاز. يجب أن يكون هناك مسار شبكي فعلي بين الراوترين؛ لا ينشئ VPN رابطًا فيزيائيًا بين MikroTik.',
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
