import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/repositories/chat_repository.dart';
import '../../chat/presentation/chat_room_screen.dart';
import '../data/shake_service.dart';

class ShakeScreen extends StatefulWidget {
  const ShakeScreen({required this.repository, super.key});

  final ChatRepository repository;

  @override
  State<ShakeScreen> createState() => _ShakeScreenState();
}

class _ShakeScreenState extends State<ShakeScreen>
    with SingleTickerProviderStateMixin {
  late final ShakeService _service;
  late final AnimationController _animation;
  bool _searching = false;
  bool _matched = false;
  bool _loadingUser = false;
  String? _otherUserId;
  Map<String, dynamic>? _user;
  String _status = 'فعّل البحث ثم رجّ هاتفك للعثور على شخص يهتز معك';

  @override
  void initState() {
    super.initState();
    _service = ShakeService();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _service.dispose();
    _animation.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_searching) return;
    setState(() {
      _searching = true;
      _matched = false;
      _otherUserId = null;
      _user = null;
      _status = 'جاري البحث... رجّ هاتفك الآن';
    });

    await _service.start(
      onShake: () {
        if (!mounted) return;
        _animation.repeat(reverse: true);
        setState(() => _status = 'تم اكتشاف الرجّة — نبحث عن مطابق...');
      },
      onMatch: (match) {
        if (!mounted || _matched || _loadingUser) return;
        _matched = true;
        _otherUserId = match.otherUserId;
        _loadUser(match.otherUserId);
      },
      onError: (_) {
        if (mounted) {
          setState(() => _status = 'تعذر تشغيل التعارف بالرجّ');
        }
      },
    );
  }

  Future<void> _loadUser(String userId) async {
    _loadingUser = true;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (!mounted || !doc.exists) return;
      setState(() {
        _user = doc.data();
        _status = 'تم العثور على شخص يشاركك الرجّة';
      });
      _animation.stop();
    } finally {
      _loadingUser = false;
    }
  }

  Future<void> _message() async {
    final id = _otherUserId;
    final data = _user;
    if (id == null || data == null) return;

    final name = data['displayName']?.toString() ?? 'مستخدم';
    final photo =
        data['photoUrl']?.toString() ?? data['photoURL']?.toString();

    final chatId = await widget.repository.createConversation(
      otherUserId: id,
      otherUserName: name,
      otherUserPhoto: photo,
    );

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          chatId: chatId,
          otherUserId: id,
          otherUserName: name,
          otherUserImage: photo,
        ),
      ),
    );
  }

  void _again() {
    _service.stopPresence();
    setState(() {
      _searching = false;
      _matched = false;
      _otherUserId = null;
      _user = null;
      _status = 'فعّل البحث ثم رجّ هاتفك للعثور على شخص يهتز معك';
    });
    _start();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final data = _user;
    final photo =
        data?['photoUrl']?.toString() ?? data?['photoURL']?.toString() ?? '';
    final name = data?['displayName']?.toString() ?? 'مستخدم';

    return Scaffold(
      appBar: AppBar(title: const Text('رجّ للتعارف')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: _animation,
                  builder: (_, child) => Transform.rotate(
                    angle: (_animation.value - .5) * .12,
                    child: child,
                  ),
                  child: Container(
                    width: 176,
                    height: 176,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0A8F83), Color(0xFFFF3F91)],
                      ),
                      borderRadius: BorderRadius.circular(48),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withOpacity(.22),
                          blurRadius: 30,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.vibration_rounded,
                      color: Colors.white,
                      size: 82,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  _matched ? 'تم العثور على شخص!' : 'رجّ هاتفك',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                if (data != null) ...[
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundImage:
                                photo.isNotEmpty ? NetworkImage(photo) : null,
                            child:
                                photo.isEmpty ? Text(name.characters.first) : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                if ((data['publicId']?.toString() ?? '').isNotEmpty)
                                  Text('@${data['publicId']}'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _message,
                      icon: const Icon(Icons.chat_bubble_rounded),
                      label: const Text('ابدأ المحادثة'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _again,
                    child: const Text('البحث عن شخص آخر'),
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 28),
                    child: FilledButton.icon(
                      onPressed: _searching ? null : _start,
                      icon: const Icon(Icons.vibration_rounded),
                      label: Text(
                        _searching ? 'جاري البحث...' : 'ابدأ التعارف',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
