import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_client.dart';
import '../models/leaderboard_models.dart';

class LeaderboardNotifier extends Notifier<LeaderboardState> {
  final _api = ApiClient.instance;

  @override
  LeaderboardState build() {
    return const LeaderboardState();
  }

  /// Fetch leaderboard from the backend API.
  Future<void> fetchLeaderboard({String sortBy = 'wins', int page = 1}) async {
    try {
      final response = await _api.get(
        '/leaderboard?sortBy=$sortBy&page=$page&limit=20',
      );

      final playersJson = response['players'] as List<dynamic>;
      final players = playersJson.map((json) {
        final p = json as Map<String, dynamic>;
        return LeaderboardPlayer(
          id: p['walletAddress'] as String,
          gamerTag: (p['gamerTag'] as String?) ??
              (p['walletAddress'] as String).substring(0, 8),
          wins: p['wins'] as int,
          losses: p['losses'] as int,
          ties: (p['ties'] as int?) ?? 0,
          pnl: (p['totalPnl'] as num).toDouble(),
          streak: p['currentStreak'] as int,
        );
      }).toList();

      state = state.copyWith(players: players);
    } catch (_) {
      // If API fails, keep existing data.
    }
  }

  void filterByPeriod(String period) {
    state = state.copyWith(selectedPeriod: period);
    fetchLeaderboard();
  }

  void filterByTimeframe(String timeframe) {
    state = state.copyWith(selectedTimeframe: timeframe);
    fetchLeaderboard();
  }
}

final leaderboardProvider =
    NotifierProvider<LeaderboardNotifier, LeaderboardState>(
        LeaderboardNotifier.new);
