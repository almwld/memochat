import 'package:flutter/material.dart';
import '../../../../core/widgets/user_name.dart';

class ReelCaption extends StatelessWidget {
  const ReelCaption({super.key, required this.author, required this.caption, required this.musicTitle});
  final String author;
  final String caption;
  final String musicTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [const Text('@', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)), Flexible(child: UserName(userId: author, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)))]),
        if (caption.isNotEmpty) ...[
          const SizedBox(height: 7),
          Text(caption, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, height: 1.35, fontSize: 14)),
        ],
        if (musicTitle.isNotEmpty) ...[
          const SizedBox(height: 7),
          Row(children: [const Icon(Icons.music_note_rounded, color: Colors.white, size: 17), const SizedBox(width: 5), Expanded(child: Text(musicTitle, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)))])
        ],
      ],
    );
  }
}
