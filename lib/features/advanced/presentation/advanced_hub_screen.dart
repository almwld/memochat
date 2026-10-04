import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/advanced_features_service.dart';
import '../../../core/services/mini_app_state_service.dart';
import '../../chat/services/livekit_service.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/premium_ui.dart';
import '../../communities/presentation/communities_screen.dart';

class AdvancedHubScreen extends StatelessWidget {
  const AdvancedHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final liveItems = [
      ('غرف صوتية', 'نقاشات مباشرة عبر LiveKit مع حضور لحظي.', Icons.mic_rounded, const VoiceRoomsScreen(), const Color(0xFF0A8F83)),
      ('المجتمعات', 'قنوات منظمة للنقاش، الأعضاء والمحتوى المشترك.', Icons.groups_rounded, const CommunitiesScreen(), const Color(0xFF1677C8)),
      ('Business', 'ملف نشاط احترافي قابل للاكتشاف والتواصل.', Icons.storefront_rounded, const BusinessScreen(), const Color(0xFF7B4DFF)),
    ];
    final productivityItems = [
      ('Mini Apps', 'ملاحظات وحاسبة داخل التطبيق مع مزامنة آمنة.', Icons.apps_rounded, const MiniAppsScreen(), const Color(0xFFEA7B24)),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('المزايا المتقدمة', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        children: [
          const PremiumHero(
            icon: AppIcons.more,
            title: 'وسّع تجربة MemoChat',
            subtitle: 'أدوات حية وإنتاجية مصممة لتعمل داخل محادثاتك، مع مزامنة وحماية أفضل.',
          ),
          const SizedBox(height: 18),
          const _AdvancedSectionTitle(icon: Icons.bolt_rounded, title: 'تجارب حية'),
          const SizedBox(height: 8),
          _AdvancedFeatureGrid(items: liveItems),
          const SizedBox(height: 20),
          const _AdvancedSectionTitle(icon: Icons.auto_awesome_rounded, title: 'إنتاجية داخلية'),
          const SizedBox(height: 8),
          _AdvancedFeatureGrid(items: productivityItems),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(child: Text('مصمم للعمل مع LiveKit وFirestore والمزامنة المحلية دون مغادرة التطبيق.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdvancedFeatureGrid extends StatelessWidget {
  const _AdvancedFeatureGrid({required this.items});
  final List<(String, String, IconData, Widget, Color)> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 680 ? 2 : 1;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 142,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return _AdvancedFeatureCard(
                title: item.$1,
                subtitle: item.$2,
                icon: item.$3,
                color: item.$5,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => item.$4)),
              );
            },
          );
        },
      );
}

class _AdvancedFeatureCard extends StatelessWidget {
  const _AdvancedFeatureCard({required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap});
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(17)),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 5),
                  Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.3, fontSize: 12)),
                ])),
                Icon(Icons.arrow_back_ios_new_rounded, size: 15, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      );
}

class _AdvancedSectionTitle extends StatelessWidget {
  const _AdvancedSectionTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;
  @override
  Widget build(BuildContext context) => Row(children: [Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 7), Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))]);
}

class VoiceRoomsScreen extends StatefulWidget {
  const VoiceRoomsScreen({super.key});
  @override State<VoiceRoomsScreen> createState() => _VoiceRoomsScreenState();
}

class _VoiceRoomsScreenState extends State<VoiceRoomsScreen> {
  final _service = AdvancedFeaturesService();

  Future<void> _createRoom() async {
    final name = TextEditingController();
    final topic = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('غرفة صوتية جديدة'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم الغرفة')),
          const SizedBox(height: 8),
          TextField(controller: topic, maxLines: 2, decoration: const InputDecoration(labelText: 'الموضوع (اختياري)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(onPressed: () async {
            try {
              await _service.createVoiceRoom(name: name.text, topic: topic.text);
              if (context.mounted) Navigator.pop(context, true);
            } catch (e) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
            }
          }, child: const Text('إنشاء')),
        ],
      ),
    );
    name.dispose();
    topic.dispose();
    if (result == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الغرف الصوتية'), actions: [
      IconButton(onPressed: _createRoom, icon: const Icon(Icons.add_rounded), tooltip: 'إنشاء غرفة'),
    ]),
    body: StreamBuilder(
      stream: _service.watchVoiceRooms(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('تعذر تحميل الغرف.'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final rooms = snapshot.data!.docs;
        if (rooms.isEmpty) return const Center(child: Text('لا توجد غرف نشطة حالياً.'));
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rooms.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final d = rooms[i].data();
            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.mic_rounded)),
                title: Text(d['name']?.toString() ?? 'غرفة'),
                subtitle: Text(d['topic']?.toString().isNotEmpty == true ? d['topic'].toString() : 'نقاش صوتي مباشر'),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => VoiceRoomScreen(
                    roomId: rooms[i].id,
                    roomName: d['roomName']?.toString() ?? '',
                    title: d['name']?.toString() ?? 'غرفة',
                  ),
                )),
              ),
            );
          },
        );
      },
    ),
  );
}

class VoiceRoomScreen extends StatefulWidget {
  const VoiceRoomScreen({required this.roomId, required this.roomName, required this.title, super.key});
  final String roomId;
  final String roomName;
  final String title;
  @override State<VoiceRoomScreen> createState() => _VoiceRoomScreenState();
}

class _VoiceRoomScreenState extends State<VoiceRoomScreen> {
  final _service = AdvancedFeaturesService();
  final _liveKit = LiveKitService();
  Room? _room;
  Timer? _participantsRefresh;
  bool _joining = true;
  bool _mic = false;
  bool _speaker = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _join();
  }

  Future<void> _join() async {
    try {
      await _service.joinVoiceRoom(widget.roomId);
      final user = FirebaseAuth.instance.currentUser;
      _room = await _liveKit.connectVoiceRoom(
        roomId: widget.roomId,
        roomName: widget.roomName,
        participantName: user?.displayName,
      );
      _participantsRefresh = Timer.periodic(const Duration(milliseconds: 700), (_) {
        if (mounted) setState(() {});
      });
      if (mounted) {
        setState(() {
          _joining = false;
          _mic = _liveKit.isMicrophoneEnabled;
          _speaker = _liveKit.isSpeakerOn;
        });
      }
    } catch (e) {
      try { await _service.leaveVoiceRoom(widget.roomId); } catch (_) {}
      if (mounted) {
        setState(() {
          _joining = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _toggleMic() async {
    final value = await _liveKit.toggleMicrophone();
    if (mounted) setState(() => _mic = value);
  }

  Future<void> _toggleSpeaker() async {
    final value = !_speaker;
    await _liveKit.setSpeakerphone(value);
    if (mounted) setState(() => _speaker = value);
  }

  Future<void> _leave() async {
    _participantsRefresh?.cancel();
    await _liveKit.endCall();
    try {
      await _service.leaveVoiceRoom(widget.roomId);
    } finally {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _participantsRefresh?.cancel();
    if (_liveKit.isConnected) unawaited(_liveKit.endCall());
    super.dispose();
  }

  List<_VoiceParticipant> _participants() {
    final room = _room;
    if (room == null) return const [];
    final result = <_VoiceParticipant>[];
    final local = room.localParticipant;
    if (local != null) {
      result.add(_VoiceParticipant(
        identity: local.identity,
        name: local.name.isEmpty ? 'أنت' : local.name,
        muted: !_mic,
        isLocal: true,
      ));
    }
    for (final participant in room.remoteParticipants.values) {
      dynamic p = participant;
      var muted = true;
      try {
        for (final publication in p.trackPublications.values) {
          final source = publication.source.toString().toLowerCase();
          if (source.contains('microphone')) {
            muted = publication.muted == true;
            break;
          }
        }
      } catch (_) {}
      result.add(_VoiceParticipant(
        identity: p.identity.toString(),
        name: p.name.toString().isEmpty ? 'مشارك' : p.name.toString(),
        muted: muted,
        isLocal: false,
      ));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final participants = _participants();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: _speaker ? 'السماعة الخارجية مفعلة' : 'السماعة الخارجية متوقفة',
            onPressed: _toggleSpeaker,
            icon: Icon(_speaker ? Icons.volume_up_rounded : Icons.volume_off_rounded),
          ),
        ],
      ),
      body: _joining
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_rounded, size: 56),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('العودة'),
                        ),
                      ],
                    ),
                  ),
                )
              : SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 18),
                      const Icon(Icons.graphic_eq_rounded, size: 46),
                      const SizedBox(height: 8),
                      Text(widget.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(
                        participants.length.toString() + ' مشارك الآن',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: participants.isEmpty
                            ? const Center(child: Text('بانتظار المشاركين…'))
                            : GridView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                                itemCount: participants.length,
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisExtent: 118,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                ),
                                itemBuilder: (_, index) {
                                  final participant = participants[index];
                                  return Card(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        CircleAvatar(
                                          radius: 28,
                                          child: Icon(participant.muted ? Icons.mic_off_rounded : Icons.mic_rounded),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          participant.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w800),
                                        ),
                                        Text(
                                          participant.muted ? 'صامت' : 'يتحدث',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FloatingActionButton.large(
                              onPressed: _toggleMic,
                              child: Icon(_mic ? Icons.mic_rounded : Icons.mic_off_rounded),
                            ),
                            const SizedBox(width: 18),
                            FloatingActionButton.large(
                              backgroundColor: Theme.of(context).colorScheme.error,
                              foregroundColor: Theme.of(context).colorScheme.onError,
                              onPressed: _leave,
                              child: const Icon(Icons.call_end_rounded),
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

class _VoiceParticipant {
  const _VoiceParticipant({
    required this.identity,
    required this.name,
    required this.muted,
    required this.isLocal,
  });
  final String identity;
  final String name;
  final bool muted;
  final bool isLocal;
}

class MiniAppsScreen extends StatelessWidget {
  const MiniAppsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final apps = [
      ('الملاحظات', 'مذكرة محلية سريعة محفوظة على الجهاز.', Icons.note_alt_rounded, const QuickNotesScreen()),
      ('الحاسبة', 'حاسبة بسيطة داخل MemoChat.', Icons.calculate_rounded, const MiniCalculatorScreen()),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Mini Apps')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: apps.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => Card(
          child: ListTile(
            leading: CircleAvatar(child: Icon(apps[i].$3)),
            title: Text(apps[i].$1, style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text(apps[i].$2),
            trailing: const Icon(Icons.chevron_left_rounded),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => apps[i].$4)),
          ),
        ),
      ),
    );
  }
}

class QuickNotesScreen extends StatefulWidget {
  const QuickNotesScreen({super.key});
  @override State<QuickNotesScreen> createState() => _QuickNotesScreenState();
}

class _QuickNotesScreenState extends State<QuickNotesScreen> {
  final _controller = TextEditingController();
  final _cloudState = MiniAppStateService();
  bool _loaded = false;
  bool _cloudSynced = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _controller.text = prefs.getString('mini_notes') ?? '';
    if (Firebase.apps.isNotEmpty && FirebaseAuth.instance.currentUser != null) {
      try {
        final cloud = await _cloudState.load('quick_notes');
        final cloudText = cloud?['text']?.toString();
        if (cloudText != null && cloudText.isNotEmpty) _controller.text = cloudText;
        _cloudSynced = cloud != null;
      } catch (_) {
        // Local notes remain available when the account or network is offline.
      }
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mini_notes', _controller.text);
    var message = 'تم الحفظ محلياً';
    if (Firebase.apps.isNotEmpty && FirebaseAuth.instance.currentUser != null) {
      try {
        await _cloudState.save('quick_notes', {'text': _controller.text});
        _cloudSynced = true;
        message = 'تم الحفظ محلياً ومزامنته سحابياً';
      } catch (_) {
        message = 'تم الحفظ محلياً؛ ستتم المزامنة عند توفر الاتصال';
      }
    }
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الملاحظات'), actions: [
      IconButton(onPressed: _loaded ? _save : null, icon: const Icon(Icons.save_rounded)),
    ]),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              _cloudSynced ? 'مزامنة سحابية مفعّلة' : 'حفظ محلي آمن',
              style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(child: TextField(controller: _controller, enabled: _loaded, maxLines: null, expands: true, decoration: const InputDecoration(hintText: 'اكتب ملاحظتك...'))),
        ],
      ),
    ),
  );
}

class MiniCalculatorScreen extends StatefulWidget {
  const MiniCalculatorScreen({super.key});
  @override State<MiniCalculatorScreen> createState() => _MiniCalculatorScreenState();
}

class _MiniCalculatorScreenState extends State<MiniCalculatorScreen> {
  String _value = '0';
  String _operator = '';
  double _first = 0;
  bool _fresh = true;

  void _press(String key) {
    setState(() {
      if (key == 'C') { _value = '0'; _operator = ''; _first = 0; _fresh = true; return; }
      if ('+-×÷'.contains(key)) { _first = double.tryParse(_value) ?? 0; _operator = key; _fresh = true; return; }
      if (key == '=') {
        final second = double.tryParse(_value) ?? 0;
        final result = switch (_operator) {
          '+' => _first + second,
          '-' => _first - second,
          '×' => _first * second,
          '÷' => second == 0 ? double.nan : _first / second,
          _ => second,
        };
        _value = result.isNaN ? 'خطأ' : result.toStringAsFixed(result.truncateToDouble() == result ? 0 : 4);
        _operator = '';
        _fresh = true;
        return;
      }
      if (key == '.') { if (!_value.contains('.')) _value += '.'; return; }
      if (_fresh || _value == 'خطأ') { _value = key; _fresh = false; }
      else if (_value.length < 18) _value += key;
    });
  }

  @override
  Widget build(BuildContext context) {
    const keys = ['C', '÷', '×', '-', '7', '8', '9', '+', '4', '5', '6', '=', '1', '2', '3', '.', '0'];
    return Scaffold(
      appBar: AppBar(title: const Text('الحاسبة')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Expanded(child: Align(alignment: Alignment.bottomRight, child: Text(_value, style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900)))),
          GridView.builder(
            shrinkWrap: true,
            itemCount: keys.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.35),
            itemBuilder: (_, i) => FilledButton(onPressed: () => _press(keys[i]), child: Text(keys[i], style: const TextStyle(fontSize: 20))),
          ),
        ]),
      ),
    );
  }
}

class BusinessScreen extends StatefulWidget {
  const BusinessScreen({super.key});
  @override State<BusinessScreen> createState() => _BusinessScreenState();
}

class _BusinessScreenState extends State<BusinessScreen> {
  final _service = AdvancedFeaturesService();

  Future<void> _createBusiness() async {
    final name = TextEditingController();
    final category = TextEditingController();
    final description = TextEditingController();
    final phone = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إنشاء ملف نشاط'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم النشاط')),
          TextField(controller: category, decoration: const InputDecoration(labelText: 'التصنيف')),
          TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'الوصف')),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'الهاتف (اختياري)')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(onPressed: () async {
            try {
              await _service.createBusiness(name: name.text, category: category.text, description: description.text, phone: phone.text);
              if (context.mounted) Navigator.pop(context, true);
            } catch (e) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
            }
          }, child: const Text('نشر')),
        ],
      ),
    );
    name.dispose(); category.dispose(); description.dispose(); phone.dispose();
    if (created == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Business'), actions: [
      IconButton(onPressed: _createBusiness, icon: const Icon(Icons.add_business_rounded)),
    ]),
    body: StreamBuilder(
      stream: _service.watchBusinesses(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('تعذر تحميل الأنشطة.'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('لا توجد أنشطة منشورة بعد.'));
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final d = docs[i].data();
            return Card(child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.storefront_rounded)),
              title: Text(d['name']?.toString() ?? 'نشاط', style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text('${d['category'] ?? 'عام'}\n${d['description'] ?? ''}'),
              isThreeLine: true,
            ));
          },
        );
      },
    ),
  );
}
