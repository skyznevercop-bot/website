/// A friend with their trading stats.
class Friend {
  final String address;
  final String gamerTag;
  final int wins;
  final int losses;
  final int ties;
  final double totalPnl;
  final int currentStreak;
  final int gamesPlayed;
  final String connectedSince;

  const Friend({
    required this.address,
    required this.gamerTag,
    this.wins = 0,
    this.losses = 0,
    this.ties = 0,
    this.totalPnl = 0,
    this.currentStreak = 0,
    this.gamesPlayed = 0,
    this.connectedSince = '',
  });

  double get winRate => gamesPlayed > 0 ? (wins / gamesPlayed * 100) : 0;

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      address: json['address'] as String,
      gamerTag: (json['gamerTag'] as String?) ?? json['address'].toString().substring(0, 8),
      wins: (json['wins'] as int?) ?? 0,
      losses: (json['losses'] as int?) ?? 0,
      ties: (json['ties'] as int?) ?? 0,
      totalPnl: ((json['totalPnl'] as num?) ?? 0).toDouble(),
      currentStreak: (json['currentStreak'] as int?) ?? 0,
      gamesPlayed: (json['gamesPlayed'] as int?) ?? 0,
      connectedSince: (json['connectedSince'] as String?) ?? '',
    );
  }
}

/// An incoming friend request.
class FriendRequest {
  final String fromAddress;
  final String fromGamerTag;
  final String createdAt;

  const FriendRequest({
    required this.fromAddress,
    required this.fromGamerTag,
    required this.createdAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      fromAddress: json['fromAddress'] as String,
      fromGamerTag: (json['fromGamerTag'] as String?) ?? json['fromAddress'].toString().substring(0, 8),
      createdAt: (json['createdAt'] as String?) ?? '',
    );
  }
}

/// A challenge (sent or received).
class Challenge {
  final String id;
  final String from;
  final String to;
  final String? fromGamerTag;
  final String? toGamerTag;
  final String duration;
  final double bet;
  final String status;
  final int? expiresAt;
  final String? matchId;

  const Challenge({
    required this.id,
    required this.from,
    required this.to,
    this.fromGamerTag,
    this.toGamerTag,
    required this.duration,
    required this.bet,
    required this.status,
    this.expiresAt,
    this.matchId,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id'] as String,
      from: json['from'] as String,
      to: json['to'] as String,
      fromGamerTag: json['fromGamerTag'] as String?,
      toGamerTag: json['toGamerTag'] as String?,
      duration: json['duration'] as String,
      bet: ((json['bet'] as num?) ?? 0).toDouble(),
      status: (json['status'] as String?) ?? 'pending',
      expiresAt: json['expiresAt'] as int?,
      matchId: json['matchId'] as String?,
    );
  }

  bool get isExpired =>
      expiresAt != null && DateTime.now().millisecondsSinceEpoch >= expiresAt!;

  Duration get timeRemaining {
    if (expiresAt == null) return Duration.zero;
    final ms = expiresAt! - DateTime.now().millisecondsSinceEpoch;
    return ms > 0 ? Duration(milliseconds: ms) : Duration.zero;
  }
}

/// State for the friends feature.
class FriendsState {
  final List<Friend> friends;
  final List<FriendRequest> incomingRequests;
  final List<Challenge> sentChallenges;
  final List<Challenge> receivedChallenges;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const FriendsState({
    this.friends = const [],
    this.incomingRequests = const [],
    this.sentChallenges = const [],
    this.receivedChallenges = const [],
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  FriendsState copyWith({
    List<Friend>? friends,
    List<FriendRequest>? incomingRequests,
    List<Challenge>? sentChallenges,
    List<Challenge>? receivedChallenges,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return FriendsState(
      friends: friends ?? this.friends,
      incomingRequests: incomingRequests ?? this.incomingRequests,
      sentChallenges: sentChallenges ?? this.sentChallenges,
      receivedChallenges: receivedChallenges ?? this.receivedChallenges,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }

  int get requestCount => incomingRequests.length;
  int get challengeCount => receivedChallenges.length;
}
