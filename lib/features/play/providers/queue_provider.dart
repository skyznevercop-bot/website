import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_client.dart';

/// Search phase for matchmaking animation states.
enum SearchPhase {
  idle,       // Not searching
  scanning,   // In queue, searching for opponent
  found,      // Match found, showing face-off
}

/// Queue state for matchmaking.
class QueueState {
  /// Per-duration queue sizes (index matches AppConstants.durations).
  final List<int> queueSizes;

  /// Per-duration estimated wait times.
  final List<String> waitTimes;

  /// Whether the user is currently in a queue.
  final bool isInQueue;

  /// The duration index the user queued for.
  final int? queuedDurationIndex;

  /// Duration label and bet amount for the active queue entry (used by leaveQueue).
  final String? queuedDurationLabel;
  final double? queuedBet;

  /// Seconds spent waiting in queue.
  final int waitSeconds;

  /// Current search phase for animation.
  final SearchPhase searchPhase;

  /// When a match is found.
  final MatchFoundData? matchFound;

  /// Platform stats for the hero section.
  final int totalPlayers;
  final int totalMatches;
  final double totalVolume;

  /// User stats (fetched from backend).
  final int userWins;
  final int userLosses;
  final double userPnl;

  /// Online player count (from WS connections).
  final int onlinePlayers;

  /// User's leaderboard rank (null if unranked).
  final int? userRank;
  final int rankTotal;

  /// Live matches happening now.
  final List<LiveMatch> liveMatches;

  /// Recent match results for lobby display.
  final List<RecentMatchResult> recentMatches;

  /// Whether initial data has been loaded from the backend.
  final bool isLoaded;

  const QueueState({
    this.queueSizes = const [0, 0, 0, 0, 0],
    this.waitTimes = const ['--', '--', '--', '--', '--'],
    this.isInQueue = false,
    this.searchPhase = SearchPhase.idle,
    this.queuedDurationIndex,
    this.queuedDurationLabel,
    this.queuedBet,
    this.waitSeconds = 0,
    this.matchFound,
    this.totalPlayers = 0,
    this.totalMatches = 0,
    this.totalVolume = 0,
    this.userWins = 0,
    this.userLosses = 0,
    this.userPnl = 0,
    this.onlinePlayers = 0,
    this.userRank,
    this.rankTotal = 0,
    this.liveMatches = const [],
    this.recentMatches = const [],
    this.isLoaded = false,
  });

  int get userGamesPlayed => userWins + userLosses;

  int get userWinRate {
    if (userGamesPlayed == 0) return 0;
    return ((userWins / userGamesPlayed) * 100).round();
  }

  QueueState copyWith({
    List<int>? queueSizes,
    List<String>? waitTimes,
    bool? isInQueue,
    SearchPhase? searchPhase,
    int? queuedDurationIndex,
    String? queuedDurationLabel,
    double? queuedBet,
    bool clearQueuedDuration = false,
    int? waitSeconds,
    MatchFoundData? matchFound,
    bool clearMatchFound = false,
    int? totalPlayers,
    int? totalMatches,
    double? totalVolume,
    int? userWins,
    int? userLosses,
    double? userPnl,
    int? onlinePlayers,
    int? userRank,
    bool clearUserRank = false,
    int? rankTotal,
    List<LiveMatch>? liveMatches,
    List<RecentMatchResult>? recentMatches,
    bool? isLoaded,
  }) {
    return QueueState(
      queueSizes: queueSizes ?? this.queueSizes,
      waitTimes: waitTimes ?? this.waitTimes,
      isInQueue: isInQueue ?? this.isInQueue,
      searchPhase: searchPhase ?? this.searchPhase,
      queuedDurationIndex: clearQueuedDuration
          ? null
          : (queuedDurationIndex ?? this.queuedDurationIndex),
      queuedDurationLabel: clearQueuedDuration
          ? null
          : (queuedDurationLabel ?? this.queuedDurationLabel),
      queuedBet: clearQueuedDuration
          ? null
          : (queuedBet ?? this.queuedBet),
      waitSeconds: waitSeconds ?? this.waitSeconds,
      matchFound:
          clearMatchFound ? null : (matchFound ?? this.matchFound),
      totalPlayers: totalPlayers ?? this.totalPlayers,
      totalMatches: totalMatches ?? this.totalMatches,
      totalVolume: totalVolume ?? this.totalVolume,
      userWins: userWins ?? this.userWins,
      userLosses: userLosses ?? this.userLosses,
      userPnl: userPnl ?? this.userPnl,
      onlinePlayers: onlinePlayers ?? this.onlinePlayers,
      userRank: clearUserRank ? null : (userRank ?? this.userRank),
      rankTotal: rankTotal ?? this.rankTotal,
      liveMatches: liveMatches ?? this.liveMatches,
      recentMatches: recentMatches ?? this.recentMatches,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}

class MatchFoundData {
  final String matchId;
  final String opponentGamerTag;
  final String opponentAddress;
  final String duration;
  final double bet;
  final int? startTime;
  final int? endTime;

  const MatchFoundData({
    required this.matchId,
    required this.opponentGamerTag,
    required this.opponentAddress,
    required this.duration,
    required this.bet,
    this.startTime,
    this.endTime,
  });
}

class LiveMatch {
  final String player1;
  final String player2;
  final String duration;
  final bool player1Leading;
  final double bet;
  final int? endTime;
  final int? startTime;

  const LiveMatch({
    required this.player1,
    required this.player2,
    required this.duration,
    required this.player1Leading,
    this.bet = 0,
    this.endTime,
    this.startTime,
  });
}

class RecentMatchResult {
  final String opponentGamerTag;
  final String result; // 'WIN', 'LOSS', 'TIE'
  final double pnl;
  final String duration;
  final double betAmount;
  final int settledAt;

  const RecentMatchResult({
    required this.opponentGamerTag,
    required this.result,
    required this.pnl,
    required this.duration,
    required this.betAmount,
    required this.settledAt,
  });
}

class QueueNotifier extends Notifier<QueueState> {
  final _api = ApiClient.instance;
  StreamSubscription? _wsSubscription;
  Timer? _waitTimer;
  Timer? _pollTimer;
  Timer? _liveTimer;

  @override
  QueueState build() {
    ref.onDispose(() {
      _wsSubscription?.cancel();
      _waitTimer?.cancel();
      _pollTimer?.cancel();
      _liveTimer?.cancel();
    });
    return const QueueState();
  }

  /// Start listening for queue events and fetch initial data.
  void init() {
    _wsSubscription?.cancel();
    _wsSubscription = _api.wsStream.listen(_handleWsEvent);

    // Fetch real data from backend.
    _fetchAll();

    // Poll queue stats every 10s as fallback.
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchAll();
    });

    // Refresh live matches every 15s.
    _liveTimer?.cancel();
    _liveTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      fetchLiveMatches();
    });
  }

  Future<void> _fetchAll() async {
    await fetchQueueStats();
    await fetchLiveMatches();
    if (!state.isLoaded) {
      state = state.copyWith(isLoaded: true);
    }
  }

  /// Stop listening.
  void dispose() {
    _wsSubscription?.cancel();
    _waitTimer?.cancel();
    _pollTimer?.cancel();
    _liveTimer?.cancel();
  }

  void _handleWsEvent(Map<String, dynamic> data) {
    switch (data['type']) {
      case 'ws_connected':
        // WS reconnected — re-join queue if we were in one.
        // This handles two cases:
        //   1. joinQueue() was called before WS was OPEN (message was dropped).
        //   2. WS dropped and reconnected while player was searching.
        if (state.isInQueue &&
            state.queuedDurationLabel != null &&
            state.queuedBet != null) {
          _api.wsSend({
            'type': 'join_queue',
            'duration': state.queuedDurationLabel!,
            'bet': state.queuedBet!,
          });
        }
        break;
      case 'queue_stats':
        _handleQueueStats(data);
        break;
      case 'match_found':
        _handleMatchFound(data);
        break;
      case 'error':
        // If we're in queue and get an error, the join likely failed.
        // Reset state so user sees the failure instead of spinning forever.
        if (state.isInQueue) {
          _waitTimer?.cancel();
          state = state.copyWith(
            isInQueue: false,
            searchPhase: SearchPhase.idle,
            clearQueuedDuration: true,
            waitSeconds: 0,
          );
        }
        break;
    }
  }

  void _handleQueueStats(Map<String, dynamic> data) {
    final queues = data['queues'] as List<dynamic>?;
    if (queues == null) return;

    final count = AppConstants.durations.length;
    final sizes = List<int>.filled(count, 0);
    final waits = List<String>.filled(count, '--');

    for (final q in queues) {
      final queue = q as Map<String, dynamic>;
      final index = queue['index'] as int?;
      if (index != null && index >= 0 && index < count) {
        sizes[index] = queue['size'] as int? ?? 0;
        final avgWait = queue['avgWaitSeconds'] as int?;
        waits[index] = avgWait != null ? _formatWait(avgWait) : '--';
      }
    }

    state = state.copyWith(queueSizes: sizes, waitTimes: waits);
  }

  void _handleMatchFound(Map<String, dynamic> data) {
    _waitTimer?.cancel();
    state = state.copyWith(
      isInQueue: false,
      searchPhase: SearchPhase.found,
      clearQueuedDuration: true,
      waitSeconds: 0,
      matchFound: MatchFoundData(
        matchId: data['matchId'] as String,
        opponentGamerTag:
            (data['opponent'] as Map<String, dynamic>?)?['gamerTag']
                    as String? ??
                'Opponent',
        opponentAddress:
            (data['opponent'] as Map<String, dynamic>?)?['address']
                    as String? ??
                '',
        duration: data['duration'] as String? ?? '',
        bet: (data['bet'] as num?)?.toDouble() ?? 0,
        startTime: (data['startTime'] as num?)?.toInt(),
        endTime: (data['endTime'] as num?)?.toInt(),
      ),
    );
  }

  /// Join the matchmaking queue.
  void joinQueue({
    required int durationIndex,
    required String durationLabel,
    required double betAmount,
  }) {
    if (state.isInQueue) return;

    state = state.copyWith(
      isInQueue: true,
      searchPhase: SearchPhase.scanning,
      queuedDurationIndex: durationIndex,
      queuedDurationLabel: durationLabel,
      queuedBet: betAmount,
      waitSeconds: 0,
      clearMatchFound: true,
    );

    _api.wsSend({
      'type': 'join_queue',
      'duration': durationLabel,
      'bet': betAmount,
    });

    // Track wait time.
    _waitTimer?.cancel();
    _waitTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(waitSeconds: state.waitSeconds + 1);
    });
  }

  /// Leave the matchmaking queue.
  void leaveQueue() {
    if (!state.isInQueue) return;

    _waitTimer?.cancel();
    _api.wsSend({
      'type': 'leave_queue',
      'duration': state.queuedDurationLabel,
      'bet': state.queuedBet,
    });

    state = state.copyWith(
      isInQueue: false,
      searchPhase: SearchPhase.idle,
      clearQueuedDuration: true,
      waitSeconds: 0,
    );
  }

  /// Clear the match found data after navigating to arena.
  void clearMatchFound() {
    state = state.copyWith(clearMatchFound: true);
  }

  /// Set match found data externally (e.g. from challenge accept response).
  void setMatchFound(MatchFoundData data) {
    state = state.copyWith(
      isInQueue: false,
      searchPhase: SearchPhase.found,
      matchFound: data,
    );
  }

  /// Reset search phase to idle (after navigation or cancel).
  void resetSearchPhase() {
    state = state.copyWith(searchPhase: SearchPhase.idle);
  }

  /// Fetch queue stats from the REST API.
  Future<void> fetchQueueStats() async {
    try {
      final response = await _api.get('/queue/stats');
      final queues = response['queues'] as List<dynamic>?;
      if (queues == null) return;

      final count = AppConstants.durations.length;
      final sizes = List<int>.filled(count, 0);
      final waits = List<String>.filled(count, '--');

      for (final q in queues) {
        final queue = q as Map<String, dynamic>;
        final index = queue['index'] as int?;
        if (index != null && index >= 0 && index < count) {
          sizes[index] = queue['size'] as int? ?? 0;
          final avgWait = queue['avgWaitSeconds'] as int?;
          waits[index] = avgWait != null ? _formatWait(avgWait) : '--';
        }
      }

      state = state.copyWith(queueSizes: sizes, waitTimes: waits);

      // Platform stats from backend.
      if (response['totalPlayers'] != null) {
        state = state.copyWith(
          totalPlayers: response['totalPlayers'] as int? ?? 0,
          totalMatches: response['totalMatches'] as int? ?? 0,
          totalVolume: (response['totalVolume'] as num?)?.toDouble() ?? 0,
        );
      }

      // Online player count from WS connections.
      final online = response['onlinePlayers'] as int?;
      if (online != null) {
        state = state.copyWith(onlinePlayers: online);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Queue] fetchQueueStats failed: $e');
    }
  }

  /// Fetch user stats and rank from the backend.
  Future<void> fetchUserStats(String address) async {
    try {
      final responses = await Future.wait([
        _api.get('/user/$address'),
        _api.get('/leaderboard/rank/$address'),
      ]);
      final userResp = responses[0];
      final rankResp = responses[1];
      state = state.copyWith(
        userWins: userResp['wins'] as int? ?? 0,
        userLosses: userResp['losses'] as int? ?? 0,
        userPnl: (userResp['totalPnl'] as num?)?.toDouble() ?? 0,
        userRank: rankResp['rank'] as int?,
        clearUserRank: rankResp['rank'] == null,
        rankTotal: rankResp['total'] as int? ?? 0,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Queue] fetchUserStats failed: $e');
    }
    // Fetch recent matches separately (non-blocking).
    fetchRecentMatches(address);
  }

  /// Fetch the user's last 5 match results for the lobby display.
  Future<void> fetchRecentMatches(String address) async {
    try {
      final response = await _api.get('/match/history/$address?limit=5');
      final matchesJson = response['matches'] as List<dynamic>?;
      if (matchesJson == null) return;

      final matches = matchesJson.map((m) {
        final match = m as Map<String, dynamic>;
        return RecentMatchResult(
          opponentGamerTag: match['opponentGamerTag'] as String? ?? '???',
          result: match['result'] as String? ?? 'TIE',
          pnl: (match['pnl'] as num?)?.toDouble() ?? 0,
          duration: match['duration'] as String? ?? '',
          betAmount: (match['betAmount'] as num?)?.toDouble() ?? 0,
          settledAt: (match['settledAt'] as num?)?.toInt() ?? 0,
        );
      }).toList();

      state = state.copyWith(recentMatches: matches);
    } catch (e) {
      if (kDebugMode) debugPrint('[Queue] fetchRecentMatches failed: $e');
    }
  }

  /// Fetch live matches from the backend.
  Future<void> fetchLiveMatches() async {
    try {
      final response = await _api.get('/match/active/list');
      final matchesJson = response['matches'] as List<dynamic>?;
      if (matchesJson == null) return;

      final matches = matchesJson.take(5).map((m) {
        final match = m as Map<String, dynamic>;
        return LiveMatch(
          player1: match['player1GamerTag'] as String? ?? '???',
          player2: match['player2GamerTag'] as String? ?? '???',
          duration: match['duration'] as String? ?? '',
          player1Leading: (match['player1Pnl'] as num?)?.toDouble() !=
                  null &&
              ((match['player1Pnl'] as num?)?.toDouble() ?? 0) >=
                  ((match['player2Pnl'] as num?)?.toDouble() ?? 0),
          bet: (match['bet'] as num?)?.toDouble() ??
              (match['betAmount'] as num?)?.toDouble() ?? 0,
          endTime: (match['endTime'] as num?)?.toInt(),
          startTime: (match['startTime'] as num?)?.toInt(),
        );
      }).toList();

      state = state.copyWith(liveMatches: matches);
    } catch (e) {
      if (kDebugMode) debugPrint('[Queue] fetchLiveMatches failed: $e');
    }
  }

  static String _formatWait(int seconds) {
    if (seconds < 60) return '~${seconds}s';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '~${minutes}m';
    return '~${minutes ~/ 60}h';
  }
}

final queueProvider =
    NotifierProvider<QueueNotifier, QueueState>(QueueNotifier.new);
