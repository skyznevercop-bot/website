import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../models/achievement_models.dart';

class AchievementBadge extends StatelessWidget {
  final Achievement achievement;
  final bool compact;

  const AchievementBadge({
    super.key,
    required this.achievement,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;
    final iconSize = compact ? 24.0 : 32.0;
    final containerSize = compact ? 52.0 : 64.0;

    return Tooltip(
      message: unlocked
          ? '${achievement.name}\n${achievement.description}'
          : '${achievement.name} (Locked)\n${achievement.description}',
      preferBelow: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: containerSize,
            height: containerSize,
            decoration: BoxDecoration(
              color: unlocked
                  ? _categoryColor.withValues(alpha: 0.12)
                  : AppTheme.surface,
              borderRadius: BorderRadius.circular(compact ? 12 : 16),
              border: Border.all(
                color: unlocked
                    ? _categoryColor.withValues(alpha: 0.3)
                    : AppTheme.border,
              ),
              boxShadow: unlocked
                  ? [
                      BoxShadow(
                        color: _categoryColor.withValues(alpha: 0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              unlocked ? achievement.iconData : Icons.lock_rounded,
              size: iconSize,
              color: unlocked
                  ? _categoryColor
                  : AppTheme.textTertiary.withValues(alpha: 0.4),
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: 80,
              child: Text(
                achievement.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: unlocked
                      ? AppTheme.textPrimary
                      : AppTheme.textTertiary.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color get _categoryColor {
    switch (achievement.category) {
      case 'wins':
        return AppTheme.solanaPurple;
      case 'streaks':
        return AppTheme.error;
      case 'pnl':
        return AppTheme.solanaGreen;
      case 'trades':
        return AppTheme.info;
      case 'special':
        return AppTheme.warning;
      default:
        return AppTheme.solanaPurple;
    }
  }
}
