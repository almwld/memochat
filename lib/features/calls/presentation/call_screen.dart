import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import '../../../core/calls/livekit_token_service.dart';
import '../../../core/calls/call_notification_service.dart';
import '../../../core/notifications/ringtone_service.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key, required this.chatId, required this.otherUserId, required this.otherUserName, this.otherUserImage, required this.isVideo, this.incomingCallId});
  final String chatId, otherUserId, otherUserName;
  final String? otherUserImage;
  final bool isVideo;
  final String? incomingCallId;
  @override State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _token = const LiveKitTokenService();
  final _db = FirebaseFirestore.instance;
  final _ringtone = RingtoneService();
  Room? _room;
  Timer? _timer;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _callSubscription;
  String? _callId;
  String? _error;
  bool _connecting = false, _muted = false, _camera = false, _speaker = true;
  int _seconds = 0;
  bool get _isIncoming => widget.incomingCallId != null;

  @override void initState() {
    super.initState();
    if (_isIncoming) { _callId = widget.incomingCallId; _loadIncoming(); } else { _startOutgoing(); }
  }

  Future<void> _loadIncoming() async {
    try {
      final ref = _db.collection('calls').doc(widget.incomingCallId);
      final snap = await ref.get();
      final data = snap.data();
      if (!snap.exists || data == null) throw StateError('المكالمة غير موجودة');
      if (data['receiverId'] != FirebaseAuth.instance.currentUser?.uid) throw StateError('هذه المكالمة ليست موجهة لهذا المستخدم');
      if (data['status'] == 'ended' || data['status'] == 'rejected') throw StateError('انتهت المكالمة');
      await _ringtone.startIncomingCallRingtone(vibrate: true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _startOutgoing() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { if (mounted) setState(() => _error = 'يرجى تسجيل الدخول'); return; }
    final ref = _db.collection('calls').doc();
    _callId = ref.id;
    final roomName = 'call_${ref.id}';
    try {
      await ref.set({
        'callId': ref.id, 'chatId': widget.chatId, 'callerId': uid, 'receiverId': widget.otherUserId,
        'callerName': FirebaseAuth.instance.currentUser?.displayName ?? 'مستخدم',
        'callerPhotoUrl': FirebaseAuth.instance.currentUser?.photoURL ?? '',
        'receiverName': widget.otherUserName, 'receiverPhotoUrl': widget.otherUserImage ?? '',
        'isVideo': widget.isVideo, 'callType': widget.isVideo ? 'video' : 'audio', 'status': 'calling',
        'roomName': roomName, 'liveKitRoomName': roomName,
        'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp(),
      });
      await const CallNotificationService().send(ref.id);
      if (mounted) setState(() => _connecting = false);
      _callSubscription = ref.snapshots().listen((snap) async {
        final data = snap.data();
        final status = data?['status']?.toString();
        if (status == 'accepted' || status == 'connected') {
          await _callSubscription?.cancel();
          _callSubscription = null;
          await _connect(roomName, ref);
        } else if (status == 'rejected' || status == 'ended') {
          await _callSubscription?.cancel();
          _callSubscription = null;
          if (mounted) {
            setState(() => _error = status == 'rejected' ? 'تم رفض المكالمة' : 'انتهت المكالمة');
          }
        }
      });
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
  }

  Future<void> _acceptIncoming() async {
    final ref = _db.collection('calls').doc(widget.incomingCallId);
    try {
      await HapticFeedback.mediumImpact();
      await _ringtone.stopIncomingCallRingtone();
      final snap = await ref.get();
      final data = snap.data();
      if (!snap.exists || data == null) throw StateError('المكالمة غير متاحة');
      if (data['status'] == 'ended' || data['status'] == 'rejected') throw StateError('انتهت المكالمة');
      final roomName = (data['roomName'] ?? 'call_${ref.id}').toString();
      await ref.update({'status': 'accepted', 'answeredAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()});
      await _connect(roomName, ref);
    } catch (e) {
      if (mounted) setState(() { _connecting = false; _error = e.toString(); });
    }
  }

  Future<void> _rejectIncoming() async {
    await HapticFeedback.mediumImpact();
    await _ringtone.stopIncomingCallRingtone();
    final id = _callId;
    if (id != null) {
      await _db.collection('calls').doc(id).set({'status': 'rejected', 'endedAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _connect(String roomName, DocumentReference<Map<String, dynamic>> ref) async {
    try {
      if (mounted) setState(() => _connecting = true);
      final issued = await _token.issue(roomName: roomName, participantName: FirebaseAuth.instance.currentUser?.displayName ?? 'مستخدم');
      final room = Room(roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true));
      await room.connect(issued.serverUrl, issued.token);
      await room.localParticipant?.setMicrophoneEnabled(true);
      if (widget.isVideo) await room.localParticipant?.setCameraEnabled(true);
      await room.setSpeakerOn(true);
      if (!mounted) { await room.disconnect(); return; }
      setState(() { _room = room; _connecting = false; _camera = widget.isVideo; });
      await ref.update({'status': 'connected', 'connectedAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()});
      _timer = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() => _seconds++); });
    } catch (e) { if (mounted) setState(() { _connecting = false; _error = e.toString(); }); }
  }

  Future<void> _mute() async {
    final p = _room?.localParticipant; if (p == null) return;
    final next = !_muted; await p.setMicrophoneEnabled(!next); if (mounted) setState(() => _muted = next);
  }
  Future<void> _cameraToggle() async {
    final p = _room?.localParticipant; if (p == null || !widget.isVideo) return;
    final next = !_camera; await p.setCameraEnabled(next); if (mounted) setState(() => _camera = next);
  }
  Future<void> _speakerToggle() async {
    final next = !_speaker; await _room?.setSpeakerOn(next); if (mounted) setState(() => _speaker = next);
  }
  Future<void> _end() async {
    await HapticFeedback.mediumImpact();
    await _ringtone.stopAllSounds();
    final id = _callId;
    if (id != null) await _db.collection('calls').doc(id).set({'status': 'ended', 'endedAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    _timer?.cancel();
    final room = _room; if (room != null) await room.disconnect();
    if (mounted) Navigator.of(context).pop();
  }
  @override void dispose() {
    unawaited(_ringtone.dispose()); _timer?.cancel(); unawaited(_callSubscription?.cancel());
    final room = _room; if (room != null) unawaited(room.disconnect()); super.dispose();
  }
  String _time() => '${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}';

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF081012),
    body: SafeArea(child: Stack(children: [
      if (_room != null) Positioned.fill(child: _remoteView()),
      if (_isIncoming && _room == null && _error == null) _incomingView(),
      if (!_isIncoming && _room == null && _error == null) _outgoingView(),
      if (_connecting) const Center(child: CircularProgressIndicator(color: Color(0xFF0A8F83))),
      if (_error != null) _errorView(),
      if (_room != null) _controls(),
    ])),
  );

  Widget _incomingView() => Center(child: Padding(
    padding: const EdgeInsets.all(28),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      CircleAvatar(radius: 62, backgroundImage: widget.otherUserImage?.isNotEmpty == true ? NetworkImage(widget.otherUserImage!) : null, child: widget.otherUserImage?.isNotEmpty == true ? null : const Icon(Icons.person_rounded, size: 58)),
      const SizedBox(height: 20),
      Text(widget.otherUserName, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text(widget.isVideo ? 'مكالمة فيديو واردة' : 'مكالمة صوتية واردة', style: const TextStyle(color: Colors.white70)),
      const SizedBox(height: 32),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _roundAction(Icons.call_end_rounded, Colors.red, _rejectIncoming),
        const SizedBox(width: 32),
        _roundAction(widget.isVideo ? Icons.videocam_rounded : Icons.call_rounded, const Color(0xFF0A8F83), _acceptIncoming),
      ]),
    ]),
  ));

  Widget _outgoingView() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    CircleAvatar(radius: 62, backgroundImage: widget.otherUserImage?.isNotEmpty == true ? NetworkImage(widget.otherUserImage!) : null, child: widget.otherUserImage?.isNotEmpty == true ? null : const Icon(Icons.person_rounded, size: 58)),
    const SizedBox(height: 20),
    Text(widget.otherUserName, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
    const SizedBox(height: 8),
    Text(widget.isVideo ? 'جاري الاتصال عبر الفيديو...' : 'جاري الاتصال...', style: const TextStyle(color: Colors.white70)),
    const SizedBox(height: 28),
    const CircularProgressIndicator(color: Color(0xFF0A8F83)),
    const SizedBox(height: 28),
    IconButton.filled(onPressed: _end, style: IconButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.all(20)), icon: const Icon(Icons.call_end_rounded, size: 30)),
  ]));

  Widget _roundAction(IconData icon, Color color, VoidCallback action) => IconButton.filled(
    onPressed: action, style: IconButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, padding: const EdgeInsets.all(20)), icon: Icon(icon, size: 30),
  );

  Widget _errorView() => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, color: Colors.white70, size: 56),
      const SizedBox(height: 12),
      const Text('تعذر بدء الاتصال', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8), Text(_error!, style: const TextStyle(color: Colors.white60), textAlign: TextAlign.center),
      const SizedBox(height: 20), FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('عودة')),
    ]),
  ));

  Widget _controls() => Stack(children: [
    PositionedDirectional(top: 12, start: 12, end: 12, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      IconButton(onPressed: _end, icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white)),
      Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(24)), child: Text(_time(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
    ])),
    PositionedDirectional(start: 16, end: 16, bottom: 24, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(32)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _button(_muted ? Icons.mic_off : Icons.mic, _mute),
        if (widget.isVideo) _button(_camera ? Icons.videocam : Icons.videocam_off, _cameraToggle),
        _button(_speaker ? Icons.volume_up : Icons.volume_off, _speakerToggle),
        _button(Icons.call_end, _end, danger: true),
      ]),
    )),
  ]);

  Widget _button(IconData icon, VoidCallback action, {bool danger = false}) => IconButton.filled(
    onPressed: action, style: IconButton.styleFrom(backgroundColor: danger ? Colors.red : Colors.white12, foregroundColor: Colors.white, padding: const EdgeInsets.all(15)), icon: Icon(icon, size: 25),
  );

  Widget _remoteView() {
    final participants = _room!.remoteParticipants.values.toList();
    if (participants.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      CircleAvatar(radius: 58, backgroundImage: widget.otherUserImage?.isNotEmpty == true ? NetworkImage(widget.otherUserImage!) : null, child: widget.otherUserImage?.isNotEmpty == true ? null : const Icon(Icons.person, size: 56)),
      const SizedBox(height: 16), Text(widget.otherUserName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8), const Text('في انتظار الطرف الآخر...', style: TextStyle(color: Colors.white60)),
    ]));
    final participant = participants.first;
    for (final publication in participant.trackPublications.values) {
      final track = publication.track;
      if (track is RemoteVideoTrack) return VideoTrackRenderer(track);
    }
    return Center(child: Text(widget.otherUserName, style: const TextStyle(color: Colors.white, fontSize: 24)));
  }
}
