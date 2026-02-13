/// A single player on the leaderboard.
class LeaderboardPlayer {
  final String id;
  final String gamerTag;
  final int wins;
  final int losses;
  final int ties;
  final double pnl;
  final int streak;

  const LeaderboardPlayer({
    required this.id,
    required this.gamerTag,
    this.wins = 0,
    this.losses = 0,
    this.ties = 0,
    this.pnl = 0,
    this.streak = 0,
  });

  int get gamesPlayed => wins + losses + ties;

  double get winRate =>
      gamesPlayed > 0 ? (wins / gamesPlayed * 100) : 0;

  LeaderboardPlayer copyWith({
    String? id,
    String? gamerTag,
    int? wins,
    int? losses,
    int? ties,
    double? pnl,
    int? streak,
  }) {
    return LeaderboardPlayer(
      id: id ?? this.id,
      gamerTag: gamerTag ?? this.gamerTag,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      ties: ties ?? this.ties,
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
