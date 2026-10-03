import 'package:flutter/material.dart';
import 'package:memochat/core/constants/app_colors.dart';

class TypingIndicator extends StatelessWidget {
  final String name;

  const TypingIndicator({
    super.key,
    this.name = '',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (name.isNotEmpty)
            Text(
              name,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          if (name.isNotEmpty) const SizedBox(width: 4),
          Text(
            'يكتب',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 6),
          _buildDot(0, isDark),
          _buildDot(1, isDark),
          _buildDot(2, isDark),
        ],
      ),
    );
  }

  Widget _buildDot(int index, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[500] : Colors.grey[400],
        shape: BoxShape.circle,
      ),
    );
  }
}
