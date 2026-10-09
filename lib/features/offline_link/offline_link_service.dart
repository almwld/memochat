import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineLinkMessage {
  const OfflineLinkMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.isMine,
    required this.status,
  });

  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isMine;
  final String status;

  OfflineLinkMessage copyWith({String? status}) => OfflineLinkMessage(
        id: id,
        senderId: senderId,
        text: text,
        timestamp: timestamp,
        isMine: isMine,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'senderId': senderId,
        'text': text,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'isMine': isMine,
        'status': status,
      };

  factory OfflineLinkMessage.fromJson(Map<String, dynamic> json) =>
      OfflineLinkMessage(
        id: json['id']?.toString() ?? '',
        senderId: json['senderId']?.toString() ?? '',
        text: json['text']?.toString() ?? '',
        timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '')?.toLocal() ??
            DateTime.now(),
        isMine: json['isMine'] == true,
        status: json['status']?.toString() ?? 'received',
      );
}

/// Optional direct messenger over the separately configured MemoChat VPN.
/// It never reads or writes Firestore and is not used by ordinary chat rooms.
class OfflineLinkService extends ChangeNotifier {
  OfflineLinkService._();

  static final OfflineLinkService instance = OfflineLinkService._();
  static const String _historyKey = 'offline_link.messages.v1';
  static const int _historyLimit = 300;
  static const int defaultPort = 1440;

  final AesGcm _cipher = AesGcm.with256bits();
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _localKeyName = 'offline_link.local_history_key';
  final Random _random = Random.secure();
  final Set<Socket> _clients = <Socket>{};

  SharedPreferences? _preferences;
  ServerSocket? _server;
  StreamSubscription<Socket>? _serverSubscription;
  List<OfflineLinkMessage> _messages = <OfflineLinkMessage>[];
  String _localPeerId = '';
  String _remotePeerId = '';
  String _remoteAddress = '';
  String _sharedSecret = '';
  int _port = defaultPort;
  bool _initialized = false;
  bool _busy = false;

  List<OfflineLinkMessage> get messages =>
      List<OfflineLinkMessage>.unmodifiable(_messages);
  bool get isListening => _server != null;
  bool get isBusy => _busy;
  int get port => _port;

  Future<void> initialize() async {
    if (_initialized) return;
    _preferences = await SharedPreferences.getInstance();
    final stored = _preferences!.getString(_historyKey);
    final restored = <OfflineLinkMessage>[];
    if (stored != null && stored.isNotEmpty) {
      try {
        final envelope = Map<String, dynamic>.from(jsonDecode(stored) as Map);
        final key = await _localHistoryKey();
        final clear = await _cipher.decrypt(
          SecretBox(
            base64Decode(envelope['ciphertext']?.toString() ?? ''),
            nonce: base64Decode(envelope['nonce']?.toString() ?? ''),
            mac: Mac(base64Decode(envelope['mac']?.toString() ?? '')),
          ),
          secretKey: key,
        );
        final decoded = jsonDecode(utf8.decode(clear));
        if (decoded is List) {
          for (final value in decoded) {
            if (value is Map) {
              restored.add(OfflineLinkMessage.fromJson(
                Map<String, dynamic>.from(value),
              ));
            }
          }
        }
      } catch (error) {
        debugPrint('Offline Link local history could not be decrypted: $error');
      }
    }
    _messages = restored.take(_historyLimit).toList();
    _initialized = true;
    notifyListeners();
  }

  void configure({
    required String localPeerId,
    required String remotePeerId,
    required String remoteAddress,
    required String sharedSecret,
    int port = defaultPort,
  }) {
    // The bound TCP listener cannot move ports in-place. Reject a live port
    // change instead of letting the UI believe it is listening on a new port.
    if (_server != null && port != _port) {
      throw StateError('أوقف مستمع Offline Link قبل تغيير المنفذ.');
    }
    _localPeerId = localPeerId.trim();
    _remotePeerId = remotePeerId.trim();
    _remoteAddress = remoteAddress.trim();
    _sharedSecret = sharedSecret.trim();
    _port = port;
  }

  Future<void> startListening({int port = defaultPort}) async {
    await initialize();
    if (_server != null) return;
    if (_localPeerId.isEmpty || _sharedSecret.trim().length < 16) {
      throw StateError('أكمل معرّف الجهاز ومفتاح التشفير أولاً.');
    }
    if (!RegExp(r'^[a-zA-Z0-9_.-]{1,64}$').hasMatch(_localPeerId) ||
        !RegExp(r'^[a-zA-Z0-9_.-]{1,64}$').hasMatch(_remotePeerId) ||
        _localPeerId == _remotePeerId) {
      throw StateError('تحقق من معرّفي الجهازين قبل تشغيل القناة.');
    }
    final remoteIp = InternetAddress.tryParse(_remoteAddress);
    if (remoteIp == null || remoteIp.type != InternetAddressType.IPv4) {
      throw StateError('أدخل عنوان IPv4 الحقيقي للجهاز الآخر داخل الشبكة المترابطة.');
    }
    if (port < 1024 || port > 65535) {
      throw ArgumentError.value(port, 'port', 'منفذ غير صالح');
    }
    // Bind on all IPv4 interfaces so a peer routed through MikroTik WireGuard can reach this listener.
    final server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    _server = server;
    _port = port;
    _serverSubscription = server.listen(
      (socket) {
        _clients.add(socket);
        unawaited(_handleIncoming(socket));
      },
      onError: (Object error, StackTrace stack) {
        debugPrint('Offline Link listener error: $error');
      },
      onDone: () {
        if (identical(_server, server)) {
          _server = null;
          notifyListeners();
        }
      },
      cancelOnError: false,
    );
    notifyListeners();
  }

  Future<void> stopListening() async {
    final server = _server;
    _server = null;
    await _serverSubscription?.cancel();
    _serverSubscription = null;
    for (final socket in _clients.toList()) {
      socket.destroy();
    }
    _clients.clear();
    await server?.close();
    notifyListeners();
  }

  Future<SecretKey> _deriveKey() async {
    if (_sharedSecret.trim().length < 16) {
      throw StateError('مفتاح التشفير المشترك قصير جدًا.');
    }
    final digest = await Sha256().hash(utf8.encode(_sharedSecret));
    return SecretKey(digest.bytes);
  }

  String _newId() => List<int>.generate(16, (_) => _random.nextInt(256))
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();

  Future<bool> sendMessage(String text) async {
    await initialize();
    final clean = text.trim();
    if (clean.isEmpty || clean.length > 8000 || _busy) return false;
    if (_server == null) {
      throw StateError('شغّل مستمع Offline Link أولاً لاستقبال الرد والتأكيد.');
    }
    final remoteIp = InternetAddress.tryParse(_remoteAddress);
    if (remoteIp == null || remoteIp.type != InternetAddressType.IPv4) {
      throw StateError('أدخل عنوان IPv4 للجهاز الآخر داخل شبكة MikroTik، مثل 192.168.20.10.');
    }
    if (_localPeerId.isEmpty || _remotePeerId.isEmpty) {
      throw StateError('أكمل معرّف الجهاز المحلي والبعيد.');
    }

    final message = OfflineLinkMessage(
      id: _newId(),
      senderId: _localPeerId,
      text: clean,
      timestamp: DateTime.now(),
      isMine: true,
      status: 'pending',
    );
    await _append(message);
    return _deliver(message, remoteIp);
  }

  Future<bool> retryMessage(String messageId) async {
    await initialize();
    final index = _messages.indexWhere(
      (message) => message.id == messageId && message.isMine,
    );
    if (index < 0) return false;
    final message = _messages[index].copyWith(status: 'pending');
    await _replace(message);
    final remoteIp = InternetAddress.tryParse(_remoteAddress);
    if (remoteIp == null || remoteIp.type != InternetAddressType.IPv4) {
      await _replace(message.copyWith(status: 'failed'));
      throw StateError('عنوان الجهاز الآخر غير صالح.');
    }
    return _deliver(message, remoteIp);
  }

  Future<bool> _deliver(OfflineLinkMessage message, InternetAddress remoteIp) async {
    _busy = true;
    notifyListeners();
    Socket? socket;
    try {
      final key = await _deriveKey();
      final clear = utf8.encode(jsonEncode(<String, dynamic>{
        'id': message.id,
        'senderId': message.senderId,
        'text': message.text,
        'timestamp': message.timestamp.toUtc().toIso8601String(),
      }));
      final nonce = _cipher.newNonce();
      final encrypted = await _cipher.encrypt(clear, secretKey: key, nonce: nonce);
      final envelope = <String, dynamic>{
        'protocol': 'memochat-offline-v1',
        'id': message.id,
        'nonce': base64Encode(encrypted.nonce),
        'ciphertext': base64Encode(encrypted.cipherText),
        'mac': base64Encode(encrypted.mac.bytes),
      };

      socket = await Socket.connect(remoteIp, _port,
          timeout: const Duration(seconds: 8));
      socket.write('${jsonEncode(envelope)}\n');
      await socket.flush();
      final line = await socket
          .cast<List<int>>().transform(utf8.decoder)
          .transform(const LineSplitter())
          .first
          .timeout(const Duration(seconds: 8));
      final response = Map<String, dynamic>.from(jsonDecode(line) as Map);
      final expectedProof = await Hmac.sha256().calculateMac(
        utf8.encode('ack:${message.id}'),
        secretKey: key,
      );
      final receivedProof = base64Decode(response['proof']?.toString() ?? '');
      if (response['accepted'] != true ||
          response['id']?.toString() != message.id ||
          !_constantTimeEquals(receivedProof, expectedProof.bytes)) {
        throw StateError('لم يؤكد الجهاز الآخر استلام الرسالة بشكل موثوق.');
      }
      await _replace(message.copyWith(status: 'sent'));
      return true;
    } catch (error) {
      debugPrint('Offline Link send failed: $error');
      await _replace(message.copyWith(status: 'failed'));
      return false;
    } finally {
      socket?.destroy();
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _handleIncoming(Socket socket) async {
    try {
      if (_remoteAddress.isEmpty ||
          socket.remoteAddress.address != _remoteAddress) {
        throw const FormatException('Unexpected source address');
      }
      final line = await socket
          .cast<List<int>>().transform(utf8.decoder)
          .transform(const LineSplitter())
          .first
          .timeout(const Duration(seconds: 8));
      if (line.length > 90000) throw const FormatException('Message too large');
      final envelope = Map<String, dynamic>.from(jsonDecode(line) as Map);
      if (envelope['protocol'] != 'memochat-offline-v1') {
        throw const FormatException('Unsupported offline protocol');
      }

      final id = envelope['id']?.toString() ?? '';
      if (id.isEmpty || id.length > 64) throw const FormatException('Invalid message ID');
      final key = await _deriveKey();
      final nonce = base64Decode(envelope['nonce']?.toString() ?? '');
      final ciphertext = base64Decode(envelope['ciphertext']?.toString() ?? '');
      final mac = base64Decode(envelope['mac']?.toString() ?? '');
      final clear = await _cipher.decrypt(
        SecretBox(ciphertext, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
      );
      final payload = Map<String, dynamic>.from(jsonDecode(utf8.decode(clear)) as Map);
      final senderId = payload['senderId']?.toString().trim() ?? '';
      final text = payload['text']?.toString() ?? '';
      final payloadId = payload['id']?.toString() ?? '';
      if (payloadId != id ||
          senderId.isEmpty ||
          (_remotePeerId.isNotEmpty && senderId != _remotePeerId) ||
          text.trim().isEmpty) {
        throw const FormatException('Invalid encrypted message payload');
      }

      final duplicate = _messages.any((message) => message.id == id);
      if (!duplicate) {
        await _append(OfflineLinkMessage(
          id: id,
          senderId: senderId,
          text: text,
          timestamp: DateTime.tryParse(payload['timestamp']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
          isMine: false,
          status: 'received',
        ));
      }
      final acknowledgementProof = await Hmac.sha256().calculateMac(
        utf8.encode('ack:$id'),
        secretKey: key,
      );
      socket.write('${jsonEncode(<String, dynamic>{
        'accepted': true,
        'id': id,
        'proof': base64Encode(acknowledgementProof.bytes),
      })}\n');
      await socket.flush();
    } catch (error) {
      debugPrint('Offline Link receive rejected: $error');
      try {
        socket.write('${jsonEncode(<String, dynamic>{'accepted': false, 'message': 'invalid_message'})}\n');
        await socket.flush();
      } catch (_) {}
    } finally {
      _clients.remove(socket);
      socket.destroy();
    }
  }

  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }

  Future<void> _append(OfflineLinkMessage message) async {
    _messages.removeWhere((item) => item.id == message.id);
    _messages.insert(0, message);
    if (_messages.length > _historyLimit) {
      _messages = _messages.take(_historyLimit).toList();
    }
    await _persist();
    notifyListeners();
  }

  Future<void> _replace(OfflineLinkMessage message) async {
    final index = _messages.indexWhere((item) => item.id == message.id);
    if (index < 0) return;
    _messages[index] = message;
    await _persist();
    notifyListeners();
  }

  Future<SecretKey> _localHistoryKey() async {
    var encoded = await _secureStorage.read(key: _localKeyName);
    if (encoded != null && encoded.isNotEmpty) {
      try {
        final bytes = base64Decode(encoded);
        if (bytes.length == 32) return SecretKey(bytes);
      } catch (_) {}
    }
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    encoded = base64Encode(bytes);
    await _secureStorage.write(key: _localKeyName, value: encoded);
    return SecretKey(bytes);
  }

  Future<void> _persist() async {
    final prefs = _preferences ??= await SharedPreferences.getInstance();
    final clear = utf8.encode(jsonEncode(
      _messages.map((message) => message.toJson()).toList(),
    ));
    final nonce = _cipher.newNonce();
    final encrypted = await _cipher.encrypt(
      clear,
      secretKey: await _localHistoryKey(),
      nonce: nonce,
    );
    await prefs.setString(_historyKey, jsonEncode(<String, dynamic>{
      'nonce': base64Encode(encrypted.nonce),
      'ciphertext': base64Encode(encrypted.cipherText),
      'mac': base64Encode(encrypted.mac.bytes),
    }));
  }
}
