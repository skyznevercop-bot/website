import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

import '../../../core/services/api_client.dart';
import '../models/trading_models.dart';

/// Provides real-time crypto prices via multiple sources.
///
/// 1. Binance WebSocket aggTrade stream (real-time, fires on every trade).
/// 2. CoinGecko REST API polling (CORS-friendly, no proxy needed).
/// 3. Backend WebSocket relay (if connected).
///
/// Incoming WS prices are buffered and flushed every 250ms to avoid
/// excessive UI rebuilds while staying responsive.
class PriceFeedNotifier extends Notifier<Map<String, double>> {
  web.WebSocket? _binanceWs;
  Timer? _reconnectTimer;
  Timer? _pollTimer;
  Timer? _flushTimer;
  StreamSubscription? _backendWsSub;
  int _reconnectAttempts = 0;
  bool _started = false;
  bool _wsConnected = false;

  /// Buffer for incoming WS prices — flushed to state periodically.
  final Map<String, double> _priceBuffer = {};

  static const _flushInterval = Duration(milliseconds: 250);

  /// Map Binance trading pair symbols to our asset symbols.
  static final _symbolMap = {
    for (final a in TradingAsset.all) a.binanceSymbol: a.symbol,
  };

  final _api = ApiClient.instance;

  @override
  Map<String, double> build() {
    ref.onDispose(stop);
    return {};
  }

  void start() {
    if (_started) return;
    _started = true;
    _wsConnected = false;

    // 1. Fetch prices from CoinGecko immediately (reliable, CORS-friendly).
    _fetchCoinGecko();

    // 2. Connect Binance WebSocket for real-time streaming.
    _connectBinanceWs();

    // 3. Start flush timer for buffered WS prices.
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(_flushInterval, (_) => _flushBuffer());

    // 4. Start polling as fallback — runs until WS is confirmed working.
    _startPolling();

    // 5. Always listen to backend WS price_update events.
    // The backend broadcasts prices to match rooms every 3s, so this works
    // even when Binance WS / CoinGecko are unavailable from the client.
    _backendWsSub?.cancel();
    _backendWsSub = _api.wsStream
        .where((d) => d['type'] == 'price_update')
        .listen((data) {
      for (final asset in TradingAsset.all) {
        final key = asset.symbol.toLowerCase();
        if (data[key] != null) {
          _priceBuffer[asset.symbol] = (data[key] as num).toDouble();
        }
      }
    });
  }

  void stop() {
    _started = false;
    _wsConnected = false;
    _binanceWs?.close();
    _binanceWs = null;
    _reconnectTimer?.cancel();
    _pollTimer?.cancel();
    _flushTimer?.cancel();
    _backendWsSub?.cancel();
    _priceBuffer.clear();
  }

  // ── Binance WebSocket (primary — real-time) ───────────────────────────────

  void _connectBinanceWs() {
    if (!_started) return;

    _binanceWs?.close();
    _wsConnected = false;

    final streams = TradingAsset.all
        .map((a) => '${a.binanceSymbol.toLowerCase()}@aggTrade')
        .join('/');
    final url = 'wss://stream.binance.com:9443/stream?streams=$streams';

    try {
      _binanceWs = web.WebSocket(url);
    } catch (e) {
      debugPrint('[PriceFeed] WS create failed: $e');
      return;
    }

    _binanceWs!.onopen = ((web.Event e) {
      _reconnectAttempts = 0;
      _wsConnected = true;
      debugPrint('[PriceFeed] Binance aggTrade WS connected');
    }).toJS;

    _binanceWs!.onmessage = ((web.MessageEvent event) {
      try {
        // event.data is a JSAny — cast to JSString then convert to Dart.
        final raw = (event.data as JSString).toDart;
        final msg = json.decode(raw) as Map<String, dynamic>;
        final data = msg['data'] as Map<String, dynamic>;
        final symbol = data['s'] as String; // e.g. 'BTCUSDT'
        final price = double.parse(data['p'] as String); // trade price

        final assetSymbol = _symbolMap[symbol];
        if (assetSymbol != null) {
          _priceBuffer[assetSymbol] = price;
        }
      } catch (e) {
        debugPrint('[PriceFeed] WS parse error: $e');
      }
    }).toJS;

    _binanceWs!.onclose = ((web.Event e) {
      debugPrint('[PriceFeed] Binance WS disconnected');
      _wsConnected = false;
      if (_started) _scheduleReconnect();
    }).toJS;

    _binanceWs!.onerror = ((web.Event e) {
      debugPrint('[PriceFeed] Binance WS error');
      _wsConnected = false;
      _binanceWs?.close();
    }).toJS;
  }

  void _scheduleReconnect() {
    if (!_started) return;
    final delay = Duration(
      milliseconds: 1000 * (1 << _reconnectAttempts.clamp(0, 5)),
    );
    _reconnectAttempts++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _connectBinanceWs);
  }

  // ── CoinGecko REST (fallback — CORS-friendly, no proxy) ───────────────────

  void _startPolling() {
    _pollTimer?.cancel();
    // Poll every 2s. Once WS is confirmed working, slow down to every 10s
    // as a safety net.
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_wsConnected) {
        // WS is working — slow down polling to just a keep-alive check.
        _pollTimer?.cancel();
        _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
          if (!_wsConnected) {
            // WS dropped — speed polling back up.
            _startPolling();
          } else {
            _fetchCoinGecko();
          }
        });
      } else {
        _fetchCoinGecko();
      }
    });
  }

  Future<void> _fetchCoinGecko() async {
    try {
      final ids = TradingAsset.all.map((a) => a.coingeckoId).join(',');
      final uri = Uri.parse(
        'https://api.coingecko.com/api/v3/simple/price'
        '?ids=$ids&vs_currencies=usd',
      );
      final response = await http.get(uri).timeout(
        const Duration(seconds: 8),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final prices = <String, double>{};
        for (final asset in TradingAsset.all) {
          final coinData = data[asset.coingeckoId] as Map<String, dynamic>?;
          if (coinData != null && coinData['usd'] != null) {
            prices[asset.symbol] = (coinData['usd'] as num).toDouble();
          }
        }
        if (prices.isNotEmpty) {
          debugPrint('[PriceFeed] CoinGecko: $prices');
          _merge(prices);
        }
      } else {
        debugPrint('[PriceFeed] CoinGecko HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[PriceFeed] CoinGecko fetch failed: $e');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Flush buffered WS prices to provider state.
  void _flushBuffer() {
    if (_priceBuffer.isEmpty) return;
    final flushed = Map<String, double>.from(_priceBuffer);
    _priceBuffer.clear();
    _merge(flushed);
  }

  void _merge(Map<String, double> incoming) {
    final updated = Map<String, double>.from(state);
    updated.addAll(incoming);
    state = updated;
  }
}

final priceFeedProvider =
    NotifierProvider<PriceFeedNotifier, Map<String, double>>(
        PriceFeedNotifier.new);
