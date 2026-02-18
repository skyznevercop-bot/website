import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_client.dart';
import '../models/trading_models.dart';
import '../utils/arena_helpers.dart';
import 'price_feed_provider.dart';

/// State for the entire trading arena session.
class TradingState {
  final int selectedAssetIndex;
  final Map<String, double> currentPrices;
  final List<Position> positions;
  final double balance;
  final int matchTimeRemainingSeconds;
  final bool matchActive;
  final double initialBalance;
  final String? matchId;
  final String? opponentAddress;
  final String? opponentGamerTag;
  final double opponentPnl;
  final double opponentEquity;
  final int opponentPositionCount;
  final String? arenaRoute;
  final String? matchWinner;
  final bool matchIsTie;
  final bool matchIsForfeit;
  final double peakEquity;
  final MatchStats? matchStats;

  // v2: Phase & momentum tracking (computed client-side)
  final MatchPhase matchPhase;
  final int totalDurationSeconds;
  final bool wasLeading;
  final int leadChangeCount;
  final int consecutiveWins;
  final int bestStreak;

  static const double demoBalance = 1000000;

  const TradingState({
    this.selectedAssetIndex = 0,
    this.currentPrices = const {},
    this.positions = const [],
    this.balance = demoBalance,
    this.matchTimeRemainingSeconds = 0,
    this.matchActive = false,
    this.initialBalance = demoBalance,
    this.matchId,
    this.opponentAddress,
    this.opponentGamerTag,
    this.opponentPnl = 0,
    this.opponentEquity = demoBalance,
    this.opponentPositionCount = 0,
    this.arenaRoute,
    this.matchWinner,
    this.matchIsTie = false,
    this.matchIsForfeit = false,
    this.peakEquity = demoBalance,
    this.matchStats,
    this.matchPhase = MatchPhase.intro,
    this.totalDurationSeconds = 0,
    this.wasLeading = false,
    this.leadChangeCount = 0,
    this.consecutiveWins = 0,
    this.bestStreak = 0,
  });

  TradingAsset get selectedAsset => TradingAsset.all[selectedAssetIndex];

  double get currentPrice =>
      currentPrices[selectedAsset.symbol] ?? selectedAsset.basePrice;

  List<Position> get openPositions =>
      positions.where((p) => p.isOpen).toList();

  List<Position> get closedPositions =>
      positions.where((p) => !p.isOpen).toList().reversed.toList();

  double get totalUnrealizedPnl {
    double total = 0;
    for (final p in openPositions) {
      final price = currentPrices[p.assetSymbol] ?? 0;
      total += p.pnl(price);
    }
    return total;
  }

  double get equity => balance + totalUnrealizedPnl;

  double get totalRealizedPnl {
    double total = 0;
    for (final p in closedPositions) {
      total += p.pnl(p.exitPrice ?? p.entryPrice);
    }
    return total;
  }

  double get opponentRoi =>
      opponentEquity > 0 && initialBalance > 0
          ? (opponentEquity - initialBalance) / initialBalance * 100
          : 0;

  /// Sentinel to distinguish "not passed" from "explicitly set to null".
  static const _unchanged = Object();

  TradingState copyWith({
    int? selectedAssetIndex,
    Map<String, double>? currentPrices,
    List<Position>? positions,
    double? balance,
    int? matchTimeRemainingSeconds,
    bool? matchActive,
    double? initialBalance,
    Object? matchId = _unchanged,
    Object? opponentAddress = _unchanged,
    Object? opponentGamerTag = _unchanged,
    double? opponentPnl,
    double? opponentEquity,
    int? opponentPositionCount,
    Object? arenaRoute = _unchanged,
    Object? matchWinner = _unchanged,
    bool? matchIsTie,
    bool? matchIsForfeit,
    double? peakEquity,
    Object? matchStats = _unchanged,
    MatchPhase? matchPhase,
    int? totalDurationSeconds,
    bool? wasLeading,
    int? leadChangeCount,
    int? consecutiveWins,
    int? bestStreak,
  }) {
    return TradingState(
      selectedAssetIndex: selectedAssetIndex ?? this.selectedAssetIndex,
      currentPrices: currentPrices ?? this.currentPrices,
      positions: positions ?? this.positions,
      balance: balance ?? this.balance,
      matchTimeRemainingSeconds:
          matchTimeRemainingSeconds ?? this.matchTimeRemainingSeconds,
      matchActive: matchActive ?? this.matchActive,
      initialBalance: initialBalance ?? this.initialBalance,
      matchId: matchId == _unchanged ? this.matchId : matchId as String?,
      opponentAddress: opponentAddress == _unchanged
          ? this.opponentAddress
          : opponentAddress as String?,
      opponentGamerTag: opponentGamerTag == _unchanged
          ? this.opponentGamerTag
          : opponentGamerTag as String?,
      opponentPnl: opponentPnl ?? this.opponentPnl,
      opponentEquity: opponentEquity ?? this.opponentEquity,
      opponentPositionCount:
          opponentPositionCount ?? this.opponentPositionCount,
      arenaRoute:
          arenaRoute == _unchanged ? this.arenaRoute : arenaRoute as String?,
      matchWinner: matchWinner == _unchanged
          ? this.matchWinner
          : matchWinner as String?,
      matchIsTie: matchIsTie ?? this.matchIsTie,
      matchIsForfeit: matchIsForfeit ?? this.matchIsForfeit,
      peakEquity: peakEquity ?? this.peakEquity,
      matchStats: matchStats == _unchanged
          ? this.matchStats
          : matchStats as MatchStats?,
      matchPhase: matchPhase ?? this.matchPhase,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      wasLeading: wasLeading ?? this.wasLeading,
      leadChangeCount: leadChangeCount ?? this.leadChangeCount,
      consecutiveWins: consecutiveWins ?? this.consecutiveWins,
      bestStreak: bestStreak ?? this.bestStreak,
    );
  }
}

class TradingNotifier extends Notifier<TradingState> {
  Timer? _matchTimer;
  Timer? _checkTimer;
  StreamSubscription? _wsSubscription;
  int _positionCounter = 0;

  final _api = ApiClient.instance;

  PriceFeedNotifier get _priceFeed => ref.read(priceFeedProvider.notifier);

  @override
  TradingState build() {
    ref.onDispose(() {
      _matchTimer?.cancel();
      _checkTimer?.cancel();
      _resultPollTimer?.cancel();
      _wsSubscription?.cancel();
      _priceFeed.stop();
    });
    return const TradingState();
  }

  /// Start the trading match.
  /// When resuming an already-known match (same matchId), positions and
  /// balance are preserved but timers & WebSocket are (re)started.
  void startMatch({
    required int durationSeconds,
    required double betAmount,
    String? matchId,
    String? opponentAddress,
    String? opponentGamerTag,
    String? arenaRoute,
  }) {
    // Resuming: keep positions/balance, just update remaining time.
    final isResume =
        state.matchActive && matchId != null && state.matchId == matchId;

    _priceFeed.start();

    if (isResume) {
      state = state.copyWith(
        matchTimeRemainingSeconds: durationSeconds,
        arenaRoute: arenaRoute,
        totalDurationSeconds: durationSeconds,
      );
    } else {
      state = state.copyWith(
        positions: [],
        balance: TradingState.demoBalance,
        initialBalance: TradingState.demoBalance,
        matchTimeRemainingSeconds: durationSeconds,
        matchActive: true,
        matchId: matchId,
        opponentAddress: opponentAddress,
        opponentGamerTag: opponentGamerTag,
        opponentPnl: 0,
        opponentEquity: TradingState.demoBalance,
        opponentPositionCount: 0,
        arenaRoute: arenaRoute,
        // Reset result state from any previous match.
        matchWinner: null,
        matchIsTie: false,
        matchIsForfeit: false,
        peakEquity: TradingState.demoBalance,
        matchStats: null,
        // v2: Phase & momentum
        matchPhase: MatchPhase.intro,
        totalDurationSeconds: durationSeconds,
        wasLeading: false,
        leadChangeCount: 0,
        consecutiveWins: 0,
        bestStreak: 0,
      );
    }

    // Join the match room via WebSocket.
    if (matchId != null) {
      _api.wsSend({'type': 'join_match', 'matchId': matchId});

      // Listen for WebSocket events.
      _wsSubscription?.cancel();
      _wsSubscription = _api.wsStream.listen(_handleWsEvent);
    }

    // Countdown timer.
    _matchTimer?.cancel();
    _matchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.matchTimeRemainingSeconds <= 1) {
        endMatch();
      } else {
        final newRemaining = state.matchTimeRemainingSeconds - 1;
        final newPhase = computePhase(newRemaining, state.totalDurationSeconds);
        state = state.copyWith(
          matchTimeRemainingSeconds: newRemaining,
          matchPhase: newPhase,
        );
      }
    });

    // Check SL/TP/liquidation every 500ms.
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _checkPositions();
    });
  }

  void _handleWsEvent(Map<String, dynamic> data) {
    switch (data['type']) {
      case 'ws_connected':
        // WebSocket reconnected (network blip, not a full page refresh).
        // Re-join the match room so the backend sends prices + match_snapshot.
        // Also re-join after the local timer fires (matchActive == false) so
        // we still receive match_end / claim_available events.
        if (state.matchId != null) {
          _api.wsSend({'type': 'join_match', 'matchId': state.matchId});
        }
        break;

      case 'price_update':
        final prices = <String, double>{};
        if (data['btc'] != null) prices['BTC'] = (data['btc'] as num).toDouble();
        if (data['eth'] != null) prices['ETH'] = (data['eth'] as num).toDouble();
        if (data['sol'] != null) prices['SOL'] = (data['sol'] as num).toDouble();
        if (prices.isNotEmpty) updatePrices(prices);
        break;

      case 'opponent_update':
        final pnl = (data['pnl'] as num?)?.toDouble() ?? 0;
        final equity =
            (data['equity'] as num?)?.toDouble() ?? TradingState.demoBalance;
        final posCount = (data['positionCount'] as num?)?.toInt() ?? 0;

        // Track lead changes: compare my ROI vs opponent ROI.
        final myRoi = state.initialBalance > 0
            ? (state.equity - state.initialBalance) / state.initialBalance
            : 0.0;
        final oppRoi = state.initialBalance > 0
            ? (equity - state.initialBalance) / state.initialBalance
            : 0.0;
        final amLeading = myRoi > oppRoi;
        final leadChanged = state.wasLeading != amLeading &&
            state.matchTimeRemainingSeconds < state.totalDurationSeconds - 5;

        state = state.copyWith(
          opponentPnl: pnl,
          opponentEquity: equity,
          opponentPositionCount: posCount,
          wasLeading: amLeading,
          leadChangeCount: leadChanged
              ? state.leadChangeCount + 1
              : null,
        );
        break;

      case 'position_closed':
        // Server closed a position (SL/TP/liquidation triggered server-side).
        final closedId = data['positionId'] as String?;
        final exitPx = (data['exitPrice'] as num?)?.toDouble();
        final serverPnl = (data['pnl'] as num?)?.toDouble();
        final reason = data['closeReason'] as String? ?? 'sl';
        if (closedId != null && exitPx != null) {
          final now = DateTime.now();
          double balanceReturn = 0;
          double? closedPnl;
          final updated = state.positions.map((p) {
            if (p.id == closedId && p.isOpen) {
              p.exitPrice = exitPx;
              p.closedAt = now;
              p.closeReason = reason;
              closedPnl = serverPnl ?? p.pnl(exitPx);
              balanceReturn = p.size + closedPnl!;
            }
            return p;
          }).toList();

          // Track consecutive wins/losses.
          int newConsecutive = state.consecutiveWins;
          int newBest = state.bestStreak;
          if (closedPnl != null) {
            if (closedPnl! >= 0) {
              newConsecutive++;
              if (newConsecutive > newBest) newBest = newConsecutive;
            } else {
              newConsecutive = 0;
            }
          }

          state = state.copyWith(
            positions: updated,
            balance: state.balance + balanceReturn,
            consecutiveWins: newConsecutive,
            bestStreak: newBest,
          );
        }
        break;

      case 'match_end':
        endMatch(
          winner: data['winner'] as String?,
          isTie: data['isTie'] as bool? ?? false,
          isForfeit: data['isForfeit'] as bool? ?? false,
        );
        break;

      case 'claim_available':
        // Winner can now claim — update state if not already set.
        final winner = data['winner'] as String?;
        if (winner != null && state.matchWinner == null) {
          state = state.copyWith(matchWinner: winner);
        }
        break;

      case 'match_snapshot':
        // Backend sends this after join_match to restore UI state after a
        // page refresh or WS reconnect.
        _applySnapshot(data);
        break;

      case 'chat_message':
        // Handled by MatchChatNotifier's own wsStream subscription.
        break;
    }
  }

  /// Restore positions and balance from a backend snapshot.
  /// Also advances [_positionCounter] to avoid ID collisions with new positions.
  void _applySnapshot(Map<String, dynamic> data) {
    if (!state.matchActive) return;

    final rawList = data['positions'] as List<dynamic>? ?? [];
    final snapshotBalance = (data['balance'] as num?)?.toDouble();

    final positions = rawList.map<Position>((raw) {
      final p = raw as Map<String, dynamic>;
      return Position(
        id:          p['id'] as String,
        assetSymbol: p['assetSymbol'] as String,
        isLong:      p['isLong'] as bool,
        entryPrice:  (p['entryPrice'] as num).toDouble(),
        size:        (p['size'] as num).toDouble(),
        leverage:    (p['leverage'] as num).toDouble(),
        openedAt:    p['openedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(p['openedAt'] as int)
            : DateTime.now(),
        stopLoss:    (p['stopLoss'] as num?)?.toDouble(),
        takeProfit:  (p['takeProfit'] as num?)?.toDouble(),
        exitPrice:   (p['exitPrice'] as num?)?.toDouble(),
        closedAt:    p['closedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(p['closedAt'] as int)
            : null,
        closeReason: p['closeReason'] as String?,
      );
    }).toList();

    // Advance counter past any restored IDs (e.g. pos_3) so new positions
    // get unique IDs and don't collide with existing Firebase records.
    for (final p in positions) {
      final m = RegExp(r'^pos_(\d+)$').firstMatch(p.id);
      if (m != null) {
        final n = int.tryParse(m.group(1)!) ?? 0;
        if (n > _positionCounter) _positionCounter = n;
      }
    }

    state = state.copyWith(
      positions: positions,
      balance: snapshotBalance ?? state.balance,
    );
  }

  /// Called externally when price feed updates.
  void updatePrices(Map<String, double> prices) {
    if (prices.isNotEmpty) {
      state = state.copyWith(currentPrices: prices);
    }
  }

  void _checkPositions() {
    final prices = state.currentPrices;
    if (prices.isEmpty) return;

    final now = DateTime.now();
    bool changed = false;
    double balanceAdjust = 0;
    final closedPnls = <double>[];

    final updatedPositions = state.positions.map((p) {
      if (!p.isOpen) return p;

      final price = prices[p.assetSymbol] ?? p.entryPrice;

      // Check liquidation.
      final isLiquidated = p.isLong
          ? price <= p.liquidationPrice
          : price >= p.liquidationPrice;

      if (isLiquidated) {
        p.exitPrice = p.liquidationPrice;
        p.closedAt = now;
        p.closeReason = 'liquidation';
        final pnl = p.pnl(p.liquidationPrice);
        balanceAdjust += p.size + pnl;
        closedPnls.add(pnl);
        changed = true;
        return p;
      }

      // Check stop loss.
      if (p.stopLoss != null) {
        final slHit =
            p.isLong ? price <= p.stopLoss! : price >= p.stopLoss!;
        if (slHit) {
          p.exitPrice = p.stopLoss;
          p.closedAt = now;
          p.closeReason = 'sl';
          final pnl = p.pnl(p.stopLoss!);
          balanceAdjust += p.size + pnl;
          closedPnls.add(pnl);
          changed = true;
          return p;
        }
      }

      // Check take profit.
      if (p.takeProfit != null) {
        final tpHit =
            p.isLong ? price >= p.takeProfit! : price <= p.takeProfit!;
        if (tpHit) {
          p.exitPrice = p.takeProfit;
          p.closedAt = now;
          p.closeReason = 'tp';
          final pnl = p.pnl(p.takeProfit!);
          balanceAdjust += p.size + pnl;
          closedPnls.add(pnl);
          changed = true;
          return p;
        }
      }

      return p;
    }).toList();

    if (changed) {
      final newBalance = state.balance + balanceAdjust;
      // Recalculate equity for peak tracking.
      double unrealized = 0;
      for (final p in updatedPositions) {
        if (p.isOpen) {
          final px = prices[p.assetSymbol] ?? p.entryPrice;
          unrealized += p.pnl(px);
        }
      }
      final newEquity = newBalance + unrealized;

      // Track consecutive wins/losses for auto-closed positions.
      int newConsecutive = state.consecutiveWins;
      int newBest = state.bestStreak;
      for (final pnl in closedPnls) {
        if (pnl >= 0) {
          newConsecutive++;
          if (newConsecutive > newBest) newBest = newConsecutive;
        } else {
          newConsecutive = 0;
        }
      }

      state = state.copyWith(
        positions: updatedPositions,
        balance: newBalance,
        peakEquity:
            newEquity > state.peakEquity ? newEquity : null,
        consecutiveWins: newConsecutive,
        bestStreak: newBest,
      );
    } else {
      // Even without position changes, track peak equity from price moves.
      final currentEquity = state.equity;
      if (currentEquity > state.peakEquity) {
        state = state.copyWith(peakEquity: currentEquity);
      }
    }
  }

  void selectAsset(int index) {
    state = state.copyWith(selectedAssetIndex: index);
  }

  /// Open a new position (reported to server via WebSocket).
  void openPosition({
    required String assetSymbol,
    required bool isLong,
    required double size,
    required double leverage,
    double? stopLoss,
    double? takeProfit,
  }) {
    if (size > state.balance || size <= 0) return;

    final price = state.currentPrices[assetSymbol];
    if (price == null) return;

    _positionCounter++;
    final position = Position(
      id: 'pos_$_positionCounter',
      assetSymbol: assetSymbol,
      isLong: isLong,
      entryPrice: price,
      size: size,
      leverage: leverage,
      openedAt: DateTime.now(),
      stopLoss: stopLoss,
      takeProfit: takeProfit,
    );

    state = state.copyWith(
      positions: [...state.positions, position],
      balance: state.balance - size,
    );

    // Report to server — include the local ID so Firebase uses the same key.
    if (state.matchId != null) {
      _api.wsSend({
        'type': 'open_position',
        'matchId': state.matchId,
        'positionId': position.id,
        'asset': assetSymbol,
        'isLong': isLong,
        'size': size,
        'leverage': leverage,
        'sl': ?stopLoss,
        'tp': ?takeProfit,
      });
    }
  }

  /// Close an open position at market price.
  void closePosition(String positionId) {
    final now = DateTime.now();
    double balanceReturn = 0;
    double? closedPnl;

    final updatedPositions = state.positions.map((p) {
      if (p.id == positionId && p.isOpen) {
        final currentPrice =
            state.currentPrices[p.assetSymbol] ?? p.entryPrice;
        p.exitPrice = currentPrice;
        p.closedAt = now;
        p.closeReason = 'manual';
        closedPnl = p.pnl(currentPrice);
        balanceReturn = p.size + closedPnl!;
      }
      return p;
    }).toList();

    // Track consecutive wins/losses.
    int newConsecutive = state.consecutiveWins;
    int newBest = state.bestStreak;
    if (closedPnl != null) {
      if (closedPnl! >= 0) {
        newConsecutive++;
        if (newConsecutive > newBest) newBest = newConsecutive;
      } else {
        newConsecutive = 0;
      }
    }

    state = state.copyWith(
      positions: updatedPositions,
      balance: state.balance + balanceReturn,
      consecutiveWins: newConsecutive,
      bestStreak: newBest,
    );

    // Report to server.
    if (state.matchId != null) {
      _api.wsSend({
        'type': 'close_position',
        'matchId': state.matchId,
        'positionId': positionId,
      });
    }
  }

  /// Check if the player has an active match on the backend.
  /// If found, populate state so the _ActiveMatchBanner appears on PlayScreen.
  Future<void> checkActiveMatch(String walletAddress) async {
    // Don't overwrite if we already have an active match loaded.
    if (state.matchActive) return;

    try {
      final result = await _api.get('/match/active/$walletAddress');
      final match = result['match'];
      if (match == null) return;

      // BUG 2 fix: only show the banner for genuinely active matches.
      final matchStatus = match['status'] as String?;
      if (matchStatus != 'active') return;

      final matchId = match['matchId'] as String;
      final betAmount = (match['betAmount'] as num?)?.toDouble() ?? 1.0;
      final oppAddress = match['opponentAddress'] as String?;
      final oppTag = match['opponentGamerTag'] as String?;
      final endTime = match['endTime'] as int?;
      final duration = match['duration'] as String? ?? '15m';

      // Parse duration string to seconds.
      int durationSeconds = 900;
      final m = RegExp(r'^(\d+)(m|h)$').firstMatch(duration);
      if (m != null) {
        final value = int.parse(m.group(1)!);
        durationSeconds = m.group(2) == 'h' ? value * 3600 : value * 60;
      }

      // Calculate remaining time using server endTime (shared clock).
      int remaining = durationSeconds;
      if (endTime != null) {
        remaining = ((endTime - DateTime.now().millisecondsSinceEpoch) / 1000)
            .round()
            .clamp(0, durationSeconds);
      }

      // Build the arena route for navigation.
      final arenaUri = Uri(
        path: AppConstants.arenaRoute,
        queryParameters: {
          'd': durationSeconds.toString(),
          'bet': betAmount.toString(),
          'matchId': matchId,
          if (oppAddress != null) 'opp': oppAddress,
          if (oppTag != null) 'oppTag': oppTag,
          if (endTime != null) 'et': endTime.toString(),
        },
      ).toString();

      state = state.copyWith(
        matchId: matchId,
        matchActive: true,
        opponentAddress: oppAddress,
        opponentGamerTag: oppTag,
        matchTimeRemainingSeconds: remaining,
        arenaRoute: arenaUri,
      );
    } catch (_) {
      // Silently fail — this is a best-effort reconnection check.
    }
  }

  Timer? _resultPollTimer;
  int _pollAttempt = 0;

  void endMatch({
    String? winner,
    bool? isTie,
    bool? isForfeit,
  }) {
    _matchTimer?.cancel();
    _checkTimer?.cancel();
    // Keep _wsSubscription alive — the backend's match_end / claim_available
    // events may arrive after the client timer fires. The subscription is
    // cleaned up in build()'s onDispose.
    _priceFeed.stop();

    // ── Close all open positions at current market price ──
    final now = DateTime.now();
    double balanceReturn = 0;
    final updatedPositions = state.positions.map((p) {
      if (p.isOpen) {
        final currentPrice =
            state.currentPrices[p.assetSymbol] ?? p.entryPrice;
        p.exitPrice = currentPrice;
        p.closedAt = now;
        p.closeReason = 'match_end';
        balanceReturn += p.size + p.pnl(currentPrice);
      }
      return p;
    }).toList();

    final myFinalBalance = state.balance + balanceReturn;

    // ── Compute match statistics ──
    final stats = MatchStats.compute(
      positions: updatedPositions,
      initialBalance: state.initialBalance,
      finalBalance: myFinalBalance,
      peakEquity: state.peakEquity > myFinalBalance
          ? state.peakEquity
          : myFinalBalance,
    );

    // Preserve any existing server-authoritative result when called without
    // explicit winner/tie info (e.g. the client-side timer fires after a WS
    // match_end already delivered the result).
    final String? resolvedWinner = winner ?? state.matchWinner;
    final bool resolvedIsTie = isTie ?? state.matchIsTie;
    final bool resolvedIsForfeit = isForfeit ?? state.matchIsForfeit;

    state = state.copyWith(
      positions: updatedPositions,
      balance: myFinalBalance,
      matchActive: false,
      matchTimeRemainingSeconds: 0,
      matchWinner: resolvedWinner,
      matchIsTie: resolvedIsTie,
      matchIsForfeit: resolvedIsForfeit,
      matchStats: stats,
      matchPhase: MatchPhase.ended,
    );

    // If we still don't have a winner/tie result (client timer fired before
    // backend settled), poll the backend with exponential backoff.
    // Also re-join the match room so WS broadcasts can still reach us.
    if (resolvedWinner == null && !resolvedIsTie) {
      if (state.matchId != null) {
        _api.wsSend({'type': 'join_match', 'matchId': state.matchId});
      }
      _startResultPolling();
    } else {
      _resultPollTimer?.cancel();
    }
  }

  void _startResultPolling() {
    _resultPollTimer?.cancel();
    _pollAttempt = 0;
    if (state.matchId == null) return;
    final matchId = state.matchId!;

    _pollResult(matchId);
  }

  Future<void> _pollResult(String matchId) async {
    if (state.matchWinner != null || state.matchIsTie) {
      _resultPollTimer?.cancel();
      return;
    }

    // Exponential backoff: 2s, 2s, 4s, 4s, 8s, 8s... capped at 10s.
    // Total ~3 minutes before giving up (30 attempts).
    if (_pollAttempt >= 30) {
      _resultPollTimer?.cancel();
      return;
    }

    try {
      final result = await _api.get('/match/$matchId');
      final status = result['status'] as String?;
      if (status == 'completed' ||
          status == 'tied' ||
          status == 'forfeited') {
        _resultPollTimer?.cancel();
        final w = result['winner'] as String?;
        state = state.copyWith(
          matchWinner: w,
          matchIsTie: status == 'tied',
          matchIsForfeit: status == 'forfeited',
        );
        return;
      }
    } catch (_) {
      // Will retry on next attempt.
    }

    _pollAttempt++;
    final delaySec = (_pollAttempt < 4) ? 2 : (_pollAttempt < 10 ? 4 : 10);
    _resultPollTimer = Timer(Duration(seconds: delaySec), () {
      _pollResult(matchId);
    });
  }
}

final tradingProvider =
    NotifierProvider<TradingNotifier, TradingState>(TradingNotifier.new);
