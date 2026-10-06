import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/call_model.dart';
import '../services/active_call_registry.dart';
import '../services/call_service.dart';
import '../services/call_sound_coordinator.dart';
import '../services/toast_service.dart';
import 'call_screen.dart';

/// The incoming-call screen is deliberately a UI-only acceptance surface.
/// It never requests microphone/camera permission and never joins LiveKit.
/// CallScreen owns the single media-permission + LiveKit startup transaction.
class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final String callerName;
  final String callerId;
  final String? callerImage;
  final bool isVideo;
  final String chatId;
  final ValueChanged<bool> onCallAnswered;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.callerName,
    required this.callerId,
    this.callerImage,
    required this.isVideo,
    required this.chatId,
    required this.onCallAnswered,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with WidgetsBindingObserver {
  static const teal = Color(0xFF0A8F83);
  static const cyan = Color(0xFF00BCD4);
  static const red = Color(0xFFE53935);
  static const bg = Color(0xFF071311);

  final _calls = CallService();
  StreamSubscription<CallModel?>? _callSub;

  bool _busy = false;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ActiveCallRegistry.instance.register(widget.callId);
    unawaited(WakelockPlus.enable());
    _callSub = _calls.streamCall(widget.callId).listen(
      _onCallChanged,
      onError: (Object error, StackTrace stack) {
        debugPrint('INCOMING CALL STREAM ERROR: $error');
      },
    );
  }

  void _onCallChanged(CallModel? call) {
    if (!mounted || _closed || call == null) return;

    if (call.status == CallStatus.ended ||
        call.status == CallStatus.cancelled ||
        call.status == CallStatus.rejected ||
        call.status == CallStatus.missed ||
        call.status == CallStatus.busy) {
      unawaited(_closeWithoutAction());
      return;
    }

    // Another UI owner already answered the call.
    if (call.isAnswered && call.status != CallStatus.connected) {
      unawaited(_closeWithoutAction());
    }
  }

  Future<void> _accept() async {
    if (_busy || _closed) return;
    setState(() => _busy = true);

    try {
      await HapticFeedback.mediumImpact();
      await _calls.acceptCall(widget.callId);

      if (!mounted) return;
      _stopAlerting();
      widget.onCallAnswered(true);

      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (_, __, ___) => CallScreen(
            callId: widget.callId,
            chatId: widget.chatId,
            userId: widget.callerId,
            userName: widget.callerName,
            userImage: widget.callerImage,
            isVideo: widget.isVideo,
            isOutgoing: false,
          ),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 220),
        ),
      );
    } catch (e, st) {
      debugPrint('INCOMING ACCEPT ERROR: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      setState(() => _busy = false);
      ToastService.showError('تعذر قبول المكالمة. حاول مرة أخرى.');
    }
  }

  Future<void> _reject() async {
    if (_busy || _closed) return;
    setState(() => _busy = true);

    try {
      await _calls.rejectCall(widget.callId);
    } catch (e) {
      debugPrint('INCOMING REJECT ERROR: $e');
    } finally {
      if (mounted) await _closeWithoutAction();
    }
  }

  Future<void> _closeWithoutAction() async {
    if (_closed) return;
    _closed = true;
    _stopAlerting();
    await _callSub?.cancel();
    _callSub = null;
    ActiveCallRegistry.instance.unregister(widget.callId);
    if (mounted) Navigator.of(context).pop();
  }

  void _stopAlerting() {
    unawaited(CallSoundCoordinator.instance.stopForCall(widget.callId));
  }

  @override
  void dispose() {
    _callSub?.cancel();
    _stopAlerting();
    ActiveCallRegistry.instance.unregister(widget.callId);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) unawaited(_reject());
      },
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 1.25,
                      colors: [
                        teal.withOpacity(.28),
                        bg,
                      ],
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  const SizedBox(height: 18),
                  _statusPill(),
                  const Spacer(),
                  _avatar(),
                  const SizedBox(height: 26),
                  Text(
                    widget.callerName.trim().isEmpty
                        ? 'مستخدم'
                        : widget.callerName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 29,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.isVideo
                        ? 'مكالمة فيديو واردة'
                        : 'مكالمة صوتية واردة',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 18),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _action(
                          icon: Icons.call_end_rounded,
                          label: 'رفض',
                          color: red,
                          onTap: _busy ? null : _reject,
                        ),
                        _action(
                          icon: widget.isVideo
                              ? Icons.videocam_rounded
                              : Icons.call_rounded,
                          label: 'قبول',
                          color: teal,
                          onTap: _busy ? null : _accept,
                          primary: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(.10)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.phone_in_talk_rounded, color: cyan, size: 17),
          SizedBox(width: 8),
          Text(
            'مكالمة واردة',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar() {
    final image = widget.callerImage?.trim() ?? '';
    return Container(
      width: 156,
      height: 156,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: teal.withOpacity(.16),
        border: Border.all(color: Colors.white.withOpacity(.24), width: 3),
        boxShadow: [
          BoxShadow(
            color: teal.withOpacity(.28),
            blurRadius: 40,
            spreadRadius: 4,
          ),
        ],
        image: image.isEmpty
            ? null
            : DecorationImage(
                image: NetworkImage(image),
                fit: BoxFit.cover,
                onError: (_, __) {},
              ),
      ),
      child: image.isEmpty
          ? const Icon(
              Icons.person_rounded,
              color: Colors.white70,
              size: 72,
            )
          : null,
    );
  }

  Widget _action({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
    bool primary = false,
  }) {
    final size = primary ? 78.0 : 68.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: primary ? color : color.withOpacity(.12),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: primary
                    ? null
                    : Border.all(color: color.withOpacity(.8), width: 1.5),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: primary ? 34 : 29,
              ),
            ),
          ),
        ),
        const SizedBox(height: 9),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
