// ── Lightweight-Charts bridge for Flutter Web ────────────────────────────
// All state keyed by containerId so multiple charts can coexist.
(function () {
  "use strict";

  var charts = {};

  // ── Symbol mapping: Binance-style → Coinbase product ID ──
  var COINBASE_PRODUCT_MAP = {
    "BTCUSDT": "BTC-USD",
    "ETHUSDT": "ETH-USD",
    "SOLUSDT": "SOL-USD",
  };

  // Convert interval seconds to label string (e.g. 60 → "1m", 3600 → "1h")
  function intervalLabel(sec) {
    if (sec >= 3600) return Math.floor(sec / 3600) + "h";
    return Math.floor(sec / 60) + "m";
  }

  // ── Fetch historical candles ──────────────────────────────────────────
  // Tries Coinbase REST directly (CORS-friendly), then backend proxy as fallback.
  // Retries up to 3 times with 10s gaps (handles Render cold-starts).
  async function fetchCandles(id, symbol, series, chart, intervalSec) {
    var productId = COINBASE_PRODUCT_MAP[symbol] || symbol;
    intervalSec = intervalSec || 60;

    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        await new Promise(function (r) { setTimeout(r, 10000); });
      }
      var s = charts[id];
      if (!s || s.series !== series) return;

      // Source 1: Coinbase REST (direct from browser, no proxy needed)
      try {
        var end = new Date().toISOString();
        var start = new Date(Date.now() - 300 * intervalSec * 1000).toISOString();
        var cbUrl = "https://api.exchange.coinbase.com/products/" + productId +
                    "/candles?granularity=" + intervalSec + "&start=" + start + "&end=" + end;
        var resp = await fetch(cbUrl, { signal: AbortSignal.timeout(8000) });
        if (resp.ok) {
          var data = await resp.json();
          if (Array.isArray(data) && data.length > 0) {
            // CRITICAL: Coinbase returns [time_s, LOW, HIGH, open, close, volume]
            // AND returns newest-first, so reverse.
            var candles = data.reverse().map(function (k) {
              return {
                time: k[0],                  // already in seconds
                open: parseFloat(k[3]),      // open is index 3
                high: parseFloat(k[2]),      // high is index 2
                low: parseFloat(k[1]),       // low is index 1
                close: parseFloat(k[4]),     // close is index 4
              };
            });

            var s2 = charts[id];
            if (!s2 || s2.series !== series) return;

            s2.candleData = candles.slice(0, -1);
            series.setData(candles);
            // Seed currentCandle with the last fetched candle so live ticks
            // don't try to update an older timestamp.
            var last = candles[candles.length - 1];
            s2.currentCandle = { time: last.time, open: last.open, high: last.high, low: last.low, close: last.close };
            chart.timeScale().scrollToRealTime();
            updateIndicators(id);
            console.log("[LWChart] Loaded", candles.length, "candles for", symbol, "via Coinbase");
            return;
          }
        }
      } catch (e) {
        console.warn("[LWChart] Coinbase direct failed:", e.message);
      }

      // Source 2: Backend proxy (returns Binance-format: [timeMs, open, high, low, close, ...])
      try {
        var proxyUrl = "https://solfight-backend.onrender.com/api/klines/" + symbol +
                       "?interval=" + intervalLabel(intervalSec) + "&limit=300";
        var resp2 = await fetch(proxyUrl, { signal: AbortSignal.timeout(8000) });
        if (resp2.ok) {
          var data2 = await resp2.json();
          if (Array.isArray(data2) && data2.length > 0) {
            var candles2 = data2.map(function (k) {
              return {
                time: Math.floor(k[0] / 1000),
                open: parseFloat(k[1]),
                high: parseFloat(k[2]),
                low: parseFloat(k[3]),
                close: parseFloat(k[4]),
              };
            });

            var s3 = charts[id];
            if (!s3 || s3.series !== series) return;

            s3.candleData = candles2.slice(0, -1);
            series.setData(candles2);
            var last2 = candles2[candles2.length - 1];
            s3.currentCandle = { time: last2.time, open: last2.open, high: last2.high, low: last2.low, close: last2.close };
            chart.timeScale().scrollToRealTime();
            updateIndicators(id);
            console.log("[LWChart] Loaded", candles2.length, "candles for", symbol, "via backend proxy");
            return;
          }
        }
      } catch (e2) {
        console.warn("[LWChart] Backend proxy failed:", e2.message);
      }
    }

    // All attempts failed — still scroll to live edge so real-time ticks show.
    if (chart) {
      try { chart.timeScale().scrollToRealTime(); } catch (_) {}
    }
  }

  // ── Find the container element ──────────────────────────────────────────
  // Flutter Web (HTML renderer) puts platform views directly in the DOM.
  // CanvasKit / Skwasm renderer may wrap them in nested shadow DOMs or iframes.
  function findContainer(id) {
    // 1. Direct DOM lookup (works for HTML renderer).
    var el = document.getElementById(id);
    if (el) return el;

    // 2. Recursive shadow DOM walk (handles nested shadow roots in Flutter 3.22+).
    el = searchShadowRoots(document.body, id);
    if (el) return el;

    // 3. Iframes (CanvasKit platform views).
    var iframes = document.querySelectorAll("iframe");
    for (var j = 0; j < iframes.length; j++) {
      try {
        var doc = iframes[j].contentDocument || iframes[j].contentWindow.document;
        if (doc) {
          el = doc.getElementById(id);
          if (el) return el;
          el = searchShadowRoots(doc.body, id);
          if (el) return el;
        }
      } catch (_) {}
    }

    return null;
  }

  // Recursively search shadow roots for an element by ID.
  function searchShadowRoots(root, id) {
    if (!root) return null;
    var children = root.querySelectorAll("*");
    for (var i = 0; i < children.length; i++) {
      var sr = children[i].shadowRoot;
      if (sr) {
        var el = sr.getElementById(id);
        if (el) return el;
        el = searchShadowRoots(sr, id);
        if (el) return el;
      }
    }
    return null;
  }

  // ── Create chart (with direct element reference from Dart) ──────────────
  window._createLWChartEl = function (containerId, containerEl, binanceSymbol) {
    window._destroyLWChart(containerId);
    if (containerEl) {
      setTimeout(function () {
        if (!charts[containerId]) {
          createInContainer(containerId, containerEl, binanceSymbol);
        }
      }, 50);
      return;
    }
    window._createLWChart(containerId, binanceSymbol);
  };

  // ── Create chart (legacy DOM-search path) ──────────────────────────────
  window._createLWChart = function (containerId, binanceSymbol) {
    window._destroyLWChart(containerId);

    var container = findContainer(containerId);
    if (!container) {
      console.warn("[LWChart] Container", containerId, "not in DOM yet — waiting…");
      var observer = new MutationObserver(function () {
        var el = findContainer(containerId);
        if (el) {
          observer.disconnect();
          createInContainer(containerId, el, binanceSymbol);
        }
      });
      observer.observe(document.body, { childList: true, subtree: true });

      setTimeout(function () {
        observer.disconnect();
        var el = findContainer(containerId);
        if (el && !charts[containerId]) {
          createInContainer(containerId, el, binanceSymbol);
        } else if (!charts[containerId]) {
          console.error("[LWChart] Container", containerId, "never appeared");
        }
      }, 8000);
      return;
    }

    setTimeout(function () {
      if (!charts[containerId]) {
        createInContainer(containerId, findContainer(containerId) || container, binanceSymbol);
      }
    }, 50);
  };

  function createInContainer(id, container, symbol) {
    if (charts[id]) return;

    var w = container.clientWidth || 600;
    var h = container.clientHeight || 400;

    var chart;
    try {
      chart = LightweightCharts.createChart(container, {
        width: w,
        height: h,
        layout: {
          background: { color: "#131722" },
          textColor: "#D1D4DC",
          fontFamily: "'Inter', -apple-system, BlinkMacSystemFont, sans-serif",
        },
        grid: {
          vertLines: { color: "rgba(255,255,255,0.04)" },
          horzLines: { color: "rgba(255,255,255,0.04)" },
        },
        crosshair: { mode: LightweightCharts.CrosshairMode.Normal },
        rightPriceScale: {
          borderColor: "#2A2E39",
          autoScale: true,
        },
        timeScale: {
          borderColor: "#2A2E39",
          timeVisible: true,
          secondsVisible: false,
          rightOffset: 5,
          lockVisibleTimeRangeOnResize: true,
        },
      });
    } catch (e) {
      console.error("[LWChart] createChart failed:", e);
      return;
    }

    var series = chart.addSeries(LightweightCharts.CandlestickSeries, {
      upColor: "#26a69a",
      downColor: "#ef5350",
      borderUpColor: "#26a69a",
      borderDownColor: "#ef5350",
      wickUpColor: "#26a69a",
      wickDownColor: "#ef5350",
    });

    var ro = new ResizeObserver(function (entries) {
      var entry = entries[0];
      if (!entry) return;
      var cw = Math.round(entry.contentRect.width);
      var ch = Math.round(entry.contentRect.height);
      if (cw > 0 && ch > 0) {
        chart.applyOptions({ width: cw, height: ch });
      }
    });
    ro.observe(container);

    charts[id] = {
      chart: chart,
      series: series,
      symbol: symbol || "BTCUSDT",
      interval: 60,
      currentCandle: null,
      positionLines: {},
      markers: [],
      ro: ro,
      container: container,
      // Indicator state
      candleData: [],
      indicatorSeries: {},
      activeIndicators: { ema: false, bb: false, rsi: false },
      // RSI pane
      rsiChart: null,
      rsiSeries: null,
      rsiDiv: null,
      rsiRangeListener: null,
    };

    console.log("[LWChart] Created:", id, symbol, w + "x" + h);

    fetchCandles(id, symbol || "BTCUSDT", series, chart, 60);
  }

  // ── Resize (called from Dart after layout) ──────────────────────────────
  window._resizeLWChart = function (containerId, width, height) {
    var s = charts[containerId];
    if (!s) return;
    var w = Math.round(width);
    var h = Math.round(height);
    if (w > 0 && h > 0) {
      s.chart.applyOptions({ width: w, height: h });
    }
  };

  // ── Destroy ─────────────────────────────────────────────────────────────
  window._destroyLWChart = function (containerId) {
    var s = charts[containerId];
    if (!s) return;
    hideRsiPane(containerId);
    try { s.ro.disconnect(); } catch (_) {}
    try { s.chart.remove(); } catch (_) {}
    delete charts[containerId];
  };

  // ── Switch symbol ───────────────────────────────────────────────────────
  window._setLWChartSymbol = function (containerId, binanceSymbol) {
    var s = charts[containerId];
    if (!s) return;
    if (s.symbol === binanceSymbol) return;
    s.symbol = binanceSymbol;
    s.currentCandle = null;
    s.candleData = [];
    s.markers = [];
    window._removeAllPositionLines(containerId);
    try { s.series.setMarkers([]); } catch (_) {}
    fetchCandles(containerId, binanceSymbol, s.series, s.chart, s.interval);
  };

  // ── Switch interval ───────────────────────────────────────────────────
  window._setLWChartInterval = function (containerId, intervalSeconds) {
    var s = charts[containerId];
    if (!s) return;
    if (s.interval === intervalSeconds) return;
    s.interval = intervalSeconds;
    s.currentCandle = null;
    s.candleData = [];
    s.markers = [];
    try { s.series.setMarkers([]); } catch (_) {}
    fetchCandles(containerId, s.symbol, s.series, s.chart, intervalSeconds);
  };

  // ── Live tick → candlestick ─────────────────────────────────────────────
  window._updateLWChartTick = function (containerId, price, timestampMs) {
    var s = charts[containerId];
    if (!s || !price || price <= 0) return;

    var ivSec = s.interval || 60;
    var ivMs = ivSec * 1000;
    var bucketTime = Math.floor(timestampMs / ivMs) * ivSec;

    var c = s.currentCandle;
    if (!c || bucketTime > c.time) {
      // Previous candle is complete — finalize it
      if (c) {
        s.series.update(c);
        s.candleData.push({
          time: c.time, open: c.open, high: c.high, low: c.low, close: c.close
        });
        updateIndicators(containerId);
      }
      c = { time: bucketTime, open: price, high: price, low: price, close: price };
      s.currentCandle = c;
    } else {
      c.close = price;
      if (price > c.high) c.high = price;
      if (price < c.low) c.low = price;
    }
    s.series.update(c);
    updateIndicatorTip(containerId, c);
  };

  // ── Position price lines ────────────────────────────────────────────────

  window._addPositionLine = function (containerId, positionId, entryPrice, slPrice, tpPrice, isLong) {
    var s = charts[containerId];
    if (!s) return;

    var lines = [];
    var entryColor = isLong ? "#26a69a" : "#ef5350";

    lines.push(
      s.series.createPriceLine({
        price: entryPrice,
        color: entryColor,
        lineWidth: 2,
        lineStyle: LightweightCharts.LineStyle.Solid,
        axisLabelVisible: true,
        title: "Entry",
      })
    );

    if (slPrice && slPrice > 0) {
      lines.push(
        s.series.createPriceLine({
          price: slPrice,
          color: "#ef5350",
          lineWidth: 1,
          lineStyle: LightweightCharts.LineStyle.Dashed,
          axisLabelVisible: true,
          title: "SL",
        })
      );
    }

    if (tpPrice && tpPrice > 0) {
      lines.push(
        s.series.createPriceLine({
          price: tpPrice,
          color: "#26a69a",
          lineWidth: 1,
          lineStyle: LightweightCharts.LineStyle.Dashed,
          axisLabelVisible: true,
          title: "TP",
        })
      );
    }

    s.positionLines[positionId] = lines;
  };

  window._removePositionLine = function (containerId, positionId) {
    var s = charts[containerId];
    if (!s) return;
    var lines = s.positionLines[positionId];
    if (!lines) return;
    lines.forEach(function (line) {
      try { s.series.removePriceLine(line); } catch (_) {}
    });
    delete s.positionLines[positionId];
  };

  window._removeAllPositionLines = function (containerId) {
    var s = charts[containerId];
    if (!s) return;
    Object.keys(s.positionLines).forEach(function (pid) {
      var lines = s.positionLines[pid];
      if (lines) {
        lines.forEach(function (line) {
          try { s.series.removePriceLine(line); } catch (_) {}
        });
      }
    });
    s.positionLines = {};
  };

  // ── Trade markers (entry/exit arrows on chart) ────────────────────────

  window._addLWChartMarker = function (containerId, time, isEntry, isLong, text) {
    var s = charts[containerId];
    if (!s) return;

    var marker = {
      time: time,
      position: isEntry ? "belowBar" : "aboveBar",
      color: isLong ? "#26a69a" : "#ef5350",
      shape: isEntry ? "arrowUp" : "arrowDown",
      text: text || "",
    };

    s.markers.push(marker);
    // Re-sort by time (required by lightweight-charts v5).
    s.markers.sort(function (a, b) { return a.time - b.time; });
    s.series.setMarkers(s.markers);
  };

  window._clearLWChartMarkers = function (containerId) {
    var s = charts[containerId];
    if (!s) return;
    s.markers = [];
    try { s.series.setMarkers([]); } catch (_) {}
  };

  // =====================================================================
  // ── Technical Indicators ─────────────────────────────────────────────
  // =====================================================================

  // ── EMA computation (SMA seed, then exponential smoothing) ──
  function computeEMA(candles, period) {
    if (!candles || candles.length < period) return [];
    var k = 2 / (period + 1);
    var result = [];

    // Seed with SMA of first `period` candles
    var sum = 0;
    for (var i = 0; i < period; i++) sum += candles[i].close;
    var prev = sum / period;
    result.push({ time: candles[period - 1].time, value: prev });

    for (var i = period; i < candles.length; i++) {
      prev = candles[i].close * k + prev * (1 - k);
      result.push({ time: candles[i].time, value: prev });
    }
    return result;
  }

  // ── Bollinger Bands (SMA + standard deviation) ──
  function computeBB(candles, period, mult) {
    period = period || 20;
    mult = mult || 2;
    if (!candles || candles.length < period) return { upper: [], middle: [], lower: [] };

    var upper = [], middle = [], lower = [];
    for (var i = period - 1; i < candles.length; i++) {
      var sum = 0;
      for (var j = i - period + 1; j <= i; j++) sum += candles[j].close;
      var mean = sum / period;
      var sq = 0;
      for (var j = i - period + 1; j <= i; j++) {
        var d = candles[j].close - mean;
        sq += d * d;
      }
      var std = Math.sqrt(sq / period);
      var t = candles[i].time;
      middle.push({ time: t, value: mean });
      upper.push({ time: t, value: mean + mult * std });
      lower.push({ time: t, value: mean - mult * std });
    }
    return { upper: upper, middle: middle, lower: lower };
  }

  // ── RSI (Wilder's smoothing) ──
  function computeRSI(candles, period) {
    period = period || 14;
    if (!candles || candles.length < period + 1) return [];

    var gains = 0, losses = 0;
    for (var i = 1; i <= period; i++) {
      var change = candles[i].close - candles[i - 1].close;
      if (change >= 0) gains += change;
      else losses -= change;
    }
    var avgGain = gains / period;
    var avgLoss = losses / period;
    var result = [];
    var rsi = avgLoss === 0 ? 100 : 100 - 100 / (1 + avgGain / avgLoss);
    result.push({ time: candles[period].time, value: rsi });

    for (var i = period + 1; i < candles.length; i++) {
      var change = candles[i].close - candles[i - 1].close;
      if (change >= 0) {
        avgGain = (avgGain * (period - 1) + change) / period;
        avgLoss = (avgLoss * (period - 1)) / period;
      } else {
        avgGain = (avgGain * (period - 1)) / period;
        avgLoss = (avgLoss * (period - 1) - change) / period;
      }
      rsi = avgLoss === 0 ? 100 : 100 - 100 / (1 + avgGain / avgLoss);
      result.push({ time: candles[i].time, value: rsi });
    }
    return result;
  }

  // ── Create indicator series lazily ──
  function ensureIndicatorSeries(id) {
    var s = charts[id];
    if (!s) return;

    if (!s.indicatorSeries.ema9) {
      s.indicatorSeries.ema9 = s.chart.addSeries(LightweightCharts.LineSeries, {
        color: "rgba(38, 166, 154, 0.8)",
        lineWidth: 1,
        priceLineVisible: false,
        lastValueVisible: false,
        crosshairMarkerVisible: false,
      });
      s.indicatorSeries.ema9.applyOptions({ visible: false });
    }
    if (!s.indicatorSeries.ema21) {
      s.indicatorSeries.ema21 = s.chart.addSeries(LightweightCharts.LineSeries, {
        color: "rgba(239, 83, 80, 0.8)",
        lineWidth: 1,
        priceLineVisible: false,
        lastValueVisible: false,
        crosshairMarkerVisible: false,
      });
      s.indicatorSeries.ema21.applyOptions({ visible: false });
    }
    if (!s.indicatorSeries.bbUpper) {
      s.indicatorSeries.bbUpper = s.chart.addSeries(LightweightCharts.LineSeries, {
        color: "rgba(255, 152, 0, 0.5)",
        lineWidth: 1,
        priceLineVisible: false,
        lastValueVisible: false,
        crosshairMarkerVisible: false,
      });
      s.indicatorSeries.bbUpper.applyOptions({ visible: false });
    }
    if (!s.indicatorSeries.bbMiddle) {
      s.indicatorSeries.bbMiddle = s.chart.addSeries(LightweightCharts.LineSeries, {
        color: "rgba(255, 152, 0, 0.35)",
        lineWidth: 1,
        lineStyle: LightweightCharts.LineStyle.Dashed,
        priceLineVisible: false,
        lastValueVisible: false,
        crosshairMarkerVisible: false,
      });
      s.indicatorSeries.bbMiddle.applyOptions({ visible: false });
    }
    if (!s.indicatorSeries.bbLower) {
      s.indicatorSeries.bbLower = s.chart.addSeries(LightweightCharts.LineSeries, {
        color: "rgba(255, 152, 0, 0.5)",
        lineWidth: 1,
        priceLineVisible: false,
        lastValueVisible: false,
        crosshairMarkerVisible: false,
      });
      s.indicatorSeries.bbLower.applyOptions({ visible: false });
    }
  }

  // ── Recompute all active indicators from candleData ──
  function updateIndicators(id) {
    var s = charts[id];
    if (!s || !s.candleData || s.candleData.length === 0) return;

    ensureIndicatorSeries(id);

    if (s.activeIndicators.ema) {
      var ema9 = computeEMA(s.candleData, 9);
      var ema21 = computeEMA(s.candleData, 21);
      s.indicatorSeries.ema9.setData(ema9);
      s.indicatorSeries.ema21.setData(ema21);
      s.indicatorSeries.ema9.applyOptions({ visible: true });
      s.indicatorSeries.ema21.applyOptions({ visible: true });
    }

    if (s.activeIndicators.bb) {
      var bb = computeBB(s.candleData, 20, 2);
      s.indicatorSeries.bbUpper.setData(bb.upper);
      s.indicatorSeries.bbMiddle.setData(bb.middle);
      s.indicatorSeries.bbLower.setData(bb.lower);
      s.indicatorSeries.bbUpper.applyOptions({ visible: true });
      s.indicatorSeries.bbMiddle.applyOptions({ visible: true });
      s.indicatorSeries.bbLower.applyOptions({ visible: true });
    }

    // RSI updates if pane exists
    if (s.activeIndicators.rsi && s.rsiSeries) {
      var rsiData = computeRSI(s.candleData, 14);
      s.rsiSeries.setData(rsiData);
    }
  }

  // ── Update indicator tip on each live tick ──
  function updateIndicatorTip(id, currentCandle) {
    var s = charts[id];
    if (!s || !s.candleData || s.candleData.length === 0) return;

    // Temp array: historical candles + the in-progress candle
    var tempCandles = s.candleData.concat([currentCandle]);

    if (s.activeIndicators.ema && s.indicatorSeries.ema9) {
      var ema9 = computeEMA(tempCandles, 9);
      var ema21 = computeEMA(tempCandles, 21);
      if (ema9.length > 0) s.indicatorSeries.ema9.update(ema9[ema9.length - 1]);
      if (ema21.length > 0) s.indicatorSeries.ema21.update(ema21[ema21.length - 1]);
    }

    if (s.activeIndicators.bb && s.indicatorSeries.bbUpper) {
      var bb = computeBB(tempCandles, 20, 2);
      if (bb.upper.length > 0) {
        s.indicatorSeries.bbUpper.update(bb.upper[bb.upper.length - 1]);
        s.indicatorSeries.bbMiddle.update(bb.middle[bb.middle.length - 1]);
        s.indicatorSeries.bbLower.update(bb.lower[bb.lower.length - 1]);
      }
    }

    if (s.activeIndicators.rsi && s.rsiSeries) {
      var rsiData = computeRSI(tempCandles, 14);
      if (rsiData.length > 0) {
        s.rsiSeries.update(rsiData[rsiData.length - 1]);
      }
    }
  }

  // ── Toggle indicator on/off ──
  window._setLWChartIndicator = function (containerId, indicatorName, enabled) {
    var s = charts[containerId];
    if (!s) return;

    s.activeIndicators[indicatorName] = enabled;
    ensureIndicatorSeries(containerId);

    if (indicatorName === "ema") {
      if (enabled) {
        updateIndicators(containerId);
      } else {
        if (s.indicatorSeries.ema9) s.indicatorSeries.ema9.applyOptions({ visible: false });
        if (s.indicatorSeries.ema21) s.indicatorSeries.ema21.applyOptions({ visible: false });
      }
    }

    if (indicatorName === "bb") {
      if (enabled) {
        updateIndicators(containerId);
      } else {
        if (s.indicatorSeries.bbUpper) s.indicatorSeries.bbUpper.applyOptions({ visible: false });
        if (s.indicatorSeries.bbMiddle) s.indicatorSeries.bbMiddle.applyOptions({ visible: false });
        if (s.indicatorSeries.bbLower) s.indicatorSeries.bbLower.applyOptions({ visible: false });
      }
    }

    if (indicatorName === "rsi") {
      if (enabled) {
        showRsiPane(containerId);
      } else {
        hideRsiPane(containerId);
      }
    }
  };

  // =====================================================================
  // ── RSI Pane (separate chart instance below main chart) ──────────────
  // =====================================================================

  function showRsiPane(id) {
    var s = charts[id];
    if (!s || s.rsiChart) return;

    var mainContainer = s.container;
    if (!mainContainer || !mainContainer.parentElement) return;

    // Create RSI container div
    var rsiDiv = document.createElement("div");
    rsiDiv.id = id + "-rsi";
    rsiDiv.style.width = "100%";
    rsiDiv.style.height = "100px";
    rsiDiv.style.borderTop = "1px solid #2A2E39";
    rsiDiv.style.flexShrink = "0";
    mainContainer.parentElement.appendChild(rsiDiv);

    // Shrink main chart to make room
    var mainH = mainContainer.clientHeight - 100;
    if (mainH > 100) {
      s.chart.applyOptions({ height: mainH });
      mainContainer.style.height = mainH + "px";
    }

    var rsiChart = LightweightCharts.createChart(rsiDiv, {
      width: rsiDiv.clientWidth || mainContainer.clientWidth || 600,
      height: 100,
      layout: {
        background: { color: "#131722" },
        textColor: "#787B86",
        fontFamily: "'Inter', -apple-system, BlinkMacSystemFont, sans-serif",
        fontSize: 10,
      },
      grid: {
        vertLines: { color: "rgba(255,255,255,0.02)" },
        horzLines: { color: "rgba(255,255,255,0.04)" },
      },
      rightPriceScale: {
        borderColor: "#2A2E39",
        scaleMargins: { top: 0.1, bottom: 0.1 },
      },
      timeScale: {
        visible: false,
      },
      crosshair: { mode: LightweightCharts.CrosshairMode.Normal },
      handleScroll: false,
      handleScale: false,
    });

    var rsiSeries = rsiChart.addSeries(LightweightCharts.LineSeries, {
      color: "#9945FF",
      lineWidth: 1.5,
      priceLineVisible: false,
      lastValueVisible: true,
      crosshairMarkerVisible: true,
    });

    // Reference lines at 30 and 70
    rsiSeries.createPriceLine({
      price: 70,
      color: "rgba(239, 83, 80, 0.3)",
      lineWidth: 1,
      lineStyle: LightweightCharts.LineStyle.Dashed,
      axisLabelVisible: false,
      title: "",
    });
    rsiSeries.createPriceLine({
      price: 30,
      color: "rgba(38, 166, 154, 0.3)",
      lineWidth: 1,
      lineStyle: LightweightCharts.LineStyle.Dashed,
      axisLabelVisible: false,
      title: "",
    });

    s.rsiChart = rsiChart;
    s.rsiSeries = rsiSeries;
    s.rsiDiv = rsiDiv;

    // Sync time scales: main → RSI
    var rangeListener = function (range) {
      if (range) {
        try { rsiChart.timeScale().setVisibleLogicalRange(range); } catch (_) {}
      }
    };
    s.chart.timeScale().subscribeVisibleLogicalRangeChange(rangeListener);
    s.rsiRangeListener = rangeListener;

    // Compute and set initial RSI data
    if (s.candleData && s.candleData.length > 0) {
      var rsiData = computeRSI(s.candleData, 14);
      rsiSeries.setData(rsiData);
    }

    console.log("[LWChart] RSI pane shown for", id);
  }

  function hideRsiPane(id) {
    var s = charts[id];
    if (!s) return;

    // Unsubscribe time scale sync
    if (s.rsiRangeListener) {
      try {
        s.chart.timeScale().unsubscribeVisibleLogicalRangeChange(s.rsiRangeListener);
      } catch (_) {}
      s.rsiRangeListener = null;
    }

    if (s.rsiChart) {
      try { s.rsiChart.remove(); } catch (_) {}
      s.rsiChart = null;
      s.rsiSeries = null;
    }

    if (s.rsiDiv) {
      try { s.rsiDiv.remove(); } catch (_) {}
      s.rsiDiv = null;
    }

    // Restore main chart height
    var mainContainer = s.container;
    if (mainContainer) {
      mainContainer.style.height = "100%";
      var h = mainContainer.clientHeight;
      if (h > 0) {
        s.chart.applyOptions({ height: h });
      }
    }

    console.log("[LWChart] RSI pane hidden for", id);
  }
})();
