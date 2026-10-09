import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Optional, isolated local-network messaging. It does not replace or hook into
/// the normal MemoChat/Firestore conversation pipeline.
class OfflineLinkScreen extends StatefulWidget {
  const OfflineLinkScreen({super.key});

  @override
  State<OfflineLinkScreen> createState() => _OfflineLinkScreenState();
}

class _OfflineLinkScreenState extends State<OfflineLinkScreen> {
  static const int _port = 42551;
  static const int _maxTextLength = 4000;
  final _hostController = TextEditingController();
  final _codeController = TextEditingController();
  final _messageController = TextEditingController();
  final _cipher = AesGcm.with256bits();
  final List<_OfflineMessage> _messages = [];
  final Set<String> _seenIds = {};
  final Random _random = Random.secure();

  ServerSocket? _server;
  Socket? _socket;
  StreamSubscription<String>? _socketSubscription;
  List<String> _localAddresses = [];
  List<int>? _sessionKey;
  bool _hostMode = true;
  bool _starting = false;
  bool _connected = false;
  String _status = 'غير متصل';

  @override
  void initState() {
    super.initState();
    _loadLocalAddresses();
  }

  Future<void> _loadLocalAddresses() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      final addresses = interfaces
          .expand((interface) => interface.addresses)
          .where((address) => address.type == InternetAddressType.IPv4)
          .map((address) => address.address)
          .where((address) => address != '0.0.0.0')
          .toSet()
          .toList()
        ..sort();
      if (mounted) setState(() => _localAddresses = addresses);
    } on SocketException {
      if (mounted) setState(() => _localAddresses = []);
    }
  }

  String _generateSessionCode() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    _sessionKey = bytes;
    final code = base64UrlEncode(bytes).replaceAll('=', '');
    _codeController.text = code;
    return code;
  }

  List<int>? _readSessionKey() {
    try {
      final normalized = base64Url.normalize(_codeController.text.trim());
      final bytes = base64Url.decode(normalized);
      return bytes.length == 32 ? bytes : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> _startHost() async {
    if (_starting || _connected || _server != null) return;
    if (_sessionKey == null) _generateSessionCode();
    setState(() {
      _starting = true;
      _status = 'جاري فتح القناة المحلية…';
    });
    try {
      final server = await ServerSocket.bind(InternetAddress.anyIPv4, _port);
      if (!mounted) {
        await server.close();
        return;
      }
      _server = server;
      server.listen(
        _attachSocket,
        onError: (Object error) => _setFailure('تعذر استقبال اتصال محلي.'),
      );
      setState(() {
        _starting = false;
        _status = 'بانتظار الجهاز الآخر على المنفذ $_port';
      });
    } on SocketException catch (error) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _status = 'تعذر فتح القناة المحلية: ${error.message}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _status = 'تعذر فتح القناة المحلية.';
      });
    }
  }

  Future<void> _startClient() async {
    if (_starting || _connected) return;
    final key = _readSessionKey();
    final host = _hostController.text.trim();
    if (key == null) {
      _showMessage('أدخل رمز الجلسة الكامل الذي أنشأه الجهاز المضيف.');
      return;
    }
    if (host.isEmpty) {
      _showMessage('أدخل عنوان IP المحلي للجهاز المضيف.');
      return;
    }

    setState(() {
      _starting = true;
      _status = 'جاري الاتصال بالجهاز المضيف…';
    });
    try {
      final socket = await Socket.connect(
        host,
        _port,
        timeout: const Duration(seconds: 8),
      );
      if (!mounted) {
        socket.destroy();
        return;
      }
      _sessionKey = key;
      _attachSocket(socket);
    } on SocketException {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _status = 'تعذر الاتصال. تحقق من الشبكة المحلية والعنوان والرمز.';
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _status = 'انتهت مهلة الاتصال. تأكد أن الجهازين على الشبكة نفسها.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _status = 'حدث خطأ أثناء الاتصال؛ بقي MemoChat الأساسي دون تغيير.';
      });
    }
  }

  void _attachSocket(Socket socket) {
    if (!mounted) {
      socket.destroy();
      return;
    }
    _socketSubscription?.cancel();
    _socket?.destroy();
    _socket = socket;
    setState(() {
      _starting = false;
      _connected = true;
      _status = 'اتصال محلي مباشر نشط';
    });
    _socketSubscription = utf8.decoder
        .bind(socket)
        .transform(const LineSplitter())
        .listen(
      (line) => unawaited(_handleIncomingLine(line)),
      onError: (Object _) => _handleDisconnect(),
      onDone: _handleDisconnect,
      cancelOnError: true,
    );
  }

  Future<void> _handleIncomingLine(String line) async {
    if (line.length > 12000 || _sessionKey == null) return;
    try {
      final envelope = jsonDecode(line) as Map<String, dynamic>;
      final nonce = base64Url.decode(envelope['n'] as String);
      final ciphertext = base64Url.decode(envelope['c'] as String);
      final mac = base64Url.decode(envelope['m'] as String);
      final clearBytes = await _cipher.decrypt(
        SecretBox(ciphertext, nonce: nonce, mac: Mac(mac)),
        secretKey: SecretKey(_sessionKey!),
      );
      final payload = jsonDecode(utf8.decode(clearBytes)) as Map<String, dynamic>;
      final id = payload['id'] as String?;
      final text = payload['text'] as String?;
      final timestamp = payload['time'] as int?;
      if (id == null || text == null || timestamp == null || text.length > _maxTextLength) {
        return;
      }
      if (!_seenIds.add(id) || !mounted) return;
      setState(() {
        _messages.add(_OfflineMessage(
          id: id,
          text: text,
          time: DateTime.fromMillisecondsSinceEpoch(timestamp),
          outgoing: false,
        ));
      });
    } on Object {
      // Wrong session codes and malformed packets are ignored without crashing
      // the app or affecting regular MemoChat conversations.
    }
  }

  Future<void> _sendMessage() async {
    final socket = _socket;
    final key = _sessionKey;
    final text = _messageController.text.trim();
    if (!_connected || socket == null || key == null || text.isEmpty) return;
    if (text.length > _maxTextLength) {
      _showMessage('الحد الأقصى للرسالة $_maxTextLength حرف.');
      return;
    }

    final id = base64UrlEncode(
      List<int>.generate(16, (_) => _random.nextInt(256)),
    ).replaceAll('=', '');
    final now = DateTime.now();
    try {
      final box = await _cipher.encrypt(
        utf8.encode(jsonEncode({
          'id': id,
          'time': now.millisecondsSinceEpoch,
          'text': text,
        })),
        secretKey: SecretKey(key),
      );
      final envelope = jsonEncode({
        'n': base64UrlEncode(box.nonce),
        'c': base64UrlEncode(box.cipherText),
        'm': base64UrlEncode(box.mac.bytes),
      });
      if (envelope.length > 12000) {
        _showMessage('تعذر إرسال الرسالة بسبب حجمها.');
        return;
      }
      socket.write('$envelope\n');
      _seenIds.add(id);
      if (!mounted) return;
      setState(() {
        _messages.add(_OfflineMessage(
          id: id,
          text: text,
          time: now,
          outgoing: true,
        ));
        _messageController.clear();
      });
    } on Object {
      _showMessage('تعذر تشفير الرسالة أو إرسالها عبر القناة المحلية.');
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    if (!mounted) return;
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _socket?.destroy();
    _socket = null;
    setState(() {
      _connected = false;
      _starting = false;
      _status = 'انقطع الاتصال المحلي؛ أعد الاتصال لإرسال رسائل جديدة.';
    });
  }

  void _setFailure(String message) {
    if (!mounted) return;
    setState(() {
      _starting = false;
      _connected = false;
      _status = message;
    });
  }

  Future<void> _stop() async {
    final subscription = _socketSubscription;
    _socketSubscription = null;
    await subscription?.cancel();
    _socket?.destroy();
    _socket = null;
    final server = _server;
    _server = null;
    await server?.close();
    if (!mounted) return;
    setState(() {
      _connected = false;
      _starting = false;
      _status = 'تم إيقاف القناة المحلية.';
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    _socket?.destroy();
    _server?.close();
    _hostController.dispose();
    _codeController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('القناة المحلية المستقلة'),
        actions: [
          IconButton(
            tooltip: 'تحديث عناوين الشبكة',
            onPressed: _loadLocalAddresses,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lan_rounded),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'وضع اختياري منفصل',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'يرسل النصوص مباشرة عبر شبكة Wi-Fi محلية أو نقطة اتصال، دون Firebase أو إنترنت. لا يغيّر مسار المحادثات العادي، ويتوقف عند مغادرة هذه الشاشة.',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        _connected ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                        color: _connected ? Colors.green : theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_status)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: true,
                icon: Icon(Icons.router_rounded),
                label: Text('هذا الجهاز مضيف'),
              ),
              ButtonSegment<bool>(
                value: false,
                icon: Icon(Icons.devices_rounded),
                label: Text('هذا الجهاز يتصل'),
              ),
            ],
            selected: {_hostMode},
            onSelectionChanged: _connected || _starting
                ? null
                : (selection) => setState(() => _hostMode = selection.first),
          ),
          const SizedBox(height: 12),
          if (_hostMode) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('عناوين هذا الجهاز على الشبكة المحلية',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    if (_localAddresses.isEmpty)
                      const Text('لم يُعثر على عنوان IPv4 محلي. اتصل بشبكة Wi-Fi أو نقطة اتصال ثم حدّث العناوين.')
                    else
                      ..._localAddresses.map(
                        (address) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.wifi_rounded),
                          title: SelectableText(address),
                          subtitle: const Text('عنوان المضيف — المنفذ 42551'),
                          trailing: IconButton(
                            tooltip: 'نسخ العنوان',
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: address));
                              _showMessage('تم نسخ عنوان الجهاز.');
                            },
                            icon: const Icon(Icons.copy_rounded),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _codeController,
                      readOnly: true,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'رمز جلسة مشفّر — شاركه مع الطرف الآخر',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _connected || _starting
                              ? null
                              : () {
                                  _generateSessionCode();
                                  setState(() {});
                                },
                          icon: const Icon(Icons.key_rounded),
                          label: const Text('توليد رمز جديد'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _codeController.text.isEmpty
                              ? null
                              : () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: _codeController.text),
                                  );
                                  _showMessage('تم نسخ رمز الجلسة.');
                                },
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('نسخ الرمز'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'أنشئ الرمز وشاركه عبر وسيلة موثوقة. لا تشاركه مع أشخاص آخرين؛ من يملكه يستطيع محاولة الانضمام إلى جلستك.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _starting || _connected ? null : _startHost,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('بدء الاستماع المحلي'),
            ),
          ] else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _hostController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'عنوان IP للجهاز المضيف',
                        hintText: 'مثال: 192.168.1.20',
                        prefixIcon: Icon(Icons.router_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _codeController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'رمز الجلسة الذي شاركه المضيف',
                        prefixIcon: Icon(Icons.key_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _starting || _connected ? null : _startClient,
                        icon: const Icon(Icons.link_rounded),
                        label: const Text('الاتصال بالجهاز المضيف'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_connected) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    SizedBox(
                      height: 260,
                      child: _messages.isEmpty
                          ? const Center(child: Text('القناة متصلة. أرسل أول رسالة نصية.'))
                          : ListView.builder(
                              reverse: true,
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final message = _messages[_messages.length - 1 - index];
                                return Align(
                                  alignment: message.outgoing
                                      ? AlignmentDirectional.centerEnd
                                      : AlignmentDirectional.centerStart,
                                  child: Container(
                                    constraints: const BoxConstraints(maxWidth: 300),
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: message.outgoing
                                          ? theme.colorScheme.primaryContainer
                                          : theme.colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(message.text),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${message.time.hour.toString().padLeft(2, '0')}:${message.time.minute.toString().padLeft(2, '0')}',
                                          style: theme.textTheme.labelSmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            minLines: 1,
                            maxLines: 4,
                            maxLength: _maxTextLength,
                            decoration: const InputDecoration(
                              hintText: 'رسالة محلية مشفّرة…',
                              border: OutlineInputBorder(),
                              counterText: '',
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _sendMessage,
                          icon: const Icon(Icons.send_rounded),
                          tooltip: 'إرسال',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _stop,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('إيقاف القناة'),
            ),
          ],
        ],
      ),
    );
  }
}

class _OfflineMessage {
  const _OfflineMessage({
    required this.id,
    required this.text,
    required this.time,
    required this.outgoing,
  });

  final String id;
  final String text;
  final DateTime time;
  final bool outgoing;
}
