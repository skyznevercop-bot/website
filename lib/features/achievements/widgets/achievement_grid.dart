import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../models/achievement_models.dart';
import 'achievement_badge.dart';

class AchievementGrid extends StatelessWidget {
  final List<Achievement> achievements;
  final int unlockedCount;
  final int totalCount;
  final bool compact;

  const AchievementGrid({
    super.key,
    required this.achievements,
    required this.unlockedCount,
    required this.totalCount,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = Responsive.value<int>(
      context,
      mobile: 4,
      tablet: 5,
      desktop: 6,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '$unlockedCount/$totalCount',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.solanaPurple,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Achievements Unlocked',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: compact ? 8 : 12,
            crossAxisSpacing: compact ? 8 : 12,
            childAspectRatio: compact ? 1 : 0.75,
          ),
          itemCount: achievements.length,
          itemBuilder: (context, index) {
            return AchievementBadge(
              achievement: achievements[index],
              compact: compact,
            );
          },
        ),
      ],
    );
  }
}
