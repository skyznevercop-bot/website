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

  // ── Fetch historical candles ──────────────────────────────────────────
  // Tries Coinbase REST directly (CORS-friendly), then backend proxy as fallback.
  // Retries up to 3 times with 10s gaps (handles Render cold-starts).
  async function fetchCandles(id, symbol, series, chart) {
    var productId = COINBASE_PRODUCT_MAP[symbol] || symbol;

    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        await new Promise(function (r) { setTimeout(r, 10000); });
      }
      var s = charts[id];
      if (!s || s.series !== series) return;

      // Source 1: Coinbase REST (direct from browser, no proxy needed)
      try {
        var end = new Date().toISOString();
        var start = new Date(Date.now() - 300 * 60 * 1000).toISOString();
        var cbUrl = "https://api.exchange.coinbase.com/products/" + productId +
                    "/candles?granularity=60&start=" + start + "&end=" + end;
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

            series.setData(candles);
            chart.timeScale().scrollToRealTime();
            console.log("[LWChart] Loaded", candles.length, "candles for", symbol, "via Coinbase");
            return;
          }
        }
      } catch (e) {
        console.warn("[LWChart] Coinbase direct failed:", e.message);
      }

      // Source 2: Backend proxy (returns Binance-format: [timeMs, open, high, low, close, ...])
      try {
        var proxyUrl = "https://solfight-backend.onrender.com/api/klines/" + symbol + "?interval=1m&limit=300";
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

            series.setData(candles2);
            chart.timeScale().scrollToRealTime();
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
      currentCandle: null,
      positionLines: {},
      markers: [],
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
    s.markers = [];
    window._removeAllPositionLines(containerId);
    try { s.series.setMarkers([]); } catch (_) {}
    fetchCandles(containerId, binanceSymbol, s.series, s.chart);
  };

  // ── Live tick → candlestick ─────────────────────────────────────────────
  window._updateLWChartTick = function (containerId, price, timestampMs) {
    var s = charts[containerId];
    if (!s || !price || price <= 0) return;

    var minute = Math.floor(timestampMs / 60000) * 60;

    var c = s.currentCandle;
    if (!c || minute > c.time) {
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
})();
