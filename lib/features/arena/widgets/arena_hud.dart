import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../models/trading_models.dart';
import '../providers/trading_provider.dart';
import '../utils/arena_helpers.dart';

// =============================================================================
// Arena HUD — Gaming-style heads-up display
//
// Layout: [← YOU stats]  [⏱ TIMER + PHASE]  [OPP stats 💬]
//         [══════════════ progress bar ══════════════════]
// =============================================================================

class ArenaHud extends ConsumerWidget {
  final TradingState state;
  final int durationSeconds;

  const ArenaHud({
    super.key,
    required this.state,
    required this.durationSeconds,
  });

  double get _roi => state.myRoiPercent;

  double get _timeProgress =>
      durationSeconds > 0
          ? state.matchTimeRemainingSeconds / durationSeconds
          : 0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = Responsive.isMobile(context);
    final roi = _roi;
    final oppRoi = state.opponentRoi;
    final phase = state.matchPhase;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Main HUD row ──
        Container(
          height: isMobile ? 52 : 56,
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16),
          decoration: const BoxDecoration(
            color: AppTheme.background,
            border: Border(
              bottom: BorderSide(color: AppTheme.border, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              // ── Left: Back ──
              _BackButton(state: state, isMobile: isMobile),

              const Spacer(),

              // ── Center: Timer + Phase ──
              if (state.matchActive)
                _CenterTimer(
                  seconds: state.matchTimeRemainingSeconds,
                  progress: _timeProgress,
                  phase: phase,
                  isMobile: isMobile,
                ),

              const Spacer(),

              // ── Right: Opponent + Player stats + Equity + Chat ──
              if (state.matchActive && state.isPracticeMode) ...[
                _PracticeBadge(isMobile: isMobile),
                const SizedBox(width: 8),
              ] else if (state.matchActive && state.opponentGamerTag != null) ...[
                _OpponentBadge(
                  tag: state.opponentGamerTag!,
                  roi: oppRoi,
                  positionCount: state.opponentPositionCount,
                  isMobile: isMobile,
                ),
                const SizedBox(width: 8),
              ],
              if (!isMobile)
                _PlayerBadge(
                  equity: state.equity,
                  roi: roi,
                  balance: state.balance,
                )
              else
                _MobileStatCycler(
                  roi: roi,
                  balance: state.balance,
                  equity: state.equity,
                ),
            ],
          ),
        ),

        // ── Time progress bar ──
        if (state.matchActive)
          _TimeProgressBar(
            progress: _timeProgress,
            seconds: state.matchTimeRemainingSeconds,
          ),
      ],
    );
  }
}

// =============================================================================
// Center Timer — Large countdown with phase pill
// =============================================================================

class _CenterTimer extends StatelessWidget {
  final int seconds;
  final double progress;
  final MatchPhase phase;
  final bool isMobile;

  const _CenterTimer({
    required this.seconds,
    required this.progress,
    required this.phase,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final isLastStand = phase == MatchPhase.lastStand;
    final isFinalSprint = phase == MatchPhase.finalSprint;
    final timerColor = isLastStand
        ? AppTheme.error
        : isFinalSprint
            ? AppTheme.warning
            : AppTheme.textPrimary;
    final pColor = phaseColor(phase);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Circular progress ring.
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            strokeWidth: 2.5,
            backgroundColor: AppTheme.border,
            color: pColor,
          ),
        ),
        const SizedBox(width: 8),

        // Timer text — scales up in urgency.
        Text(
          fmtTime(seconds),
          style: interStyle(
            fontSize: isLastStand ? 20 : isFinalSprint ? 18 : 16,
            fontWeight: FontWeight.w800,
            color: timerColor,
            tabularFigures: true,
            letterSpacing: 1.0,
          ),
        ),

        // Phase pill badge.
        if (!isMobile && phase != MatchPhase.intro) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: pColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: pColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              phaseLabel(phase),
              style: interStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: pColor,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// Player Badge — Your equity + ROI on the left side
// =============================================================================

class _PlayerBadge extends StatelessWidget {
  final double equity;
  final double roi;
  final double balance;

  const _PlayerBadge({
    required this.equity,
    required this.roi,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    final roiCol = pnlColor(roi);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ROI badge — sized to match the stacked Balance/Equity height.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: roiCol.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: roiCol.withValues(alpha: 0.25)),
          ),
          child: Text(
            fmtPercent(roi),
            style: interStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: roiCol,
              tabularFigures: true,
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Balance on top, Equity on bottom.
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Balance: ',
                    style: interStyle(
                        fontSize: 10, color: AppTheme.textTertiary)),
                Text(fmtBalance(balance),
                    style: interStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      tabularFigures: true,
                    )),
              ],
            ),
            const SizedBox(height: 1),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Equity: ',
                    style: interStyle(
                        fontSize: 10, color: AppTheme.textTertiary)),
                Text(fmtBalance(equity),
                    style: interStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      tabularFigures: true,
                    )),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// Mobile Stat Cycler — tap to cycle through ROI / Balance / Equity
// =============================================================================

class _MobileStatCycler extends StatefulWidget {
  final double roi;
  final double balance;
  final double equity;

  const _MobileStatCycler({
    required this.roi,
    required this.balance,
    required this.equity,
  });

  @override
  State<_MobileStatCycler> createState() => _MobileStatCyclerState();
}

class _MobileStatCyclerState extends State<_MobileStatCycler> {
  int _index = 0; // 0=ROI, 1=Balance, 2=Equity

  String get _label => const ['ROI', 'Balance', 'Equity'][_index];

  String get _value {
    switch (_index) {
      case 0:
        return fmtPercent(widget.roi);
      case 1:
        return fmtBalance(widget.balance);
      case 2:
        return fmtBalance(widget.equity);
      default:
        return '';
    }
  }

  Color get _color => _index == 0 ? pnlColor(widget.roi) : AppTheme.textPrimary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _index = (_index + 1) % 3),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Container(
            key: ValueKey(_index),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (_index == 0
                      ? pnlColor(widget.roi)
                      : AppTheme.solanaPurple)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: (_index == 0
                        ? pnlColor(widget.roi)
                        : AppTheme.solanaPurple)
                    .withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _label,
                  style: interStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textTertiary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _value,
                  style: interStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _color,
                    tabularFigures: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Opponent Badge — activity dot + tag + ROI
// =============================================================================

class _OpponentBadge extends StatelessWidget {
  final String tag;
  final double roi;
  final int positionCount;
  final bool isMobile;

  const _OpponentBadge({
    required this.tag,
    required this.roi,
    required this.positionCount,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final roiCol = pnlColor(roi);

    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Activity dot.
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

            // Tag (desktop only).
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
              const SizedBox(width: 6),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: roiCol.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                fmtPercent(roi),
                style: interStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: roiCol,
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
// Practice Badge — amber pill shown instead of opponent badge
// =============================================================================

class _PracticeBadge extends StatelessWidget {
  final bool isMobile;

  const _PracticeBadge({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.school_rounded,
              size: 14, color: AppTheme.warning),
          const SizedBox(width: 6),
          Text(
            'PRACTICE',
            style: interStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.warning,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Time Progress Bar — phase-colored progress line
// =============================================================================

class _TimeProgressBar extends StatelessWidget {
  final double progress;
  final int seconds;

  const _TimeProgressBar({required this.progress, required this.seconds});

  @override
  Widget build(BuildContext context) {
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
// Back Button — with exit/forfeit dialog
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
              const SizedBox(width: 6),
              Text(
                'SolFight',
                style: interStyle(
                  fontSize: 14,
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
    if (state.isPracticeMode) {
      showDialog(
        context: context,
        builder: (ctx) => PointerInterceptor(
          child: AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
            title: Text('Leave Practice?',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AppTheme.textPrimary)),
            content: Text(
                'Your practice session will end and progress will not be saved.',
                style: GoogleFonts.inter(
                    fontSize: 14, color: AppTheme.textSecondary)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Stay')),
              ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppTheme.warning),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ProviderScope.containerOf(context)
                      .read(tradingProvider.notifier)
                      .endMatch(isForfeit: true);
                  context.go(AppConstants.playRoute);
                },
                child: const Text('Leave'),
              ),
            ],
          ),
        ),
      );
      return;
    }
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

