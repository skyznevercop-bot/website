/// App-wide constants for SolFight.
class AppConstants {
  AppConstants._();

  // ── App Info ──────────────────────────────────────────────────────────────
  static const String appName = 'SolFight';
  static const String appTagline = '1v1 Trading Battles on Solana';

  // ── Match Durations ────────────────────────────────────────────────────
  static const List<QueueDuration> durations = [
    QueueDuration(label: '5m', length: Duration(minutes: 5)),
    QueueDuration(label: '15m', length: Duration(minutes: 15)),
    QueueDuration(label: '1h', length: Duration(hours: 1)),
    QueueDuration(label: '4h', length: Duration(hours: 4)),
    QueueDuration(label: '24h', length: Duration(hours: 24)),
  ];

  // ── Bet Amounts (USDC) ──────────────────────────────────────────────────
  static const List<int> betAmounts = [1, 5, 10, 25, 100];
  static const int defaultBetIndex = 2; // $10

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
  static const String friendsRoute = '/friends';
  static const String helpRoute = '/help';
  static const String rulesRoute = '/rules';
  static const String feedbackRoute = '/feedback';
  static const String aboutRoute = '/about';
  static const String privacyRoute = '/privacy';
  static const String termsRoute = '/terms';
  static const String profileRoute = '/profile';
  static const String spectateRoute = '/spectate';
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
