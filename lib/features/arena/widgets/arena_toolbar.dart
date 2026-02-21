import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../providers/trading_provider.dart';
import '../utils/arena_helpers.dart';

// =============================================================================
// Arena Toolbar — Redesigned with match progress bar & live stats
// =============================================================================

class ArenaToolbar extends ConsumerWidget {
  final TradingState state;
  final int durationSeconds;
  final bool chatOpen;
  final VoidCallback onChatToggle;

  const ArenaToolbar({
    super.key,
    required this.state,
    required this.durationSeconds,
    this.chatOpen = false,
    required this.onChatToggle,
  });

  double get _roi => state.myRoiPercent;

  double get _timeProgress =>
      durationSeconds > 0
          ? state.matchTimeRemainingSeconds / durationSeconds
          : 0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = Responsive.isMobile(context);
    final oppRoi = state.opponentRoi;
    final roi = _roi;
    final roiCol = pnlColor(roi);
    final oppRoiCol = pnlColor(oppRoi);

    return Column(
      children: [
        // ── Main toolbar row ──
        Container(
          height: 52,
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20),
          color: AppTheme.background,
          child: Row(
            children: [
              // Back / SolFight
              _BackButton(state: state, isMobile: isMobile),
              const SizedBox(width: 12),

              if (state.matchActive) ...[
                // Timer badge
                _TimerBadge(
                  seconds: state.matchTimeRemainingSeconds,
                  progress: _timeProgress,
                ),
                const SizedBox(width: 10),

                // Opponent info
                if (state.opponentGamerTag != null) ...[
                  _OpponentBadge(
                    tag: state.opponentGamerTag!,
                    roi: oppRoi,
                    roiColor: oppRoiCol,
                    positionCount: state.opponentPositionCount,
                    isMobile: isMobile,
                  ),
                  const SizedBox(width: 10),
                ],
              ],

              const Spacer(),

              if (!isMobile) ...[
                // Chat toggle
                _ChatToggle(isOpen: chatOpen, onTap: onChatToggle),
                const SizedBox(width: 12),

                // Balance
                _StatChip(
                  label: 'Balance',
                  value: fmtBalance(state.balance),
                ),
                const SizedBox(width: 8),
              ],

              // Equity
              _StatChip(
                label: 'Equity',
                value: fmtBalance(state.equity),
              ),
              const SizedBox(width: 8),

              // ROI badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: roiCol.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: roiCol.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  fmtPercent(roi),
                  style: interStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: roiCol,
                    tabularFigures: true,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Time progress bar (thin line at bottom of toolbar) ──
        if (state.matchActive)
          _TimeProgressBar(progress: _timeProgress, seconds: state.matchTimeRemainingSeconds),
      ],
    );
  }
}

// =============================================================================
// Time Progress Bar — thin animated bar showing match time remaining
// =============================================================================

class _TimeProgressBar extends StatelessWidget {
  final double progress;
  final int seconds;

  const _TimeProgressBar({required this.progress, required this.seconds});

  @override
  Widget build(BuildContext context) {
    // Color shifts from purple → orange → red as time runs out.
    final Color barColor;
    if (seconds <= 30) {
      barColor = AppTheme.error;
    } else if (seconds <= 60) {
      barColor = AppTheme.warning;
    } else {
      barColor = AppTheme.solanaPurple;
    }

    return Container(
      height: 3,
      width: double.infinity,
      color: AppTheme.border,
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 900),
          curve: Curves.linear,
          decoration: BoxDecoration(
            color: barColor,
            boxShadow: seconds <= 60
                ? [
                    BoxShadow(
                      color: barColor.withValues(alpha: 0.5),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Timer Badge — countdown with circular progress ring
// =============================================================================

class _TimerBadge extends StatelessWidget {
  final int seconds;
  final double progress;

  const _TimerBadge({required this.seconds, required this.progress});

  @override
  Widget build(BuildContext context) {
    final isUrgent = seconds <= 30;
    final isWarning = seconds <= 60;
    final color = isUrgent
        ? AppTheme.error
        : isWarning
            ? AppTheme.warning
            : AppTheme.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isUrgent
            ? AppTheme.error.withValues(alpha: 0.12)
            : AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        boxShadow: isUrgent
            ? [
                BoxShadow(
                  color: AppTheme.error.withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mini circular progress.
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              strokeWidth: 2,
              backgroundColor: AppTheme.border,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            fmtTime(seconds),
            style: interStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isUrgent ? AppTheme.error : AppTheme.textPrimary,
              tabularFigures: true,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Opponent Badge — shows opponent tag, ROI, and activity indicator
// =============================================================================

class _OpponentBadge extends StatelessWidget {
  final String tag;
  final double roi;
  final Color roiColor;
  final int positionCount;
  final bool isMobile;

  const _OpponentBadge({
    required this.tag,
    required this.roi,
    required this.roiColor,
    required this.positionCount,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Opponent activity indicator (pulsing dot when they have positions).
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: positionCount > 0
                    ? AppTheme.warning
                    : AppTheme.textTertiary,
                shape: BoxShape.circle,
                boxShadow: positionCount > 0
                    ? [
                        BoxShadow(
                          color: AppTheme.warning.withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 6),

            if (!isMobile) ...[
              Flexible(
                child: Text(
                  'VS $tag',
                  style: interStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
            ] else ...[
              Text(
                'VS ',
                style: interStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],

            // Opponent ROI chip.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: roiColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                fmtPercent(roi),
                style: interStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: roiColor,
                  tabularFigures: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Small shared toolbar widgets
// =============================================================================

class _BackButton extends StatelessWidget {
  final TradingState state;
  final bool isMobile;

  const _BackButton({required this.state, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (state.matchActive) {
            _showExitDialog(context);
          } else {
            context.go(AppConstants.playRoute);
          }
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_back_rounded,
                size: 18, color: AppTheme.textSecondary),
            if (!isMobile) ...[
              const SizedBox(width: 8),
              Text(
                'SolFight',
                style: interStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => PointerInterceptor(
        child: AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
          title: Text('Leave Match?',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppTheme.textPrimary)),
          content: Text(
              'You can return to your match from the lobby, or forfeit to end it now.',
              style: GoogleFonts.inter(
                  fontSize: 14, color: AppTheme.textSecondary)),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Stay')),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.solanaPurple),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                context.go(AppConstants.playRoute);
              },
              child: Text('Return to Lobby',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.solanaPurple)),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
              onPressed: () {
                Navigator.of(ctx).pop();
                ApiClient.instance.disconnectWebSocket();
                ProviderScope.containerOf(context)
                    .read(tradingProvider.notifier)
                    .endMatch(isForfeit: true);
                context.go(AppConstants.playRoute);
                Future.delayed(const Duration(seconds: 1), () {
                  ApiClient.instance.connectWebSocket();
                });
              },
              child: const Text('Forfeit Match'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatToggle extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onTap;

  const _ChatToggle({required this.isOpen, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isOpen
                ? AppTheme.solanaPurple.withValues(alpha: 0.15)
                : AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isOpen
                ? Icons.chat_bubble_rounded
                : Icons.chat_bubble_outline_rounded,
            size: 16,
            color:
                isOpen ? AppTheme.solanaPurple : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label,
            style: interStyle(
              fontSize: 10,
              color: AppTheme.textTertiary,
            )),
        Text(value,
            style: interStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              tabularFigures: true,
            )),
      ],
    );
  }
}
