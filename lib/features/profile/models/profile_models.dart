class PlayerProfile {
  final String walletAddress;
  final String gamerTag;
  final int wins;
  final int losses;
  final int ties;
  final double totalPnl;
  final int currentStreak;
  final int bestStreak;
  final int gamesPlayed;
  final int totalTrades;
  final double winRate;
  final Map<String, bool> achievements;
  final DeepStats deepStats;
  final List<MatchHistoryEntry> recentMatches;
  final int createdAt;

  const PlayerProfile({
    required this.walletAddress,
    required this.gamerTag,
    required this.wins,
    required this.losses,
    required this.ties,
    required this.totalPnl,
    required this.currentStreak,
    required this.bestStreak,
    required this.gamesPlayed,
    required this.totalTrades,
    required this.winRate,
    required this.achievements,
    required this.deepStats,
    required this.recentMatches,
    required this.createdAt,
  });

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    return PlayerProfile(
      walletAddress: json['walletAddress'] as String,
      gamerTag: json['gamerTag'] as String,
      wins: json['wins'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
      ties: json['ties'] as int? ?? 0,
      totalPnl: (json['totalPnl'] as num?)?.toDouble() ?? 0,
      currentStreak: json['currentStreak'] as int? ?? 0,
      bestStreak: json['bestStreak'] as int? ?? 0,
      gamesPlayed: json['gamesPlayed'] as int? ?? 0,
      totalTrades: json['totalTrades'] as int? ?? 0,
      winRate: (json['winRate'] as num?)?.toDouble() ?? 0,
      achievements: (json['achievements'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as bool)) ??
          {},
      deepStats: DeepStats.fromJson(
          json['deepStats'] as Map<String, dynamic>? ?? {}),
      recentMatches: (json['recentMatches'] as List<dynamic>?)
              ?.map(
                  (m) => MatchHistoryEntry.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['createdAt'] as int? ?? 0,
    );
  }
}

class DeepStats {
  final double avgPnlPerMatch;
  final double bestMatchPnl;
  final double worstMatchPnl;
  final String? favoriteAsset;
  final double avgLeverage;
  final double totalVolume;

  const DeepStats({
    this.avgPnlPerMatch = 0,
    this.bestMatchPnl = 0,
    this.worstMatchPnl = 0,
    this.favoriteAsset,
    this.avgLeverage = 0,
    this.totalVolume = 0,
  });

  factory DeepStats.fromJson(Map<String, dynamic> json) {
    return DeepStats(
      avgPnlPerMatch: (json['avgPnlPerMatch'] as num?)?.toDouble() ?? 0,
      bestMatchPnl: (json['bestMatchPnl'] as num?)?.toDouble() ?? 0,
      worstMatchPnl: (json['worstMatchPnl'] as num?)?.toDouble() ?? 0,
      favoriteAsset: json['favoriteAsset'] as String?,
      avgLeverage: (json['avgLeverage'] as num?)?.toDouble() ?? 0,
      totalVolume: (json['totalVolume'] as num?)?.toDouble() ?? 0,
    );
  }
}

class MatchHistoryEntry {
  final String id;
  final String opponentAddress;
  final String opponentGamerTag;
  final String duration;
  final double betAmount;
  final String result;
  final double pnl;
  final int settledAt;

  const MatchHistoryEntry({
    required this.id,
    required this.opponentAddress,
    required this.opponentGamerTag,
    required this.duration,
    required this.betAmount,
    required this.result,
    required this.pnl,
    required this.settledAt,
  });

  factory MatchHistoryEntry.fromJson(Map<String, dynamic> json) {
    return MatchHistoryEntry(
      id: json['id'] as String,
      opponentAddress: json['opponentAddress'] as String,
      opponentGamerTag: json['opponentGamerTag'] as String,
      duration: json['duration'] as String? ?? '',
      betAmount: (json['betAmount'] as num?)?.toDouble() ?? 0,
      result: json['result'] as String,
      pnl: (json['pnl'] as num?)?.toDouble() ?? 0,
      settledAt: json['settledAt'] as int? ?? 0,
    );
  }
}

class ProfileState {
  final PlayerProfile? profile;
  final bool isLoading;
  final String? error;

  const ProfileState({
    this.profile,
    this.isLoading = false,
    this.error,
  });

  ProfileState copyWith({
    PlayerProfile? profile,
    bool? isLoading,
    String? error,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
