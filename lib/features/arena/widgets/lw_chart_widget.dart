import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../models/trading_models.dart';
import '../providers/price_feed_provider.dart';
import '../providers/trading_provider.dart';

// ── JS interop ──────────────────────────────────────────────────────────────

@JS('window._createLWChartEl')
external void _jsCreateEl(
    String containerId, JSObject containerEl, String binanceSymbol);

@JS('window._createLWChart')
external void _jsCreate(String containerId, String binanceSymbol);

@JS('window._destroyLWChart')
external void _jsDestroy(String containerId);

@JS('window._setLWChartSymbol')
external void _jsSetSymbol(String containerId, String binanceSymbol);

@JS('window._updateLWChartTick')
external void _jsTick(String containerId, double price, double timestampMs);

@JS('window._resizeLWChart')
external void _jsResize(String containerId, double width, double height);

@JS('window._addPositionLine')
external void _jsAddLine(
  String containerId,
  String positionId,
  double entryPrice,
  double slPrice,
  double tpPrice,
  bool isLong,
);

@JS('window._removePositionLine')
external void _jsRemoveLine(String containerId, String positionId);

@JS('window._removeAllPositionLines')
external void _jsRemoveAllLines(String containerId);

@JS('window._addLWChartMarker')
external void _jsAddMarker(
    String containerId, int time, bool isEntry, bool isLong, String text);

@JS('window._clearLWChartMarkers')
external void _jsClearMarkers(String containerId);

// ── Widget ──────────────────────────────────────────────────────────────────

class LWChart extends ConsumerStatefulWidget {
  const LWChart({super.key});

  @override
  ConsumerState<LWChart> createState() => _LWChartState();
}

class _LWChartState extends ConsumerState<LWChart> {
  static int _counter = 0;

  late final String _containerId;
  late final String _viewType;
  bool _ready = false;

  /// Direct reference to the platform view div — passed to JS so it doesn't
  /// need to search the DOM (fixes CanvasKit/Skwasm shadow-DOM issues).
  web.HTMLDivElement? _containerDiv;

  String _assetSymbol = '';
  final Set<String> _drawnLines = {};
  final Set<String> _drawnMarkerIds = {};
  String? _lastMatchId;

  @override
  void initState() {
    super.initState();
    _counter++;
    _containerId = 'lwc-$_counter';
    _viewType = 'lwc-view-$_counter';

    // Register the platform view factory — creates a plain div.
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      _containerDiv = web.HTMLDivElement()
        ..id = _containerId
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = '#131722';
      return _containerDiv!;
    });

    // After the first frame is drawn, give the browser a moment to lay out
    // the platform view, then tell JS to create the chart.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Short delay so the div gets actual dimensions from CSS layout.
      Future.delayed(const Duration(milliseconds: 100), _create);
    });
  }

  void _create() {
    if (!mounted) return;
    final asset = ref.read(tradingProvider).selectedAsset;
    _assetSymbol = asset.symbol;

    // Pass the actual DOM element to JS — avoids shadow-DOM search issues.
    if (_containerDiv != null) {
      _jsCreateEl(_containerId, _containerDiv!, asset.binanceSymbol);
    } else {
      _jsCreate(_containerId, asset.binanceSymbol);
    }
    _ready = true;

    // After Flutter layout is fully settled, push exact dimensions.
    Future.delayed(const Duration(milliseconds: 500), _pushSize);
  }

  void _pushSize() {
    if (!mounted || !_ready) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final size = box.size;
    if (size.width > 0 && size.height > 0) {
      _jsResize(_containerId, size.width, size.height);
    }
  }

  @override
  void dispose() {
    if (_ready) _jsDestroy(_containerId);
    super.dispose();
  }

  // ── Price tick → chart ──────────────────────────────────────────────────

  void _onPrices(Map<String, double> prices) {
    if (!_ready) return;
    final p = prices[_assetSymbol];
    if (p == null || p <= 0) return;
    _jsTick(_containerId, p, DateTime.now().millisecondsSinceEpoch.toDouble());
  }

  // ── Asset switch ────────────────────────────────────────────────────────

  void _onAssetChanged(TradingAsset asset) {
    if (!_ready) return;
    _assetSymbol = asset.symbol;
    _drawnLines.clear();
    _drawnMarkerIds.clear();
    _jsSetSymbol(_containerId, asset.binanceSymbol);
  }

  // ── Position lines ──────────────────────────────────────────────────────

  void _syncLines(List<Position> positions, bool active) {
    if (!_ready) return;

    if (!active) {
      _jsRemoveAllLines(_containerId);
      _drawnLines.clear();
      return;
    }

    final openIds = <String>{};
    for (final p in positions) {
      if (p.isOpen) openIds.add(p.id);
    }

    // Remove closed.
    for (final id in _drawnLines.difference(openIds)) {
      _jsRemoveLine(_containerId, id);
    }
    _drawnLines.removeAll(_drawnLines.difference(openIds));

    // Add new.
    for (final id in openIds.difference(_drawnLines)) {
      final pos = positions.firstWhere((p) => p.id == id);
      _jsAddLine(
        _containerId,
        pos.id,
        pos.entryPrice,
        pos.stopLoss ?? 0.0,
        pos.takeProfit ?? 0.0,
        pos.isLong,
      );
      _drawnLines.add(id);
    }
  }

  // ── Trade markers (entry/exit arrows) ──────────────────────────────────

  void _syncMarkers(List<Position> positions, bool matchActive) {
    if (!_ready) return;

    if (!matchActive) return;

    for (final p in positions) {
      // Only mark positions for the current asset.
      if (p.assetSymbol != _assetSymbol) continue;

      // Entry marker.
      final entryMarkerId = '${p.id}_entry';
      if (!_drawnMarkerIds.contains(entryMarkerId)) {
        final time = p.openedAt.millisecondsSinceEpoch ~/ 60000 * 60;
        final text = p.isLong ? 'Long' : 'Short';
        _jsAddMarker(_containerId, time, true, p.isLong, text);
        _drawnMarkerIds.add(entryMarkerId);
      }

      // Exit marker (only when position is closed).
      final exitMarkerId = '${p.id}_exit';
      if (!p.isOpen && !_drawnMarkerIds.contains(exitMarkerId)) {
        final exitTime =
            (p.closedAt ?? DateTime.now()).millisecondsSinceEpoch ~/ 60000 * 60;
        final pnlValue = p.pnl(p.exitPrice ?? p.entryPrice);
        final sign = pnlValue >= 0 ? '+' : '';
        final text = '$sign\$${pnlValue.toStringAsFixed(2)}';
        _jsAddMarker(_containerId, exitTime, false, p.isLong, text);
        _drawnMarkerIds.add(exitMarkerId);
      }
    }
  }

  void _onMatchReset() {
    if (!_ready) return;
    _jsClearMarkers(_containerId);
    _drawnMarkerIds.clear();
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen<Map<String, double>>(priceFeedProvider, (_, prices) {
      _onPrices(prices);
    });

    ref.listen<TradingState>(tradingProvider, (prev, next) {
      if (prev == null || prev.selectedAssetIndex != next.selectedAssetIndex) {
        _onAssetChanged(next.selectedAsset);
      }

      // Detect match reset (new match or match ended → started).
      if (prev != null && next.matchId != _lastMatchId) {
        _lastMatchId = next.matchId;
        _onMatchReset();
      }

      _syncLines(next.positions, next.matchActive);
      _syncMarkers(next.positions, next.matchActive);
    });

    return HtmlElementView(viewType: _viewType);
  }
}
