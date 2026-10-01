import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:memochat/features/chat/models/call_model.dart';
import 'package:memochat/features/chat/services/active_call_registry.dart';
import 'package:memochat/features/chat/services/call_service.dart';
import 'package:memochat/features/chat/services/livekit_service.dart';
import 'package:memochat/features/chat/services/toast_service.dart';

class CallScreen extends StatefulWidget {
  final String chatId;
  final String? callId;
  final String userName;
  final String userId;
  final bool isVideo;
  final String? userImage;
  final bool isOutgoing;

  const CallScreen({
    super.key,
    required this.chatId,
    this.callId,
    required this.userName,
    required this.userId,
    this.isVideo = true,
    this.userImage,
    this.isOutgoing = true,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  static const teal = Color(0xFF0A8F83);
  static const cyan = Color(0xFF00BCD4);
  static const red = Color(0xFFE53935);
  static const card = Color(0xFF1A1A1A);

  final live = LiveKitService();
  final calls = CallService();
  Room? room;
  StreamSubscription<CallModel?>? callSub;
  StreamSubscription<List<ConnectivityResult>>? netSub;
  Timer? timeout;
  Timer? timer;
  Timer? sync;
  String? callId;
  String? roomName;
  String? error;
  VideoTrack? localTrack;
  VideoTrack? remoteTrack;
  DateTime? connectedAt;
  int seconds = 0;
  bool joined = false;
  bool ending = false;
  bool connecting = true;
  bool muted = false;
  bool camera = true;
  bool speaker = false;
  double speakerVolume = 0.75;
  bool online = true;
  bool swapped = false;
  String connectionStatus = 'جاري الاتصال...';

  @override
  void initState() {
    super.initState();
    final id = widget.callId?.trim();
    if ((id == null || id.isEmpty) && widget.isOutgoing) {
      if (ActiveCallRegistry.instance.hasActiveCall) {
        debugPrint('⚡ CallScreen: clearing stale registry before new outgoing call');
        ActiveCallRegistry.instance.reset();
      }
    }
    if (id != null && id.isNotEmpty) {
      final registry = ActiveCallRegistry.instance;
      if (registry.hasActiveCall && !registry.isActive(id)) {
        debugPrint('CALL SCREEN BLOCKED second call id=$id active=${registry.activeCallId}');
        unawaited(calls.markBusy(id));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).pop();
          ToastService.showError('مشغول في مكالمة أخرى');
        });
        return;
      }
      registry.register(id);
    }
    unawaited(watchNet());
    unawaited(_loadSpeakerVolume());
    unawaited(connect());
  }

  Future<void> watchNet() async {
    try {
      final c = await Connectivity().checkConnectivity();
      if (mounted) setState(() => online = !c.contains(ConnectivityResult.none));
      netSub = Connectivity().onConnectivityChanged.listen((c) {
        if (mounted) setState(() => online = !c.contains(ConnectivityResult.none));
      });
    } catch (e) {
      debugPrint('CALL NET $e');
    }
  }

  Future<void> _retryConnection() async {
    if (ending) return;
    timeout?.cancel();
    timer?.cancel();
    sync?.cancel();
    await callSub?.cancel();
    await live.endCall();
    if (!mounted) return;
    setState(() {
      error = null;
      connecting = true;
      joined = false;
      localTrack = null;
      remoteTrack = null;
      connectionStatus = 'جاري إعادة الاتصال...';
    });
    await connect();
  }

  String _friendlyCallError(Object value) {
    final raw = value.toString().toLowerCase();
    if (raw.contains('mediaconnectexception') || raw.contains('peerconnection') || raw.contains('ice connectivity')) {
      return 'تعذر إنشاء اتصال المكالمة. تحقق من الإنترنت ثم أعد المحاولة.';
    }
    if (raw.contains('timeout') || raw.contains('timed out')) {
      return 'انتهت مهلة الاتصال. تحقق من جودة الإنترنت وحاول مرة أخرى.';
    }
    if (raw.contains('permission') || raw.contains('إذن')) {
      return 'يلزم السماح بالميكروفون${widget.isVideo ? ' والكاميرا' : ''} لإجراء المكالمة.';
    }
    if (raw.contains('network') || raw.contains('socket')) {
      return 'تعذر الاتصال بالشبكة. تحقق من الإنترنت وحاول مرة أخرى.';
    }
    return 'تعذر بدء المكالمة. حاول مرة أخرى.';
  }

  Future<void> connect() async {
    if (widget.isOutgoing) ToastService.showInfo('جاري الاتصال...');
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw StateError('يجب تسجيل الدخول');
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.isEmpty || connectivity.every((item) => item == ConnectivityResult.none)) {
        throw StateError('لا يوجد اتصال بالإنترنت');
      }

      late final CallModel c;
      final supplied = widget.callId?.trim();
      if (supplied != null && supplied.isNotEmpty) {
        final loaded = await calls.streamCall(supplied).first;
        if (loaded == null) throw StateError('المكالمة غير موجودة');
        if (widget.isOutgoing && loaded.callerId != user.uid) {
          throw StateError('المكالمة ليست صادرة من المستخدم');
        }
        if (!widget.isOutgoing && loaded.receiverId != user.uid) {
          throw StateError('المكالمة ليست موجهة لهذا المستخدم');
        }
        c = loaded;
      } else if (widget.isOutgoing) {
        final created = await calls.initiateCall(
          receiverId: widget.userId,
          receiverName: widget.userName,
          receiverPhotoUrl: widget.userImage,
          type: widget.isVideo ? CallType.video : CallType.audio,
          chatId: widget.chatId,
        );
        if (created == null) throw StateError('تعذر إنشاء المكالمة');
        c = created;
      } else {
        throw StateError('معرّف المكالمة مفقود');
      }

      callId = c.id;
      final rn = c.liveKitRoomName?.trim();
      roomName = rn != null && rn.isNotEmpty ? rn : 'call_${c.id}';
      ActiveCallRegistry.instance.register(c.id);

      callSub = calls.streamCall(c.id).listen(
        (u) {
          if (!mounted || u == null || ending) return;
          if (u.status == CallStatus.connected) {
            final d = u.connectedAt?.toDate();
            if (d != null) setConnectedAt(d);
            if (!joined) unawaited(join(u, user));
          } else if (_terminal(u.status)) {
            unawaited(finishRemote());
          }
        },
        onError: (Object streamError, StackTrace stackTrace) {
          if (!mounted || ending) return;
          final friendly = _friendlyCallError(streamError);
          debugPrint('CALL STREAM ERROR $streamError');
          setState(() {
            connecting = false;
            error = friendly;
          });
        },
      );

      if (widget.isOutgoing && c.status != CallStatus.connected) {
        timeout = Timer(const Duration(seconds: 30), () async {
          if (ending || joined) return;
          try {
            await calls.missCall(c.id);
          } catch (e) {
            debugPrint('CALL TIMEOUT $e');
          }
          if (mounted) await finishRemote();
        });
      }

      if (c.status == CallStatus.connected || !widget.isOutgoing) {
        await join(c, user);
      } else if (mounted) {
        setState(() => connecting = false);
      }
    } catch (e) {
      ActiveCallRegistry.instance.unregister(callId ?? widget.callId);
      final failedCallId = callId ?? widget.callId;
      if (failedCallId != null) {
        unawaited(
          FirebaseFirestore.instance
              .collection('calls')
              .doc(failedCallId)
              .update({
                'status': 'ended',
                'endedAt': FieldValue.serverTimestamp(),
                'endedReason': 'livekit_failed',
              })
              .catchError((_) {}),
        );
      }
      debugPrint('CALL CONNECT $e');
      if (mounted) {
        final friendly = _friendlyCallError(e);
        setState(() {
          connecting = false;
          error = friendly;
        });
        ToastService.showError(friendly);
      }
    }
  }

  bool _terminal(CallStatus s) => s == CallStatus.cancelled ||
      s == CallStatus.rejected ||
      s == CallStatus.missed ||
      s == CallStatus.ended ||
      s == CallStatus.busy;

  void setConnectedAt(DateTime d) {
    connectedAt = d;
    final e = DateTime.now().difference(d).inSeconds;
    seconds = e < 0 ? 0 : e;
    if (mounted) setState(() {});
    timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !ending && connectedAt != null) {
        final n = DateTime.now().difference(connectedAt!).inSeconds;
        setState(() => seconds = n < 0 ? 0 : n);
      }
    });
  }

  Future<void> join(CallModel c, User user) async {
    if (joined || ending || (c.status != CallStatus.connected && widget.isOutgoing)) return;
    try {
      // Request all required permissions in one batch to avoid Android
      // PermissionManager rejecting a second request while the first is active.
      final permissions = <Permission>[Permission.microphone];
      if (widget.isVideo) permissions.add(Permission.camera);
      final statuses = await permissions.request();

      if (widget.isVideo && !(statuses[Permission.camera]?.isGranted ?? false)) {
        throw StateError('يرجى منح إذن الكاميرا من إعدادات التطبيق');
      }
      if (!(statuses[Permission.microphone]?.isGranted ?? false)) {
        throw StateError('يرجى منح إذن الميكروفون من إعدادات التطبيق');
      }
      final registry = ActiveCallRegistry.instance;
      if (registry.hasActiveCall && !registry.isActive(c.id)) {
        throw StateError('مكالمة أخرى نشطة');
      }
      room = await live.startCall(
        roomName: roomName!,
        callerName: user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : widget.userName,
        isVideo: widget.isVideo,
      );
      // The accept transition is already persisted by CallService.
      // Do not make the LiveKit media UI depend on a second Firestore write:
      // if that write fails after WebRTC has started, the old code showed
      // "call failed" while the microphone/camera kept publishing.
      joined = true;
      timeout?.cancel();
      registry.register(c.id);
      setConnectedAt(c.connectedAt?.toDate() ?? DateTime.now());
      syncTracks();
      connectionStatus = 'متصل';
      room!.events.on<RoomReconnectingEvent>((_) {
        if (mounted) setState(() => connectionStatus = 'إعادة الاتصال...');
      });
      room!.events.on<RoomReconnectedEvent>((_) {
        if (mounted) {
          setState(() {
            connectionStatus = 'متصل';
            error = null;
          });
          syncTracks();
        }
      });
      room!.events.on<RoomDisconnectedEvent>((_) {
        if (mounted && !ending) {
          setState(() => connectionStatus = 'انقطع الاتصال');
        }
      });
      room!.events.on<ParticipantConnectedEvent>((_) => syncTracks());
      room!.events.on<TrackSubscribedEvent>((e) {
        syncTracks();
        bind(e.participant);
      });
      room!.events.on<TrackPublishedEvent>((e) {
        syncTracks();
        bind(e.participant);
      });
      room!.events.on<ParticipantDisconnectedEvent>((_) => syncTracks());
      sync = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (mounted && !ending) syncTracks();
      });
      await live.setSpeakerphone(speaker);
      if (mounted) setState(() { connecting = false; error = null; });
    } catch (e) {
      ActiveCallRegistry.instance.unregister(c.id);
      // If LiveKit started before a later UI/state step failed, tear down the
      // media session so audio cannot continue behind an error screen.
      try {
        await live.endCall();
      } catch (cleanupError) {
        debugPrint('CALL LIVEKIT CLEANUP $cleanupError');
      }
      final friendly = _friendlyCallError(e);
      debugPrint('CALL LIVEKIT $e');
      if (mounted) {
        setState(() {
          connecting = false;
          error = friendly;
        });
        ToastService.showError(friendly);
      }
    }
  }

  void syncTracks() {
    final r = room;
    if (r == null || !mounted) return;
    VideoTrack? l;
    VideoTrack? rem;
    final lp = r.localParticipant;
    if (lp != null) {
      for (final p in lp.trackPublications.values) {
        if (p.track is VideoTrack) { l = p.track as VideoTrack; break; }
      }
    }
    for (final part in r.remoteParticipants.values) {
      for (final p in part.trackPublications.values) {
        if (p.track is VideoTrack) { rem = p.track as VideoTrack; break; }
      }
      if (rem != null) break;
    }
    if (l != localTrack || rem != remoteTrack) setState(() { localTrack = l; remoteTrack = rem; });
  }

  void bind(Participant p) {
    for (final pub in p.trackPublications.values) {
      if (pub.track is VideoTrack) {
        if (p is LocalParticipant) {
          if (mounted) setState(() => localTrack = pub.track as VideoTrack);
        } else if (mounted) {
          setState(() => remoteTrack = pub.track as VideoTrack);
        }
      }
    }
  }

  Future<void> finishRemote() async {
    if (ending) return;
    ending = true;
    timeout?.cancel();
    timer?.cancel();
    sync?.cancel();
    await callSub?.cancel();
    ActiveCallRegistry.instance.unregister(callId ?? widget.callId);
    await live.endCall();
    if (mounted) Navigator.pop(context);
  }

  Future<void> end() async {
    if (ending) return;
    ending = true;
    timeout?.cancel();
    timer?.cancel();
    sync?.cancel();
    await callSub?.cancel();
    ActiveCallRegistry.instance.unregister(callId ?? widget.callId);
    try {
      if (callId != null) await calls.endCall(callId!, durationSeconds: joined ? seconds : 0);
    } catch (e) { debugPrint('CALL END $e'); }
    await live.endCall();
    if (mounted) Navigator.pop(context);
  }

  Future<void> mute() async {
    final enabled = await live.toggleMicrophone();
    if (mounted) setState(() => muted = !enabled);
  }

  Future<void> toggleCamera() async {
    final enabled = await live.toggleCamera();
    if (mounted) setState(() => camera = enabled);
    syncTracks();
  }

  Future<void> switchCamera() async => live.switchCamera();

  Future<void> _loadSpeakerVolume() async {
    final value = await live.getCallVolume();
    if (mounted) setState(() => speakerVolume = value);
  }

  Future<void> toggleSpeaker() async {
    final enabled = !speaker;
    await live.setSpeakerphone(enabled);
    if (mounted) setState(() => speaker = enabled);
  }

  Future<void> _showSpeakerVolume() async {
    await _loadSpeakerVolume();
    if (!mounted) return;
    var value = speakerVolume;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('مستوى صوت المكالمة', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('${(value * 100).round()}%', style: const TextStyle(color: Colors.white70)),
                Slider(
                  value: value,
                  min: 0.05,
                  max: 1.0,
                  divisions: 19,
                  activeColor: teal,
                  onChanged: (next) {
                    value = next;
                    setSheetState(() {});
                    unawaited(live.setCallVolume(next));
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Icon(Icons.volume_mute_rounded, color: Colors.white54),
                    Icon(Icons.volume_down_rounded, color: Colors.white70),
                    Icon(Icons.volume_up_rounded, color: Colors.white),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() => speakerVolume = value);
  }

  @override
  void dispose() {
    timeout?.cancel();
    timer?.cancel();
    sync?.cancel();
    callSub?.cancel();
    netSub?.cancel();
    ActiveCallRegistry.instance.unregister(callId ?? widget.callId);
    if (joined) unawaited(live.endCall());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remote = swapped ? localTrack : remoteTrack;
    final local = swapped ? remoteTrack : localTrack;
    final status = error ??
        (!online ? 'غير متصل' : !joined ? (connecting ? 'جاري الاتصال' : 'في انتظار الرد') : connectionStatus == 'متصل' ? fmt(seconds) : connectionStatus);
    return Scaffold(
      backgroundColor: const Color(0xFF071116),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF071116), Color(0xFF0A2025), Color(0xFF050B10)]),
        ),
        child: SafeArea(
          child: Stack(children: [
            if (widget.isVideo && remote != null)
              Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(28), child: VideoTrackRenderer(remote)))
            else
              Positioned.fill(child: waiting(centerMessageFor(status))),
            Positioned(top: 12, left: 14, right: 14, child: _callHeader(status)),
            if (widget.isVideo && local != null)
              PositionedDirectional(top: 82, end: 18, child: preview(local)),
            if (widget.isVideo && joined && remoteTrack == null)
              Positioned.fill(child: IgnorePointer(child: fallback())),
            if (error == null)
              Positioned(left: 14, right: 14, bottom: 14, child: controls())
            else
              Positioned.fill(child: _errorPanel()),
          ]),
        ),
      ),
    );
  }

  String centerMessageFor(String status) => error ?? (!online ? 'تحقق من اتصال الإنترنت' : connecting ? 'جاري الاتصال...' : !joined ? 'في انتظار قبول المكالمة...' : status);

  Widget _callHeader(String status) => Row(
    children: [
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: Colors.black.withOpacity(.34), borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white.withOpacity(.10))),
          child: Row(children: [
            CircleAvatar(radius: 20, backgroundImage: widget.userImage?.trim().isNotEmpty == true ? NetworkImage(widget.userImage!.trim()) : null, child: widget.userImage?.trim().isNotEmpty == true ? null : const Icon(Icons.person_rounded)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.userName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              Text(status, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 11)),
            ])),
            if (joined) Text(fmt(seconds), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
      const SizedBox(width: 8),
      _iconButton(icon: Icons.call_end_rounded, onTap: end, color: red),
    ],
  );

  Widget _errorPanel() => Positioned.fill(
    child: Center(child: Padding(padding: const EdgeInsets.all(24), child: Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.black.withOpacity(.58), borderRadius: BorderRadius.circular(28), border: Border.all(color: red.withOpacity(.25))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 48),
        const SizedBox(height: 14),
        const Text('تعذر الاتصال', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, height: 1.5)),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: connecting ? null : _retryConnection, icon: const Icon(Icons.refresh_rounded), label: Text(connecting ? 'جاري إعادة الاتصال...' : 'إعادة المحاولة'))),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: ending ? null : end, icon: const Icon(Icons.close_rounded), label: const Text('العودة'))),
      ]),
    ))),
  );

  Widget preview(VideoTrack t) => Container(
    width: 118,
    height: 176,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.black,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white38, width: 1.5),
    ),
    child: VideoTrackRenderer(t),
  );

  Widget fallback() => Center(
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(24), border: Border.all(color: teal.withOpacity(.3))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        avatar(96),
        const SizedBox(height: 12),
        Text(widget.userName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('الكاميرا غير مفعلة', style: TextStyle(color: Colors.white60)),
      ]),
    ),
  );

  Widget waiting(String s) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      avatar(140),
      const SizedBox(height: 22),
      Text(widget.userName, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
      if (s.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(s, style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600)),
      ],
      const SizedBox(height: 22),
      Text(fmt(seconds), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w300)),
    ]),
  );

  Widget avatar(double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: teal,
      image: widget.userImage?.trim().isNotEmpty == true
          ? DecorationImage(image: NetworkImage(widget.userImage!.trim()), fit: BoxFit.cover)
          : null,
    ),
    child: widget.userImage?.trim().isNotEmpty == true
        ? null
        : const Icon(Icons.person_rounded, color: Colors.white, size: 64),
  );

  Widget top(String s) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      _iconButton(icon: Icons.call_end, onTap: end, color: red),
      badge(joined ? fmt(seconds) : s),
      if (widget.isVideo && remoteTrack != null)
        _iconButton(icon: Icons.flip_camera_ios_rounded, onTap: () => setState(() => swapped = !swapped), color: Colors.white)
      else
        const SizedBox(width: 44),
    ],
  );

  Widget badge(String s) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
    decoration: BoxDecoration(color: teal.withOpacity(.15), borderRadius: BorderRadius.circular(24), border: Border.all(color: teal.withOpacity(.3))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: joined ? Colors.greenAccent : cyan)),
      const SizedBox(width: 7),
      Text(s, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget controls() => ClipRRect(
    borderRadius: BorderRadius.circular(30),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
      decoration: BoxDecoration(color: card.withOpacity(.9), border: Border.all(color: Colors.white.withOpacity(.1)), borderRadius: BorderRadius.circular(30)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        GestureDetector(
          onTap: toggleSpeaker,
          onLongPress: _showSpeakerVolume,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: speaker ? teal.withOpacity(.22) : card.withOpacity(.8),
                  border: Border.all(color: speaker ? teal : Colors.white24, width: 1.4),
                ),
                child: Icon(speaker ? Icons.volume_up_rounded : Icons.volume_down_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(height: 5),
              Text('سماعة ${(speakerVolume * 100).round()}%', style: const TextStyle(color: Colors.white70, fontSize: 10)),
            ],
          ),
        ),
        button(muted ? Icons.mic_off : Icons.mic, 'كتم', cyan, mute, active: muted),
        if (widget.isVideo) button(camera ? Icons.videocam : Icons.videocam_off, 'كاميرا', cyan, toggleCamera, active: !camera),
        if (widget.isVideo) button(Icons.cameraswitch_rounded, 'تبديل', teal, switchCamera),
        button(Icons.call_end, 'إنهاء', red, end, main: true),
      ]),
    ),
  );

  Widget button(IconData icon, String label, Color color, VoidCallback action, {bool active = false, bool main = false}) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      GestureDetector(
        onTap: action,
        child: Container(
          width: main ? 68 : 58,
          height: main ? 68 : 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: main ? color : (active ? color.withOpacity(.22) : color.withOpacity(.12)),
            border: Border.all(color: main ? color : color.withOpacity(.7), width: main ? 0 : 1.4),
          ),
          child: Icon(icon, color: Colors.white, size: main ? 32 : 26),
        ),
      ),
      const SizedBox(height: 5),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
    ],
  );

  Widget _iconButton({required IconData icon, required VoidCallback onTap, required Color color}) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(.16))),
      child: Icon(icon, color: color, size: 23),
    ),
  );

  String fmt(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    return h > 0 ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}' : '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}
