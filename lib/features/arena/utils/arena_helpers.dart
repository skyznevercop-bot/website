import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../models/match_event.dart';
import '../models/trading_models.dart';

// =============================================================================
// Shared formatting & helper functions used across Arena widgets
// =============================================================================

/// Format a price with appropriate decimal places.
String fmtPrice(double price) {
  if (price >= 100) return price.toStringAsFixed(2);
  return price.toStringAsFixed(3);
}

/// Format a balance as a compact dollar string.
String fmtBalance(double value) {
  if (value >= 1000000) return '\$${(value / 1000000).toStringAsFixed(2)}M';
  if (value >= 1000) return '\$${(value / 1000).toStringAsFixed(1)}K';
  return '\$${value.toStringAsFixed(2)}';
}

/// Format a PnL value with sign.
String fmtPnl(double pnl) {
  final sign = pnl >= 0 ? '+' : '';
  return '$sign\$${pnl.toStringAsFixed(2)}';
}

/// Format a percentage with sign.
String fmtPercent(double pct) {
  final sign = pct >= 0 ? '+' : '';
  return '$sign${pct.toStringAsFixed(2)}%';
}

/// Format time remaining as MM:SS.
String fmtTime(int totalSeconds) {
  final m = totalSeconds ~/ 60;
  final s = totalSeconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// Format leverage display.
String fmtLeverage(double lev) {
  return '${lev.toStringAsFixed(lev == lev.roundToDouble() ? 0 : 1)}x';
}

/// Get the brand color for a crypto asset.
Color assetColor(String symbol) {
  switch (symbol) {
    case 'BTC':
      return const Color(0xFFF7931A);
    case 'ETH':
      return const Color(0xFF627EEA);
    case 'SOL':
      return AppTheme.solanaPurple;
    default:
      return AppTheme.textSecondary;
  }
}

/// Get the color for a leverage level.
Color leverageColor(double lev, bool isLong) {
  if (lev >= 76) return AppTheme.error;
  if (lev >= 26) return AppTheme.warning;
  return isLong ? AppTheme.success : AppTheme.error;
}

/// PnL color helper.
Color pnlColor(double pnl) => pnl >= 0 ? AppTheme.success : AppTheme.error;

/// Inter text style factory for consistent typography.
TextStyle interStyle({
  required double fontSize,
  FontWeight fontWeight = FontWeight.w400,
  Color? color,
  double? letterSpacing,
  bool tabularFigures = false,
  double? height,
}) {
  return GoogleFonts.inter(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color ?? AppTheme.textPrimary,
    letterSpacing: letterSpacing,
    height: height,
    fontFeatures: tabularFigures
        ? const [FontFeature.tabularFigures()]
        : null,
  );
}

/// Risk level from leverage.
enum RiskLevel { low, medium, high, extreme }

RiskLevel riskFromLeverage(double lev) {
  if (lev >= 76) return RiskLevel.extreme;
  if (lev >= 26) return RiskLevel.high;
  if (lev >= 10) return RiskLevel.medium;
  return RiskLevel.low;
}

String riskLabel(RiskLevel risk) {
  switch (risk) {
    case RiskLevel.low:
      return 'LOW';
    case RiskLevel.medium:
      return 'MED';
    case RiskLevel.high:
      return 'HIGH';
    case RiskLevel.extreme:
      return 'EXTREME';
  }
}

Color riskColor(RiskLevel risk) {
  switch (risk) {
    case RiskLevel.low:
      return AppTheme.success;
    case RiskLevel.medium:
      return AppTheme.warning;
    case RiskLevel.high:
      return const Color(0xFFFF6B35);
    case RiskLevel.extreme:
      return AppTheme.error;
  }
}

// =============================================================================
// Match Phase helpers
// =============================================================================

/// Accent color for each match phase.
Color phaseColor(MatchPhase phase) {
  switch (phase) {
    case MatchPhase.intro:
      return Colors.white;
    case MatchPhase.openingBell:
      return AppTheme.solanaPurple;
    case MatchPhase.midGame:
      return AppTheme.solanaPurple;
    case MatchPhase.finalSprint:
      return AppTheme.warning;
    case MatchPhase.lastStand:
      return AppTheme.error;
    case MatchPhase.ended:
      return AppTheme.textTertiary;
  }
}

/// Display label for each match phase.
String phaseLabel(MatchPhase phase) {
  switch (phase) {
    case MatchPhase.intro:
      return 'GET READY';
    case MatchPhase.openingBell:
      return 'OPENING BELL';
    case MatchPhase.midGame:
      return 'MID GAME';
    case MatchPhase.finalSprint:
      return 'FINAL SPRINT';
    case MatchPhase.lastStand:
      return 'LAST STAND';
    case MatchPhase.ended:
      return 'MATCH OVER';
  }
}

/// Compute the match phase from time remaining and total duration.
MatchPhase computePhase(int remainingSeconds, int totalSeconds) {
  if (totalSeconds <= 0) return MatchPhase.ended;
  final elapsed = totalSeconds - remainingSeconds;
  if (elapsed < 5) return MatchPhase.intro;
  if (remainingSeconds <= 0) return MatchPhase.ended;
  final pctRemaining = remainingSeconds / totalSeconds;
  if (pctRemaining > 0.80) return MatchPhase.openingBell;
  if (pctRemaining > 0.30) return MatchPhase.midGame;
  if (pctRemaining > 0.10) return MatchPhase.finalSprint;
  return MatchPhase.lastStand;
}

/// Format a Duration as "Xm Ys" or "Xs".
String fmtDuration(Duration d) {
  final mins = d.inMinutes;
  final secs = d.inSeconds % 60;
  if (mins > 0) return '${mins}m ${secs}s';
  return '${secs}s';
}

// =============================================================================
// Event Feed helpers
// =============================================================================

/// Icon for each event type.
IconData eventIcon(EventType type) {
  switch (type) {
    case EventType.leadChange:
      return Icons.swap_horiz_rounded;
    case EventType.opponentTrade:
      return Icons.person_rounded;
    case EventType.bigMove:
      return Icons.show_chart_rounded;
    case EventType.milestone:
      return Icons.flag_rounded;
    case EventType.phaseChange:
      return Icons.timer_rounded;
    case EventType.liquidation:
      return Icons.warning_amber_rounded;
    case EventType.streak:
      return Icons.local_fire_department_rounded;
    case EventType.tradeResult:
      return Icons.check_circle_outline_rounded;
  }
}

/// Color for each event type.
Color eventColor(EventType type) {
  switch (type) {
    case EventType.leadChange:
      return const Color(0xFFFFD700); // gold
    case EventType.opponentTrade:
      return const Color(0xFFFF6B35); // orange
    case EventType.bigMove:
      return AppTheme.info;
    case EventType.milestone:
      return AppTheme.success;
    case EventType.phaseChange:
      return AppTheme.solanaPurple;
    case EventType.liquidation:
      return AppTheme.error;
    case EventType.streak:
      return const Color(0xFFFF6B35);
    case EventType.tradeResult:
      return AppTheme.success;
  }
}
