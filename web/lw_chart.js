// ── Lightweight-Charts bridge for Flutter Web ────────────────────────────
// All state keyed by containerId so multiple charts can coexist.
(function () {
  "use strict";

  var charts = {};

  // ── Klines data sources (backend proxy first, Binance direct fallback) ──
  var KLINE_SOURCES = [
    "https://solfight-backend.onrender.com/api/klines",
    "https://api.binance.com/api/v3/klines",
  ];

  // ── Fetch historical candles ──────────────────────────────────────────
  // Retries up to 3 times with 10s gaps (handles Render cold-starts).
  async function fetchCandles(id, symbol, series, chart) {
    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        await new Promise(function (r) { setTimeout(r, 10000); });
      }
      // Bail if chart was destroyed while waiting.
      var s = charts[id];
      if (!s || s.series !== series) return;

      for (var i = 0; i < KLINE_SOURCES.length; i++) {
        try {
          var base = KLINE_SOURCES[i];
          var url =
            base.indexOf("binance.com") !== -1
              ? base + "?symbol=" + symbol + "&interval=1m&limit=300"
              : base + "/" + symbol + "?interval=1m&limit=300";

          var resp = await fetch(url, { signal: AbortSignal.timeout(8000) });
          if (!resp.ok) continue;
          var data = await resp.json();
          if (!Array.isArray(data) || data.length === 0) continue;

          var candles = data.map(function (k) {
            return {
              time: Math.floor(k[0] / 1000),
              open: parseFloat(k[1]),
              high: parseFloat(k[2]),
              low: parseFloat(k[3]),
              close: parseFloat(k[4]),
            };
          });

          // Bail if chart was replaced while fetching.
          var s2 = charts[id];
          if (!s2 || s2.series !== series) return;

          series.setData(candles);
          chart.timeScale().scrollToRealTime();
          console.log("[LWChart] Loaded", candles.length, "candles for", symbol);
          return;
        } catch (e) {
          console.warn("[LWChart] klines source", i, "failed:", e.message);
        }
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
          // Also search shadow DOMs inside iframes.
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
        // Recurse into nested shadow roots.
        el = searchShadowRoots(sr, id);
        if (el) return el;
      }
    }
    return null;
  }

  // ── Create chart (with direct element reference from Dart) ──────────────
  // Preferred path: Dart passes the actual HTMLDivElement, bypassing DOM search.
  window._createLWChartEl = function (containerId, containerEl, binanceSymbol) {
    window._destroyLWChart(containerId);
    if (containerEl) {
      // Wait a tick for the element to get dimensions from CSS layout.
      setTimeout(function () {
        if (!charts[containerId]) {
          createInContainer(containerId, containerEl, binanceSymbol);
        }
      }, 50);
      return;
    }
    // Fallback: search the DOM (legacy path).
    window._createLWChart(containerId, binanceSymbol);
  };

  // ── Create chart (legacy DOM-search path) ──────────────────────────────
  window._createLWChart = function (containerId, binanceSymbol) {
    // Destroy any previous chart in this container.
    window._destroyLWChart(containerId);

    var container = findContainer(containerId);
    if (!container) {
      console.warn("[LWChart] Container", containerId, "not in DOM yet — waiting…");
      // Use MutationObserver to wait for the element to appear.
      var observer = new MutationObserver(function () {
        var el = findContainer(containerId);
        if (el) {
          observer.disconnect();
          createInContainer(containerId, el, binanceSymbol);
        }
      });
      observer.observe(document.body, { childList: true, subtree: true });

      // Safety timeout: give up after 8s.
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

    // Container already exists — wait a tick for it to get dimensions.
    setTimeout(function () {
      if (!charts[containerId]) {
        createInContainer(containerId, findContainer(containerId) || container, binanceSymbol);
      }
    }, 50);
  };

  function createInContainer(id, container, symbol) {
    // Ensure we're not double-creating.
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

    // ResizeObserver keeps the chart sized to its container.
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
      currentCandle: null,
      positionLines: {},
      ro: ro,
    };

    console.log("[LWChart] Created:", id, symbol, w + "x" + h);

    fetchCandles(id, symbol || "BTCUSDT", series, chart);
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
    // Remove all position lines (they belong to the old symbol).
    window._removeAllPositionLines(containerId);
    fetchCandles(containerId, binanceSymbol, s.series, s.chart);
  };

  // ── Live tick → candlestick ─────────────────────────────────────────────
  // Builds 1-minute OHLC candles from individual price ticks.
  window._updateLWChartTick = function (containerId, price, timestampMs) {
    var s = charts[containerId];
    if (!s || !price || price <= 0) return;

    var minute = Math.floor(timestampMs / 60000) * 60; // floor to minute boundary (seconds)

    var c = s.currentCandle;
    if (!c || minute > c.time) {
      // New minute — push old candle and start fresh.
      if (c) s.series.update(c);
      c = { time: minute, open: price, high: price, low: price, close: price };
      s.currentCandle = c;
    } else {
      c.close = price;
      if (price > c.high) c.high = price;
      if (price < c.low) c.low = price;
    }
    s.series.update(c);
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
})();
