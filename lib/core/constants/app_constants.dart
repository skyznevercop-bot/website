/// App-wide constants for SolFight.
class AppConstants {
  AppConstants._();

  // ── App Info ──────────────────────────────────────────────────────────────
  static const String appName = 'SolFight';
  static const String appTagline = '1v1 Trading Battles on Solana';

  // ── Match Durations ────────────────────────────────────────────────────
  static const List<QueueDuration> durations = [
    QueueDuration(label: '15m', length: Duration(minutes: 15)),
    QueueDuration(label: '1h', length: Duration(hours: 1)),
    QueueDuration(label: '4h', length: Duration(hours: 4)),
    QueueDuration(label: '12h', length: Duration(hours: 12)),
    QueueDuration(label: '24h', length: Duration(hours: 24)),
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

/// Represents a match duration option for matchmaking.
class QueueDuration {
  final String label;
  final Duration length;

  const QueueDuration({
    required this.label,
    required this.length,
  });
}
