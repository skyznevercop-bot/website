import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../models/trading_models.dart';
import '../providers/price_feed_provider.dart';
import '../providers/trading_provider.dart';

// ── JS interop bindings ────────────────────────────────────────────────────

@JS('window._createLWChart')
external void _jsCreateLWChart(String containerId, String binanceSymbol);

@JS('window._destroyLWChart')
external void _jsDestroyLWChart(String containerId);

@JS('window._setLWChartSymbol')
external void _jsSetLWChartSymbol(String containerId, String binanceSymbol);

@JS('window._updateLWChartTick')
external void _jsUpdateLWChartTick(
    String containerId, double price, double timestampMs);

@JS('window._addPositionLine')
external void _jsAddPositionLine(
    String containerId,
    String positionId,
    double entryPrice,
    double slPrice,
    double tpPrice,
    bool isLong);

@JS('window._removePositionLine')
external void _jsRemovePositionLine(String containerId, String positionId);

@JS('window._removeAllPositionLines')
external void _jsRemoveAllPositionLines(String containerId);

// ── Widget ─────────────────────────────────────────────────────────────────

/// Lightweight-charts (MIT) candlestick chart with real-time Binance ticks
/// and position entry/SL/TP lines drawn directly on the chart.
///
/// Self-contained: watches [priceFeedProvider] for tick updates and
/// [tradingProvider] for position/asset changes — no props required.
class LWChart extends ConsumerStatefulWidget {
  const LWChart({super.key});

  @override
  ConsumerState<LWChart> createState() => _LWChartState();
}

class _LWChartState extends ConsumerState<LWChart> {
  static int _counter = 0;
  late final String _viewType;
  late final String _containerId;

  Timer? _initTimer;
  bool _chartCreated = false;

  /// Asset symbol shown in the chart (e.g. 'BTC').
  String _currentAssetSymbol = '';
  String _currentBinanceSymbol = '';

  /// Tracks which position IDs we've drawn lines for.
  final Set<String> _drawnPositionIds = {};

  @override
  void initState() {
    super.initState();
    _counter++;
    _containerId = 'lw-chart-$_counter';
    _viewType = 'lw-chart-view-$_counter';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return web.HTMLDivElement()
        ..id = _containerId
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = '#131722';
    });

    // Wait for the div to be inserted into the DOM before calling JS.
    _initTimer = Timer(const Duration(milliseconds: 300), _initChart);
  }

  void _initChart() {
    if (!mounted) return;
    final tradingState = ref.read(tradingProvider);
    _currentAssetSymbol = tradingState.selectedAsset.symbol;
    _currentBinanceSymbol = tradingState.selectedAsset.binanceSymbol;
    _jsCreateLWChart(_containerId, _currentBinanceSymbol);
    _chartCreated = true;
  }

  @override
  void dispose() {
    _initTimer?.cancel();
    if (_chartCreated) {
      _jsDestroyLWChart(_containerId);
    }
    super.dispose();
  }

  // ── Price tick → chart update ──────────────────────────────────────────────

  /// Called every time [priceFeedProvider] emits a new price map.
  void _onPriceUpdate(Map<String, double> prices) {
    if (!_chartCreated) return;
    final price = prices[_currentAssetSymbol];
    if (price == null || price <= 0) return;
    _jsUpdateLWChartTick(
      _containerId,
      price,
      DateTime.now().millisecondsSinceEpoch.toDouble(),
    );
  }

  // ── Position lines ─────────────────────────────────────────────────────────

  void _syncPositionLines(List<Position> positions, bool matchActive) {
    if (!_chartCreated) return;

    if (!matchActive) {
      // Match ended — clear everything.
      _jsRemoveAllPositionLines(_containerId);
      _drawnPositionIds.clear();
      return;
    }

    // Determine which positions should be visible (open ones only).
    final openIds = <String>{};
    for (final p in positions) {
      if (p.isOpen) openIds.add(p.id);
    }

    // Remove lines for positions that are now closed.
    final toRemove = _drawnPositionIds.difference(openIds);
    for (final id in toRemove) {
      _jsRemovePositionLine(_containerId, id);
      _drawnPositionIds.remove(id);
    }

    // Add lines for newly opened positions.
    final toAdd = openIds.difference(_drawnPositionIds);
    for (final id in toAdd) {
      final pos = positions.firstWhere((p) => p.id == id);
      _jsAddPositionLine(
        _containerId,
        pos.id,
        pos.entryPrice,
        pos.stopLoss ?? 0.0,
        pos.takeProfit ?? 0.0,
        pos.isLong,
      );
      _drawnPositionIds.add(id);
    }
  }

  // ── Asset changes ──────────────────────────────────────────────────────────

  void _onAssetChanged(TradingAsset asset) {
    if (!_chartCreated) return;
    _currentAssetSymbol = asset.symbol;
    _currentBinanceSymbol = asset.binanceSymbol;
    _drawnPositionIds.clear(); // lines belong to previous symbol context
    _jsSetLWChartSymbol(_containerId, _currentBinanceSymbol);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Watch price feed — forward the currently-selected asset's price as a tick.
    ref.listen<Map<String, double>>(priceFeedProvider, (_, prices) {
      _onPriceUpdate(prices);
    });

    // Watch trading state for asset / position changes.
    ref.listen<TradingState>(tradingProvider, (prev, next) {
      // Asset switched.
      if (prev == null ||
          prev.selectedAssetIndex != next.selectedAssetIndex) {
        _onAssetChanged(next.selectedAsset);
      }

      // Sync position lines.
      _syncPositionLines(next.positions, next.matchActive);
    });

    return HtmlElementView(viewType: _viewType);
  }
}
