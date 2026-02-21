import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_client.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../models/referral_models.dart';

/// Captures the ?ref= query parameter from the initial URL.
/// Read once on app start; cleared after applying.
class _PendingReferralNotifier extends Notifier<String?> {
  @override
  String? build() {
    try {
      return Uri.base.queryParameters['ref'];
    } catch (_) {
      return null;
    }
  }

  void clear() => state = null;
}

final pendingReferralCodeProvider =
    NotifierProvider<_PendingReferralNotifier, String?>(
        _PendingReferralNotifier.new);

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
          gamerTag: (r['gamerTag'] as String?) ?? 'Unknown',
          status: _parseStatus(r['status'] as String? ?? 'JOINED'),
          joinedAt: DateTime.fromMillisecondsSinceEpoch(
              (r['joinedAt'] as num?)?.toInt() ?? 0),
          gamesPlayed: (r['gamesPlayed'] as num?)?.toInt() ?? 0,
          rewardEarned: (r['rewardEarned'] as num?)?.toDouble() ?? 0,
        );
      }).toList();

      state = state.copyWith(
        referralCode: code,
        referredUsers: referrals,
        totalEarned: (response['totalEarned'] as num?)?.toDouble() ?? 0,
        referralBalance:
            (response['referralBalance'] as num?)?.toDouble() ?? 0,
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

  /// Claim pending referral rewards — moves referralBalance to main balance.
  Future<void> claimRewards() async {
    if (state.isClaiming || state.referralBalance <= 0) return;

    state = state.copyWith(isClaiming: true);

    try {
      final response = await _api.post('/referral/claim');
      final amount = (response['amount'] as num?)?.toDouble() ?? 0;

      if (amount > 0) {
        ref.read(walletProvider.notifier).addBalance(amount);
      }

      state = state.copyWith(
        isClaiming: false,
        totalEarned: state.totalEarned + amount,
        referralBalance: 0,
      );
    } catch (_) {
      state = state.copyWith(isClaiming: false);
    }
  }

  /// Apply a referral code (from URL ?ref= param) after wallet connects.
  Future<void> applyReferralCode(String code) async {
    if (!_api.hasToken || code.length != 8) return;

    try {
      await _api.post('/referral/apply', {'code': code.toUpperCase()});
      // Clear the pending code so it's not applied again.
      ref.read(pendingReferralCodeProvider.notifier).clear();
    } catch (_) {
      // Already referred or invalid code — silently ignore.
    }
  }

  static ReferralStatus _parseStatus(String status) {
    switch (status) {
      case 'PLAYED':
        return ReferralStatus.played;
      default:
        return ReferralStatus.joined;
    }
  }
}

final referralProvider =
    NotifierProvider<ReferralNotifier, ReferralState>(ReferralNotifier.new);
