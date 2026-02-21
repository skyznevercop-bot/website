import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../providers/trading_provider.dart';
import '../utils/arena_helpers.dart';

// =============================================================================
// Battle Bar — Dramatic tug-of-war visualization (replaces equity_bar.dart)
//
// Enhanced: taller bar, gradient shimmer on leader, avatar circles,
// lead change flash effect, center diamond marker.
// =============================================================================

class BattleBar extends ConsumerStatefulWidget {
  final TradingState state;

  const BattleBar({super.key, required this.state});

  @override
  ConsumerState<BattleBar> createState() => _BattleBarState();
}

class _BattleBarState extends ConsumerState<BattleBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _flashController;
  int _lastLeadChangeCount = 0;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _lastLeadChangeCount = widget.state.leadChangeCount;
  }

  @override
  void didUpdateWidget(BattleBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger flash animation on lead change.
    if (widget.state.leadChangeCount > _lastLeadChangeCount) {
      _lastLeadChangeCount = widget.state.leadChangeCount;
      _flashController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myTag = ref.watch(walletProvider).gamerTag ?? 'You';
    final oppTag = widget.state.opponentGamerTag ?? 'Opponent';

    final myRoi = widget.state.myRoiPercent;
    final oppRoi = widget.state.opponentRoi;

    // Sigmoid mapping: diff → 0..1 (0.5 = tied).
    final diff = myRoi - oppRoi;
    final myFraction =
        (0.5 + (diff / (diff.abs() + 5)) * 0.45).clamp(0.15, 0.85);

    const myColor = AppTheme.solanaPurple;
    const oppColor = Color(0xFFFF6B35);

    final isAhead = myRoi > oppRoi;
    final isTied = (myRoi - oppRoi).abs() < 0.01;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 0.5)),
      ),
      child: Row(
        children: [
          // ── My avatar + tag + ROI ──
          _AvatarLabel(
            tag: myTag,
            roi: myRoi,
            color: myColor,
            isLeading: isAhead && !isTied,
            alignment: CrossAxisAlignment.start,
          ),

          const SizedBox(width: 8),

          // ── Tug-of-war bar with lead-change flash ──
          Expanded(
            child: AnimatedBuilder(
              animation: _flashController,
              builder: (context, child) {
                final flashOpacity = (1.0 - _flashController.value) * 0.4;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // The bar itself.
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: SizedBox(
                        height: 10,
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
                                      myColor.withValues(alpha: 0.5),
                                      myColor,
                                    ],
                                  ),
                                  boxShadow: isAhead
                                      ? [
                                          BoxShadow(
                                            color: myColor
                                                .withValues(alpha: 0.4),
                                            blurRadius: 6,
                                            spreadRadius: 1,
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
                                      oppColor.withValues(alpha: 0.5),
                                    ],
                                  ),
                                  boxShadow: !isAhead && !isTied
                                      ? [
                                          BoxShadow(
                                            color: oppColor
                                                .withValues(alpha: 0.4),
                                            blurRadius: 6,
                                            spreadRadius: 1,
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

                    // Lead-change flash overlay.
                    if (flashOpacity > 0.01)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: Colors.white.withValues(alpha: flashOpacity),
                          ),
                        ),
                      ),

                    // Center diamond marker.
                    Positioned(
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Transform.rotate(
                          angle: 0.785, // 45 degrees
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              border: Border.all(
                                color: isTied
                                    ? AppTheme.textTertiary
                                    : isAhead
                                        ? myColor
                                        : oppColor,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(width: 8),

          // ── Opponent avatar + tag + ROI ──
          _AvatarLabel(
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

// =============================================================================
// Avatar Label — Circle avatar with first letter + tag + ROI
// =============================================================================

class _AvatarLabel extends StatelessWidget {
  final String tag;
  final double roi;
  final Color color;
  final bool isLeading;
  final CrossAxisAlignment alignment;

  const _AvatarLabel({
    required this.tag,
    required this.roi,
    required this.color,
    required this.isLeading,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment == CrossAxisAlignment.start;

    return SizedBox(
      width: 110,
      child: Row(
        mainAxisAlignment:
            isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (!isLeft) ...[
            _buildStats(),
            const SizedBox(width: 6),
          ],

          // Avatar circle.
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: isLeading ? 0.2 : 0.08),
              border: Border.all(
                color: isLeading ? color : AppTheme.border,
                width: 1.5,
              ),
              boxShadow: isLeading
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                tag.isNotEmpty ? tag[0].toUpperCase() : '?',
                style: interStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isLeading ? color : AppTheme.textTertiary,
                ),
              ),
            ),
          ),

          if (isLeft) ...[
            const SizedBox(width: 6),
            _buildStats(),
          ],
        ],
      ),
    );
  }

  Widget _buildStats() {
    final isLeft = alignment == CrossAxisAlignment.start;
    return Flexible(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: isLeft
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: [
          Text(
            tag,
            style: interStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isLeading ? color : AppTheme.textTertiary,
            ),
            overflow: TextOverflow.ellipsis,
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
