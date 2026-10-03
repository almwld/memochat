import 'package:flutter/material.dart';
import '../../data/social_service.dart';

class ReelActions extends StatelessWidget {
  const ReelActions({
    super.key,
    required this.service,
    required this.id,
    required this.data,
    required this.liked,
    required this.saved,
    required this.following,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onSave,
    required this.onFollow,
    required this.onMore,
  });

  final SocialService service;
  final String id;
  final Map<String, dynamic> data;
  final bool liked;
  final bool saved;
  final bool following;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onSave;
  final VoidCallback? onFollow;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Action(icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, label: _n(data['likesCount']), onTap: onLike, active: liked),
        _Action(icon: Icons.mode_comment_rounded, label: _n(data['commentsCount']), onTap: onComment),
        _Action(icon: Icons.share_rounded, label: _n(data['sharesCount']), onTap: onShare),
        _Action(icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, label: 'حفظ', onTap: onSave),
        if (onFollow != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: FilledButton(
              onPressed: onFollow,
              style: FilledButton.styleFrom(
                minimumSize: const Size(54, 34),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(following ? 'متابَع' : 'متابعة', style: const TextStyle(fontSize: 11)),
            ),
          ),
        _Action(icon: Icons.more_horiz_rounded, label: 'المزيد', onTap: onMore),
      ],
    );
  }

  String _n(dynamic value) => value is num ? value.toInt().toString() : (value?.toString() ?? '0');
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap, this.active = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: IconButton(
              onPressed: onTap,
              color: active ? Colors.redAccent : Colors.white,
              icon: Icon(icon),
              tooltip: label,
            ),
          ),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
