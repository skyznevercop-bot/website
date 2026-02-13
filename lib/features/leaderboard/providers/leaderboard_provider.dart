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
  Future<void> fetchLeaderboard({String sortBy = 'elo', int page = 1}) async {
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
          eloRating: p['eloRating'] as int,
          wins: p['wins'] as int,
          losses: p['losses'] as int,
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

  void recordMatchResult(String winnerId, String loserId) {
    final players = [...state.players];
    final winnerIdx = players.indexWhere((p) => p.id == winnerId);
    final loserIdx = players.indexWhere((p) => p.id == loserId);
    if (winnerIdx == -1 || loserIdx == -1) return;

    final winner = players[winnerIdx];
    final loser = players[loserIdx];

    final (newWinnerElo, newLoserElo) = EloCalculator.calculateNewRatings(
      winner.eloRating,
      loser.eloRating,
      1.0,
      gamesA: winner.gamesPlayed,
      gamesB: loser.gamesPlayed,
    );

    players[winnerIdx] = winner.copyWith(
      eloRating: newWinnerElo,
      wins: winner.wins + 1,
      streak: winner.streak + 1,
    );
    players[loserIdx] = loser.copyWith(
      eloRating: newLoserElo,
      losses: loser.losses + 1,
      streak: 0,
    );

    players.sort((a, b) => b.eloRating.compareTo(a.eloRating));

    state = state.copyWith(players: players);
  }
}

final leaderboardProvider =
    NotifierProvider<LeaderboardNotifier, LeaderboardState>(
        LeaderboardNotifier.new);
