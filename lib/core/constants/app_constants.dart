/// App-wide constants for SolFight.
class AppConstants {
  AppConstants._();

  // ── App Info ──────────────────────────────────────────────────────────────
  static const String appName = 'SolFight';
  static const String appTagline = '1v1 Trading Battles on Solana';

  // ── Queue Timeframes ──────────────────────────────────────────────────────
  static const List<QueueTimeframe> timeframes = [
    QueueTimeframe(label: '15m', duration: Duration(minutes: 15)),
    QueueTimeframe(label: '1h', duration: Duration(hours: 1)),
    QueueTimeframe(label: '4h', duration: Duration(hours: 4)),
    QueueTimeframe(label: '12h', duration: Duration(hours: 12)),
    QueueTimeframe(label: '24h', duration: Duration(hours: 24)),
  ];

  // ── Bet Amounts (USDC) ──────────────────────────────────────────────────
  static const List<int> betAmounts = [1, 2, 5, 10, 25, 50, 100];
  static const int defaultBetIndex = 3; // $10

  // ── Layout ────────────────────────────────────────────────────────────────
  static const double topBarHeight = 64.0;
  static const double maxContentWidth = 1280.0;
  static const double mobileBreakpoint = 768.0;
  static const double tabletBreakpoint = 1024.0;
  static const double desktopBreakpoint = 1280.0;

  // ── Navigation Routes ─────────────────────────────────────────────────────
  static const String playRoute = '/play';
  static const String clanRoute = '/clan';
  static const String leaderboardRoute = '/leaderboard';
  static const String portfolioRoute = '/portfolio';
  static const String learnRoute = '/learn';
  static const String arenaRoute = '/arena';
  static const String referralRoute = '/referral';
}

/// Represents a queue timeframe option for matchmaking.
class QueueTimeframe {
  final String label;
  final Duration duration;

  const QueueTimeframe({
    required this.label,
    required this.duration,
  });
}
