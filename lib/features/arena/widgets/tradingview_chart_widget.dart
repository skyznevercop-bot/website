import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Embeds a TradingView Advanced Chart widget via iframe.
/// Symbol changes are sent to the iframe via postMessage.
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

class _TradingViewChartState extends State<TradingViewChart> {
  static int _counter = 0;
  late final String _viewType;
  web.HTMLIFrameElement? _iframe;

  @override
  void initState() {
    super.initState();
    _counter++;
    _viewType = 'tradingview-chart-$_counter';
    _registerFactory();
  }

  void _registerFactory() {
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final src = 'tradingview_chart.html'
          '?symbol=${Uri.encodeComponent(widget.tvSymbol)}'
          '&theme=${widget.theme}';
      _iframe = web.HTMLIFrameElement()
        ..src = src
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'clipboard-write';
      _iframe!.setAttribute('loading', 'lazy');
      return _iframe!;
    });
  }

  @override
  void didUpdateWidget(TradingViewChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tvSymbol != widget.tvSymbol) {
      _iframe?.contentWindow?.postMessage(
        <String, String>{
          'type': 'changeSymbol',
          'symbol': widget.tvSymbol,
        }.jsify(),
        '*'.toJS,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
