import 'package:flutter/material.dart';
import 'package:memochat/core/constants/app_colors.dart';

class MessageReactions extends StatefulWidget {
  final Function(String) onReactionSelected;
  final List<String> currentReactions;

  const MessageReactions({
    super.key,
    required this.onReactionSelected,
    this.currentReactions = const [],
  });

  @override
  State<MessageReactions> createState() => _MessageReactionsState();
}

class _MessageReactionsState extends State<MessageReactions> {
  final List<Map<String, dynamic>> _reactions = [
    {'emoji': '👍', 'label': 'إعجاب', 'color': Colors.blue},
    {'emoji': '❤️', 'label': 'حب', 'color': Colors.red},
    {'emoji': '😂', 'label': 'ضحك', 'color': Colors.orange},
    {'emoji': '😮', 'label': 'مفاجأة', 'color': Colors.purple},
    {'emoji': '😢', 'label': 'حزن', 'color': Colors.blueGrey},
    {'emoji': '🙏', 'label': 'شكر', 'color': Colors.teal},
    {'emoji': '🔥', 'label': 'نار', 'color': Colors.deepOrange},
    {'emoji': '👏', 'label': 'تصفيق', 'color': Colors.amber},
  ];

  String? _selectedReaction;

  @override
  void initState() {
    super.initState();
    if (widget.currentReactions.isNotEmpty) {
      _selectedReaction = widget.currentReactions.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'اختر رد فعل',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 1.2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _reactions.length,
            itemBuilder: (context, index) {
              final reaction = _reactions[index];
              final emoji = reaction['emoji'] as String;
              final label = reaction['label'] as String;
              final color = reaction['color'] as Color;
              final isSelected = _selectedReaction == emoji;

              return GestureDetector(
                onTap: () {
                  setState(() => _selectedReaction = emoji);
                  widget.onReactionSelected(emoji);
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? color : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        emoji,
                        style: TextStyle(
                          fontSize: isSelected ? 36 : 30,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected ? color : (isDark ? Colors.grey[400] : Colors.grey[600]),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          if (_selectedReaction != null)
            TextButton(
              onPressed: () {
                setState(() => _selectedReaction = null);
                widget.onReactionSelected('');
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('إزالة التفاعل'),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
