import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/services/api_client.dart';
import '../models/trading_models.dart';

/// Provides real-time crypto prices.
///
/// When backend is connected: receives prices via WebSocket.
/// Fallback: CoinGecko / Binance / random walk (same as before).
class PriceFeedNotifier extends Notifier<Map<String, double>> {
  Timer? _pollTimer;
  StreamSubscription? _wsSubscription;
  final Random _random = Random();
  final Map<String, double> _lastKnown = {};
  bool _useBinanceFallback = false;

  static const _corsProxy = 'https://corsproxy.io/?';

  final _api = ApiClient.instance;

  @override
  Map<String, double> build() {
    ref.onDispose(() {
      _pollTimer?.cancel();
      _wsSubscription?.cancel();
    });
    return {};
  }

  void start() {
    // Try WebSocket price feed first.
    if (_api.isWsConnected) {
      _wsSubscription?.cancel();
      _wsSubscription = _api.wsStream
          .where((data) => data['type'] == 'price_update')
          .listen((data) {
        final prices = <String, double>{};
        if (data['btc'] != null) {
          prices['BTC'] = (data['btc'] as num).toDouble();
        }
        if (data['eth'] != null) {
          prices['ETH'] = (data['eth'] as num).toDouble();
        }
        if (data['sol'] != null) {
          prices['SOL'] = (data['sol'] as num).toDouble();
        }
        if (prices.isNotEmpty) {
          _lastKnown.addAll(prices);
          state = prices;
        }
      });
    }

    // Also poll as fallback (if WS disconnects or for initial data).
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_api.isWsConnected) {
        _fetchPrices();
      }
    });
    _fetchPrices();
  }

  void stop() {
    _pollTimer?.cancel();
    _wsSubscription?.cancel();
  }

  Future<void> _fetchPrices() async {
    if (_useBinanceFallback) {
      await _fetchFromBinance();
    } else {
      await _fetchFromCoinGecko();
    }
  }

  Future<void> _fetchFromCoinGecko() async {
    try {
      final ids = TradingAsset.all.map((a) => a.coingeckoId).join(',');
      final targetUrl =
          'https://api.coingecko.com/api/v3/simple/price'
          '?ids=$ids&vs_currencies=usd';
      final uri = Uri.parse(
        kIsWeb ? '$_corsProxy${Uri.encodeComponent(targetUrl)}' : targetUrl,
      );
      final response = await http.get(uri).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final newPrices = Map<String, double>.from(state);

        for (final asset in TradingAsset.all) {
          final entry = data[asset.coingeckoId] as Map<String, dynamic>?;
          if (entry != null && entry['usd'] != null) {
            final price = (entry['usd'] as num).toDouble();
            newPrices[asset.symbol] = price;
            _lastKnown[asset.symbol] = price;
          }
        }

        state = newPrices;
        return;
      }

      if (response.statusCode == 429) {
        _useBinanceFallback = true;
        await _fetchFromBinance();
        return;
      }

      _simulateFallback();
    } catch (e) {
      debugPrint('CoinGecko unavailable, trying Binance');
      await _fetchFromBinance();
    }
  }

  Future<void> _fetchFromBinance() async {
    try {
      final futures = TradingAsset.all.map((asset) async {
        final targetUrl =
            'https://api.binance.com/api/v3/ticker/price'
            '?symbol=${asset.binanceSymbol}';
        final uri = Uri.parse(
          kIsWeb ? '$_corsProxy${Uri.encodeComponent(targetUrl)}' : targetUrl,
        );
        final response = await http.get(uri).timeout(
          const Duration(seconds: 5),
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return MapEntry(
            asset.symbol,
            double.parse(data['price'] as String),
          );
        }
        return null;
      });

      final results = await Future.wait(futures);
      final newPrices = Map<String, double>.from(state);
      bool gotAny = false;

      for (final entry in results) {
        if (entry != null) {
          newPrices[entry.key] = entry.value;
          _lastKnown[entry.key] = entry.value;
          gotAny = true;
        }
      }

      if (gotAny) {
        state = newPrices;
      } else {
        _simulateFallback();
      }
    } catch (e) {
      debugPrint('Binance unavailable, using price simulation');
      _simulateFallback();
    }
  }

  void _simulateFallback() {
    final newPrices = Map<String, double>.from(state);
    for (final asset in TradingAsset.all) {
      final current = _lastKnown[asset.symbol] ?? asset.basePrice;
      final drift = (asset.basePrice - current) * 0.0001;
      final noise =
          current * asset.volatility * (_random.nextDouble() * 2 - 1);
      final newPrice = current + drift + noise;
      _lastKnown[asset.symbol] = newPrice;
      newPrices[asset.symbol] = newPrice;
    }
    state = newPrices;
  }
}

final priceFeedProvider =
    NotifierProvider<PriceFeedNotifier, Map<String, double>>(
        PriceFeedNotifier.new);
