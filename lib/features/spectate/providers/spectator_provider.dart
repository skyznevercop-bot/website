import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../arena/models/chat_message.dart';
import '../../arena/models/match_event.dart';
import '../models/spectator_models.dart';
import '../services/spectator_ws.dart';

// =============================================================================
// Spectator Provider — manages spectator WS connection + state
// =============================================================================

final spectatorProvider =
    NotifierProvider<SpectatorNotifier, SpectatorState>(SpectatorNotifier.new);

class SpectatorNotifier extends Notifier<SpectatorState> {
  SpectatorWs? _ws;
  StreamSubscription? _wsSub;
  Timer? _countdownTimer;

  // State for event generation
  double _prevP1Roi = 0;
  double _prevP2Roi = 0;
  bool _p1WasLeading = false;
  int _eventCounter = 0;

  @override
  SpectatorState build() => const SpectatorState();

  /// Start spectating a match by connecting a dedicated WebSocket.
  void startSpectating(String matchId) {
    stopSpectating();

    state = SpectatorState(matchId: matchId, isLoading: true);

    _ws = SpectatorWs();
    _wsSub = _ws!.stream.listen(_handleMessage);
    _ws!.connect(matchId);
  }

  /// Stop spectating and clean up resources.
  void stopSpectating() {
    _countdownTimer?.cancel();
    _wsSub?.cancel();
    _ws?.dispose();
    _ws = null;
    _wsSub = null;
    _countdownTimer = null;
    _prevP1Roi = 0;
    _prevP2Roi = 0;
    _p1WasLeading = false;
    _eventCounter = 0;
    state = const SpectatorState();
  }

  void _handleMessage(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == null) return;

    switch (type) {
      case 'spectator_snapshot':
        _handleSnapshot(data);
        break;
      case 'spectator_update':
        _handleUpdate(data);
        break;
      case 'price_update':
        _handlePriceUpdate(data);
        break;
      case 'chat_message':
        _handleChat(data);
        break;
      case 'match_end':
        _handleMatchEnd(data);
        break;
      case 'opponent_disconnected':
      case 'opponent_reconnected':
        _handleConnectionEvent(data);
        break;
    }
  }

  List<SpectatorPosition> _parsePositions(Map<String, dynamic> player) {
    final list = player['positions'] as List<dynamic>?;
    if (list == null) return const [];
    return list
        .map((p) => SpectatorPosition.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  void _handleSnapshot(Map<String, dynamic> data) {
    final p1 = data['player1'] as Map<String, dynamic>? ?? {};
    final p2 = data['player2'] as Map<String, dynamic>? ?? {};

    final endTime = data['endTime'] as int? ?? 0;
    final startTime = data['startTime'] as int? ?? 0;
    final durationMs = endTime - startTime;
    final durationSeconds = (durationMs / 1000).round().clamp(0, 86400);

    final remaining =
        ((endTime - DateTime.now().millisecondsSinceEpoch) / 1000)
            .round()
            .clamp(0, durationSeconds);

    final prices = data['prices'] as Map<String, dynamic>? ?? {};
    final status = data['status'] as String? ?? 'active';
    final isEnded = status != 'active';

    state = state.copyWith(
      matchId: data['matchId'] as String? ?? state.matchId,
      player1: SpectatorPlayer(
        address: p1['address'] as String? ?? '',
        gamerTag: p1['gamerTag'] as String? ?? 'Player 1',
        roi: (p1['roi'] as num?)?.toDouble() ?? 0,
        equity: (p1['equity'] as num?)?.toDouble() ?? 1000000,
        positionCount: (p1['positionCount'] as num?)?.toInt() ?? 0,
        positions: _parsePositions(p1),
      ),
      player2: SpectatorPlayer(
        address: p2['address'] as String? ?? '',
        gamerTag: p2['gamerTag'] as String? ?? 'Player 2',
        roi: (p2['roi'] as num?)?.toDouble() ?? 0,
        equity: (p2['equity'] as num?)?.toDouble() ?? 1000000,
        positionCount: (p2['positionCount'] as num?)?.toInt() ?? 0,
        positions: _parsePositions(p2),
      ),
      spectatorCount: (data['spectatorCount'] as num?)?.toInt() ?? 0,
      durationSeconds: durationSeconds,
      matchTimeRemainingSeconds: remaining,
      betAmount: (data['betAmount'] as num?)?.toDouble() ?? 0,
      endTime: endTime,
      matchEnded: isEnded,
      winner: data['winner'] as String?,
      prices: {
        'BTC': (prices['btc'] as num?)?.toDouble() ?? 0,
        'ETH': (prices['eth'] as num?)?.toDouble() ?? 0,
        'SOL': (prices['sol'] as num?)?.toDouble() ?? 0,
      },
      isConnected: true,
      isLoading: false,
    );

    _prevP1Roi = state.player1.roi;
    _prevP2Roi = state.player2.roi;
    _p1WasLeading = state.player1.roi > state.player2.roi;

    // Start countdown timer.
    if (!isEnded) {
      _startCountdown();
    }

    // Add a system event.
    _addEvent(EventType.phaseChange, 'You joined as a spectator');
  }

  void _handleUpdate(Map<String, dynamic> data) {
    final p1 = data['player1'] as Map<String, dynamic>? ?? {};
    final p2 = data['player2'] as Map<String, dynamic>? ?? {};

    final newP1Roi = (p1['roi'] as num?)?.toDouble() ?? state.player1.roi;
    final newP2Roi = (p2['roi'] as num?)?.toDouble() ?? state.player2.roi;

    final p1Positions = p1.containsKey('positions')
        ? _parsePositions(p1)
        : state.player1.positions;
    final p2Positions = p2.containsKey('positions')
        ? _parsePositions(p2)
        : state.player2.positions;

    state = state.copyWith(
      player1: state.player1.copyWith(
        roi: newP1Roi,
        equity: (p1['equity'] as num?)?.toDouble() ?? state.player1.equity,
        positionCount: (p1['positionCount'] as num?)?.toInt() ??
            state.player1.positionCount,
        positions: p1Positions,
      ),
      player2: state.player2.copyWith(
        roi: newP2Roi,
        equity: (p2['equity'] as num?)?.toDouble() ?? state.player2.equity,
        positionCount: (p2['positionCount'] as num?)?.toInt() ??
            state.player2.positionCount,
        positions: p2Positions,
      ),
      spectatorCount: (data['spectatorCount'] as num?)?.toInt() ??
          state.spectatorCount,
    );

    // Generate events from state changes.
    _generateEvents(newP1Roi, newP2Roi);

    _prevP1Roi = newP1Roi;
    _prevP2Roi = newP2Roi;
  }

  void _handlePriceUpdate(Map<String, dynamic> data) {
    state = state.copyWith(
      prices: {
        'BTC': (data['btc'] as num?)?.toDouble() ?? state.prices['BTC']!,
        'ETH': (data['eth'] as num?)?.toDouble() ?? state.prices['ETH']!,
        'SOL': (data['sol'] as num?)?.toDouble() ?? state.prices['SOL']!,
      },
    );
  }

  void _handleChat(Map<String, dynamic> data) {
    final msg = ChatMessage(
      id: 'chat_${DateTime.now().millisecondsSinceEpoch}',
      senderTag: data['senderTag'] as String? ?? 'Unknown',
      content: data['content'] as String? ?? '',
      timestamp: DateTime.now(),
      isMe: false, // Spectators are never the sender
      isSystem: false,
    );
    state = state.copyWith(
      chatMessages: [...state.chatMessages, msg].length > 100
          ? [...state.chatMessages, msg]
              .sublist([...state.chatMessages, msg].length - 100)
          : [...state.chatMessages, msg],
    );
  }

  void _handleMatchEnd(Map<String, dynamic> data) {
    _countdownTimer?.cancel();

    final p1Roi = (data['p1Roi'] as num?)?.toDouble() ?? state.player1.roi;
    final p2Roi = (data['p2Roi'] as num?)?.toDouble() ?? state.player2.roi;

    state = state.copyWith(
      matchEnded: true,
      winner: data['winner'] as String?,
      isTie: data['isTie'] as bool? ?? false,
      isForfeit: data['isForfeit'] as bool? ?? false,
      matchTimeRemainingSeconds: 0,
      player1: state.player1.copyWith(roi: p1Roi),
      player2: state.player2.copyWith(roi: p2Roi),
    );

    final isTie = data['isTie'] as bool? ?? false;
    final winner = data['winner'] as String?;
    if (isTie) {
      _addEvent(EventType.phaseChange, 'Match ended in a TIE!');
    } else if (winner == state.player1.address) {
      _addEvent(
          EventType.phaseChange, '${state.player1.gamerTag} wins the match!');
    } else {
      _addEvent(
          EventType.phaseChange, '${state.player2.gamerTag} wins the match!');
    }
  }

  void _handleConnectionEvent(Map<String, dynamic> data) {
    final type = data['type'] as String;
    final player = data['player'] as String? ?? '';
    final isP1 = player == state.player1.address;
    final tag = isP1 ? state.player1.gamerTag : state.player2.gamerTag;

    if (type == 'opponent_disconnected') {
      _addEvent(EventType.phaseChange, '$tag disconnected');
    } else {
      _addEvent(EventType.phaseChange, '$tag reconnected');
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.endTime == null || state.matchEnded) {
        _countdownTimer?.cancel();
        return;
      }
      final remaining =
          ((state.endTime! - DateTime.now().millisecondsSinceEpoch) / 1000)
              .round()
              .clamp(0, state.durationSeconds);
      state = state.copyWith(matchTimeRemainingSeconds: remaining);

      if (remaining <= 0 && !state.matchEnded) {
        _countdownTimer?.cancel();
      }
    });
  }

  void _generateEvents(double newP1Roi, double newP2Roi) {
    final p1Leading = newP1Roi > newP2Roi;
    final wasTied = (_prevP1Roi - _prevP2Roi).abs() < 0.01;
    final isTied = (newP1Roi - newP2Roi).abs() < 0.01;

    // Lead change detection.
    if (!isTied && !wasTied && p1Leading != _p1WasLeading) {
      final leader =
          p1Leading ? state.player1.gamerTag : state.player2.gamerTag;
      _addEvent(EventType.leadChange, '$leader takes the lead!');
      _p1WasLeading = p1Leading;
    }

    // Big ROI swing (5%+ change from previous update).
    final p1Delta = (newP1Roi - _prevP1Roi).abs();
    final p2Delta = (newP2Roi - _prevP2Roi).abs();
    if (p1Delta >= 5) {
      final dir = newP1Roi > _prevP1Roi ? 'surges' : 'drops';
      _addEvent(EventType.milestone,
          '${state.player1.gamerTag} $dir to ${newP1Roi.toStringAsFixed(2)}%');
    }
    if (p2Delta >= 5) {
      final dir = newP2Roi > _prevP2Roi ? 'surges' : 'drops';
      _addEvent(EventType.milestone,
          '${state.player2.gamerTag} $dir to ${newP2Roi.toStringAsFixed(2)}%');
    }
  }

  void _addEvent(EventType type, String message) {
    _eventCounter++;
    final event = MatchEvent(
      id: 'spec_evt_$_eventCounter',
      type: type,
      message: message,
      timestamp: DateTime.now(),
    );
    final events = [...state.events, event];
    state = state.copyWith(
      events: events.length > 50 ? events.sublist(events.length - 50) : events,
    );
  }
}
