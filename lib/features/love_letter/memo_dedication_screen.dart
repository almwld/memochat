import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The dedication remains deliberately hidden behind seven rapid taps.
class MemoDedicationScreen extends StatefulWidget {
  const MemoDedicationScreen({super.key});

  @override
  State<MemoDedicationScreen> createState() => _MemoDedicationScreenState();
}

class _MemoDedicationScreenState extends State<MemoDedicationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _stars;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _stars = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _stars.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090718),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _stars,
                builder: (_, __) => CustomPaint(
                  painter: _StarfieldPainter(_stars.value),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 16,
              child: IconButton(
                tooltip: 'إغلاق',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 54, 24, 30),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'MemoChat',
                        style: TextStyle(
                          color: Color(0xFFFFE7A0),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.2,
                        ),
                      ),
                      const SizedBox(height: 22),
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (_, __) => Transform.scale(
                          scale: 1 + (_pulse.value * .07),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF70B5)
                                      .withOpacity(.16 + _pulse.value * .22),
                                  blurRadius: 22 + _pulse.value * 28,
                                  spreadRadius: 2 + _pulse.value * 7,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.favorite_rounded,
                              size: 76,
                              color: Color(0xFFFF78B7),
                              shadows: [
                                Shadow(color: Color(0xFFFFB7D8), blurRadius: 24),
                                Shadow(color: Color(0xFFFF4FA3), blurRadius: 44),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'إهداء خاص إلى ميمو',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFFFE6A0),
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          shadows: [
                            Shadow(color: Color(0xFFFFD76A), blurRadius: 18),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 23,
                          vertical: 27,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF211632).withOpacity(.84),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: const Color(0xFFFFD98A).withOpacity(.42),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFB47BFF).withOpacity(.12),
                              blurRadius: 30,
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color: const Color(0xFFFFD76A).withOpacity(.08),
                              blurRadius: 22,
                            ),
                          ],
                        ),
                        child: const Text(
                          'إلى ميمو…\\n\\n'
                          'لم يكن MemoChat مجرد تطبيق، بل هدية صنعتها لك بكل محبة، '
                          'وأودعت في تفاصيلها شيئًا من قلبي واهتمامي.\\n\\n'
                          'أردت أن يكون رمزًا للمحبة التي أكنّها لك؛ '
                          'شيئًا صُنع خصيصًا لك، ويحمل بصمتي ومعنى لا تحتاج معه الكلمات إلى الإطالة.\\n\\n'
                          'هذا التطبيق هديتي إليك، وكل تفصيل فيه يحمل لك محبةً لا تختصرها الحروف.\\n\\n'
                          'بكل الودّ والمحبة،\\n'
                          'من فلانتشتاين',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFFFF8FF),
                            fontSize: 17,
                            height: 1.9,
                            letterSpacing: .1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'بعض الرسائل لا تُعلن عن نفسها؛ يكفي أن تعرف أين تبحث.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFC8B9D9),
                          fontSize: 12,
                          height: 1.6,
                        ),
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

class _StarfieldPainter extends CustomPainter {
  _StarfieldPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(731942);
    for (var i = 0; i < 115; i++) {
      final x = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final radius = .45 + random.nextDouble() * 1.65;
      final phase = random.nextDouble() * math.pi * 2;
      final twinkle = (.25 + .75 *
          ((math.sin(progress * math.pi * 2 * (1 + (i % 4)) + phase) + 1) / 2));
      final drift = (progress * (8 + i % 19)) % (size.height + 18);
      final y = (baseY + drift) % (size.height + 18) - 9;
      final color = i % 7 == 0
          ? const Color(0xFFFFE7A0)
          : i % 5 == 0
              ? const Color(0xFFD9B8FF)
              : const Color(0xFFFFFFFF);
      final paint = Paint()..color = color.withOpacity(twinkle * .85);
      canvas.drawCircle(Offset(x, y), radius * (.7 + twinkle * .45), paint);
      if (i % 9 == 0) {
        final glow = Paint()
          ..color = color.withOpacity(twinkle * .34)
          ..strokeWidth = .7
          ..strokeCap = StrokeCap.round;
        final length = 3 + twinkle * 5;
        canvas.drawLine(Offset(x - length, y), Offset(x + length, y), glow);
        canvas.drawLine(Offset(x, y - length), Offset(x, y + length), glow);
        canvas.drawCircle(
          Offset(x, y),
          length * 1.25,
          Paint()
            ..color = color.withOpacity(twinkle * .08)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// The ordinary licenses entry is visible; the dedication itself is not.
class MemoLicensesScreen extends StatelessWidget {
  const MemoLicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حول MemoChat')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                children: [
                  SecretSevenTap(
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Column(
                        children: [
                          Icon(Icons.forum_rounded, size: 42),
                          SizedBox(height: 8),
                          Text(
                            'MemoChat',
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'المراسلة، الذكريات، واللحظات التي تستحق أن تبقى.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.article_outlined),
              title: const Text('المصادر المفتوحة والتراخيص'),
              subtitle: const Text('عرض التراخيص ومعلومات الحزم المستخدمة'),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'MemoChat',
                applicationLegalese: 'MemoChat — تطبيق للمراسلة والذكريات.',
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'تلميح: توجد تفاصيل صغيرة في التطبيق لا تظهر إلا لمن يلاحظها.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
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
      behavior: HitTestBehavior.opaque,
      onPointerUp: (_) => _tap(),
      child: widget.child,
    );
  }
}
