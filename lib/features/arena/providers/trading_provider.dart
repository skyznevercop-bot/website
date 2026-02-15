import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
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
  final String? matchWinner;
  final bool matchIsTie;
  final bool matchIsForfeit;

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

  /// Check if the player has an active match on the backend.
  /// If found, populate state so the _ActiveMatchBanner appears on PlayScreen.
  Future<void> checkActiveMatch(String walletAddress) async {
    // Don't overwrite if we already have an active match loaded.
    if (state.matchActive) return;

    try {
      final result = await _api.get('/match/active/$walletAddress');
      final match = result['match'];
      if (match == null) return;

      final matchId = match['matchId'] as String;
      final betAmount = (match['betAmount'] as num?)?.toDouble() ?? 1.0;
      final oppAddress = match['opponentAddress'] as String?;
      final oppTag = match['opponentGamerTag'] as String?;
      final startTime = match['startTime'] as int?;
      final endTime = match['endTime'] as int?;
      final duration = match['duration'] as String? ?? '15m';

      // Parse duration string to seconds.
      int durationSeconds = 900;
      final m = RegExp(r'^(\d+)(m|h)$').firstMatch(duration);
      if (m != null) {
        final value = int.parse(m.group(1)!);
        durationSeconds = m.group(2) == 'h' ? value * 3600 : value * 60;
      }

      // Calculate remaining time.
      int remaining = durationSeconds;
      int? startTimeMs = startTime;
      if (endTime != null) {
        remaining = ((endTime - DateTime.now().millisecondsSinceEpoch) / 1000)
            .round()
            .clamp(0, durationSeconds);
      } else if (startTime != null) {
        final elapsed =
            (DateTime.now().millisecondsSinceEpoch - startTime) ~/ 1000;
        remaining = (durationSeconds - elapsed).clamp(0, durationSeconds);
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
          if (startTimeMs != null) 'st': startTimeMs.toString(),
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
      matchWinner: winner,
      matchIsTie: isTie,
      matchIsForfeit: isForfeit,
    );
  }
}

final tradingProvider =
    NotifierProvider<TradingNotifier, TradingState>(TradingNotifier.new);
