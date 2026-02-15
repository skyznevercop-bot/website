import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_client.dart';
import '../models/leaderboard_models.dart';

class LeaderboardNotifier extends Notifier<LeaderboardState> {
  final _api = ApiClient.instance;

  @override
  LeaderboardState build() {
    // Auto-load leaderboard data on first access.
    Future.microtask(() => fetchLeaderboard());
    return const LeaderboardState(isLoading: true);
  }

  /// Fetch leaderboard from the backend API.
  Future<void> fetchLeaderboard({String sortBy = 'wins', int page = 1}) async {
    state = state.copyWith(isLoading: true);

    try {
      final response = await _api.get(
        '/leaderboard?sortBy=$sortBy&page=$page&limit=50',
      );

      final playersJson = response['players'] as List<dynamic>? ?? [];
      final players = playersJson.map((json) {
        final p = json as Map<String, dynamic>;
        return LeaderboardPlayer(
          id: p['walletAddress'] as String,
          gamerTag: (p['gamerTag'] as String?) ??
              _shortenAddress(p['walletAddress'] as String),
          wins: (p['wins'] as int?) ?? 0,
          losses: (p['losses'] as int?) ?? 0,
          ties: (p['ties'] as int?) ?? 0,
          pnl: (p['totalPnl'] as num?)?.toDouble() ?? 0,
          streak: (p['currentStreak'] as int?) ?? 0,
        );
      }).toList();

      state = state.copyWith(players: players, isLoading: false);
    } catch (_) {
      // If API fails, stop loading and keep existing data.
      state = state.copyWith(isLoading: false);
    }
  }

  /// Sort by a different metric and re-fetch.
  void sortBy(String metric) {
    fetchLeaderboard(sortBy: metric);
  }

  void filterByPeriod(String period) {
    state = state.copyWith(selectedPeriod: period);
    fetchLeaderboard();
  }

  void filterByTimeframe(String timeframe) {
    state = state.copyWith(selectedTimeframe: timeframe);
    fetchLeaderboard();
  }

  static String _shortenAddress(String address) {
    if (address.length <= 8) return address;
    return '${address.substring(0, 4)}..${address.substring(address.length - 4)}';
  }
}

final leaderboardProvider =
    NotifierProvider<LeaderboardNotifier, LeaderboardState>(
        LeaderboardNotifier.new);
