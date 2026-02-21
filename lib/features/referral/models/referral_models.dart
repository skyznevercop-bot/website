/// Status of a referred user in the funnel.
enum ReferralStatus { joined, played }

/// A user referred via the referral program.
class ReferredUser {
  final String gamerTag;
  final ReferralStatus status;
  final DateTime joinedAt;
  final int gamesPlayed;
  final double rewardEarned;

  const ReferredUser({
    required this.gamerTag,
    required this.status,
    required this.joinedAt,
    this.gamesPlayed = 0,
    this.rewardEarned = 0,
  });
}

/// State of the referral feature.
class ReferralState {
  final String? referralCode;
  final List<ReferredUser> referredUsers;
  final double totalEarned;
  final double referralBalance;
  final bool isLoading;
  final bool isClaiming;

  const ReferralState({
    this.referralCode,
    this.referredUsers = const [],
    this.totalEarned = 0,
    this.referralBalance = 0,
    this.isLoading = false,
    this.isClaiming = false,
  });

  ReferralState copyWith({
    String? referralCode,
    List<ReferredUser>? referredUsers,
    double? totalEarned,
    double? referralBalance,
    bool? isLoading,
    bool? isClaiming,
  }) {
    return ReferralState(
      referralCode: referralCode ?? this.referralCode,
      referredUsers: referredUsers ?? this.referredUsers,
      totalEarned: totalEarned ?? this.totalEarned,
      referralBalance: referralBalance ?? this.referralBalance,
      isLoading: isLoading ?? this.isLoading,
      isClaiming: isClaiming ?? this.isClaiming,
    );
  }
}
