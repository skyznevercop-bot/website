import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';

/// Learn screen — tutorials, articles, and paper-trading demo.
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          // Header
          Padding(
            padding: Responsive.horizontalPadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Learn to Trade',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Master the arena with tutorials, strategies, and practice modes.',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Content cards
          Padding(
            padding: Responsive.horizontalPadding(context),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: const [
                _LearnCard(
                  icon: Icons.play_circle_filled_rounded,
                  title: 'Getting Started',
                  description: 'Learn how SolFight works, from connecting your wallet to winning matches.',
                  tag: 'BEGINNER',
                  tagColor: AppTheme.success,
                ),
                _LearnCard(
                  icon: Icons.candlestick_chart_rounded,
                  title: 'Reading Charts',
                  description: 'Understand price charts, candlesticks, support & resistance levels.',
                  tag: 'FUNDAMENTALS',
                  tagColor: AppTheme.info,
                ),
                _LearnCard(
                  icon: Icons.psychology_rounded,
                  title: 'Trading Strategies',
                  description: 'Explore proven strategies for short and long timeframe battles.',
                  tag: 'INTERMEDIATE',
                  tagColor: AppTheme.warning,
                ),
                _LearnCard(
                  icon: Icons.science_rounded,
                  title: 'Paper Trading',
                  description: 'Practice with virtual funds before risking real USDC.',
                  tag: 'PRACTICE',
                  tagColor: AppTheme.solanaPurple,
                ),
                _LearnCard(
                  icon: Icons.shield_rounded,
                  title: 'Risk Management',
                  description: 'Learn position sizing, stop losses, and how to protect your capital.',
                  tag: 'ESSENTIAL',
                  tagColor: AppTheme.error,
                ),
                _LearnCard(
                  icon: Icons.emoji_events_rounded,
                  title: 'Advanced Tactics',
                  description: 'Scalping, mean-reversion, and momentum strategies for pros.',
                  tag: 'ADVANCED',
                  tagColor: AppTheme.solanaPurpleDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LearnCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final String tag;
  final Color tagColor;

  const _LearnCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.tag,
    required this.tagColor,
  });

  @override
  State<_LearnCard> createState() => _LearnCardState();
}

class _LearnCardState extends State<_LearnCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final width = Responsive.value<double>(context,
        mobile: MediaQuery.sizeOf(context).width - 32,
        tablet: (MediaQuery.sizeOf(context).width - 80) / 2,
        desktop: (MediaQuery.sizeOf(context).width - 144) / 3);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width.clamp(0, 400),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: _hovered
                ? widget.tagColor.withValues(alpha: 0.3)
                : AppTheme.border,
          ),
          boxShadow: _hovered ? AppTheme.shadowMd : AppTheme.shadowSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.tagColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.icon, color: widget.tagColor, size: 22),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.tagColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.tag,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: widget.tagColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.description,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
