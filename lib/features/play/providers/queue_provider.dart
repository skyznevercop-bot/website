import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_client.dart';

/// Queue state for matchmaking.
class QueueState {
  /// Per-timeframe queue sizes (index matches AppConstants.timeframes).
  final List<int> queueSizes;

  /// Per-timeframe estimated wait times.
  final List<String> waitTimes;

  /// Whether the user is currently in a queue.
  final bool isInQueue;

  /// The timeframe index the user queued for.
  final int? queuedTimeframeIndex;

  /// Seconds spent waiting in queue.
  final int waitSeconds;

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

  /// Live matches happening now.
  final List<LiveMatch> liveMatches;

  const QueueState({
    this.queueSizes = const [0, 0, 0, 0, 0, 0],
    this.waitTimes = const ['--', '--', '--', '--', '--', '--'],
    this.isInQueue = false,
    this.queuedTimeframeIndex,
    this.waitSeconds = 0,
    this.matchFound,
    this.totalPlayers = 0,
    this.totalMatches = 0,
    this.totalVolume = 0,
    this.userWins = 0,
    this.userLosses = 0,
    this.userPnl = 0,
    this.liveMatches = const [],
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
    int? queuedTimeframeIndex,
    bool clearQueuedTimeframe = false,
    int? waitSeconds,
    MatchFoundData? matchFound,
    bool clearMatchFound = false,
    int? totalPlayers,
    int? totalMatches,
    double? totalVolume,
    int? userWins,
    int? userLosses,
    double? userPnl,
    List<LiveMatch>? liveMatches,
  }) {
    return QueueState(
      queueSizes: queueSizes ?? this.queueSizes,
      waitTimes: waitTimes ?? this.waitTimes,
      isInQueue: isInQueue ?? this.isInQueue,
      queuedTimeframeIndex: clearQueuedTimeframe
          ? null
          : (queuedTimeframeIndex ?? this.queuedTimeframeIndex),
      waitSeconds: waitSeconds ?? this.waitSeconds,
      matchFound:
          clearMatchFound ? null : (matchFound ?? this.matchFound),
      totalPlayers: totalPlayers ?? this.totalPlayers,
      totalMatches: totalMatches ?? this.totalMatches,
      totalVolume: totalVolume ?? this.totalVolume,
      userWins: userWins ?? this.userWins,
      userLosses: userLosses ?? this.userLosses,
      userPnl: userPnl ?? this.userPnl,
      liveMatches: liveMatches ?? this.liveMatches,
    );
  }
}

class MatchFoundData {
  final String matchId;
  final String opponentGamerTag;
  final String opponentAddress;
  final String timeframe;
  final double bet;

  const MatchFoundData({
    required this.matchId,
    required this.opponentGamerTag,
    required this.opponentAddress,
    required this.timeframe,
    required this.bet,
  });
}

class LiveMatch {
  final String player1;
  final String player2;
  final String timeframe;
  final bool player1Leading;

  const LiveMatch({
    required this.player1,
    required this.player2,
    required this.timeframe,
    required this.player1Leading,
  });
}

class QueueNotifier extends Notifier<QueueState> {
  final _api = ApiClient.instance;
  StreamSubscription? _wsSubscription;
  Timer? _waitTimer;
  Timer? _pollTimer;

  @override
  QueueState build() {
    ref.onDispose(() {
      _wsSubscription?.cancel();
      _waitTimer?.cancel();
      _pollTimer?.cancel();
    });
    return const QueueState();
  }

  /// Start listening for queue events and fetch initial data.
  void init() {
    _wsSubscription?.cancel();
    _wsSubscription = _api.wsStream.listen(_handleWsEvent);

    // Fetch initial data.
    fetchQueueStats();
    fetchLiveMatches();

    // Poll queue stats every 10s as fallback.
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      fetchQueueStats();
    });
  }

  /// Stop listening.
  void dispose() {
    _wsSubscription?.cancel();
    _waitTimer?.cancel();
    _pollTimer?.cancel();
  }

  void _handleWsEvent(Map<String, dynamic> data) {
    switch (data['type']) {
      case 'queue_stats':
        _handleQueueStats(data);
        break;
      case 'match_found':
        _handleMatchFound(data);
        break;
    }
  }

  void _handleQueueStats(Map<String, dynamic> data) {
    final queues = data['queues'] as List<dynamic>?;
    if (queues == null) return;

    final sizes = List<int>.filled(6, 0);
    final waits = List<String>.filled(6, '--');

    for (final q in queues) {
      final queue = q as Map<String, dynamic>;
      final index = queue['index'] as int?;
      if (index != null && index >= 0 && index < 6) {
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
      clearQueuedTimeframe: true,
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
        timeframe: data['timeframe'] as String? ?? '',
        bet: (data['bet'] as num?)?.toDouble() ?? 0,
      ),
    );
  }

  /// Join the matchmaking queue.
  void joinQueue({
    required int timeframeIndex,
    required String timeframeLabel,
    required double betAmount,
  }) {
    if (state.isInQueue) return;

    state = state.copyWith(
      isInQueue: true,
      queuedTimeframeIndex: timeframeIndex,
      waitSeconds: 0,
      clearMatchFound: true,
    );

    _api.wsSend({
      'type': 'join_queue',
      'timeframe': timeframeLabel,
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
    _api.wsSend({'type': 'leave_queue'});

    state = state.copyWith(
      isInQueue: false,
      clearQueuedTimeframe: true,
      waitSeconds: 0,
    );
  }

  /// Clear the match found data after navigating to arena.
  void clearMatchFound() {
    state = state.copyWith(clearMatchFound: true);
  }

  /// Fetch queue stats from the REST API.
  Future<void> fetchQueueStats() async {
    try {
      final response = await _api.get('/queue/stats');
      final queues = response['queues'] as List<dynamic>?;
      if (queues == null) return;

      final sizes = List<int>.filled(6, 0);
      final waits = List<String>.filled(6, '--');

      for (final q in queues) {
        final queue = q as Map<String, dynamic>;
        final index = queue['index'] as int?;
        if (index != null && index >= 0 && index < 6) {
          sizes[index] = queue['size'] as int? ?? 0;
          final avgWait = queue['avgWaitSeconds'] as int?;
          waits[index] = avgWait != null ? _formatWait(avgWait) : '--';
        }
      }

      state = state.copyWith(queueSizes: sizes, waitTimes: waits);

      // Also grab platform stats if present.
      if (response['totalPlayers'] != null) {
        state = state.copyWith(
          totalPlayers: response['totalPlayers'] as int? ?? 0,
          totalMatches: response['totalMatches'] as int? ?? 0,
          totalVolume: (response['totalVolume'] as num?)?.toDouble() ?? 0,
        );
      }
    } catch (_) {}
  }

  /// Fetch user stats from the backend.
  Future<void> fetchUserStats(String address) async {
    try {
      final response = await _api.get('/user/$address');
      state = state.copyWith(
        userWins: response['wins'] as int? ?? 0,
        userLosses: response['losses'] as int? ?? 0,
        userPnl: (response['totalPnl'] as num?)?.toDouble() ?? 0,
      );
    } catch (_) {}
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
          timeframe: match['timeframe'] as String? ?? '',
          player1Leading: (match['player1Pnl'] as num?)?.toDouble() !=
                  null &&
              ((match['player1Pnl'] as num?)?.toDouble() ?? 0) >=
                  ((match['player2Pnl'] as num?)?.toDouble() ?? 0),
        );
      }).toList();

      state = state.copyWith(liveMatches: matches);
    } catch (_) {}
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
