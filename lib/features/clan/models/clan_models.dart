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

/// Mock clans for browsing.
final mockClans = [
  Clan(
    id: 'clan_1',
    name: 'Alpha Wolves',
    tag: 'AWLF',
    description: 'Top-tier competitive traders. Only the best survive.',
    memberCount: 47,
    maxMembers: 50,
    winRate: 72,
    totalWins: 180,
    totalLosses: 70,
    trophies: 58200,
    level: 14,
    clanWarWins: 126,
    requiredTrophies: 4000,
    isWarActive: true,
    members: [
      ClanMember(address: 'addr1', gamerTag: 'CryptoKing', role: ClanRole.leader, trophies: 6200, donations: 342, joinedAt: DateTime(2024, 6, 1)),
      ClanMember(address: 'addr2', gamerTag: 'SolSniper', role: ClanRole.coLeader, trophies: 5800, donations: 287, joinedAt: DateTime(2024, 6, 5)),
      ClanMember(address: 'addr3', gamerTag: 'DegenLord', role: ClanRole.coLeader, trophies: 5650, donations: 198, joinedAt: DateTime(2024, 6, 10)),
      ClanMember(address: 'addr4', gamerTag: 'MoonTrader', role: ClanRole.elder, trophies: 5200, donations: 256, joinedAt: DateTime(2024, 7, 1)),
      ClanMember(address: 'addr5', gamerTag: 'WhaleHunter', role: ClanRole.elder, trophies: 4900, donations: 178, joinedAt: DateTime(2024, 7, 15)),
      ClanMember(address: 'addr6', gamerTag: 'BullishAF', role: ClanRole.member, trophies: 4600, donations: 145, joinedAt: DateTime(2024, 8, 1)),
      ClanMember(address: 'addr7', gamerTag: 'DipBuyer', role: ClanRole.member, trophies: 4300, donations: 89, joinedAt: DateTime(2024, 9, 1)),
      ClanMember(address: 'addr8', gamerTag: 'PumpChaser', role: ClanRole.member, trophies: 4100, donations: 67, joinedAt: DateTime(2024, 10, 1)),
    ],
    warLog: [
      ClanWarResult(opponentName: 'DeFi Dynasty', opponentTag: 'DEFI', won: true, starsEarned: 42, starsOpponent: 31, date: DateTime(2025, 2, 8)),
      ClanWarResult(opponentName: 'Bear Hunters', opponentTag: 'BEAR', won: true, starsEarned: 38, starsOpponent: 35, date: DateTime(2025, 2, 5)),
      ClanWarResult(opponentName: 'Whale Watch', opponentTag: 'WHAL', won: false, starsEarned: 28, starsOpponent: 33, date: DateTime(2025, 2, 1)),
      ClanWarResult(opponentName: 'Moon Cartel', opponentTag: 'MOON', won: true, starsEarned: 45, starsOpponent: 22, date: DateTime(2025, 1, 28)),
    ],
    createdAt: DateTime(2024, 6, 1),
  ),
  Clan(
    id: 'clan_2',
    name: 'DeFi Dynasty',
    tag: 'DEFI',
    description: 'DeFi natives dominating the arena',
    memberCount: 42,
    maxMembers: 50,
    winRate: 68,
    totalWins: 136,
    totalLosses: 64,
    trophies: 51400,
    level: 12,
    clanWarWins: 98,
    requiredTrophies: 3500,
    isWarActive: true,
    createdAt: DateTime(2024, 7, 15),
  ),
  Clan(
    id: 'clan_3',
    name: 'SOL Snipers',
    tag: 'SNPR',
    description: 'Precision entries, maximum exits',
    memberCount: 50,
    maxMembers: 50,
    winRate: 65,
    totalWins: 260,
    totalLosses: 140,
    trophies: 49800,
    level: 13,
    clanWarWins: 112,
    requiredTrophies: 3000,
    isWarActive: false,
    createdAt: DateTime(2024, 5, 10),
  ),
  Clan(
    id: 'clan_4',
    name: 'Moon Cartel',
    tag: 'MOON',
    description: 'To the moon or bust',
    memberCount: 35,
    maxMembers: 50,
    winRate: 61,
    totalWins: 92,
    totalLosses: 59,
    trophies: 42100,
    level: 10,
    clanWarWins: 67,
    requiredTrophies: 2500,
    isWarActive: false,
    createdAt: DateTime(2024, 8, 20),
  ),
  Clan(
    id: 'clan_5',
    name: 'Bear Hunters',
    tag: 'BEAR',
    description: 'We thrive in bear markets',
    memberCount: 38,
    maxMembers: 50,
    winRate: 59,
    totalWins: 118,
    totalLosses: 82,
    trophies: 38600,
    level: 9,
    clanWarWins: 54,
    requiredTrophies: 2000,
    isWarActive: true,
    createdAt: DateTime(2024, 9, 5),
  ),
  Clan(
    id: 'clan_6',
    name: 'Whale Watch',
    tag: 'WHAL',
    description: 'Following the smart money',
    memberCount: 44,
    maxMembers: 50,
    winRate: 57,
    totalWins: 160,
    totalLosses: 121,
    trophies: 35200,
    level: 8,
    clanWarWins: 45,
    requiredTrophies: 1500,
    isWarActive: false,
    createdAt: DateTime(2024, 4, 12),
  ),
  Clan(
    id: 'clan_7',
    name: 'Degen Alliance',
    tag: 'DGEN',
    description: 'High risk, high reward traders',
    memberCount: 50,
    maxMembers: 50,
    winRate: 54,
    totalWins: 227,
    totalLosses: 193,
    trophies: 31800,
    level: 7,
    clanWarWins: 38,
    requiredTrophies: 1000,
    isWarActive: true,
    createdAt: DateTime(2024, 3, 1),
  ),
  Clan(
    id: 'clan_8',
    name: 'Crypto Samurai',
    tag: 'SMRI',
    description: 'Discipline is everything',
    memberCount: 22,
    maxMembers: 50,
    winRate: 63,
    totalWins: 63,
    totalLosses: 37,
    trophies: 28400,
    level: 6,
    clanWarWins: 29,
    requiredTrophies: 800,
    isWarActive: false,
    createdAt: DateTime(2024, 10, 1),
  ),
];
