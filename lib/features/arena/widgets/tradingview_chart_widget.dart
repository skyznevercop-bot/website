import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Embeds a TradingView chart by creating a div platform view and
/// initializing the TradingView widget via tv.js (loaded in index.html).
/// No iframe nesting — works reliably with CanvasKit renderer.
class TradingViewChart extends StatefulWidget {
  final String tvSymbol;
  final String theme;

  const TradingViewChart({
    super.key,
    required this.tvSymbol,
    this.theme = 'dark',
  });

  @override
  State<TradingViewChart> createState() => _TradingViewChartState();
}

@JS('window._createTVChart')
external void _jsCreateChart(String containerId, String symbol, String theme);

@JS('window._destroyTVChart')
external void _jsDestroyChart(String containerId);

class _TradingViewChartState extends State<TradingViewChart> {
  static int _counter = 0;
  late final String _viewType;
  late final String _containerId;
  Timer? _initTimer;

  @override
  void initState() {
    super.initState();
    _counter++;
    _containerId = 'tv-chart-$_counter';
    _viewType = 'tradingview-chart-$_counter';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return web.HTMLDivElement()
        ..id = _containerId
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = '#131722';
    });

    // Wait for the div to be added to the DOM, then create the widget.
    _initTimer = Timer(const Duration(milliseconds: 300), () {
      _jsCreateChart(_containerId, widget.tvSymbol, widget.theme);
    });
  }

  @override
  void didUpdateWidget(TradingViewChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tvSymbol != widget.tvSymbol) {
      _jsCreateChart(_containerId, widget.tvSymbol, widget.theme);
    }
  }

  @override
  void dispose() {
    _initTimer?.cancel();
    _jsDestroyChart(_containerId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
