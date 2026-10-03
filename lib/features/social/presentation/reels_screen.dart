import 'package:flutter/material.dart';

import '../data/social_service.dart';
import 'widgets/reel_item.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key, required this.service});
  final SocialService service;

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  final PageController _controller = PageController();
  int _active = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: widget.service.reels(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('تعذر تحميل الريلز. حاول مرة أخرى.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('لا توجد ريلز بعد. كن أول من ينشر ريلًا.'));
        }
        return PageView.builder(
          controller: _controller,
          scrollDirection: Axis.vertical,
          itemCount: docs.length,
          onPageChanged: (index) => setState(() => _active = index),
          itemBuilder: (context, index) {
            final doc = docs[index];
            return ReelItem(
              key: ValueKey(doc.id),
              service: widget.service,
              id: doc.id,
              data: doc.data(),
              active: index == _active,
            );
          },
        );
      },
    );
  }
}
