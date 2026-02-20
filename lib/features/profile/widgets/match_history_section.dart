import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../models/profile_models.dart';

class MatchHistorySection extends StatelessWidget {
  final List<MatchHistoryEntry> matches;

  const MatchHistorySection({super.key, required this.matches});

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.border),
        ),
        child: Center(
          child: Text(
            'No matches yet',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textTertiary,
            ),
          ),
        ),
      );
    }

    final isMobile = Responsive.isMobile(context);

    if (isMobile) {
      return Column(
        children:
            matches.map((m) => _MatchCard(match: m)).toList(),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          // Table header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _headerCell('Opponent', flex: 3),
                _headerCell('Result', flex: 2),
                _headerCell('PnL', flex: 2),
                _headerCell('Bet', flex: 1),
                _headerCell('Duration', flex: 1),
                _headerCell('Date', flex: 2),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),
          // Table rows
          ...matches.map((m) => _MatchRow(match: m)),
        ],
      ),
    );
  }

  Widget _headerCell(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.textTertiary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _MatchRow extends StatelessWidget {
  final MatchHistoryEntry match;

  const _MatchRow({required this.match});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () =>
          context.go('/profile/${match.opponentAddress}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Opponent
            Expanded(
              flex: 3,
              child: Text(
                match.opponentGamerTag,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.solanaPurple,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Result
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  _ResultBadge(result: match.result),
                ],
              ),
            ),
            // PnL
            Expanded(
              flex: 2,
              child: Text(
                '${match.pnl >= 0 ? '+' : ''}\$${match.pnl.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: match.pnl >= 0
                      ? AppTheme.solanaGreen
                      : AppTheme.error,
                ),
              ),
            ),
            // Bet
            Expanded(
              flex: 1,
              child: Text(
                '\$${match.betAmount.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            // Duration
            Expanded(
              flex: 1,
              child: Text(
                match.duration,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            // Date
            Expanded(
              flex: 2,
              child: Text(
                _formatDate(match.settledAt),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(int timestamp) {
    if (timestamp == 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${date.month}/${date.day}/${date.year}';
  }
}

class _MatchCard extends StatelessWidget {
  final MatchHistoryEntry match;

  const _MatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () =>
            context.go('/profile/${match.opponentAddress}'),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _ResultBadge(result: match.result),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'vs ${match.opponentGamerTag}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${match.duration} · \$${match.betAmount.toStringAsFixed(0)} bet',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${match.pnl >= 0 ? '+' : ''}\$${match.pnl.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: match.pnl >= 0
                      ? AppTheme.solanaGreen
                      : AppTheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultBadge extends StatelessWidget {
  final String result;

  const _ResultBadge({required this.result});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    switch (result) {
      case 'WIN':
        bgColor = AppTheme.solanaGreen.withValues(alpha: 0.12);
        textColor = AppTheme.solanaGreen;
        break;
      case 'LOSS':
        bgColor = AppTheme.error.withValues(alpha: 0.12);
        textColor = AppTheme.error;
        break;
      default:
        bgColor = AppTheme.warning.withValues(alpha: 0.12);
        textColor = AppTheme.warning;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        result,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}
