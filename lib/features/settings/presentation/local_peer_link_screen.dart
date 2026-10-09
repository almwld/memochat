import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A deliberately separate LAN-only transport. It never redirects normal chat
/// traffic and does not require Firebase or the existing VPN tunnel.
class LocalPeerLinkScreen extends StatefulWidget {
  const LocalPeerLinkScreen({super.key});

  @override
  State<LocalPeerLinkScreen> createState() => _LocalPeerLinkScreenState();
}

class _LocalPeerLinkScreenState extends State<LocalPeerLinkScreen> {
  static const _channel = MethodChannel('com.memo.app/local_link');
  static const _port = 39841;

  final _host = TextEditingController();
  final _code = TextEditingController();
  final _message = TextEditingController();
  final _scroll = ScrollController();
  final List<_LocalMessage> _messages = [];
  List<String> _addresses = const [];
  Timer? _poller;
  String _state = 'stopped';
  String _hint = 'هذه قناة محلية مستقلة؛ لا تغيّر مسار المحادثات المعتاد.';
  bool _busy = false;

  bool get _connected => _state == 'connected';
  bool get _listening => _state == 'listening';

  @override
  void initState() {
    super.initState();
    _refresh();
    _poller = Timer.periodic(const Duration(milliseconds: 700), (_) => _poll());
  }

  @override
  void dispose() {
    _poller?.cancel();
    _host.dispose();
    _code.dispose();
    _message.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final status = await _channel.invokeMapMethod<String, dynamic>('status');
      final addresses = await _channel.invokeListMethod<dynamic>('addresses') ?? const [];
      final history = await _channel.invokeListMethod<dynamic>('history') ?? const [];
      if (!mounted || status == null) return;
      setState(() {
        _state = status['state'] as String? ?? 'stopped';
        _addresses = addresses.map((value) => value.toString()).where((value) => value.isNotEmpty).toList();
        _messages
          ..clear()
          ..addAll(history.whereType<Map>().map((raw) {
            final item = Map<String, dynamic>.from(raw);
            return _LocalMessage(
              id: item['id']?.toString() ?? '',
              text: item['text']?.toString() ?? '',
              incoming: item['incoming'] == true,
              delivered: item['delivered'] == true,
            );
          }));
      });
    } on PlatformException catch (e) {
      if (mounted) setState(() => _hint = e.message ?? 'تعذر قراءة حالة القناة.');
    }
  }

  Future<void> _poll() async {
    if (!mounted || _busy) return;
    try {
      final status = await _channel.invokeMapMethod<String, dynamic>('status');
      final events = await _channel.invokeListMethod<dynamic>('poll') ?? const [];
      final history = await _channel.invokeListMethod<dynamic>('history') ?? const [];
      if (!mounted) return;
      var changed = false;
      setState(() {
        final nextState = status?['state'] as String? ?? 'stopped';
        if (_state != nextState) {
          _state = nextState;
          changed = true;
        }
        for (final raw in events) {
          if (raw is! Map) continue;
          final event = Map<String, dynamic>.from(raw);
          final type = event['type']?.toString() ?? '';
          final body = event['message']?.toString() ?? '';
          final id = event['id']?.toString() ?? '';
          if (type == 'state' || type == 'error') {
            _hint = body;
            changed = true;
          } else if (type == 'received' || type == 'sent' || type == 'delivered') {
            changed = true;
          }
        }
        _messages
          ..clear()
          ..addAll(history.whereType<Map>().map((raw) {
            final item = Map<String, dynamic>.from(raw);
            return _LocalMessage(
              id: item['id']?.toString() ?? '',
              text: item['text']?.toString() ?? '',
              incoming: item['incoming'] == true,
              delivered: item['delivered'] == true,
            );
          }));
      });
      if (changed && _scroll.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        });
      }
    } catch (_) {
      // A stopped or unavailable native service must not affect the main app.
    }
  }

  Future<void> _run(String method, [Map<String, dynamic>? args]) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _channel.invokeMethod<void>(method, args);
      await _refresh();
    } on PlatformException catch (e) {
      if (mounted) setState(() => _hint = e.message ?? 'تعذر تنفيذ العملية.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _validate() {
    if (_code.text.trim().length < 8) {
      setState(() => _hint = 'استخدم رمز اقتران مشتركًا لا يقل عن 8 أحرف.');
      return false;
    }
    return true;
  }

  Future<void> _listen() async {
    if (!_validate()) return;
    FocusScope.of(context).unfocus();
    await _run('listen', {'port': _port, 'pairingCode': _code.text.trim()});
  }

  Future<void> _connect() async {
    if (!_validate()) return;
    if (_host.text.trim().isEmpty) {
      setState(() => _hint = 'أدخل عنوان IP المحلي للهاتف الذي ينتظر الاتصال.');
      return;
    }
    FocusScope.of(context).unfocus();
    await _run('connect', {
      'host': _host.text.trim(),
      'port': _port,
      'pairingCode': _code.text.trim(),
    });
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty) return;
    _message.clear();
    await _run('send', {'text': text});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = _connected || _listening || _state == 'connecting';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memo Offline Link', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(active ? Icons.link_rounded : Icons.link_off_rounded,
                              color: active ? Colors.teal : theme.colorScheme.outline),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _connected ? 'القناة متصلة' : _listening ? 'بانتظار الهاتف الآخر' :
                                  _state == 'connecting' ? 'جاري الاتصال' : 'القناة متوقفة',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                          ),
                          if (active)
                            IconButton(
                              tooltip: 'إيقاف القناة',
                              onPressed: _busy ? null : () => _run('stop'),
                              icon: const Icon(Icons.stop_circle_outlined),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(_hint, style: theme.textTheme.bodySmall),
                      if (_listening) ...[
                        const SizedBox(height: 8),
                        Text(
                          _addresses.isEmpty
                              ? 'عنوان الهاتف المحلي غير متاح؛ تحقق من اتصال Wi-Fi.'
                              : 'عنوان هذا الهاتف: ${_addresses.join('، ')}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                      const SizedBox(height: 8),
                      const Text(
                        'يجب أن يكون الهاتفان على الشبكة المحلية نفسها أو على نقطة اتصال Wi-Fi، حتى لو لم تتوفر خدمة الإنترنت. افتح هذه الشاشة على الهاتفين واستخدم رمز الاقتران نفسه.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!_connected)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        TextField(
                          controller: _code,
                          obscureText: true,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: const InputDecoration(
                            labelText: 'رمز الاقتران المشترك (8 أحرف على الأقل)',
                            prefixIcon: Icon(Icons.key_rounded),
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: _busy || active ? null : _listen,
                          icon: const Icon(Icons.wifi_tethering_rounded),
                          label: const Text('انتظار اتصال على هذا الهاتف'),
                        ),
                        const Divider(height: 24),
                        TextField(
                          controller: _host,
                          keyboardType: TextInputType.number,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'عنوان IP المحلي للهاتف الآخر',
                            hintText: 'مثل 192.168.1.23',
                            prefixIcon: Icon(Icons.router_outlined),
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _busy || active ? null : _connect,
                          icon: const Icon(Icons.link_rounded),
                          label: const Text('الاتصال بالهاتف الآخر'),
                        ),
                        const SizedBox(height: 4),
                        Text('المنفذ المحلي: $_port', style: theme.textTheme.labelSmall),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              child: _messages.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('ستظهر الرسائل المحلية هنا بعد إنشاء الاتصال. هذه المحادثة منفصلة عن الدردشات المعتادة.'),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final item = _messages[index];
                        return Align(
                          alignment: item.incoming ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 320),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                            decoration: BoxDecoration(
                              color: item.incoming ? theme.colorScheme.surfaceContainerHighest : theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Align(alignment: AlignmentDirectional.centerStart, child: Text(item.text)),
                                if (!item.incoming)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Icon(item.delivered ? Icons.done_all_rounded : Icons.check_rounded, size: 15),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
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
                          hintText: _connected ? 'رسالة عبر الشبكة المحلية...' : 'اكتب رسالة لحفظها وإرسالها لاحقًا...',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _busy ? null : _send,
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LocalMessage {
  const _LocalMessage({
    required this.id,
    required this.text,
    required this.incoming,
    this.delivered = false,
  });

  final String id;
  final String text;
  final bool incoming;
  final bool delivered;

  _LocalMessage copyWith({bool? delivered}) => _LocalMessage(
        id: id,
        text: text,
        incoming: incoming,
        delivered: delivered ?? this.delivered,
      );
}
