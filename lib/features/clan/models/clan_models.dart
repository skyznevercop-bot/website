/// Role of a member within a clan.
enum ClanRole { leader, coLeader, elder, member }

/// A single clan member.
class ClanMember {
  final String address;
  final String gamerTag;
  final ClanRole role;
  final int trophies;
  final int donations;
  final DateTime joinedAt;

  const ClanMember({
    required this.address,
    required this.gamerTag,
    required this.role,
    this.trophies = 0,
    this.donations = 0,
    required this.joinedAt,
  });
}

/// A recent clan war result.
class ClanWarResult {
  final String opponentName;
  final String opponentTag;
  final bool won;
  final int starsEarned;
  final int starsOpponent;
  final DateTime date;

  const ClanWarResult({
    required this.opponentName,
    required this.opponentTag,
    required this.won,
    required this.starsEarned,
    required this.starsOpponent,
    required this.date,
  });
}

/// Represents a clan.
class Clan {
  final String id;
  final String name;
  final String tag; // 3-5 char abbreviation
  final String description;
  final String leaderAddress;
  final int memberCount;
  final int maxMembers;
  final int winRate;
  final int totalWins;
  final int totalLosses;
  final int trophies;
  final int level;
  final int clanWarWins;
  final int requiredTrophies;
  final bool isWarActive;
  final List<ClanMember> members;
  final List<ClanWarResult> warLog;
  final DateTime createdAt;

  const Clan({
    required this.id,
    required this.name,
    required this.tag,
    this.description = '',
    this.leaderAddress = '',
    required this.memberCount,
    this.maxMembers = 50,
    required this.winRate,
    this.totalWins = 0,
    this.totalLosses = 0,
    this.trophies = 0,
    this.level = 1,
    this.clanWarWins = 0,
    this.requiredTrophies = 0,
    this.isWarActive = false,
    this.members = const [],
    this.warLog = const [],
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
    int? trophies,
    int? level,
    int? clanWarWins,
    int? requiredTrophies,
    bool? isWarActive,
    List<ClanMember>? members,
    List<ClanWarResult>? warLog,
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
      trophies: trophies ?? this.trophies,
      level: level ?? this.level,
      clanWarWins: clanWarWins ?? this.clanWarWins,
      requiredTrophies: requiredTrophies ?? this.requiredTrophies,
      isWarActive: isWarActive ?? this.isWarActive,
      members: members ?? this.members,
      warLog: warLog ?? this.warLog,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// State of the clan feature.
class ClanState {
  final Clan? userClan;
  final List<Clan> browseClansList;
  final String searchQuery;
  final bool isLoading;
  final bool isCreating;
  final String? errorMessage;

  const ClanState({
    this.userClan,
    this.browseClansList = const [],
    this.searchQuery = '',
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
    bool? isLoading,
    bool? isCreating,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ClanState(
      userClan: clearUserClan ? null : (userClan ?? this.userClan),
      browseClansList: browseClansList ?? this.browseClansList,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
