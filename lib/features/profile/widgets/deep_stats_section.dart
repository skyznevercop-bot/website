import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../models/profile_models.dart';

class DeepStatsSection extends StatelessWidget {
  final DeepStats stats;

  const DeepStatsSection({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final items = [
      _DeepStatItem(
        icon: Icons.trending_up_rounded,
        label: 'Avg PnL / Match',
        value:
            '${stats.avgPnlPerMatch >= 0 ? '+' : ''}\$${stats.avgPnlPerMatch.toStringAsFixed(2)}',
        color: stats.avgPnlPerMatch >= 0
            ? AppTheme.solanaGreen
            : AppTheme.error,
      ),
      _DeepStatItem(
        icon: Icons.arrow_upward_rounded,
        label: 'Best Match PnL',
        value: '+\$${stats.bestMatchPnl.toStringAsFixed(2)}',
        color: AppTheme.solanaGreen,
      ),
      _DeepStatItem(
        icon: Icons.arrow_downward_rounded,
        label: 'Worst Match PnL',
        value: '-\$${stats.worstMatchPnl.abs().toStringAsFixed(2)}',
        color: AppTheme.error,
      ),
      _DeepStatItem(
        icon: Icons.star_rounded,
        label: 'Favorite Asset',
        value: stats.favoriteAsset ?? 'N/A',
        color: AppTheme.warning,
      ),
      _DeepStatItem(
        icon: Icons.speed_rounded,
        label: 'Avg Leverage',
        value: '${stats.avgLeverage}x',
        color: AppTheme.info,
      ),
      _DeepStatItem(
        icon: Icons.account_balance_rounded,
        label: 'Total Volume',
        value: _formatVolume(stats.totalVolume),
        color: AppTheme.solanaPurple,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 2 : 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: isMobile ? 1.8 : 2.2,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(item.icon, size: 14, color: item.color),
                  const SizedBox(width: 6),
                  Text(
                    item.label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.value,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: item.color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatVolume(double volume) {
    if (volume >= 1000000) {
      return '\$${(volume / 1000000).toStringAsFixed(1)}M';
    } else if (volume >= 1000) {
      return '\$${(volume / 1000).toStringAsFixed(1)}K';
    }
    return '\$${volume.toStringAsFixed(0)}';
  }
}

class _DeepStatItem {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _DeepStatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
}
