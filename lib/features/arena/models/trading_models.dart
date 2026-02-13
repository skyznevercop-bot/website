/// Tradeable asset definition with base price, symbol info, and chart mapping.
class TradingAsset {
  final String symbol;
  final String name;
  final String tvSymbol; // TradingView chart symbol
  final String binanceSymbol; // Binance API symbol
  final String coingeckoId; // CoinGecko API id
  final double basePrice;
  final double volatility;
  final double maxLeverage;

  const TradingAsset({
    required this.symbol,
    required this.name,
    required this.tvSymbol,
    required this.binanceSymbol,
    required this.coingeckoId,
    required this.basePrice,
    required this.volatility,
    this.maxLeverage = 20,
  });

  static const List<TradingAsset> all = [
    TradingAsset(
      symbol: 'BTC',
      name: 'Bitcoin',
      tvSymbol: 'BINANCE:BTCUSDT',
      binanceSymbol: 'BTCUSDT',
      coingeckoId: 'bitcoin',
      basePrice: 97500,
      volatility: 0.0018,
      maxLeverage: 50,
    ),
    TradingAsset(
      symbol: 'ETH',
      name: 'Ethereum',
      tvSymbol: 'BINANCE:ETHUSDT',
      binanceSymbol: 'ETHUSDT',
      coingeckoId: 'ethereum',
      basePrice: 3850,
      volatility: 0.0022,
      maxLeverage: 50,
    ),
    TradingAsset(
      symbol: 'SOL',
      name: 'Solana',
      tvSymbol: 'BINANCE:SOLUSDT',
      binanceSymbol: 'SOLUSDT',
      coingeckoId: 'solana',
      basePrice: 178,
      volatility: 0.0030,
      maxLeverage: 50,
    ),
  ];
}

/// A single price data point for charting.
class PricePoint {
  final DateTime time;
  final double price;

  const PricePoint({required this.time, required this.price});
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
