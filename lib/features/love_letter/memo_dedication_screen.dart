import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MemoDedicationScreen extends StatefulWidget {
  const MemoDedicationScreen({super.key});

  @override
  State<MemoDedicationScreen> createState() => _MemoDedicationScreenState();
}

class _MemoDedicationScreenState extends State<MemoDedicationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF120A24),
      body: SafeArea(
        child: Stack(
          children: [
            PositionedDirectional(
              top: 12,
              end: 16,
              child: IconButton(
                tooltip: 'إغلاق',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'MemoChat',
                        style: TextStyle(
                          color: Color(0xFFFFD76A),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 22),
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, __) => Transform.scale(
                          scale: 1 + (_pulse.value * .06),
                          child: const Icon(
                            Icons.favorite_rounded,
                            size: 88,
                            color: Color(0xFFFF6B9D),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'إهداء خاص إلى ميمو',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.07),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Text(
                          'في كل لحظة جميلة، تبقى بعض الذكريات أقرب إلى القلب.\n\nإلى ميمو، دائمًا.\n\nمن فلانتشتاين',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFF9F5FA),
                            fontSize: 19,
                            height: 1.9,
                          ),
                        ),
                      ),
                      const SizedBox(height: 34),
                      const Text(
                        'اضغط على زر الإغلاق للعودة',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SecretSevenTap extends StatefulWidget {
  const SecretSevenTap({required this.child, super.key});

  final Widget child;

  @override
  State<SecretSevenTap> createState() => _SecretSevenTapState();
}

class _SecretSevenTapState extends State<SecretSevenTap> {
  int _taps = 0;
  DateTime? _lastTap;
  bool _opened = false;

  Future<void> _tap() async {
    if (_opened) return;
    final now = DateTime.now();
    if (_lastTap != null &&
        now.difference(_lastTap!).inMilliseconds > 1500) {
      _taps = 0;
    }
    _lastTap = now;
    _taps++;
    HapticFeedback.selectionClick();
    if (_taps < 7) return;

    _opened = true;
    _taps = 0;
    HapticFeedback.heavyImpact();
    if (!mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (_, __, ___) => const MemoDedicationScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
    if (mounted) _opened = false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerUp: (_) => _tap(),
      child: widget.child,
    );
  }
}
