import 'dart:async';

import 'package:flutter/material.dart';

class AdvancedFeatureCarousel extends StatefulWidget {
  const AdvancedFeatureCarousel({super.key, this.title = 'مساحتك الخاصة', this.onClose});
  final String title;
  final VoidCallback? onClose;

  @override
  State<AdvancedFeatureCarousel> createState() => _AdvancedFeatureCarouselState();
}

class _AdvancedFeatureCarouselState extends State<AdvancedFeatureCarousel> {
  static const _items = <({IconData icon, String title, String body})>[
    (icon: Icons.lock_outline_rounded, title: 'خصوصية متقدمة', body: 'محادثات خاصة بتشفير طرفي ومؤشرات أمان واضحة.'),
    (icon: Icons.mic_none_rounded, title: 'رسائل صوتية', body: 'تسجيل وإرسال صوتيات عبر صندوق إرسال متين مع إعادة المحاولة.'),
    (icon: Icons.groups_rounded, title: 'المجموعات', body: 'محادثات جماعية وإدارة أعضاء ودعوات.'),
    (icon: Icons.forum_outlined, title: 'المجتمعات', body: 'مساحات مجتمعية وقنوات ومحتوى منظم.'),
    (icon: Icons.radio_rounded, title: 'الغرف الصوتية', body: 'غرف صوتية قابلة للانضمام من داخل التطبيق.'),
    (icon: Icons.auto_stories_outlined, title: 'الحالات اليومية', body: 'شارك حالة تختفي تلقائياً بعد 24 ساعة.'),
    (icon: Icons.dynamic_feed_rounded, title: 'المنشورات', body: 'انشر صوراً وفيديو ونصوصاً وتفاعل مع المجتمع.'),
    (icon: Icons.play_circle_outline_rounded, title: 'الريلز', body: 'فيديوهات قصيرة مع تفاعل وحفظ ومشاركة.'),
    (icon: Icons.attach_file_rounded, title: 'الوسائط والملفات', body: 'إرسال الصور والفيديو والملفات مع رفع متين.'),
    (icon: Icons.notifications_outlined, title: 'الإشعارات', body: 'إشعارات الرسائل والتفاعلات مع فتح مباشر.'),
    (icon: Icons.search_rounded, title: 'بحث شامل', body: 'ابحث داخل المحادثات والمحتوى بسهولة.'),
    (icon: Icons.person_outline_rounded, title: 'ملف شخصي', body: 'صورة وغطاء وإطار وخصوصية للظهور العام.'),
    (icon: Icons.reply_rounded, title: 'الردود', body: 'رد على رسالة محددة وانتقل إلى أصلها.'),
    (icon: Icons.star_border_rounded, title: 'المحفوظات', body: 'احفظ الرسائل والمحتوى المهم للوصول السريع.'),
    (icon: Icons.shield_outlined, title: 'الأمان', body: 'إعدادات أمان وحماية للهوية والبيانات.'),
    (icon: Icons.vpn_lock_outlined, title: 'VPN Tunnel', body: 'وضع استثنائي لشبكات معزولة عبر بوابة نفق فعلية.'),
  ];

  late final PageController _controller;
  Timer? _timer;
  int _index = 0;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: .88);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _closed || !_controller.hasClients) return;
      final next = (_index + 1) % _items.length;
      _controller.animateToPage(next, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_closed) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 8),
          child: Row(
            children: [
              Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
              IconButton(
                tooltip: 'إغلاق',
                visualDensity: VisualDensity.compact,
                onPressed: () { setState(() => _closed = true); widget.onClose?.call(); },
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 142,
          child: PageView.builder(
            controller: _controller,
            itemCount: _items.length,
            onPageChanged: (value) => setState(() => _index = value),
            itemBuilder: (context, index) {
              final item = _items[index];
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  var scale = 1.0;
                  if (_controller.position.haveDimensions) {
                    final delta = (_controller.page! - index).abs().clamp(0.0, 1.0);
                    scale = 1 - (delta * .05);
                  }
                  return Transform.scale(scale: scale, child: child);
                },
                child: Card(
                  margin: const EdgeInsetsDirectional.only(end: 10, bottom: 6),
                  elevation: 0,
                  color: scheme.primaryContainer.withOpacity(.34),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(radius: 25, backgroundColor: scheme.primary.withOpacity(.12), child: Icon(item.icon, color: scheme.primary)),
                        const SizedBox(width: 13),
                        Expanded(child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                            const SizedBox(height: 6),
                            Text(item.body, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(height: 1.35, fontSize: 12)),
                          ],
                        )),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_items.length, (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: i == _index ? 18 : 5,
          height: 5,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(color: i == _index ? scheme.primary : scheme.outlineVariant, borderRadius: BorderRadius.circular(8)),
        ))),
      ],
    );
  }
}
