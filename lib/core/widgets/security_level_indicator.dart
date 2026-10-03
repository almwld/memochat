import 'package:flutter/material.dart';

import '../security/security_level.dart';
import '../security/security_settings_service.dart';

class SecurityLevelIndicator extends StatelessWidget {
  const SecurityLevelIndicator({
    this.compact = false,
    super.key,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SecuritySettingsService.instance,
      builder: (context, _) {
        final level = SecuritySettingsService.instance.level;
        final icon = switch (level) {
          SecurityLevel.standard => Icons.lock_outline_rounded,
          SecurityLevel.enhanced => Icons.lock_rounded,
          SecurityLevel.maximum => Icons.shield_rounded,
          SecurityLevel.custom => Icons.tune_rounded,
        };

        final label = switch (level) {
          SecurityLevel.standard => 'Standard',
          SecurityLevel.enhanced => 'Enhanced',
          SecurityLevel.maximum => 'Maximum',
          SecurityLevel.custom => 'Custom',
        };

        return Tooltip(
          message: 'مستوى الأمان: $label',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: compact ? 18 : 20),
              if (!compact) ...[
                const SizedBox(width: 5),
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
