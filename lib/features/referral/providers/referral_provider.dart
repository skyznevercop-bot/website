import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_client.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../models/referral_models.dart';

class ReferralNotifier extends Notifier<ReferralState> {
  final _api = ApiClient.instance;

  @override
  ReferralState build() => const ReferralState();

  /// Fetch referral data from the backend.
  Future<void> fetchReferralStats() async {
    if (!_api.hasToken) return;

    state = state.copyWith(isLoading: true);

    try {
      final response = await _api.get('/referral/stats');

      final code = response['code'] as String;
      final referralsJson = response['referrals'] as List<dynamic>;
      final referrals = referralsJson.map((json) {
        final r = json as Map<String, dynamic>;
        return ReferredUser(
          gamerTag: r['gamerTag'] as String,
          status: _parseStatus(r['status'] as String),
          joinedAt: DateTime.parse(r['joinedAt'] as String),
          rewardEarned: (r['rewardEarned'] as num).toDouble(),
        );
      }).toList();

      state = state.copyWith(
        referralCode: code,
        referredUsers: referrals,
        totalEarned: (response['totalEarned'] as num).toDouble(),
        pendingReward: (response['pendingReward'] as num).toDouble(),
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Generate a referral code from the wallet address (first4 + last4).
  void generateCode(String walletAddress) {
    if (walletAddress.length < 8) return;
    final code =
        '${walletAddress.substring(0, 4)}${walletAddress.substring(walletAddress.length - 4)}';
    state = state.copyWith(referralCode: code.toUpperCase());
    fetchReferralStats();
  }

  /// Claim pending referral rewards.
  Future<void> claimRewards() async {
    if (state.isClaiming || state.pendingReward <= 0) return;

    state = state.copyWith(isClaiming: true);

    try {
      await _api.post('/referral/claim');

      final amount = state.pendingReward;
      ref.read(walletProvider.notifier).addBalance(amount);

      state = state.copyWith(
        isClaiming: false,
        totalEarned: state.totalEarned + amount,
        pendingReward: 0,
      );
    } catch (_) {
      state = state.copyWith(isClaiming: false);
    }
  }

  static ReferralStatus _parseStatus(String status) {
    switch (status) {
      case 'PLAYED':
        return ReferralStatus.played;
      case 'DEPOSITED':
        return ReferralStatus.deposited;
      default:
        return ReferralStatus.joined;
    }
  }
}

final referralProvider =
    NotifierProvider<ReferralNotifier, ReferralState>(ReferralNotifier.new);
