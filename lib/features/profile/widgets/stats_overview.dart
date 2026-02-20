import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../models/profile_models.dart';

class StatsOverview extends StatelessWidget {
  final PlayerProfile profile;

  const StatsOverview({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final stats = [
      _StatItem(
        label: 'Record',
        value: '${profile.wins}W - ${profile.losses}L',
        sub: '${profile.ties} ties',
      ),
      _StatItem(
        label: 'Win Rate',
        value: '${profile.winRate}%',
        color:
            profile.winRate >= 50 ? AppTheme.solanaGreen : AppTheme.error,
      ),
      _StatItem(
        label: 'Total PnL',
        value:
            '${profile.totalPnl >= 0 ? '+' : ''}\$${profile.totalPnl.toStringAsFixed(2)}',
        color:
            profile.totalPnl >= 0 ? AppTheme.solanaGreen : AppTheme.error,
      ),
      _StatItem(
        label: 'Current Streak',
        value: '${profile.currentStreak}',
        sub: 'Best: ${profile.bestStreak}',
      ),
      _StatItem(
        label: 'Games Played',
        value: '${profile.gamesPlayed}',
      ),
      _StatItem(
        label: 'Total Trades',
        value: '${profile.totalTrades}',
      ),
    ];

    if (isMobile) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.0,
        ),
        itemCount: stats.length,
        itemBuilder: (context, index) => _StatCard(stat: stats[index]),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.5,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) => _StatCard(stat: stats[index]),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final String? sub;
  final Color? color;

  const _StatItem({
    required this.label,
    required this.value,
    this.sub,
    this.color,
  });
}

class _StatCard extends StatelessWidget {
  final _StatItem stat;

  const _StatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
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
          Text(
            stat.label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                stat.value,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: stat.color ?? AppTheme.textPrimary,
                ),
              ),
              if (stat.sub != null) ...[
                const SizedBox(width: 6),
                Text(
                  stat.sub!,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
