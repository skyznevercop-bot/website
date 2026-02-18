import 'dart:async';
import 'dart:math';

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

  /// Live matches happening now.
  final List<LiveMatch> liveMatches;

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
    List<LiveMatch>? liveMatches,
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
      liveMatches: liveMatches ?? this.liveMatches,
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

  const LiveMatch({
    required this.player1,
    required this.player2,
    required this.duration,
    required this.player1Leading,
    this.bet = 0,
  });
}

class QueueNotifier extends Notifier<QueueState> {
  final _api = ApiClient.instance;
  StreamSubscription? _wsSubscription;
  Timer? _waitTimer;
  Timer? _pollTimer;
  Timer? _liveTimer;
  final _rng = Random();

  // Track whether we got real data from backend.
  bool _hasRealData = false;

  // Base demo stats — slowly increment over time.
  int _demoPlayers = 1247;
  int _demoMatches = 8432;
  double _demoVolume = 423500;

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

    // Seed demo data immediately so UI is never empty.
    // Real backend data will overwrite if/when it responds.
    if (!_hasRealData) _seedDemoData();

    // Try to fetch real data from backend.
    _fetchAll();

    // Poll queue stats every 10s as fallback.
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchAll();
    });

    // Refresh live demo data every 8s for a dynamic feel.
    _liveTimer?.cancel();
    _liveTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!_hasRealData) _refreshDemoData();
    });
  }

  Future<void> _fetchAll() async {
    await fetchQueueStats();
    await fetchLiveMatches();
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
    }
  }

  void _handleQueueStats(Map<String, dynamic> data) {
    final queues = data['queues'] as List<dynamic>?;
    if (queues == null) return;

    _hasRealData = true;

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

      _hasRealData = true;

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

      // Also grab platform stats if present.
      if (response['totalPlayers'] != null) {
        state = state.copyWith(
          totalPlayers: response['totalPlayers'] as int? ?? 0,
          totalMatches: response['totalMatches'] as int? ?? 0,
          totalVolume: (response['totalVolume'] as num?)?.toDouble() ?? 0,
        );
      }
    } catch (_) {
      // Backend unavailable — seed demo data if not already set.
      if (!_hasRealData && state.totalPlayers == 0) {
        _seedDemoData();
      }
    }
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

      _hasRealData = true;

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
          bet: (match['bet'] as num?)?.toDouble() ?? 0,
        );
      }).toList();

      state = state.copyWith(liveMatches: matches);
    } catch (_) {
      // Backend unavailable — seed demo matches if empty.
      if (!_hasRealData && state.liveMatches.isEmpty) {
        state = state.copyWith(liveMatches: _generateDemoMatches());
      }
    }
  }

  // ── Demo data (shown when backend is unavailable) ───────────────────────

  static const _demoTags = [
    'CryptoKing', 'SolSniper', 'DeFiDegen', 'AlphaSeeker',
    'MoonHunter', 'DiamondHands', 'WhaleWatch', 'FlipMaster',
    'PumpChaser', 'TokenSlayer', 'YieldFarmer', 'LiqHunter',
    'ApeMode', 'GigaBrain', 'Wagmi420', 'NightTrader',
    'BullRunner', 'ChartWizard', 'StackSats', 'Mev_Andy',
  ];

  static const _demoDurations = ['15m', '1h', '4h', '12h', '24h'];

  void _seedDemoData() {
    _demoPlayers = 1200 + _rng.nextInt(200);
    _demoMatches = 8000 + _rng.nextInt(1000);
    _demoVolume = 400000 + _rng.nextInt(100000).toDouble();

    state = state.copyWith(
      totalPlayers: _demoPlayers,
      totalMatches: _demoMatches,
      totalVolume: _demoVolume,
      queueSizes: _generateQueueSizes(),
      waitTimes: _generateWaitTimes(),
      liveMatches: _generateDemoMatches(),
    );
  }

  void _refreshDemoData() {
    // Small increments to feel live.
    if (_rng.nextBool()) _demoPlayers += _rng.nextInt(3);
    if (_rng.nextDouble() > 0.3) _demoMatches += _rng.nextInt(2) + 1;
    _demoVolume += (_rng.nextInt(50) + 10).toDouble();

    state = state.copyWith(
      totalPlayers: _demoPlayers,
      totalMatches: _demoMatches,
      totalVolume: _demoVolume,
      queueSizes: _generateQueueSizes(),
      waitTimes: _generateWaitTimes(),
      liveMatches: _generateDemoMatches(),
    );
  }

  List<int> _generateQueueSizes() {
    // 15m and 1h are most popular.
    return [
      3 + _rng.nextInt(8),  // 15m
      2 + _rng.nextInt(6),  // 1h
      1 + _rng.nextInt(4),  // 4h
      _rng.nextInt(3),       // 12h
      _rng.nextInt(2),       // 24h
    ];
  }

  List<String> _generateWaitTimes() {
    return [
      '~${5 + _rng.nextInt(15)}s',
      '~${10 + _rng.nextInt(20)}s',
      '~${30 + _rng.nextInt(30)}s',
      '~${1 + _rng.nextInt(3)}m',
      '~${2 + _rng.nextInt(5)}m',
    ];
  }

  List<LiveMatch> _generateDemoMatches() {
    final shuffled = List<String>.from(_demoTags)..shuffle(_rng);
    final count = 3 + _rng.nextInt(3); // 3-5 matches
    final bets = [5, 10, 25, 50, 100];

    return List.generate(count, (i) {
      return LiveMatch(
        player1: shuffled[i * 2],
        player2: shuffled[i * 2 + 1],
        duration: _demoDurations[_rng.nextInt(_demoDurations.length)],
        player1Leading: _rng.nextBool(),
        bet: bets[_rng.nextInt(bets.length)].toDouble(),
      );
    });
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
