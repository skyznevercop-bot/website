import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_client.dart';
import '../../portfolio/models/transaction_models.dart';
import '../../portfolio/providers/portfolio_provider.dart';
import '../../wallet/providers/wallet_provider.dart';
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
  /// Server-authoritative opponent ROI % from opponent_update broadcast.
  final double? opponentServerRoi;
  final String? arenaRoute;
  final String? matchWinner;
  final bool matchIsTie;
  final bool matchIsForfeit;
  final double peakEquity;
  final MatchStats? matchStats;

  // Server-authoritative ROI values (from match_end event).
  final double? serverMyRoi;
  final double? serverOppRoi;

  // v2: Phase & momentum tracking (computed client-side)
  final MatchPhase matchPhase;
  final int totalDurationSeconds;
  final bool wasLeading;
  final int leadChangeCount;
  final int consecutiveWins;
  final int bestStreak;

  // v3: Limit orders
  final List<LimitOrder> pendingOrders;

  // v4: Practice mode
  final bool isPracticeMode;

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
    this.opponentServerRoi,
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
    this.pendingOrders = const [],
    this.serverMyRoi,
    this.serverOppRoi,
    this.isPracticeMode = false,
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
      final price = currentPrices[p.assetSymbol] ?? p.entryPrice;
      total += p.pnl(price);
    }
    return total;
  }

  double get equity {
    // balance has open position margins deducted (balance -= size on open).
    // Add back each open position's full value (margin + unrealized PnL)
    // so equity = DEMO_BALANCE + totalPnl (realized + unrealized).
    double openValue = 0;
    for (final p in openPositions) {
      final price = currentPrices[p.assetSymbol] ?? p.entryPrice;
      openValue += (p.size + p.pnl(price)).clamp(0.0, double.infinity);
    }
    return balance + openValue;
  }

  double get totalRealizedPnl {
    double total = 0;
    for (final p in closedPositions) {
      total += p.pnl(p.exitPrice ?? p.entryPrice);
    }
    return total;
  }

  /// My live ROI as a percentage (e.g. 5.00 = 5%).
  double get myRoiPercent =>
      initialBalance > 0
          ? (equity - initialBalance) / initialBalance * 100
          : 0;

  /// Opponent ROI — prefer server-authoritative value when available.
  double get opponentRoi =>
      opponentServerRoi ??
      (opponentEquity > 0 && initialBalance > 0
          ? (opponentEquity - initialBalance) / initialBalance * 100
          : 0);

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
    Object? opponentServerRoi = _unchanged,
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
    List<LimitOrder>? pendingOrders,
    Object? serverMyRoi = _unchanged,
    Object? serverOppRoi = _unchanged,
    bool? isPracticeMode,
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
      opponentServerRoi: opponentServerRoi == _unchanged
          ? this.opponentServerRoi
          : opponentServerRoi as double?,
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
      pendingOrders: pendingOrders ?? this.pendingOrders,
      serverMyRoi: serverMyRoi == _unchanged
          ? this.serverMyRoi
          : serverMyRoi as double?,
      serverOppRoi: serverOppRoi == _unchanged
          ? this.serverOppRoi
          : serverOppRoi as double?,
      isPracticeMode: isPracticeMode ?? this.isPracticeMode,
    );
  }
}

class TradingNotifier extends Notifier<TradingState> {
  Timer? _matchTimer;
  Timer? _checkTimer;
  Timer? _settlementTimeoutTimer;
  StreamSubscription? _wsSubscription;
  int _positionCounter = 0;
  int _orderCounter = 0;
  MatchPhase _lastCheckPhase = MatchPhase.intro;

  final _api = ApiClient.instance;

  PriceFeedNotifier get _priceFeed => ref.read(priceFeedProvider.notifier);

  @override
  TradingState build() {
    ref.onDispose(() {
      _matchTimer?.cancel();
      _checkTimer?.cancel();
      _settlementTimeoutTimer?.cancel();
      _resultPollTimer?.cancel();
      _wsSubscription?.cancel();
      _priceFeed.stop();
    });
    return const TradingState();
  }

  /// Start a solo practice match — no wallet, no opponent, no backend.
  void startPracticeMatch({required int durationSeconds}) {
    _priceFeed.start();

    state = state.copyWith(
      positions: [],
      balance: TradingState.demoBalance,
      initialBalance: TradingState.demoBalance,
      matchTimeRemainingSeconds: durationSeconds,
      matchActive: true,
      isPracticeMode: true,
      matchId: 'practice_${DateTime.now().millisecondsSinceEpoch}',
      opponentAddress: null,
      opponentGamerTag: null,
      opponentPnl: 0,
      opponentEquity: TradingState.demoBalance,
      opponentPositionCount: 0,
      arenaRoute: null,
      matchWinner: null,
      matchIsTie: false,
      matchIsForfeit: false,
      peakEquity: TradingState.demoBalance,
      matchStats: null,
      matchPhase: MatchPhase.intro,
      totalDurationSeconds: durationSeconds,
      wasLeading: false,
      leadChangeCount: 0,
      consecutiveWins: 0,
      bestStreak: 0,
      pendingOrders: [],
      serverMyRoi: null,
      serverOppRoi: null,
      opponentServerRoi: null,
    );

    // Countdown timer (same as competitive).
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
        if (newPhase != _lastCheckPhase) {
          _lastCheckPhase = newPhase;
          _restartCheckTimer(newPhase);
        }
      }
    });

    _lastCheckPhase = MatchPhase.intro;
    _restartCheckTimer(MatchPhase.openingBell);
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
        pendingOrders: [],
        serverMyRoi: null,
        serverOppRoi: null,
        opponentServerRoi: null,
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

        // Restart check timer if phase changed (dynamic interval).
        if (newPhase != _lastCheckPhase) {
          _lastCheckPhase = newPhase;
          _restartCheckTimer(newPhase);
        }
      }
    });

    // Check SL/TP/liquidation with phase-aware interval.
    _lastCheckPhase = MatchPhase.intro;
    _restartCheckTimer(MatchPhase.openingBell);
  }

  /// Phase-aware check interval: faster checks when match is more intense.
  void _restartCheckTimer(MatchPhase phase) {
    _checkTimer?.cancel();
    final ms = switch (phase) {
      MatchPhase.intro => 500,
      MatchPhase.openingBell => 500,
      MatchPhase.midGame => 500,
      MatchPhase.finalSprint => 350,
      MatchPhase.lastStand => 200,
      MatchPhase.ended => 500,
    };
    _checkTimer = Timer.periodic(Duration(milliseconds: ms), (_) {
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
        final serverOppRoi = (data['roi'] as num?)?.toDouble();

        // Track lead changes: compare my ROI vs opponent ROI.
        final myRoi = state.myRoiPercent;
        final oppRoi = serverOppRoi ??
            (state.initialBalance > 0
                ? (equity - state.initialBalance) / state.initialBalance * 100
                : 0.0);
        final amLeading = myRoi > oppRoi;
        final leadChanged = state.wasLeading != amLeading &&
            state.matchTimeRemainingSeconds < state.totalDurationSeconds - 5;

        state = state.copyWith(
          opponentPnl: pnl,
          opponentEquity: equity,
          opponentPositionCount: posCount,
          opponentServerRoi: serverOppRoi,
          wasLeading: amLeading,
          leadChangeCount: leadChanged
              ? state.leadChangeCount + 1
              : null,
        );
        break;

      case 'error':
        // If the error includes a positionId, the server rejected an
        // open_position — roll back the optimistic phantom position.
        final errorPosId = data['positionId'] as String?;
        if (errorPosId != null && state.matchActive) {
          final idx = state.positions.indexWhere(
              (p) => p.id == errorPosId && p.isOpen);
          if (idx != -1) {
            final phantom = state.positions[idx];
            state = state.copyWith(
              positions: [
                ...state.positions.sublist(0, idx),
                ...state.positions.sublist(idx + 1),
              ],
              balance: state.balance + phantom.size, // restore margin
            );
          }
        }
        break;

      case 'position_opened':
        // Server confirmed the position — reconcile entry price so client
        // PnL matches server calculations exactly.
        final posData = data['position'] as Map<String, dynamic>?;
        if (posData != null) {
          final posId = posData['id'] as String?;
          final serverEntry = (posData['entryPrice'] as num?)?.toDouble();
          if (posId != null && serverEntry != null) {
            bool changed = false;
            final updated = state.positions.map((p) {
              if (p.id == posId && (p.entryPrice - serverEntry).abs() > 0.001) {
                p.entryPrice = serverEntry;
                changed = true;
              }
              return p;
            }).toList();
            if (changed) {
              state = state.copyWith(positions: updated);
            }
          }
        }
        break;

      case 'position_closed':
        // Server closed a position (SL/TP/liquidation triggered server-side,
        // or manual close response). Also reconciles already-closed positions
        // so client PnL matches server.
        final closedId = data['positionId'] as String?;
        final exitPx = (data['exitPrice'] as num?)?.toDouble();
        final serverPnl = (data['pnl'] as num?)?.toDouble();
        final reason = data['closeReason'] as String? ?? 'sl';
        if (closedId != null && exitPx != null) {
          final now = DateTime.now();
          double balanceReturn = 0;
          double? closedPnl;
          final updated = state.positions.map((p) {
            if (p.id == closedId) {
              if (p.isOpen) {
                // Not yet closed locally — close it now.
                p.exitPrice = exitPx;
                p.closedAt = now;
                p.closeReason = reason;
                closedPnl = serverPnl ?? p.pnl(exitPx);
                balanceReturn =
                    (p.size + closedPnl!).clamp(0.0, double.infinity);
              } else if (serverPnl != null) {
                // Already closed locally — reconcile PnL with server.
                final oldPnl = p.pnl(p.exitPrice ?? p.entryPrice);
                p.exitPrice = exitPx;
                final oldReturn =
                    (p.size + oldPnl).clamp(0.0, double.infinity);
                final newReturn =
                    (p.size + serverPnl).clamp(0.0, double.infinity);
                balanceReturn = newReturn - oldReturn;
              }
            }
            return p;
          }).toList();

          // Track consecutive wins/losses (only for newly closed).
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
        // Apply settlement prices so client closes positions at the exact
        // same prices the server used — eliminates price drift divergence.
        final settlementPrices = data['prices'] as Map<String, dynamic>?;
        if (settlementPrices != null) {
          final prices = <String, double>{};
          for (final entry in settlementPrices.entries) {
            final v = entry.value;
            if (v is num) prices[entry.key] = v.toDouble();
          }
          if (prices.isNotEmpty) updatePrices(prices);
        }

        // Determine which ROI belongs to us vs our opponent.
        final p1Roi = (data['p1Roi'] as num?)?.toDouble();
        final p2Roi = (data['p2Roi'] as num?)?.toDouble();
        final player1Addr = data['player1'] as String?;
        final walletAddr = ref.read(walletProvider).address;
        final isP1 = player1Addr != null && player1Addr == walletAddr;
        endMatch(
          winner: data['winner'] as String?,
          isTie: data['isTie'] as bool? ?? false,
          isForfeit: data['isForfeit'] as bool? ?? false,
          serverMyRoi: isP1 ? p1Roi : p2Roi,
          serverOppRoi: isP1 ? p2Roi : p1Roi,
        );
        break;

      case 'balance_update':
        // Backend sends updated platform balance after match settlement.
        // Handled by wallet provider's WS listener — nothing to do here.
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

      // ── Trailing stop-loss: move SL with price ──
      if (p.trailingStopDistance != null && p.trailingStopDistance! > 0) {
        p.trailingPeakPrice ??= p.entryPrice;
        if (p.isLong) {
          if (price > p.trailingPeakPrice!) p.trailingPeakPrice = price;
          final newSl = p.trailingPeakPrice! - p.trailingStopDistance!;
          if (p.stopLoss == null || newSl > p.stopLoss!) {
            p.stopLoss = newSl;
            changed = true;
          }
        } else {
          if (price < p.trailingPeakPrice!) p.trailingPeakPrice = price;
          final newSl = p.trailingPeakPrice! + p.trailingStopDistance!;
          if (p.stopLoss == null || newSl < p.stopLoss!) {
            p.stopLoss = newSl;
            changed = true;
          }
        }
      }

      // Check liquidation.
      final isLiquidated = p.isLong
          ? price <= p.liquidationPrice
          : price >= p.liquidationPrice;

      if (isLiquidated) {
        p.exitPrice = p.liquidationPrice;
        p.closedAt = now;
        p.closeReason = 'liquidation';
        final pnl = p.pnl(p.liquidationPrice);
        balanceAdjust += (p.size + pnl).clamp(0.0, double.infinity);
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
          balanceAdjust += (p.size + pnl).clamp(0.0, double.infinity);
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
          balanceAdjust += (p.size + pnl).clamp(0.0, double.infinity);
          closedPnls.add(pnl);
          changed = true;
          return p;
        }
      }

      return p;
    }).toList();

    // ── Check pending limit orders ──
    bool ordersChanged = false;
    final remainingOrders = <LimitOrder>[];
    for (final order in state.pendingOrders) {
      final price = prices[order.assetSymbol];
      if (price == null) {
        remainingOrders.add(order);
        continue;
      }
      // Long limit: trigger when price drops to or below limit price.
      // Short limit: trigger when price rises to or above limit price.
      final triggered = order.isLong
          ? price <= order.limitPrice
          : price >= order.limitPrice;
      if (triggered && order.size <= state.balance + balanceAdjust) {
        _positionCounter++;
        final pos = Position(
          id: 'pos_$_positionCounter',
          assetSymbol: order.assetSymbol,
          isLong: order.isLong,
          entryPrice: price,
          size: order.size,
          leverage: order.leverage,
          openedAt: now,
          stopLoss: order.stopLoss,
          takeProfit: order.takeProfit,
          trailingStopDistance: order.trailingStopDistance,
        );
        updatedPositions.add(pos);
        balanceAdjust -= order.size;
        ordersChanged = true;
        changed = true;

        if (state.matchId != null && !state.isPracticeMode) {
          _api.wsSend({
            'type': 'open_position',
            'matchId': state.matchId,
            'positionId': pos.id,
            'asset': order.assetSymbol,
            'isLong': order.isLong,
            'size': order.size,
            'leverage': order.leverage,
            'sl': order.stopLoss,
            'tp': order.takeProfit,
          });
        }
      } else {
        remainingOrders.add(order);
      }
    }

    if (changed) {
      final newBalance = (state.balance + balanceAdjust).clamp(0.0, double.infinity);
      // Recalculate equity for peak tracking (margin + unrealized PnL).
      double openValue = 0;
      for (final p in updatedPositions) {
        if (p.isOpen) {
          final px = prices[p.assetSymbol] ?? p.entryPrice;
          openValue += (p.size + p.pnl(px)).clamp(0.0, double.infinity);
        }
      }
      final newEquity = newBalance + openValue;

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
        pendingOrders: ordersChanged ? remainingOrders : null,
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
    double? trailingStopDistance,
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
      trailingStopDistance: trailingStopDistance,
    );

    state = state.copyWith(
      positions: [...state.positions, position],
      balance: state.balance - size,
    );

    // Report to server — include the local ID so Firebase uses the same key.
    if (state.matchId != null && !state.isPracticeMode) {
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

  /// Update SL / TP on an open position.
  void updatePositionSlTp(
    String positionId, {
    double? stopLoss,
    double? takeProfit,
    bool clearSl = false,
    bool clearTp = false,
  }) {
    final positions = [...state.positions];
    final idx = positions.indexWhere((p) => p.id == positionId && p.isOpen);
    if (idx == -1) return;

    final p = positions[idx];
    if (clearSl) {
      p.stopLoss = null;
    } else if (stopLoss != null) {
      p.stopLoss = stopLoss;
    }
    if (clearTp) {
      p.takeProfit = null;
    } else if (takeProfit != null) {
      p.takeProfit = takeProfit;
    }

    state = state.copyWith(positions: positions);

    if (state.matchId != null && !state.isPracticeMode) {
      _api.wsSend({
        'type': 'update_position',
        'matchId': state.matchId,
        'positionId': positionId,
        if (!clearSl && p.stopLoss != null) 'sl': p.stopLoss,
        if (!clearTp && p.takeProfit != null) 'tp': p.takeProfit,
        if (clearSl) 'sl': null,
        if (clearTp) 'tp': null,
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

        // If price is past liquidation, close at liquidation price instead.
        final pastLiq = p.isLong
            ? currentPrice <= p.liquidationPrice
            : currentPrice >= p.liquidationPrice;
        final exitPrice = pastLiq ? p.liquidationPrice : currentPrice;

        p.exitPrice = exitPrice;
        p.closedAt = now;
        p.closeReason = pastLiq ? 'liquidation' : 'manual';
        closedPnl = p.pnl(exitPrice);
        // Never return less than zero to prevent negative balance.
        balanceReturn = (p.size + closedPnl!).clamp(0.0, double.infinity);
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
    if (state.matchId != null && !state.isPracticeMode) {
      _api.wsSend({
        'type': 'close_position',
        'matchId': state.matchId,
        'positionId': positionId,
      });
    }
  }

  /// Partially close a position (e.g. close 50%).
  /// Creates a new closed Position for the partial amount, reduces the original.
  void closePositionPartial(String positionId, double fraction) {
    if (fraction <= 0 || fraction >= 1) {
      closePosition(positionId);
      return;
    }

    final now = DateTime.now();
    final idx = state.positions.indexWhere(
        (p) => p.id == positionId && p.isOpen);
    if (idx == -1) return;

    final original = state.positions[idx];
    final currentPrice =
        state.currentPrices[original.assetSymbol] ?? original.entryPrice;

    // If price is past liquidation, close at liquidation price instead.
    final pastLiq = original.isLong
        ? currentPrice <= original.liquidationPrice
        : currentPrice >= original.liquidationPrice;
    final exitPrice = pastLiq ? original.liquidationPrice : currentPrice;

    final partialSize = original.size * fraction;
    final rawPartialPnl =
        partialSize * original.leverage *
        ((exitPrice - original.entryPrice) / original.entryPrice) *
        (original.isLong ? 1.0 : -1.0);
    final partialPnl = rawPartialPnl.clamp(-partialSize, double.infinity);

    // Create closed position for the partial amount.
    _positionCounter++;
    final closedPart = Position(
      id: 'pos_$_positionCounter',
      assetSymbol: original.assetSymbol,
      isLong: original.isLong,
      entryPrice: original.entryPrice,
      size: partialSize,
      leverage: original.leverage,
      openedAt: original.openedAt,
      exitPrice: exitPrice,
      closedAt: now,
      closeReason: pastLiq ? 'liquidation' : 'partial',
    );

    // Reduce original position's size.
    original.size -= partialSize;

    final balanceReturn = (partialSize + partialPnl).clamp(0.0, double.infinity);
    final updatedPositions = [...state.positions, closedPart];

    // Track consecutive wins/losses.
    int newConsecutive = state.consecutiveWins;
    int newBest = state.bestStreak;
    if (partialPnl >= 0) {
      newConsecutive++;
      if (newConsecutive > newBest) newBest = newConsecutive;
    } else {
      newConsecutive = 0;
    }

    state = state.copyWith(
      positions: updatedPositions,
      balance: state.balance + balanceReturn,
      consecutiveWins: newConsecutive,
      bestStreak: newBest,
    );

    if (state.matchId != null && !state.isPracticeMode) {
      _api.wsSend({
        'type': 'partial_close',
        'matchId': state.matchId,
        'positionId': positionId,
        'fraction': fraction,
      });
    }
  }

  /// Place a pending limit order.
  void placeLimitOrder({
    required String assetSymbol,
    required bool isLong,
    required double limitPrice,
    required double size,
    required double leverage,
    double? stopLoss,
    double? takeProfit,
    double? trailingStopDistance,
  }) {
    if (size <= 0) return;

    _orderCounter++;
    final order = LimitOrder(
      id: 'ord_$_orderCounter',
      assetSymbol: assetSymbol,
      isLong: isLong,
      limitPrice: limitPrice,
      size: size,
      leverage: leverage,
      stopLoss: stopLoss,
      takeProfit: takeProfit,
      trailingStopDistance: trailingStopDistance,
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      pendingOrders: [...state.pendingOrders, order],
    );
  }

  /// Cancel a pending limit order.
  void cancelLimitOrder(String orderId) {
    state = state.copyWith(
      pendingOrders:
          state.pendingOrders.where((o) => o.id != orderId).toList(),
    );
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
          'opp': ?oppAddress,
          'oppTag': ?oppTag,
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
    double? serverMyRoi,
    double? serverOppRoi,
  }) {
    _matchTimer?.cancel();
    _checkTimer?.cancel();
    // Keep _wsSubscription alive — the backend's match_end / claim_available
    // events may arrive after the client timer fires. The subscription is
    // cleaned up in build()'s onDispose.
    _priceFeed.stop();

    // Cancel settlement timeout when server data arrives.
    if (winner != null || (isTie ?? false)) {
      _settlementTimeoutTimer?.cancel();
    }

    // ── Phase 1: Close positions only when we have settlement data ──
    // When the timer fires (no args), positions stay open so the overlay
    // shows "Determining winner..." while waiting for the server's
    // match_end event with settlement prices. Positions are closed once
    // settlement data arrives (or in practice/forfeit modes immediately).
    final hasSettlement = (winner != null) ||
        (isTie ?? false) ||
        (isForfeit ?? false) ||
        state.isPracticeMode;
    final hasOpenPositions = state.positions.any((p) => p.isOpen);

    List<Position> updatedPositions = state.positions;
    double myFinalBalance = state.balance;
    MatchStats? stats = state.matchStats;

    if (hasOpenPositions && hasSettlement) {
      final now = DateTime.now();
      double balanceReturn = 0;
      updatedPositions = state.positions.map((p) {
        if (p.isOpen) {
          final currentPrice =
              state.currentPrices[p.assetSymbol] ?? p.entryPrice;
          p.exitPrice = currentPrice;
          p.closedAt = now;
          p.closeReason = 'match_end';
          balanceReturn +=
              (p.size + p.pnl(currentPrice)).clamp(0.0, double.infinity);
        }
        return p;
      }).toList();

      myFinalBalance = state.balance + balanceReturn;

      stats = MatchStats.compute(
        positions: updatedPositions,
        initialBalance: state.initialBalance,
        finalBalance: myFinalBalance,
        peakEquity: state.peakEquity > myFinalBalance
            ? state.peakEquity
            : myFinalBalance,
      );
    }

    // ── Phase 2: Resolve result (every call) ──
    // Merge incoming result data with any previously stored result.
    final String? resolvedWinner = winner ?? state.matchWinner;
    final bool resolvedIsTie = isTie ?? state.matchIsTie;
    final bool resolvedIsForfeit = isForfeit ?? state.matchIsForfeit;
    final double? resolvedMyRoi = serverMyRoi ?? state.serverMyRoi;
    final double? resolvedOppRoi = serverOppRoi ?? state.serverOppRoi;
    final hasResult = resolvedWinner != null || resolvedIsTie;

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
      serverMyRoi: resolvedMyRoi,
      serverOppRoi: resolvedOppRoi,
    );

    // ── Phase 3: Persist, poll, or start safety timeout ──
    _resultPollTimer?.cancel();
    if (state.isPracticeMode) {
      // Practice mode: no backend, no portfolio persistence. Done.
    } else if (hasResult) {
      _persistMatchResult(
          stats, resolvedWinner, resolvedIsTie, resolvedMyRoi);
    } else if (state.matchId != null) {
      // No result yet — re-join match room for WS broadcasts and start
      // polling the backend with exponential backoff.
      _api.wsSend({'type': 'join_match', 'matchId': state.matchId});
      _startResultPolling();

      // Safety net: if the server never responds within 15s, settle locally.
      _settlementTimeoutTimer?.cancel();
      _settlementTimeoutTimer = Timer(const Duration(seconds: 15), () {
        if (state.matchWinner == null && !state.matchIsTie) {
          final myRoi = state.myRoiPercent;
          final oppRoi = state.opponentRoi;
          final walletAddr = ref.read(walletProvider).address;
          endMatch(
            winner: myRoi >= oppRoi ? walletAddr : state.opponentAddress,
            isTie: (myRoi - oppRoi).abs() < 0.01,
            serverMyRoi: myRoi,
            serverOppRoi: oppRoi,
          );
        }
      });
    }
  }

  /// Persist match result into portfolio history for the match history tab.
  void _persistMatchResult(
      MatchStats? stats, String? winner, bool isTie, double? serverRoi) {
    final wallet = ref.read(walletProvider);
    // Primary: winner address matches our wallet.
    bool isWin = !isTie && winner != null && winner == wallet.address;
    // Fallback: use server ROI comparison if address match fails.
    if (!isTie && !isWin && serverRoi != null && state.serverOppRoi != null) {
      isWin = serverRoi > state.serverOppRoi!;
    }
    final result = isTie
        ? 'TIE'
        : isWin
            ? 'WIN'
            : 'LOSS';

    // Use server-authoritative ROI when available, otherwise fall back to
    // client-computed stats ROI.
    final roi = serverRoi ?? stats?.roi ?? 0.0;

    // Derive PnL from server ROI for consistency; fall back to local balance.
    final pnl = serverRoi != null
        ? serverRoi / 100 * state.initialBalance
        : state.initialBalance > 0
            ? state.equity - state.initialBalance
            : 0.0;

    final durationMin = state.totalDurationSeconds ~/ 60;
    final durationLabel = durationMin >= 60
        ? '${durationMin ~/ 60}h'
        : '${durationMin}m';

    ref.read(portfolioProvider.notifier).addMatchResult(
          MatchResult(
            id: state.matchId ?? 'local_${DateTime.now().millisecondsSinceEpoch}',
            opponent: state.opponentGamerTag ?? 'Unknown',
            duration: durationLabel,
            result: result,
            pnl: pnl,
            betAmount: 0,
            completedAt: DateTime.now(),
            totalTrades: stats?.totalTrades ?? 0,
            winRate: stats?.winRate ?? 0,
            bestTradePnl: stats?.bestTradePnl ?? 0,
            bestTradeAsset: stats?.bestTradeAsset,
            totalVolume: stats?.totalVolume ?? 0,
            hotStreak: stats?.hotStreak ?? 0,
            roi: roi,
          ),
        );
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

        // REST now returns ROI as percentage (e.g. 5.00 = 5%).
        final p1Roi = (result['player1Roi'] as num?)?.toDouble();
        final p2Roi = (result['player2Roi'] as num?)?.toDouble();
        final player1Addr = result['player1'] as String?;
        final walletAddr = ref.read(walletProvider).address;
        final isP1 = player1Addr != null && player1Addr == walletAddr;
        final myRoi = isP1 ? p1Roi : p2Roi;
        final oppRoi = isP1 ? p2Roi : p1Roi;

        endMatch(
          winner: result['winner'] as String?,
          isTie: status == 'tied',
          isForfeit: status == 'forfeited',
          serverMyRoi: myRoi,
          serverOppRoi: oppRoi,
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
