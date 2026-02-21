import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/audio_service.dart';
import '../models/match_event.dart';
import '../models/trading_models.dart';
import '../utils/arena_helpers.dart';
import 'trading_provider.dart';

// =============================================================================
// Match Events Provider — auto-generates live events from trading state changes
// =============================================================================

class MatchEventsState {
  final List<MatchEvent> events;
  final MatchEvent? latestEvent;

  const MatchEventsState({
    this.events = const [],
    this.latestEvent,
  });

  MatchEventsState copyWith({
    List<MatchEvent>? events,
    MatchEvent? latestEvent,
  }) {
    return MatchEventsState(
      events: events ?? this.events,
      latestEvent: latestEvent ?? this.latestEvent,
    );
  }
}

class MatchEventsNotifier extends Notifier<MatchEventsState> {
  int _eventCounter = 0;

  // Cached previous-frame values for diff detection.
  MatchPhase? _prevPhase;
  int _prevLeadChangeCount = 0;
  int _prevConsecutiveWins = 0;
  int _prevClosedCount = 0;
  int _prevOpponentPositionCount = 0;
  double _prevEquity = TradingState.demoBalance;
  bool _wasMatchActive = false;

  // Big move tracking: previous prices and cooldown per asset.
  Map<String, double> _prevPrices = {};
  final Map<String, DateTime> _bigMoveCooldown = {};

  @override
  MatchEventsState build() {
    // Listen to trading state changes and generate events.
    ref.listen(tradingProvider, (prev, next) {
      _onTradingStateChanged(prev, next);
    });
    return const MatchEventsState();
  }

  void _onTradingStateChanged(TradingState? prev, TradingState next) {
    // Don't generate events when match isn't active.
    if (!next.matchActive && !_wasMatchActive) return;

    // Match just started — reset tracking state.
    if (next.matchActive && !_wasMatchActive) {
      _reset();
      _wasMatchActive = true;
      return;
    }

    // Match just ended.
    if (!next.matchActive && _wasMatchActive) {
      _wasMatchActive = false;
      _addEvent(
        EventType.phaseChange,
        'Match over!',
      );
      return;
    }

    // ── Phase change ──
    if (_prevPhase != null && next.matchPhase != _prevPhase) {
      _addEvent(
        EventType.phaseChange,
        '${phaseLabel(next.matchPhase)} begins!',
      );
    }
    _prevPhase = next.matchPhase;

    // ── Lead change ──
    if (next.leadChangeCount > _prevLeadChangeCount) {
      final amLeading = next.wasLeading;
      _addEvent(
        EventType.leadChange,
        amLeading ? 'You took the lead!' : 'Opponent took the lead!',
      );
    }
    _prevLeadChangeCount = next.leadChangeCount;

    // ── Win streak ──
    if (next.consecutiveWins > _prevConsecutiveWins &&
        next.consecutiveWins >= 3) {
      _addEvent(
        EventType.streak,
        '${next.consecutiveWins}-trade win streak!',
      );
    }
    _prevConsecutiveWins = next.consecutiveWins;

    // ── Trade result (position closed) ──
    final closedCount = next.closedPositions.length;
    if (closedCount > _prevClosedCount) {
      final newlyClosed =
          next.closedPositions.take(closedCount - _prevClosedCount);
      for (final p in newlyClosed) {
        final pnl = p.pnl(p.exitPrice ?? p.entryPrice);
        final sign = pnl >= 0 ? '+' : '';
        final reason = p.closeReason == 'liquidation'
            ? 'LIQUIDATED'
            : p.closeReason == 'sl'
                ? 'SL hit'
                : p.closeReason == 'tp'
                    ? 'TP hit'
                    : 'Closed';
        _addEvent(
          p.closeReason == 'liquidation'
              ? EventType.liquidation
              : EventType.tradeResult,
          '$reason ${p.isLong ? "LONG" : "SHORT"} ${p.assetSymbol}: $sign\$${pnl.toStringAsFixed(2)}',
        );
      }
    }
    _prevClosedCount = closedCount;

    // ── Opponent activity ──
    if (next.opponentPositionCount != _prevOpponentPositionCount) {
      if (next.opponentPositionCount > _prevOpponentPositionCount) {
        _addEvent(
          EventType.opponentTrade,
          'Opponent opened a new position',
        );
      } else if (next.opponentPositionCount < _prevOpponentPositionCount) {
        _addEvent(
          EventType.opponentTrade,
          'Opponent closed a position',
        );
      }
    }
    _prevOpponentPositionCount = next.opponentPositionCount;

    // ── Big price moves (>= 2% per asset, 10s cooldown) ──
    final now = DateTime.now();
    for (final entry in next.currentPrices.entries) {
      final symbol = entry.key;
      final price = entry.value;
      final prev = _prevPrices[symbol];
      if (prev != null && prev > 0) {
        final pctChange = (price - prev) / prev * 100;
        if (pctChange.abs() >= 2.0) {
          final cooldownEnd = _bigMoveCooldown[symbol];
          if (cooldownEnd == null || now.isAfter(cooldownEnd)) {
            final direction = pctChange > 0 ? 'surged' : 'dropped';
            final sign = pctChange > 0 ? '+' : '';
            _addEvent(
              EventType.bigMove,
              '$symbol $direction $sign${pctChange.toStringAsFixed(1)}%!',
            );
            _bigMoveCooldown[symbol] = now.add(const Duration(seconds: 10));
            _prevPrices[symbol] = price;
          }
        }
      } else {
        _prevPrices[symbol] = price;
      }
    }

    // ── Portfolio milestones (every 5% ROI change) ──
    // Show the unrealized PnL of open trades instead of a raw ROI percentage,
    // which is confusing when positions are still live.
    final roi = next.myRoiPercent;
    final prevRoi = next.initialBalance > 0
        ? (_prevEquity - next.initialBalance) / next.initialBalance * 100
        : 0.0;
    final currentBucket = (roi / 5).floor();
    final prevBucket = (prevRoi / 5).floor();
    if (currentBucket != prevBucket && currentBucket != 0) {
      final unrealizedPnl = next.totalUnrealizedPnl;
      final openCount = next.openPositions.length;
      if (openCount > 0) {
        // Show open trades PnL — more useful than a raw ROI %.
        final sign = unrealizedPnl >= 0 ? '+' : '';
        _addEvent(
          EventType.milestone,
          'Open trades: $sign\$${unrealizedPnl.toStringAsFixed(0)} ($openCount pos.)',
        );
      } else {
        // No open positions — show realized portfolio ROI.
        final roiStr = roi.toStringAsFixed(1);
        _addEvent(
          EventType.milestone,
          roi > 0 ? 'Portfolio: +$roiStr%' : 'Portfolio: $roiStr%',
        );
      }
    }
    _prevEquity = next.equity;
  }

  void _addEvent(EventType type, String message) {
    _eventCounter++;
    final event = MatchEvent(
      id: 'evt_$_eventCounter',
      type: type,
      message: message,
      timestamp: DateTime.now(),
      icon: eventIcon(type),
      color: eventColor(type),
    );

    // Play sound for the event.
    final audio = AudioService.instance;
    switch (type) {
      case EventType.phaseChange:
        audio.playPhaseChange();
      case EventType.leadChange:
        audio.playLeadChange();
      case EventType.streak:
        audio.playStreak();
      case EventType.tradeResult:
        // Win or loss determined by message content.
        if (message.contains('+')) {
          audio.playWin();
        } else {
          audio.playLoss();
        }
      case EventType.liquidation:
        audio.playLiquidation();
      case EventType.milestone:
        audio.playMilestone();
      case EventType.bigMove:
        audio.playPhaseChange();
      case EventType.opponentTrade:
        break; // No sound for opponent activity.
    }

    // Keep rolling list of last 50 events.
    final updated = [...state.events, event];
    if (updated.length > 50) {
      updated.removeRange(0, updated.length - 50);
    }

    state = MatchEventsState(
      events: updated,
      latestEvent: event,
    );
  }

  void _reset() {
    _eventCounter = 0;
    _prevPhase = null;
    _prevLeadChangeCount = 0;
    _prevConsecutiveWins = 0;
    _prevClosedCount = 0;
    _prevOpponentPositionCount = 0;
    _prevEquity = TradingState.demoBalance;
    _prevPrices = {};
    _bigMoveCooldown.clear();
    state = const MatchEventsState();
  }

  /// Clear the latest event (after toast is dismissed).
  void dismissLatest() {
    state = state.copyWith(latestEvent: state.latestEvent);
  }
}

final matchEventsProvider =
    NotifierProvider<MatchEventsNotifier, MatchEventsState>(
        MatchEventsNotifier.new);
