import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../offline_link_service.dart';

class OfflineLinkScreen extends StatefulWidget {
  const OfflineLinkScreen({super.key});

  @override
  State<OfflineLinkScreen> createState() => _OfflineLinkScreenState();
}

class _OfflineLinkScreenState extends State<OfflineLinkScreen> {
  static const _vpnChannel = MethodChannel('com.memo.app/vpn_tunnel');
  static const _secureStorage = FlutterSecureStorage();
  static const _messageKeyName = 'offline_link.message_key';

  final _remotePeerId = TextEditingController();
  final _remoteAddress = TextEditingController();
  final _sharedKey = TextEditingController();
  final _port = TextEditingController(text: '1440');
  final _message = TextEditingController();
  final _scrollController = ScrollController();
  final _service = OfflineLinkService.instance;

  String _localPeerId = '';
  String _localAddress = '';
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceChanged);
    unawaited(_load());
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    _remotePeerId.dispose();
    _remoteAddress.dispose();
    _sharedKey.dispose();
    _port.dispose();
    _message.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _service.initialize();
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    _localPeerId = prefs.getString('vpn.tunnel.peer_id') ?? '';
    _localAddress = prefs.getString('vpn.tunnel.address') ?? '';
    _remotePeerId.text = prefs.getString('offline_link.remote_peer_id') ?? '';
    _remoteAddress.text = prefs.getString('offline_link.remote_address') ?? '';
    _port.text = (prefs.getInt('offline_link.port') ?? OfflineLinkService.defaultPort).toString();
    final key = await _secureStorage.read(key: _messageKeyName);
    if (!mounted) return;
    _sharedKey.text = key ?? '';
    _configureService();
    setState(() => _loading = false);
  }

  void _configureService() {
    _service.configure(
      localPeerId: _localPeerId,
      remotePeerId: _remotePeerId.text.trim(),
      localAddress: _localAddress,
      remoteAddress: _remoteAddress.text.trim(),
      sharedSecret: _sharedKey.text,
      port: int.tryParse(_port.text.trim()) ?? OfflineLinkService.defaultPort,
    );
  }

  Future<bool> _saveAndValidate() async {
    final remoteId = _remotePeerId.text.trim();
    final remoteIp = _remoteAddress.text.trim();
    final key = _sharedKey.text;
    final port = int.tryParse(_port.text.trim());
    if (_localPeerId.isEmpty || _localAddress.isEmpty) {
      _show('أكمل إعداد VPN المحلي أولاً.');
      return false;
    }
    if (!RegExp(r'^[a-zA-Z0-9_.-]{1,64}$').hasMatch(remoteId) ||
        remoteId == _localPeerId) {
      _show('أدخل معرّف الجهاز الآخر الصحيح.');
      return false;
    }
    final parsedIp = InternetAddress.tryParse(remoteIp);
    final localIp = InternetAddress.tryParse(_localAddress.split('/').first);
    if (parsedIp == null || parsedIp.type != InternetAddressType.IPv4) {
      _show('أدخل عنوان IPv4 الافتراضي للجهاز الآخر، مثل 10.254.0.3.');
      return false;
    }
    if (localIp != null && localIp.address == parsedIp.address) {
      _show('يجب أن يكون لكل جهاز عنوان TUN مختلف.');
      return false;
    }
    if (key.trim().length < 24) {
      _show('مفتاح المراسلة المشترك يجب أن يحتوي على 24 حرفًا على الأقل.');
      return false;
    }
    if (port == null || port < 1024 || port > 65535) {
      _show('رقم المنفذ غير صالح.');
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('offline_link.remote_peer_id', remoteId);
    await prefs.setString('offline_link.remote_address', remoteIp);
    await prefs.setInt('offline_link.port', port);
    await _secureStorage.write(key: _messageKeyName, value: key);
    _configureService();
    return true;
  }

  Future<void> _toggleListener() async {
    if (_service.isListening) {
      await _service.stopListening();
      _show('تم إيقاف قناة المراسلة المحلية.');
      return;
    }
    try {
      final vpnRunning = await _vpnChannel.invokeMethod<bool>('status') ?? false;
      if (!vpnRunning) {
        _show('شغّل VPN Tunnel وتأكد من اتصال الجهاز بالبوابة أولاً.');
        return;
      }
      if (!await _saveAndValidate()) return;
      final port = int.parse(_port.text.trim());
      await _service.startListening(port: port);
      _show('قناة المراسلة جاهزة على المنفذ ' + port.toString() + '.');
    } catch (error) {
      _show('تعذر تشغيل قناة المراسلة: ' + error.toString());
    }
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty || _sending) return;
    try {
      if (!await _saveAndValidate()) return;
      if (!_service.isListening) {
        _show('شغّل الاستماع المحلي على الجهازين أولاً.');
        return;
      }
      setState(() => _sending = true);
      _message.clear();
      final delivered = await _service.sendMessage(text);
      if (!delivered) _show('لم يؤكد الجهاز الآخر الاستلام؛ يمكنك إعادة المحاولة من الرسالة.');
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    } catch (error) {
      _show('تعذر إرسال الرسالة: ' + error.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _show(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  String _statusLabel(OfflineLinkMessage message) {
    if (!message.isMine) return 'مستلمة';
    switch (message.status) {
      case 'sent':
        return 'تم تأكيد الاستلام';
      case 'failed':
        return 'فشل الإرسال';
      case 'pending':
        return 'جار الإرسال';
      default:
        return message.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = _service;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Link'),
        actions: [
          IconButton(
            tooltip: service.isListening ? 'إيقاف الاستماع' : 'تشغيل الاستماع',
            onPressed: _toggleListener,
            icon: Icon(service.isListening ? Icons.stop_circle_outlined : Icons.play_circle_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: service.isListening
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(service.isListening ? Icons.link_rounded : Icons.link_off_rounded),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    service.isListening
                        ? 'القناة المحلية نشطة — المنفذ ' + service.port.toString()
                        : 'مسار مستقل عن محادثات Firebase؛ يحتاج VPN متصلًا على الجهازين.',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: _toggleListener,
                  child: Text(service.isListening ? 'إيقاف' : 'تشغيل'),
                ),
              ],
            ),
          ),
          ExpansionTile(
            initiallyExpanded: !service.isListening,
            title: const Text('إعداد الطرف الآخر والتشفير'),
            subtitle: Text('جهازك المحلي: ' + (_localPeerId.isEmpty ? 'غير مضبوط' : _localPeerId)),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            children: [
              TextField(
                controller: _remotePeerId,
                enabled: !service.isListening,
                decoration: const InputDecoration(
                  labelText: 'معرّف الجهاز الآخر',
                  hintText: 'phone-b',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _remoteAddress,
                enabled: !service.isListening,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'عنوان TUN للجهاز الآخر',
                  hintText: '10.254.0.3',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _sharedKey,
                enabled: !service.isListening,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'مفتاح التشفير المشترك بين الطرفين',
                  helperText: 'أدخل القيمة نفسها على الجهازين؛ تُحفظ في التخزين الآمن.',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _port,
                enabled: !service.isListening,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'منفذ المراسلة',
                  helperText: '1440 افتراضيًا، ويجب أن يتطابق على الطرفين.',
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  'عنوان جهازك: ' + (_localAddress.isEmpty ? 'غير مضبوط' : _localAddress) +
                  '. لا تستخدم المفتاح نفسه المستخدم لمصادقة بوابة VPN.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _toggleListener,
                icon: Icon(service.isListening ? Icons.stop_rounded : Icons.link_rounded),
                label: Text(service.isListening ? 'إيقاف القناة' : 'حفظ الإعدادات وتشغيل القناة'),
              ),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: service.messages.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'لا توجد رسائل محلية بعد.\nشغّل القناة على الجهازين ثم أرسل رسالة تجريبية.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: service.messages.length,
                    itemBuilder: (context, index) {
                      final message = service.messages[index];
                      final mine = message.isMine;
                      final hour = message.timestamp.hour.toString().padLeft(2, '0');
                      final minute = message.timestamp.minute.toString().padLeft(2, '0');
                      return Align(
                        alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                        child: Container(
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .82),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                          decoration: BoxDecoration(
                            color: mine
                                ? (theme.brightness == Brightness.dark
                                    ? const Color(0xFF005C4B)
                                    : const Color(0xFFD9FDD3))
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(message.text),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(hour + ':' + minute, style: theme.textTheme.labelSmall),
                                  const SizedBox(width: 8),
                                  Text(_statusLabel(message), style: theme.textTheme.labelSmall),
                                  if (mine && message.status == 'failed')
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      tooltip: 'إعادة المحاولة',
                                      onPressed: () async {
                                        final ok = await service.retryMessage(message.id);
                                        if (!ok) _show('تعذرت إعادة إرسال الرسالة.');
                                      },
                                      icon: const Icon(Icons.refresh_rounded, size: 16),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _message,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'رسالة مباشرة مشفرة…',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending || !service.isListening ? null : _send,
                    icon: _sending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
