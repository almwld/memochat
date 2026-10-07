import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/premium_ui.dart';

class GameResultsScreen extends StatelessWidget {
  const GameResultsScreen({
    super.key, required this.title, required this.score, required this.best,
    required this.onReplay, this.onClose, this.onChallenge,
  });

  final String title;
  final int score;
  final int best;
  final VoidCallback onReplay;
  final VoidCallback? onClose;
  final VoidCallback? onChallenge;

  Future<void> _copyResult(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: 'نتيجتي في $title: $score نقطة'));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ النتيجة')));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ScrollAwareScaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20,24,20,48),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
              children: [
                Icon(Icons.emoji_events_rounded, size: 64, color: scheme.primary),
                const SizedBox(height: 12),
                const Text('انتهت اللعبة', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text('نتيجتك: $score', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('أفضل نتيجة: $best', style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
              ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: onReplay, icon: const Icon(Icons.replay_rounded), label: const Text('إعادة اللعب')),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: () => _copyResult(context), icon: const Icon(Icons.copy_rounded), label: const Text('نسخ النتيجة')),
          if (onChallenge != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextButton.icon(onPressed: onChallenge, icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('تحدي صديق')),
            ),
          if (onClose != null) TextButton(onPressed: onClose, child: const Text('إغلاق')),
        ],
      ),
    );
  }
}
