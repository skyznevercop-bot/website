/// Match phase system — drives UI intensity and announcements.
enum MatchPhase {
  intro,        // 3-2-1 countdown (first 5 seconds)
  openingBell,  // First 20% of match
  midGame,      // 20-70% of match
  finalSprint,  // 70-90% — amber urgency
  lastStand,    // Final 10% — red, maximum intensity
  ended,        // Match over
}

/// Post-match statistics computed when the game ends.
class MatchStats {
  final int totalTrades;
  final int winningTrades;
  final int losingTrades;
  final double winRate;
  final double bestTradePnl;
  final double worstTradePnl;
  final String? bestTradeAsset;
  final String? worstTradeAsset;
  final double totalVolume; // Sum of notional values
  final double peakEquity;
  final double maxDrawdown; // Percentage from peak
  final double finalEquity;
  final double roi;
  final Map<String, int> assetBreakdown; // Symbol → trade count
  final double avgLeverage;
  final int longsCount;
  final int shortsCount;
  final Duration? longestHold;
  final Duration? avgHoldTime;

  // v2 additions
  final int leadChanges;
  final double biggestSwing;     // Largest single-trade PnL (absolute)
  final String? mvpAsset;        // Most traded asset
  final int hotStreak;           // Longest consecutive winning trades

  const MatchStats({
    this.totalTrades = 0,
    this.winningTrades = 0,
    this.losingTrades = 0,
    this.winRate = 0,
    this.bestTradePnl = 0,
    this.worstTradePnl = 0,
    this.bestTradeAsset,
    this.worstTradeAsset,
    this.totalVolume = 0,
    this.peakEquity = 0,
    this.maxDrawdown = 0,
    this.finalEquity = 0,
    this.roi = 0,
    this.assetBreakdown = const {},
    this.avgLeverage = 0,
    this.longsCount = 0,
    this.shortsCount = 0,
    this.longestHold,
    this.avgHoldTime,
    this.leadChanges = 0,
    this.biggestSwing = 0,
    this.mvpAsset,
    this.hotStreak = 0,
  });

  /// Compute stats from a list of closed positions and match data.
  factory MatchStats.compute({
    required List<Position> positions,
    required double initialBalance,
    required double finalBalance,
    required double peakEquity,
  }) {
    final closed = positions.where((p) => !p.isOpen).toList();
    if (closed.isEmpty) {
      return MatchStats(
        finalEquity: finalBalance,
        peakEquity: peakEquity,
        roi: initialBalance > 0
            ? (finalBalance - initialBalance) / initialBalance * 100
            : 0,
      );
    }

    final winning = <Position>[];
    final losing = <Position>[];
    double bestPnl = double.negativeInfinity;
    double worstPnl = double.infinity;
    String? bestAsset;
    String? worstAsset;
    double totalVol = 0;
    double totalLev = 0;
    int longs = 0;
    int shorts = 0;
    final assets = <String, int>{};
    Duration? longest;
    Duration totalHold = Duration.zero;
    double biggestSwing = 0;
    int currentStreak = 0;
    int bestStreak = 0;

    for (final p in closed) {
      final pnl = p.pnl(p.exitPrice ?? p.entryPrice);
      if (pnl >= 0) {
        winning.add(p);
        currentStreak++;
        if (currentStreak > bestStreak) bestStreak = currentStreak;
      } else {
        losing.add(p);
        currentStreak = 0;
      }
      if (pnl.abs() > biggestSwing) biggestSwing = pnl.abs();
      if (pnl > bestPnl) {
        bestPnl = pnl;
        bestAsset = p.assetSymbol;
      }
      if (pnl < worstPnl) {
        worstPnl = pnl;
        worstAsset = p.assetSymbol;
      }
      totalVol += p.notional;
      totalLev += p.leverage;
      if (p.isLong) {
        longs++;
      } else {
        shorts++;
      }
      assets[p.assetSymbol] = (assets[p.assetSymbol] ?? 0) + 1;

      if (p.closedAt != null) {
        final hold = p.closedAt!.difference(p.openedAt);
        totalHold += hold;
        if (longest == null || hold > longest) longest = hold;
      }
    }

    // MVP asset = most traded
    String? mvpAsset;
    if (assets.isNotEmpty) {
      mvpAsset = assets.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    }

    final roi = initialBalance > 0
        ? (finalBalance - initialBalance) / initialBalance * 100
        : 0.0;
    final drawdownPct = peakEquity > 0
        ? ((peakEquity - finalBalance).clamp(0, double.infinity) /
            peakEquity *
            100)
        : 0.0;

    return MatchStats(
      totalTrades: closed.length,
      winningTrades: winning.length,
      losingTrades: losing.length,
      winRate:
          closed.isNotEmpty ? (winning.length / closed.length * 100) : 0,
      bestTradePnl: bestPnl == double.negativeInfinity ? 0 : bestPnl,
      worstTradePnl: worstPnl == double.infinity ? 0 : worstPnl,
      bestTradeAsset: bestAsset,
      worstTradeAsset: worstAsset,
      totalVolume: totalVol,
      peakEquity: peakEquity,
      maxDrawdown: drawdownPct,
      finalEquity: finalBalance,
      roi: roi,
      assetBreakdown: assets,
      avgLeverage: closed.isNotEmpty ? totalLev / closed.length : 0,
      longsCount: longs,
      shortsCount: shorts,
      longestHold: longest,
      avgHoldTime:
          closed.isNotEmpty
              ? Duration(
                  milliseconds: totalHold.inMilliseconds ~/ closed.length)
              : null,
      biggestSwing: biggestSwing,
      mvpAsset: mvpAsset,
      hotStreak: bestStreak,
    );
  }
}

/// Tradeable asset definition with symbol info for chart and price feeds.
class TradingAsset {
  final String symbol;
  final String name;
  final String binanceSymbol; // Binance-style symbol (e.g. 'BTCUSDT') — used as chart key
  final String coinbaseProductId; // Coinbase product ID (e.g. 'BTC-USD')
  final String coingeckoId; // CoinGecko API id
  final double basePrice; // Fallback price before live feed connects
  final double maxLeverage;

  const TradingAsset({
    required this.symbol,
    required this.name,
    required this.binanceSymbol,
    required this.coinbaseProductId,
    required this.coingeckoId,
    required this.basePrice,
    this.maxLeverage = 20,
  });

  static const List<TradingAsset> all = [
    TradingAsset(
      symbol: 'BTC',
      name: 'Bitcoin',
      binanceSymbol: 'BTCUSDT',
      coinbaseProductId: 'BTC-USD',
      coingeckoId: 'bitcoin',
      basePrice: 66000,
      maxLeverage: 100,
    ),
    TradingAsset(
      symbol: 'ETH',
      name: 'Ethereum',
      binanceSymbol: 'ETHUSDT',
      coinbaseProductId: 'ETH-USD',
      coingeckoId: 'ethereum',
      basePrice: 2000,
      maxLeverage: 100,
    ),
    TradingAsset(
      symbol: 'SOL',
      name: 'Solana',
      binanceSymbol: 'SOLUSDT',
      coinbaseProductId: 'SOL-USD',
      coingeckoId: 'solana',
      basePrice: 80,
      maxLeverage: 100,
    ),
  ];
}

/// A pending limit order waiting to trigger at a target price.
class LimitOrder {
  final String id;
  final String assetSymbol;
  final bool isLong;
  final double limitPrice;
  final double size;
  final double leverage;
  final double? stopLoss;
  final double? takeProfit;
  final double? trailingStopDistance;
  final DateTime createdAt;

  const LimitOrder({
    required this.id,
    required this.assetSymbol,
    required this.isLong,
    required this.limitPrice,
    required this.size,
    required this.leverage,
    this.stopLoss,
    this.takeProfit,
    this.trailingStopDistance,
    required this.createdAt,
  });
}

/// Represents an open or closed trading position.
class Position {
  final String id;
  final String assetSymbol;
  final bool isLong;
  double entryPrice; // mutable for server reconciliation
  double size; // margin in USDC (mutable for partial close)
  final double leverage;
  final DateTime openedAt;
  double? stopLoss;
  double? takeProfit;
  final double? trailingStopDistance;
  /// Peak favorable price since open — used for trailing stop calculation.
  double? trailingPeakPrice;
  double? exitPrice;
  DateTime? closedAt;
  String? closeReason; // 'manual', 'sl', 'tp', 'liquidation', 'match_end', 'partial'

  Position({
    required this.id,
    required this.assetSymbol,
    required this.isLong,
    required this.entryPrice,
    required this.size,
    required this.leverage,
    required this.openedAt,
    this.stopLoss,
    this.takeProfit,
    this.trailingStopDistance,
    this.trailingPeakPrice,
    this.exitPrice,
    this.closedAt,
    this.closeReason,
  });

  bool get isOpen => closedAt == null;

  /// Notional position value.
  double get notional => size * leverage;

  /// Margin used = size.
  double get margin => size;

  /// Calculate unrealized or realized P&L (capped at -size, matching server).
  double pnl(double currentPrice) {
    final exit = exitPrice ?? currentPrice;
    final priceChange = (exit - entryPrice) / entryPrice;
    final direction = isLong ? 1.0 : -1.0;
    final raw = size * leverage * priceChange * direction;
    return raw.clamp(-size, double.infinity);
  }

  /// P&L as a percentage of margin.
  double pnlPercent(double currentPrice) {
    final exit = exitPrice ?? currentPrice;
    final priceChange = (exit - entryPrice) / entryPrice;
    final direction = isLong ? 1.0 : -1.0;
    return priceChange * direction * leverage * 100;
  }

  /// Liquidation price (simplified: lose 90% of margin).
  double get liquidationPrice {
    final marginRatio = 1.0 / leverage;
    if (isLong) {
      return entryPrice * (1 - marginRatio * 0.9);
    } else {
      return entryPrice * (1 + marginRatio * 0.9);
    }
  }
}
