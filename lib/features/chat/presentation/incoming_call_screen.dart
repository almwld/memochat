// ============================================================
// 📞 incoming_call_screen.dart — Full Support
// - Glassmorphism expansion
// - Scale ×2 on swipe
// - Background isolate (app closed)
// - Lock screen (full-screen intent)
// - Wake lock
// ============================================================

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:flutter/material.dart';
import '';
import 'package:memochat/core/models/call_model.dart';
import 'package:memochat/features/chat/services/call_service.dart';
import 'package:memochat/features/chat/services/active_call_registry.dart';
import 'package:memochat/features/chat/services/call_sound_coordinator.dart';
import 'package:memochat/core/services/toast_service.dart';
import 'call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final String callerName;
  final String callerId;
  final String? callerImage;
  final bool isVideo;
  final String chatId;
  final Function(bool) onCallAnswered;

  /// ⚠️ إذا فُتح من background isolate — قد لا يكون هناك Navigator
  final bool fromBackground;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.callerName,
    required this.callerId,
    this.callerImage,
    required this.isVideo,
    required this.chatId,
    required this.onCallAnswered,
    this.fromBackground = false,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const Color _bgDark = Color(0xFF0A0F1C);
  static const Color _bgMid = Color(0xFF10352F);
  static const Color _teal = Color(0xFF0A8F83);
  static const Color _cyan = Color(0xFF00BCD4);
  static const Color _red = Color(0xFFE53935);
  static const Color _green = Color(0xFF4CAF50);

  late final AnimationController _pulseController;
  late final AnimationController _ringController;
  late final AnimationController _haloController;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _haloAnimation;

  final CallService _callService = CallService();
  Timer? _streamRetryTimer;
  int _retryCount = 0;
  CallStatus? _lastObservedStatus;

  bool _isProcessing = false;
  bool _isMuted = false;
  bool _isAlerting = true;
  double _swipeProgress = 0.0;
  double _swipeDirection = 0.0;
  bool _swipeLocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enableWakeLock();
    _enableFullScreenUI();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutCubic),
    );

    _ringController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _haloController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    _haloAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _haloController, curve: Curves.easeOut),
    );

    unawaited(WakelockPlus.enable());
  }

  Future<void> _enableWakeLock() async {
    try {
      await WakelockPlus.enable();
    } catch (e) {
      debugPrint('Wakelock error: $e');
    }
  }

  void _enableFullScreenUI() {
    // Keep the Android status bar visible so message/call notifications remain accessible.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  void _restoreSystemUI() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _scheduleStreamRetry(Object error) {
    if (!mounted || _isProcessing || !_isAlerting) return;
    if (_streamRetryTimer?.isActive == true) return;
    debugPrint('Incoming call stream error: $error');
    _streamRetryTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || _isProcessing || !_isAlerting) return;
      setState(() => _retryCount++);
    });
  }

  void _handleStreamCall(CallModel? call) {
    if (!mounted || call == null || _isProcessing) return;
    if (_lastObservedStatus == call.status) return;
    _lastObservedStatus = call.status;

    final terminal = call.status == CallStatus.connected ||
        call.status == CallStatus.cancelled ||
        call.status == CallStatus.rejected ||
        call.status == CallStatus.missed ||
        call.status == CallStatus.busy ||
        call.status == CallStatus.ended;
    if (!terminal) return;

    _stopAlerting();
    if (call.status == CallStatus.busy) {
      ToastService.showInfo('المستخدم مشغول بمكالمة أخرى');
    }
    if (call.status != CallStatus.connected && mounted) {
      Navigator.of(context).pop();
    }
  }

  void _stopAlerting() {
    _isAlerting = false;
    _streamRetryTimer?.cancel();
    _streamRetryTimer = null;
    unawaited(CallSoundCoordinator.instance.stopForCall(widget.callId));
  }

  Future<void> _rejectCall() async {
    if (_isProcessing) return;
    if (mounted) setState(() => _isProcessing = true);
    try {
      await _callService.rejectCall(widget.callId);
      if (!mounted) return;
      _stopAlerting();
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('rejectCall failed: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _swipeProgress = 0;
          _swipeDirection = 0;
          _swipeLocked = false;
        });
        ToastService.showError('تعذر رفض المكالمة: $e');
      }
    }
  }

  void _handleAnswerSwipeUpdate(DragUpdateDetails details) {
    if (_isProcessing || _swipeLocked) return;
    final delta = details.delta.dx;
    if (delta.abs() < 0.1) return;

    final direction = delta.sign;
    final progressDelta = delta.abs() / 70.0;
    if (mounted) {
      setState(() {
        _swipeDirection = direction;
        _swipeProgress = (_swipeProgress + progressDelta).clamp(0.0, 1.0);
      });
    }

    if (_swipeProgress >= 0.7 && mounted) {
      _swipeLocked = true;
      unawaited(_handleAnswerTap(fromSwipe: true));
    }
  }

  void _handleAnswerSwipeEnd(DragEndDetails details) {
    if (_isProcessing || _swipeLocked) return;
    if (!mounted) return;
    setState(() {
      _swipeProgress = 0;
      _swipeDirection = 0;
    });
  }

  Future<void> _acceptCall({bool prelocked = false}) async {
    if (_isProcessing && !prelocked) return;
    if (!prelocked) setState(() => _isProcessing = true);
    try {
      await _callService.acceptCall(widget.callId);
      widget.onCallAnswered(true);
    } catch (e) {
      debugPrint('acceptCall failed: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _swipeProgress = 0;
          _swipeDirection = 0;
          _swipeLocked = false;
        });
        ToastService.showError('تعذر قبول المكالمة: $e');
      }
    }
  }

  Future<void> _handleAnswerTap({bool fromSwipe = false}) async {
    if (_isProcessing || (_swipeLocked && !fromSwipe)) return;
    setState(() => _isProcessing = true);

    await _pulseController.forward();
    await _pulseController.reverse();

    if (!mounted) return;
    _ringController.forward(from: 0);

    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    _navigateToCall();
  }

  Future<void> _navigateToCall() async {
    if (!mounted) return;
    try {
      // Mark the call answered before replacing the incoming UI. This prevents
      // a race where CallScreen starts joining LiveKit while the call is still
      // in `calling`, and guarantees the caller sees the answer transition.
      await _callService.acceptCall(widget.callId);
    } catch (e) {
      debugPrint('acceptCall before navigation failed: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _swipeProgress = 0;
          _swipeDirection = 0;
          _swipeLocked = false;
        });
        ToastService.showError('تعذر قبول المكالمة: $e');
      }
      return;
    }
    if (!mounted) return;
    _stopAlerting();
    widget.onCallAnswered(true);

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => CallScreen(
          callId: widget.callId,
          chatId: widget.chatId,
          userId: widget.callerId,
          userName: widget.callerName,
          userImage: widget.callerImage,
          isVideo: widget.isVideo,
          isOutgoing: false,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );

  }

  Future<void> _toggleMute() async {
    final muted = !_isMuted;
    setState(() => _isMuted = muted);
    await CallSoundCoordinator.instance.setIncomingMuted(muted);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _enableFullScreenUI();
      unawaited(WakelockPlus.enable());
    }
  }

  @override
  void dispose() {
    _streamRetryTimer?.cancel();
    _streamRetryTimer = null;
    ActiveCallRegistry.instance.unregister(widget.callId);
    _stopAlerting();
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _ringController.dispose();
    _haloController.dispose();
    _restoreSystemUI();
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CallModel?>(
      key: ValueKey(_retryCount),
      stream: _callService.streamCall(widget.callId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          _scheduleStreamRetry(snapshot.error!);
        }
        if (snapshot.hasData) {
          final call = snapshot.data;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _handleStreamCall(call);
          });
        }
        return _buildContent(context);
      },
    );
  }

  Widget _buildContent(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.height < 700;
    final imageUrl = widget.callerImage?.trim().isNotEmpty == true
        ? widget.callerImage!.trim()
        : '';

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) unawaited(_rejectCall());
      },
      child: Scaffold(
        backgroundColor: _bgDark,
        body: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [_bgDark, _bgMid, _bgDark],
                      stops: [0, .5, 1],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: RepaintBoundary(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: .85,
                      colors: [_teal.withOpacity(.20), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -80,
              left: -80,
              child: _blurCircle(240, _teal.withOpacity(.22)),
            ),
            Positioned(
              bottom: -100,
              right: -80,
              child: _blurCircle(280, _cyan.withOpacity(.12)),
            ),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  _statusLabel(),
                  SizedBox(height: isCompact ? 24 : 40),
                  _avatarSection(imageUrl, isCompact),
                  SizedBox(height: isCompact ? 18 : 26),
                  _callerInfo(isCompact),
                  const Spacer(),
                  if (_isProcessing)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 14),
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      isCompact ? 20 : 28,
                      12,
                      isCompact ? 20 : 28,
                      isCompact ? 24 : 40,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildCallButton(
                          icon: _isMuted
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                          label: _isMuted ? 'تشغيل الرنين' : 'كتم الرنين',
                          color: _cyan,
                          size: isCompact ? 58 : 65,
                          onTap: _isProcessing
                              ? null
                              : () => unawaited(_toggleMute()),
                        ),
                        _buildCallButton(
                          icon: Icons.call_end_rounded,
                          label: 'رفض',
                          color: _red,
                          size: isCompact ? 68 : 78,
                          isMain: true,
                          onTap: _isProcessing ? null : _rejectCall,
                        ),
                        _buildCallButton(
                          icon: widget.isVideo
                              ? Icons.videocam_rounded
                              : Icons.call_rounded,
                          label: 'قبول',
                          color: _green,
                          size: isCompact ? 68 : 78,
                          isMain: true,
                          pulse: true,
                          swipeDistance: _swipeProgress,
                          onTap: _isProcessing ? null : _handleAnswerTap,
                          onPanUpdate: _handleAnswerSwipeUpdate,
                          onPanEnd: _handleAnswerSwipeEnd,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: SafeArea(
                child: _iconButton(
                  icon: Icons.close_rounded,
                  onTap: _isProcessing ? null : _rejectCall,
                ),
              ),
            ),
            if (_ringController.value > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: _ExpandingRing(
                      controller: _ringController,
                      startSize: 78.0,
                      maxScale: 8.0,
                      color: _green,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _blurCircle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(color: color, blurRadius: 80, spreadRadius: 20),
          ],
        ),
      );

  Widget _statusLabel() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(.08)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PulseDot(),
            SizedBox(width: 8),
            Text(
              'مكالمة واردة',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: .3,
              ),
            ),
          ],
        ),
      );

  Widget _avatarSection(String imageUrl, bool isCompact) {
    final avatarSize = isCompact ? 140.0 : 170.0;
    return SizedBox(
      width: avatarSize * 1.5,
      height: avatarSize * 1.5,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _haloAnimation,
            builder: (_, __) {
              final v = _haloAnimation.value;
              return Container(
                width: avatarSize * (1 + v * .5),
                height: avatarSize * (1 + v * .5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _teal.withOpacity((1 - v) * .5),
                    width: 2,
                  ),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _haloAnimation,
            builder: (_, __) {
              final v = (_haloAnimation.value + .5) % 1;
              return Container(
                width: avatarSize * (1 + v * .5),
                height: avatarSize * (1 + v * .5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _teal.withOpacity((1 - v) * .5),
                    width: 2,
                  ),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (_, child) => Transform.scale(
              scale: _pulseAnimation.value,
              child: child,
            ),
            child: Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(.35),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _teal.withOpacity(.6),
                    blurRadius: 50,
                    spreadRadius: 8,
                  ),
                ],
                image: imageUrl.isEmpty ? null : DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                  onError: (_, __) {},
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _callerInfo(bool isCompact) => Column(
        children: [
          Text(
            widget.callerName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: isCompact ? 26 : 30,
              fontWeight: FontWeight.w700,
              letterSpacing: .4,
              height: 1.15,
            ),
          ),
          SizedBox(height: isCompact ? 12 : 16),
          _glassBadge(
            icon: widget.isVideo
                ? Icons.videocam_rounded
                : Icons.call_rounded,
            text: widget.isVideo ? 'مكالمة فيديو واردة' : 'مكالمة صوتية واردة',
          ),
        ],
      );

  Widget _glassBadge({required IconData icon, required String text}) =>
      ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.08),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(.18)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _iconButton({required IconData icon, VoidCallback? onTap}) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(40),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: Colors.white.withOpacity(.85),
              size: 28,
            ),
          ),
        ),
      );

  Widget _buildCallButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
    double size = 65,
    bool isMain = false,
    bool pulse = false,
    double swipeDistance = 0,
    GestureDragUpdateCallback? onPanUpdate,
    GestureDragEndCallback? onPanEnd,
  }) {
    final swipeProgress = swipeDistance.clamp(0.0, 1.0);
    final effectiveSize = size;

    Widget button = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      transform: Matrix4.identity()
        ..translate(_swipeDirection * swipeProgress * 18.0, 0.0),
      width: effectiveSize,
      height: effectiveSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isMain
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withOpacity(.95), color],
              )
            : null,
        color: isMain ? null : color.withOpacity(.12),
        border: Border.all(
          color: isMain ? Colors.white.withOpacity(.15) : color,
          width: isMain ? 0 : 2,
        ),
        boxShadow: isMain || pulse
            ? [
                BoxShadow(
                  color: color.withOpacity(.45 + swipeProgress * .3),
                  blurRadius: 20 + swipeProgress * 12,
                  spreadRadius: 4 + swipeProgress * 4,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Icon(
        icon,
        color: isMain ? Colors.white : color,
        size: isMain ? 34 : 26,
      ),
    );

    if (pulse && isMain) {
      button = AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (_, child) => Transform.scale(
          scale: _pulseAnimation.value,
          child: child,
        ),
        child: button,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          onHorizontalDragUpdate: onPanUpdate,
          onHorizontalDragEnd: onPanEnd,
          child: button,
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: .2,
          ),
        ),
      ],
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF4CAF50).withOpacity(.5 + _c.value * .5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4CAF50).withOpacity(.5),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      );
}

class _ExpandingRing extends StatelessWidget {
  final Animation<double> controller;
  final double startSize;
  final double maxScale;
  final Color color;

  const _ExpandingRing({
    required this.controller,
    required this.startSize,
    required this.maxScale,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final scale = 1.0 + (maxScale - 1.0) * controller.value;
        final opacity = (1.0 - controller.value).clamp(0.0, 1.0);
        return IgnorePointer(
          child: Container(
            width: startSize * scale,
            height: startSize * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(opacity * 0.6),
            ),
          ),
        );
      },
    );
  }
}
