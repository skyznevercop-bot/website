import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/trading_provider.dart';
import '../utils/arena_helpers.dart';
import '../../wallet/providers/wallet_provider.dart';

// =============================================================================
// Equity Bar — Live tug-of-war showing you vs opponent in real time
// =============================================================================

class EquityBar extends ConsumerWidget {
  final TradingState state;

  const EquityBar({super.key, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myTag = ref.watch(walletProvider).gamerTag ?? 'You';
    final oppTag = state.opponentGamerTag ?? 'Opponent';

    final myRoi = state.myRoiPercent;
    final oppRoi = state.opponentRoi;

    // Calculate bar ratio: normalize so the total always fills the bar.
    // Use a sigmoid-like mapping so small differences are visible.
    final diff = myRoi - oppRoi;
    // Maps diff to 0.0–1.0 range (0.5 = tied).
    final myFraction = (0.5 + (diff / (diff.abs() + 5)) * 0.45).clamp(0.15, 0.85);

    final myColor = AppTheme.solanaPurple;
    final oppColor = const Color(0xFFFF6B35); // Warm orange for opponent.

    final isAhead = myRoi > oppRoi;
    final isTied = (myRoi - oppRoi).abs() < 0.01;

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          // My tag + ROI.
          _PlayerLabel(
            tag: myTag,
            roi: myRoi,
            color: myColor,
            isLeading: isAhead && !isTied,
            alignment: CrossAxisAlignment.start,
          ),

          const SizedBox(width: 8),

          // ── Tug-of-war bar ──
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 6,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOutCubic,
                  child: Row(
                    children: [
                      // My side.
                      Flexible(
                        flex: (myFraction * 1000).round(),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeInOutCubic,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                myColor.withValues(alpha: 0.6),
                                myColor,
                              ],
                            ),
                            boxShadow: isAhead
                                ? [
                                    BoxShadow(
                                      color: myColor.withValues(alpha: 0.4),
                                      blurRadius: 4,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                      // Center divider.
                      Container(width: 2, color: AppTheme.background),
                      // Opponent side.
                      Flexible(
                        flex: ((1.0 - myFraction) * 1000).round(),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeInOutCubic,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                oppColor,
                                oppColor.withValues(alpha: 0.6),
                              ],
                            ),
                            boxShadow: !isAhead && !isTied
                                ? [
                                    BoxShadow(
                                      color: oppColor.withValues(alpha: 0.4),
                                      blurRadius: 4,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Opponent tag + ROI.
          _PlayerLabel(
            tag: oppTag,
            roi: oppRoi,
            color: oppColor,
            isLeading: !isAhead && !isTied,
            alignment: CrossAxisAlignment.end,
          ),
        ],
      ),
    );
  }
}

class _PlayerLabel extends StatelessWidget {
  final String tag;
  final double roi;
  final Color color;
  final bool isLeading;
  final CrossAxisAlignment alignment;

  const _PlayerLabel({
    required this.tag,
    required this.roi,
    required this.color,
    required this.isLeading,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: alignment,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLeading) ...[
                Icon(Icons.arrow_drop_up_rounded, size: 14, color: color),
                const SizedBox(width: 1),
              ],
              Flexible(
                child: Text(
                  tag,
                  style: interStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isLeading ? color : AppTheme.textTertiary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            fmtPercent(roi),
            style: interStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: pnlColor(roi),
              tabularFigures: true,
            ),
          ),
        ],
      ),
    );
  }
}
