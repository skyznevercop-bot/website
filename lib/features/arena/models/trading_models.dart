/// Tradeable asset definition with symbol info and chart mapping.
class TradingAsset {
  final String symbol;
  final String name;
  final String tvSymbol; // TradingView chart symbol
  final String binanceSymbol; // Binance API symbol
  final String coingeckoId; // CoinGecko API id
  final double basePrice; // Fallback price before live feed connects
  final double maxLeverage;

  const TradingAsset({
    required this.symbol,
    required this.name,
    required this.tvSymbol,
    required this.binanceSymbol,
    required this.coingeckoId,
    required this.basePrice,
    this.maxLeverage = 20,
  });

  static const List<TradingAsset> all = [
    TradingAsset(
      symbol: 'BTC',
      name: 'Bitcoin',
      tvSymbol: 'BINANCE:BTCUSDT',
      binanceSymbol: 'BTCUSDT',
      coingeckoId: 'bitcoin',
      basePrice: 66000,
      maxLeverage: 100,
    ),
    TradingAsset(
      symbol: 'ETH',
      name: 'Ethereum',
      tvSymbol: 'BINANCE:ETHUSDT',
      binanceSymbol: 'ETHUSDT',
      coingeckoId: 'ethereum',
      basePrice: 2000,
      maxLeverage: 100,
    ),
    TradingAsset(
      symbol: 'SOL',
      name: 'Solana',
      tvSymbol: 'BINANCE:SOLUSDT',
      binanceSymbol: 'SOLUSDT',
      coingeckoId: 'solana',
      basePrice: 80,
      maxLeverage: 100,
    ),
  ];
}

/// Represents an open or closed trading position.
class Position {
  final String id;
  final String assetSymbol;
  final bool isLong;
  final double entryPrice;
  final double size; // margin in USDC
  final double leverage;
  final DateTime openedAt;
  final double? stopLoss;
  final double? takeProfit;
  double? exitPrice;
  DateTime? closedAt;
  String? closeReason; // 'manual', 'sl', 'tp', 'liquidation', 'match_end'

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
    this.exitPrice,
    this.closedAt,
    this.closeReason,
  });

  bool get isOpen => closedAt == null;

  /// Notional position value.
  double get notional => size * leverage;

  /// Margin used = size.
  double get margin => size;

  /// Calculate unrealized or realized P&L.
  double pnl(double currentPrice) {
    final exit = exitPrice ?? currentPrice;
    final priceChange = (exit - entryPrice) / entryPrice;
    final direction = isLong ? 1.0 : -1.0;
    return size * leverage * priceChange * direction;
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
