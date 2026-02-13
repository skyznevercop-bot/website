/// App-wide constants for SolFight.
class AppConstants {
  AppConstants._();

  // ── App Info ──────────────────────────────────────────────────────────────
  static const String appName = 'SolFight';
  static const String appTagline = '1v1 Trading Battles on Solana';

  // ── Solana Config ─────────────────────────────────────────────────────────
  static const String solanaCluster = 'devnet'; // Switch to 'mainnet-beta' for production
  static const String rpcUrl = 'https://api.devnet.solana.com';
  static const String usdcMintDevnet = '4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU';
  static const String usdcMintMainnet = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';

  // ── Queue Timeframes ──────────────────────────────────────────────────────
  static const List<QueueTimeframe> timeframes = [
    QueueTimeframe(label: '15m', duration: Duration(minutes: 15), entryFee: 10),
    QueueTimeframe(label: '30m', duration: Duration(minutes: 30), entryFee: 10),
    QueueTimeframe(label: '1h', duration: Duration(hours: 1), entryFee: 25),
    QueueTimeframe(label: '4h', duration: Duration(hours: 4), entryFee: 25),
    QueueTimeframe(label: '12h', duration: Duration(hours: 12), entryFee: 50),
    QueueTimeframe(label: '24h', duration: Duration(hours: 24), entryFee: 50),
  ];

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
  final double entryFee; // in USDC

  const QueueTimeframe({
    required this.label,
    required this.duration,
    required this.entryFee,
  });
}
