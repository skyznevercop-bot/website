import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_client.dart';
import '../models/trading_models.dart';
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

  TradingState copyWith({
    int? selectedAssetIndex,
    Map<String, double>? currentPrices,
    List<Position>? positions,
    double? balance,
    int? matchTimeRemainingSeconds,
    bool? matchActive,
    double? initialBalance,
    String? matchId,
    String? opponentAddress,
    String? opponentGamerTag,
    double? opponentPnl,
    double? opponentEquity,
    int? opponentPositionCount,
    String? arenaRoute,
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
      matchId: matchId ?? this.matchId,
      opponentAddress: opponentAddress ?? this.opponentAddress,
      opponentGamerTag: opponentGamerTag ?? this.opponentGamerTag,
      opponentPnl: opponentPnl ?? this.opponentPnl,
      opponentEquity: opponentEquity ?? this.opponentEquity,
      opponentPositionCount:
          opponentPositionCount ?? this.opponentPositionCount,
      arenaRoute: arenaRoute ?? this.arenaRoute,
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
      _wsSubscription?.cancel();
      _priceFeed.stop();
    });
    return const TradingState();
  }

  /// Start the trading match.
  /// If a match with the same [matchId] is already active, this is a
  /// no-op (idempotent) — the user is just returning to the arena.
  void startMatch({
    required int durationSeconds,
    required double betAmount,
    String? matchId,
    String? opponentAddress,
    String? opponentGamerTag,
    String? arenaRoute,
  }) {
    // Idempotent: if returning to an already-running match, just ensure
    // the price feed is active and skip resetting state.
    if (state.matchActive && matchId != null && state.matchId == matchId) {
      _priceFeed.start();
      return;
    }

    _priceFeed.start();

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
      arenaRoute: arenaRoute,
    );

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
        state = state.copyWith(
          matchTimeRemainingSeconds: state.matchTimeRemainingSeconds - 1,
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
        state = state.copyWith(
          opponentPnl: pnl,
          opponentEquity: equity,
          opponentPositionCount: posCount,
        );
        break;

      case 'match_end':
        endMatch();
        break;

      case 'chat_message':
        // Handled by MatchChatNotifier's own wsStream subscription.
        break;
    }
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
        balanceAdjust += p.size + p.pnl(p.liquidationPrice);
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
          balanceAdjust += p.size + p.pnl(p.stopLoss!);
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
          balanceAdjust += p.size + p.pnl(p.takeProfit!);
          changed = true;
          return p;
        }
      }

      return p;
    }).toList();

    if (changed) {
      state = state.copyWith(
        positions: updatedPositions,
        balance: state.balance + balanceAdjust,
      );
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

    // Report to server.
    if (state.matchId != null) {
      _api.wsSend({
        'type': 'open_position',
        'matchId': state.matchId,
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

    final updatedPositions = state.positions.map((p) {
      if (p.id == positionId && p.isOpen) {
        final currentPrice =
            state.currentPrices[p.assetSymbol] ?? p.entryPrice;
        p.exitPrice = currentPrice;
        p.closedAt = now;
        p.closeReason = 'manual';
        balanceReturn = p.size + p.pnl(currentPrice);
      }
      return p;
    }).toList();

    state = state.copyWith(
      positions: updatedPositions,
      balance: state.balance + balanceReturn,
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

  void endMatch() {
    _matchTimer?.cancel();
    _checkTimer?.cancel();
    _wsSubscription?.cancel();
    _priceFeed.stop();

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

    state = state.copyWith(
      positions: updatedPositions,
      balance: state.balance + balanceReturn,
      matchActive: false,
      matchTimeRemainingSeconds: 0,
    );
  }
}

final tradingProvider =
    NotifierProvider<TradingNotifier, TradingState>(TradingNotifier.new);
