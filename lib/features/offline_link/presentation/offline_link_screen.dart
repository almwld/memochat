import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Optional local-network channel. Independent from Firebase chat and VPN/TUN.
class OfflineLinkScreen extends StatefulWidget {
  const OfflineLinkScreen({super.key});

  @override
  State<OfflineLinkScreen> createState() => _OfflineLinkScreenState();
}

class _OfflineLinkScreenState extends State<OfflineLinkScreen> {
  static const int _port = 1440;
  static const String _historyKey = 'offline_link.history.v1';
  static const String _deviceKey = 'offline_link.device_id.v1';
  static const int _maxHistory = 500;

  final _hostController = TextEditingController();
  final _secretController = TextEditingController();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _algorithm = AesGcm.with256bits();
  final _random = math.Random.secure();
  final Set<Socket> _sockets = <Socket>{};
  final Map<Socket, StreamSubscription<String>> _subscriptions =
      <Socket, StreamSubscription<String>>{};
  final List<Map<String, dynamic>> _messages = <Map<String, dynamic>>[];

  ServerSocket? _server;
  StreamSubscription<Socket>? _serverSubscription;
  SecretKey? _sessionKey;
  String _deviceId = '';
  String _status = 'غير متصل';
  bool _listening = false;
  bool _connecting = false;
  bool _loading = true;
  bool _showSecret = false;

  @override
  void initState() {
    super.initState();
    _loadLocalState();
  }

  String _secureSuffix() => List<int>.generate(8, (_) => _random.nextInt(256))
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();

  Future<void> _loadLocalState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _deviceId = prefs.getString(_deviceKey) ??
          'mc-${DateTime.now().microsecondsSinceEpoch}-${_secureSuffix()}';
      await prefs.setString(_deviceKey, _deviceId);
      final saved = prefs.getString(_historyKey);
      if (saved != null) {
        final decoded = jsonDecode(saved);
        if (decoded is List) {
          _messages.addAll(decoded.whereType<Map>().map(
                (item) => Map<String, dynamic>.from(item),
              ));
        }
      }
    } catch (_) {
      _status = 'تعذر تحميل السجل المحلي';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _deriveKey() async {
    final secret = _secretController.text.trim();
    if (secret.length < 12) {
      throw const FormatException('اجعل عبارة الربط 12 حرفًا على الأقل.');
    }
    final digest = await Sha256().hash(utf8.encode(secret));
    _sessionKey = SecretKey(digest.bytes);
  }

  Future<Map<String, dynamic>> _seal(Map<String, dynamic> payload) async {
    final key = _sessionKey;
    if (key == null) throw StateError('لم يتم إعداد مفتاح الربط.');
    final nonce = await _algorithm.newNonce();
    final box = await _algorithm.encrypt(
      utf8.encode(jsonEncode(payload)),
      secretKey: key,
      nonce: nonce,
    );
    return <String, dynamic>{
      'v': 1,
      'nonce': base64Encode(box.nonce),
      'cipherText': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    };
  }

  Future<Map<String, dynamic>> _openFrame(String line) async {
    final key = _sessionKey;
    if (key == null) throw StateError('أدخل عبارة الربط أولاً.');
    final frame = jsonDecode(line);
    if (frame is! Map || frame['v'] != 1) {
      throw const FormatException('إطار بروتوكول غير مدعوم.');
    }
    final box = SecretBox(
      base64Decode(frame['cipherText'] as String),
      nonce: base64Decode(frame['nonce'] as String),
      mac: Mac(base64Decode(frame['mac'] as String)),
    );
    final clear = await _algorithm.decrypt(box, secretKey: key);
    final payload = jsonDecode(utf8.decode(clear));
    if (payload is! Map) throw const FormatException('محتوى رسالة غير صالح.');
    return Map<String, dynamic>.from(payload);
  }

  Future<void> _startListening() async {
    if (_listening) return;
    try {
      await _deriveKey();
      final server = await ServerSocket.bind(InternetAddress.anyIPv4, _port);
      _server = server;
      _serverSubscription = server.listen(
        _attachSocket,
        onError: (Object error) {
          if (mounted) setState(() => _status = 'تعذر استقبال الاتصالات');
        },
      );
      if (mounted) {
        setState(() {
          _listening = true;
          _status = 'يستقبل على المنفذ $_port';
        });
      }
    } on SocketException catch (error) {
      _snack(error.osError?.message ?? 'تعذر فتح المنفذ $_port.');
    } on Object catch (error) {
      _snack(error.toString());
    }
  }

  Future<void> _stopListening() async {
    await _serverSubscription?.cancel();
    _serverSubscription = null;
    await _server?.close();
    _server = null;
    if (mounted) setState(() {
      _listening = false;
      _status = _sockets.isEmpty ? 'غير متصل' : 'اتصال قائم';
    });
  }

  Future<void> _connect() async {
    final host = _hostController.text.trim();
    if (host.isEmpty) {
      _snack('أدخل عنوان IP للهاتف الذي يستقبل الاتصال.');
      return;
    }
    if (_connecting) return;
    setState(() {
      _connecting = true;
      _status = 'جارٍ الاتصال بـ $host:$_port';
    });
    try {
      await _deriveKey();
      final socket = await Socket.connect(host, _port,
          timeout: const Duration(seconds: 8));
      _attachSocket(socket);
      if (mounted) setState(() => _status = 'اتصال مباشر مع $host');
    } on Object catch (error) {
      if (mounted) setState(() => _status = 'فشل الاتصال؛ تحقق من المسارات والجدار الناري');
      _snack('تعذر الاتصال: $error');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  void _attachSocket(Socket socket) {
    if (_sockets.contains(socket)) return;
    _sockets.add(socket);
    final subscription = socket
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) => unawaited(_handleLine(socket, line)),
      onError: (_) => _removeSocket(socket),
      onDone: () => _removeSocket(socket),
      cancelOnError: true,
    );
    _subscriptions[socket] = subscription;
    if (mounted) {
      setState(() => _status = 'اتصال مباشر قائم (${_sockets.length})');
    }
    unawaited(_resendPending(socket));
  }

  Future<void> _handleLine(Socket socket, String line) async {
    try {
      final payload = await _openFrame(line);
      final type = payload['type'];
      final id = payload['id']?.toString() ?? '';
      if (id.isEmpty) return;
      if (type == 'message') {
        final alreadyReceived = _messages.any(
          (item) => item['id'] == id && item['outgoing'] != true,
        );
        if (!alreadyReceived) {
          _messages.add(<String, dynamic>{
            'id': id,
            'text': payload['text']?.toString() ?? '',
            'sentAt': payload['sentAt']?.toString() ??
                DateTime.now().toUtc().toIso8601String(),
            'outgoing': false,
            'delivered': true,
          });
          if (_messages.length > _maxHistory) {
            _messages.removeRange(0, _messages.length - _maxHistory);
          }
          await _persistHistory();
          if (mounted) setState(() {});
        }
        await _sendPayload(socket, <String, dynamic>{'type': 'ack', 'id': id});
      } else if (type == 'ack') {
        final index = _messages.indexWhere((item) => item['id'] == id);
        if (index >= 0 && _messages[index]['outgoing'] == true) {
          _messages[index]['delivered'] = true;
          await _persistHistory();
          if (mounted) setState(() {});
        }
      }
    } on Object {
      // Malformed or unauthenticated frames are ignored; they never escape to UI.
    }
  }

  Future<void> _sendPayload(Socket socket, Map<String, dynamic> payload) async {
    try {
      final frame = await _seal(payload);
      socket.write('${jsonEncode(frame)}\n');
      await socket.flush();
    } on Object {
      _removeSocket(socket);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    if (_sessionKey == null) {
      try {
        await _deriveKey();
      } on Object catch (error) {
        _snack(error.toString());
        return;
      }
    }
    final id = '$_deviceId-${DateTime.now().microsecondsSinceEpoch}-${_secureSuffix()}';
    final item = <String, dynamic>{
      'id': id,
      'text': text,
      'sentAt': DateTime.now().toUtc().toIso8601String(),
      'outgoing': true,
      'delivered': false,
    };
    _messages.add(item);
    if (_messages.length > _maxHistory) {
      _messages.removeRange(0, _messages.length - _maxHistory);
    }
    _messageController.clear();
    await _persistHistory();
    if (mounted) setState(() {});
    var sent = false;
    for (final socket in _sockets.toList()) {
      try {
        final frame = await _seal(<String, dynamic>{
          'type': 'message',
          'id': id,
          'text': text,
          'sentAt': item['sentAt'],
        });
        socket.write('${jsonEncode(frame)}\n');
        await socket.flush();
        sent = true;
      } on Object {
        _removeSocket(socket);
      }
    }
    if (!sent && mounted) {
      _snack('حُفظت الرسالة على هذا الهاتف؛ ستبقى غير مسلّمة حتى يتصل الطرف الآخر.');
    }
    _scrollToBottom();
  }

  Future<void> _resendPending(Socket socket) async {
    for (final item in _messages.where(
      (entry) => entry['outgoing'] == true && entry['delivered'] != true,
    )) {
      await _sendPayload(socket, <String, dynamic>{
        'type': 'message',
        'id': item['id'],
        'text': item['text'],
        'sentAt': item['sentAt'],
      });
    }
  }

  void _removeSocket(Socket socket) {
    _sockets.remove(socket);
    final subscription = _subscriptions.remove(socket);
    if (subscription != null) unawaited(subscription.cancel());
    socket.destroy();
    if (mounted) {
      setState(() => _status = _sockets.isEmpty
          ? (_listening ? 'ينتظر الطرف الآخر' : 'غير متصل')
          : 'اتصال مباشر قائم (${_sockets.length})');
    }
  }

  Future<void> _persistHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_historyKey, jsonEncode(_messages));
    } catch (_) {
      if (mounted) _snack('تعذر حفظ السجل المحلي.');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _hostController.dispose();
    _secretController.dispose();
    _scrollController.dispose();
    unawaited(_serverSubscription?.cancel());
    unawaited(_server?.close());
    for (final socket in _sockets.toList()) {
      unawaited(_subscriptions[socket]?.cancel());
      socket.destroy();
    }
    _sockets.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memo Offline Link',
            style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(_sockets.isEmpty ? Icons.router_outlined : Icons.link_rounded),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_status,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  if (_connecting)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ]),
                const SizedBox(height: 4),
                const Text(
                  'قناة محلية مستقلة عن Firebase وVPN. تعمل أثناء بقاء هذه الشاشة مفتوحة وعلى وجود مسار شبكي بين الراوترين.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Column(children: [
              TextField(
                controller: _secretController,
                obscureText: !_showSecret,
                decoration: InputDecoration(
                  labelText: 'عبارة الربط المشتركة (12 حرفًا فأكثر)',
                  prefixIcon: const Icon(Icons.key_rounded),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _showSecret = !_showSecret),
                    icon: Icon(_showSecret ? Icons.visibility_off : Icons.visibility),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _listening ? _stopListening : _startListening,
                    icon: Icon(_listening ? Icons.stop_circle_outlined : Icons.sensors_rounded),
                    label: Text(_listening ? 'إيقاف الاستقبال' : 'استقبال على :$_port'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _hostController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'IP الطرف الآخر',
                      hintText: '192.168.20.10',
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'اتصال',
                  onPressed: _connecting ? null : _connect,
                  icon: const Icon(Icons.link_rounded),
                ),
              ]),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'لا توجد رسائل محلية بعد. شغّل الاستقبال على أحد الهاتفين، ثم اتصل به من الهاتف الآخر باستخدام عنوان IP وعبارة الربط نفسها.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final outgoing = message['outgoing'] == true;
                      return Align(
                        alignment: outgoing
                            ? AlignmentDirectional.centerEnd
                            : AlignmentDirectional.centerStart,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 320),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: outgoing
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(message['text']?.toString() ?? ''),
                              const SizedBox(height: 4),
                              Text(
                                '${outgoing ? (message['delivered'] == true ? 'تم الاستلام' : 'بانتظار الاستلام') : 'واردة عبر الرابط المحلي'} • ${_formatTime(message['sentAt']?.toString())}',
                                style: Theme.of(context).textTheme.labelSmall,
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
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: const InputDecoration(
                      hintText: 'اكتب رسالة عبر الشبكة المحلية…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send_rounded),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String? value) {
    final parsed = DateTime.tryParse(value ?? '')?.toLocal();
    if (parsed == null) return '';
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
