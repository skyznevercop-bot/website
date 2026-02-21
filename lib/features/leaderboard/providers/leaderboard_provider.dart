import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_client.dart';
import '../models/leaderboard_models.dart';

class LeaderboardNotifier extends Notifier<LeaderboardState> {
  final _api = ApiClient.instance;
  StreamSubscription<Map<String, dynamic>>? _wsSubscription;
  Timer? _pollTimer;

  @override
  LeaderboardState build() {
    ref.onDispose(() {
      _wsSubscription?.cancel();
      _pollTimer?.cancel();
    });

    // Start real-time listeners and initial fetch.
    Future.microtask(() => _init());
    return const LeaderboardState(isLoading: true);
  }

  void _init() {
    // Listen for WebSocket events (leaderboard_update + reconnections).
    _wsSubscription?.cancel();
    _wsSubscription = _api.wsStream.listen(_handleWsEvent);

    // Initial fetch.
    fetchLeaderboard();

    // Poll every 30s as a fallback in case WebSocket events are missed.
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      fetchLeaderboard(silent: true);
    });
  }

  void _handleWsEvent(Map<String, dynamic> data) {
    switch (data['type']) {
      case 'leaderboard_update':
        // A match just settled — refresh the leaderboard.
        fetchLeaderboard(silent: true);
        break;
      case 'ws_connected':
        // WebSocket reconnected — refresh to catch anything missed.
        fetchLeaderboard(silent: true);
        break;
    }
  }

  /// Fetch leaderboard from the backend API.
  ///
  /// When [silent] is true, the loading spinner is not shown (used for
  /// background refreshes so the UI doesn't flash).
  Future<void> fetchLeaderboard({
    String sortBy = 'pnl',
    int page = 1,
    bool silent = false,
  }) async {
    if (!silent) {
      state = state.copyWith(isLoading: true);
    }

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
