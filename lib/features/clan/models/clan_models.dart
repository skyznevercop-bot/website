/// Role of a member within a clan.
enum ClanRole { leader, coLeader, elder, member }

/// A single clan member with real trading stats.
class ClanMember {
  final String address;
  final String gamerTag;
  final ClanRole role;
  final int wins;
  final int losses;
  final int ties;
  final double totalPnl;
  final int currentStreak;
  final int gamesPlayed;
  final DateTime joinedAt;

  const ClanMember({
    required this.address,
    required this.gamerTag,
    required this.role,
    this.wins = 0,
    this.losses = 0,
    this.ties = 0,
    this.totalPnl = 0,
    this.currentStreak = 0,
    this.gamesPlayed = 0,
    required this.joinedAt,
  });

  double get winRate => gamesPlayed > 0 ? (wins / gamesPlayed * 100) : 0;
}

/// Represents a clan with aggregated stats computed from member data.
class Clan {
  final String id;
  final String name;
  final String tag;
  final String description;
  final String leaderAddress;
  final int memberCount;
  final int maxMembers;
  final int winRate;
  final int totalWins;
  final int totalLosses;
  final int totalTies;
  final double totalPnl;
  final int totalGamesPlayed;
  final int bestStreak;
  final List<ClanMember> members;
  final DateTime createdAt;

  const Clan({
    required this.id,
    required this.name,
    required this.tag,
    this.description = '',
    this.leaderAddress = '',
    required this.memberCount,
    this.maxMembers = 50,
    this.winRate = 0,
    this.totalWins = 0,
    this.totalLosses = 0,
    this.totalTies = 0,
    this.totalPnl = 0,
    this.totalGamesPlayed = 0,
    this.bestStreak = 0,
    this.members = const [],
    required this.createdAt,
  });

  Clan copyWith({
    String? id,
    String? name,
    String? tag,
    String? description,
    String? leaderAddress,
    int? memberCount,
    int? maxMembers,
    int? winRate,
    int? totalWins,
    int? totalLosses,
    int? totalTies,
    double? totalPnl,
    int? totalGamesPlayed,
    int? bestStreak,
    List<ClanMember>? members,
    DateTime? createdAt,
  }) {
    return Clan(
      id: id ?? this.id,
      name: name ?? this.name,
      tag: tag ?? this.tag,
      description: description ?? this.description,
      leaderAddress: leaderAddress ?? this.leaderAddress,
      memberCount: memberCount ?? this.memberCount,
      maxMembers: maxMembers ?? this.maxMembers,
      winRate: winRate ?? this.winRate,
      totalWins: totalWins ?? this.totalWins,
      totalLosses: totalLosses ?? this.totalLosses,
      totalTies: totalTies ?? this.totalTies,
      totalPnl: totalPnl ?? this.totalPnl,
      totalGamesPlayed: totalGamesPlayed ?? this.totalGamesPlayed,
      bestStreak: bestStreak ?? this.bestStreak,
      members: members ?? this.members,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// State of the clan feature.
class ClanState {
  final Clan? userClan;
  final List<Clan> browseClansList;
  final String searchQuery;
  final String sortBy;
  final bool isLoading;
  final bool isCreating;
  final String? errorMessage;

  const ClanState({
    this.userClan,
    this.browseClansList = const [],
    this.searchQuery = '',
    this.sortBy = 'winRate',
    this.isLoading = false,
    this.isCreating = false,
    this.errorMessage,
  });

  bool get hasClan => userClan != null;

  ClanState copyWith({
    Clan? userClan,
    bool clearUserClan = false,
    List<Clan>? browseClansList,
    String? searchQuery,
    String? sortBy,
    bool? isLoading,
    bool? isCreating,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ClanState(
      userClan: clearUserClan ? null : (userClan ?? this.userClan),
      browseClansList: browseClansList ?? this.browseClansList,
      searchQuery: searchQuery ?? this.searchQuery,
      sortBy: sortBy ?? this.sortBy,
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
