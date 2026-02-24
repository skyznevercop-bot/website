import '../../arena/models/chat_message.dart';
import '../../arena/models/match_event.dart';

/// An open position visible to spectators.
class SpectatorPosition {
  final String asset;
  final bool isLong;
  final double leverage;
  final double size;
  final double entryPrice;
  final double pnl;

  const SpectatorPosition({
    required this.asset,
    required this.isLong,
    required this.leverage,
    required this.size,
    required this.entryPrice,
    this.pnl = 0,
  });

  factory SpectatorPosition.fromJson(Map<String, dynamic> json) {
    return SpectatorPosition(
      asset: json['asset'] as String? ?? '',
      isLong: json['isLong'] as bool? ?? true,
      leverage: (json['leverage'] as num?)?.toDouble() ?? 1,
      size: (json['size'] as num?)?.toDouble() ?? 0,
      entryPrice: (json['entryPrice'] as num?)?.toDouble() ?? 0,
      pnl: (json['pnl'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Player stats visible to spectators, including open positions.
class SpectatorPlayer {
  final String address;
  final String gamerTag;
  final double roi;
  final double equity;
  final int positionCount;
  final List<SpectatorPosition> positions;

  const SpectatorPlayer({
    required this.address,
    required this.gamerTag,
    this.roi = 0,
    this.equity = 1000000,
    this.positionCount = 0,
    this.positions = const [],
  });

  SpectatorPlayer copyWith({
    String? address,
    String? gamerTag,
    double? roi,
    double? equity,
    int? positionCount,
    List<SpectatorPosition>? positions,
  }) {
    return SpectatorPlayer(
      address: address ?? this.address,
      gamerTag: gamerTag ?? this.gamerTag,
      roi: roi ?? this.roi,
      equity: equity ?? this.equity,
      positionCount: positionCount ?? this.positionCount,
      positions: positions ?? this.positions,
    );
  }
}

/// Full spectator state for a live match.
class SpectatorState {
  final String matchId;
  final SpectatorPlayer player1;
  final SpectatorPlayer player2;
  final int spectatorCount;
  final int matchTimeRemainingSeconds;
  final int durationSeconds;
  final double betAmount;
  final bool matchEnded;
  final String? winner;
  final bool isTie;
  final bool isForfeit;
  final Map<String, double> prices;
  final List<ChatMessage> chatMessages;
  final List<MatchEvent> events;
  final bool isConnected;
  final bool isLoading;
  final int? endTime;

  const SpectatorState({
    this.matchId = '',
    this.player1 = const SpectatorPlayer(address: '', gamerTag: 'Player 1'),
    this.player2 = const SpectatorPlayer(address: '', gamerTag: 'Player 2'),
    this.spectatorCount = 0,
    this.matchTimeRemainingSeconds = 0,
    this.durationSeconds = 0,
    this.betAmount = 0,
    this.matchEnded = false,
    this.winner,
    this.isTie = false,
    this.isForfeit = false,
    this.prices = const {'BTC': 0, 'ETH': 0, 'SOL': 0},
    this.chatMessages = const [],
    this.events = const [],
    this.isConnected = false,
    this.isLoading = true,
    this.endTime,
  });

  SpectatorState copyWith({
    String? matchId,
    SpectatorPlayer? player1,
    SpectatorPlayer? player2,
    int? spectatorCount,
    int? matchTimeRemainingSeconds,
    int? durationSeconds,
    double? betAmount,
    bool? matchEnded,
    String? winner,
    bool? isTie,
    bool? isForfeit,
    Map<String, double>? prices,
    List<ChatMessage>? chatMessages,
    List<MatchEvent>? events,
    bool? isConnected,
    bool? isLoading,
    int? endTime,
  }) {
    return SpectatorState(
      matchId: matchId ?? this.matchId,
      player1: player1 ?? this.player1,
      player2: player2 ?? this.player2,
      spectatorCount: spectatorCount ?? this.spectatorCount,
      matchTimeRemainingSeconds:
          matchTimeRemainingSeconds ?? this.matchTimeRemainingSeconds,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      betAmount: betAmount ?? this.betAmount,
      matchEnded: matchEnded ?? this.matchEnded,
      winner: winner ?? this.winner,
      isTie: isTie ?? this.isTie,
      isForfeit: isForfeit ?? this.isForfeit,
      prices: prices ?? this.prices,
      chatMessages: chatMessages ?? this.chatMessages,
      events: events ?? this.events,
      isConnected: isConnected ?? this.isConnected,
      isLoading: isLoading ?? this.isLoading,
      endTime: endTime ?? this.endTime,
    );
  }
}
