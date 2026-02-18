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
/// 1. Coinbase Exchange WebSocket ticker (real-time, fires on every trade).
/// 2. CoinGecko REST API polling (CORS-friendly, no proxy needed).
/// 3. Backend WebSocket relay (if connected).
///
/// Incoming WS prices are buffered and flushed every 250ms to avoid
/// excessive UI rebuilds while staying responsive.
class PriceFeedNotifier extends Notifier<Map<String, double>> {
  web.WebSocket? _coinbaseWs;
  Timer? _reconnectTimer;
  Timer? _pollTimer;
  Timer? _flushTimer;
  StreamSubscription? _backendWsSub;
  int _reconnectAttempts = 0;
  bool _started = false;

  /// Buffer for incoming WS prices — flushed to state periodically.
  final Map<String, double> _priceBuffer = {};

  static const _flushInterval = Duration(milliseconds: 250);

  /// Map Coinbase product_id → internal asset symbol.
  static final _symbolMap = {
    for (final a in TradingAsset.all) a.coinbaseProductId: a.symbol,
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

    // 1. Fetch prices from CoinGecko immediately (reliable, CORS-friendly).
    _fetchCoinGecko();

    // 2. Connect Coinbase WebSocket for real-time streaming.
    _connectCoinbaseWs();

    // 3. Start flush timer for buffered WS prices.
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(_flushInterval, (_) => _flushBuffer());

    // 4. Start polling as fallback — runs always as safety net.
    _startPolling();

    // 5. Always listen to backend WS price_update events.
    // The backend broadcasts prices to match rooms every 3s, so this works
    // even when Coinbase WS / CoinGecko are unavailable from the client.
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
    _coinbaseWs?.close();
    _coinbaseWs = null;
    _reconnectTimer?.cancel();
    _pollTimer?.cancel();
    _flushTimer?.cancel();
    _backendWsSub?.cancel();
    _priceBuffer.clear();
  }

  // ── Coinbase WebSocket (primary — real-time, US-friendly) ─────────────────

  void _connectCoinbaseWs() {
    if (!_started) return;

    _coinbaseWs?.close();

    const url = 'wss://ws-feed.exchange.coinbase.com';

    try {
      _coinbaseWs = web.WebSocket(url);
    } catch (e) {
      debugPrint('[PriceFeed] Coinbase WS create failed: $e');
      return;
    }

    _coinbaseWs!.onopen = ((web.Event e) {
      _reconnectAttempts = 0;
      debugPrint('[PriceFeed] Coinbase WS connected — subscribing to ticker');

      // Subscribe to ticker channel for all assets.
      final productIds =
          TradingAsset.all.map((a) => a.coinbaseProductId).toList();
      final subMsg = json.encode({
        'type': 'subscribe',
        'channels': [
          {'name': 'ticker', 'product_ids': productIds},
        ],
      });
      _coinbaseWs!.send(subMsg.toJS);
    }).toJS;

    _coinbaseWs!.onmessage = ((web.MessageEvent event) {
      try {
        final raw = (event.data as JSString).toDart;
        final msg = json.decode(raw) as Map<String, dynamic>;
        final type = msg['type'] as String?;

        // Only process ticker messages (ignore subscriptions, heartbeat, etc.)
        if (type != 'ticker') return;

        final productId = msg['product_id'] as String; // e.g. 'BTC-USD'
        final priceStr = msg['price'] as String;
        final price = double.parse(priceStr);

        final assetSymbol = _symbolMap[productId];
        if (assetSymbol != null) {
          _priceBuffer[assetSymbol] = price;
        }
      } catch (e) {
        debugPrint('[PriceFeed] Coinbase WS parse error: $e');
      }
    }).toJS;

    _coinbaseWs!.onclose = ((web.Event e) {
      debugPrint('[PriceFeed] Coinbase WS disconnected');
      if (_started) _scheduleReconnect();
    }).toJS;

    _coinbaseWs!.onerror = ((web.Event e) {
      debugPrint('[PriceFeed] Coinbase WS error');
      _coinbaseWs?.close();
    }).toJS;
  }

  void _scheduleReconnect() {
    if (!_started) return;
    final delay = Duration(
      milliseconds: 1000 * (1 << _reconnectAttempts.clamp(0, 5)),
    );
    _reconnectAttempts++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _connectCoinbaseWs);
  }

  // ── CoinGecko REST (fallback — CORS-friendly, no proxy) ───────────────────

  void _startPolling() {
    _pollTimer?.cancel();
    // Poll every 3s always. When WS is working this serves as a safety net;
    // when WS is down this keeps prices flowing.
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchCoinGecko();
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
