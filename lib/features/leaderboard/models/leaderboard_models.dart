import 'dart:math';

/// A single player on the leaderboard.
class LeaderboardPlayer {
  final String id;
  final String gamerTag;
  final int eloRating;
  final int wins;
  final int losses;
  final int draws;
  final double pnl;
  final int streak;

  const LeaderboardPlayer({
    required this.id,
    required this.gamerTag,
    this.eloRating = 1200,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.pnl = 0,
    this.streak = 0,
  });

  int get gamesPlayed => wins + losses + draws;

  double get winRate =>
      gamesPlayed > 0 ? (wins / gamesPlayed * 100) : 0;

  LeaderboardPlayer copyWith({
    String? id,
    String? gamerTag,
    int? eloRating,
    int? wins,
    int? losses,
    int? draws,
    double? pnl,
    int? streak,
  }) {
    return LeaderboardPlayer(
      id: id ?? this.id,
      gamerTag: gamerTag ?? this.gamerTag,
      eloRating: eloRating ?? this.eloRating,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      draws: draws ?? this.draws,
      pnl: pnl ?? this.pnl,
      streak: streak ?? this.streak,
    );
  }
}

/// State of the leaderboard feature.
class LeaderboardState {
  final List<LeaderboardPlayer> players;
  final bool isLoading;
  final String selectedPeriod;
  final String selectedTimeframe;

  const LeaderboardState({
    this.players = const [],
    this.isLoading = false,
    this.selectedPeriod = 'All Time',
    this.selectedTimeframe = 'All',
  });

  LeaderboardState copyWith({
    List<LeaderboardPlayer>? players,
    bool? isLoading,
    String? selectedPeriod,
    String? selectedTimeframe,
  }) {
    return LeaderboardState(
      players: players ?? this.players,
      isLoading: isLoading ?? this.isLoading,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      selectedTimeframe: selectedTimeframe ?? this.selectedTimeframe,
    );
  }
}

/// Chess-style ELO rating calculator.
class EloCalculator {
  EloCalculator._();

  /// Expected score of player A against player B.
  static double expectedScore(int ratingA, int ratingB) {
    return 1.0 / (1.0 + pow(10, (ratingB - ratingA) / 400.0));
  }

  /// K-factor: higher for newer players (< 30 games).
  static int kFactor(int gamesPlayed) {
    return gamesPlayed < 30 ? 40 : 32;
  }

  /// Returns (newRatingA, newRatingB) after a match.
  /// [scoreA] is 1.0 for win, 0.0 for loss, 0.5 for draw.
  static (int, int) calculateNewRatings(
    int ratingA,
    int ratingB,
    double scoreA, {
    int gamesA = 30,
    int gamesB = 30,
  }) {
    final eA = expectedScore(ratingA, ratingB);
    final eB = 1.0 - eA;
    final scoreB = 1.0 - scoreA;

    final kA = kFactor(gamesA);
    final kB = kFactor(gamesB);

    final newA = (ratingA + kA * (scoreA - eA)).round();
    final newB = (ratingB + kB * (scoreB - eB)).round();

    return (newA, newB);
  }
}
