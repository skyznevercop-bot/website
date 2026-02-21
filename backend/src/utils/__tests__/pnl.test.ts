import { describe, it, expect } from "vitest";
import {
  calculatePnl,
  liquidationPrice,
  roiDecimal,
  roiToPercent,
  type PnlPosition,
} from "../pnl";

// ── calculatePnl ────────────────────────────────────────────────

describe("calculatePnl", () => {
  it("returns 0 PnL when exit price equals entry price (long)", () => {
    const pos: PnlPosition = { entryPrice: 100, isLong: true, size: 1000, leverage: 1 };
    expect(calculatePnl(pos, 100)).toBe(0);
  });

  it("returns 0 PnL when exit price equals entry price (short)", () => {
    const pos: PnlPosition = { entryPrice: 100, isLong: false, size: 1000, leverage: 1 };
    expect(calculatePnl(pos, 100)).toBe(0);
  });

  it("calculates positive PnL for a winning long position", () => {
    const pos: PnlPosition = { entryPrice: 100, isLong: true, size: 1000, leverage: 1 };
    // Price went up 10%: PnL = (110 - 100) / 100 * 1000 * 1 = 100
    expect(calculatePnl(pos, 110)).toBe(100);
  });

  it("calculates negative PnL for a losing long position", () => {
    const pos: PnlPosition = { entryPrice: 100, isLong: true, size: 1000, leverage: 1 };
    // Price went down 10%: PnL = (90 - 100) / 100 * 1000 * 1 = -100
    expect(calculatePnl(pos, 90)).toBe(-100);
  });

  it("calculates positive PnL for a winning short position", () => {
    const pos: PnlPosition = { entryPrice: 100, isLong: false, size: 1000, leverage: 1 };
    // Price went down 10%: PnL = (100 - 90) / 100 * 1000 * 1 = 100
    expect(calculatePnl(pos, 90)).toBe(100);
  });

  it("calculates negative PnL for a losing short position", () => {
    const pos: PnlPosition = { entryPrice: 100, isLong: false, size: 1000, leverage: 1 };
    // Price went up 10%: PnL = (100 - 110) / 100 * 1000 * 1 = -100
    expect(calculatePnl(pos, 110)).toBe(-100);
  });

  it("applies leverage correctly", () => {
    const pos: PnlPosition = { entryPrice: 50000, isLong: true, size: 500, leverage: 10 };
    // Price went up 1%: PnL = (50500 - 50000) / 50000 * 500 * 10 = 50
    expect(calculatePnl(pos, 50500)).toBe(50);
  });

  it("caps losses at the position size (margin)", () => {
    const pos: PnlPosition = { entryPrice: 100, isLong: true, size: 1000, leverage: 10 };
    // Price dropped 50% — raw PnL would be -5000 but capped at -1000
    expect(calculatePnl(pos, 50)).toBe(-1000);
  });

  it("caps short losses at margin too", () => {
    const pos: PnlPosition = { entryPrice: 100, isLong: false, size: 500, leverage: 20 };
    // Price went up 50% — raw PnL would be -5000 but capped at -500
    expect(calculatePnl(pos, 150)).toBe(-500);
  });

  it("uses exitPrice from the position when provided", () => {
    const pos: PnlPosition = { entryPrice: 100, exitPrice: 120, isLong: true, size: 1000, leverage: 1 };
    // Should use exitPrice (120) not currentPrice (999)
    expect(calculatePnl(pos, 999)).toBe(200);
  });

  it("handles very small price changes accurately", () => {
    const pos: PnlPosition = { entryPrice: 50000, isLong: true, size: 100000, leverage: 1 };
    // Price moved 0.01%: PnL = 5 / 50000 * 100000 * 1 = 10
    expect(calculatePnl(pos, 50005)).toBeCloseTo(10, 2);
  });

  it("handles 100x leverage near liquidation", () => {
    const pos: PnlPosition = { entryPrice: 100, isLong: true, size: 100, leverage: 100 };
    // Price dropped 0.5%: PnL = -0.5 / 100 * 100 * 100 = -50
    expect(calculatePnl(pos, 99.5)).toBe(-50);
  });
});

// ── liquidationPrice ────────────────────────────────────────────

describe("liquidationPrice", () => {
  it("calculates liquidation price for a long position", () => {
    const pos: PnlPosition = { entryPrice: 100, isLong: true, size: 1000, leverage: 10 };
    // liqPrice = 100 * (1 - 0.9 / 10) = 100 * 0.91 = 91
    expect(liquidationPrice(pos)).toBe(91);
  });

  it("calculates liquidation price for a short position", () => {
    const pos: PnlPosition = { entryPrice: 100, isLong: false, size: 1000, leverage: 10 };
    // liqPrice = 100 * (1 + 0.9 / 10) = 100 * 1.09 = 109
    expect(liquidationPrice(pos)).toBeCloseTo(109, 10);
  });

  it("liquidation price is closer to entry with higher leverage", () => {
    const pos10x: PnlPosition = { entryPrice: 50000, isLong: true, size: 100, leverage: 10 };
    const pos100x: PnlPosition = { entryPrice: 50000, isLong: true, size: 100, leverage: 100 };

    const liq10x = liquidationPrice(pos10x);
    const liq100x = liquidationPrice(pos100x);

    // Higher leverage → liquidation price closer to entry
    expect(liq100x).toBeGreaterThan(liq10x);
    // Both should be below entry for longs
    expect(liq10x).toBeLessThan(50000);
    expect(liq100x).toBeLessThan(50000);
  });

  it("liquidation triggers at 90% margin loss for long", () => {
    const pos: PnlPosition = { entryPrice: 100, isLong: true, size: 1000, leverage: 10 };
    const liqPrice = liquidationPrice(pos);
    const pnlAtLiq = calculatePnl(pos, liqPrice);
    // At liquidation, PnL should be -90% of size = -900
    expect(pnlAtLiq).toBeCloseTo(-900, 5);
  });

  it("liquidation triggers at 90% margin loss for short", () => {
    const pos: PnlPosition = { entryPrice: 100, isLong: false, size: 1000, leverage: 10 };
    const liqPrice = liquidationPrice(pos);
    const pnlAtLiq = calculatePnl(pos, liqPrice);
    expect(pnlAtLiq).toBeCloseTo(-900, 5);
  });

  it("accepts a custom threshold parameter", () => {
    const pos: PnlPosition = { entryPrice: 100, isLong: true, size: 1000, leverage: 10 };
    // With 50% threshold: liqPrice = 100 * (1 - 0.5/10) = 95
    expect(liquidationPrice(pos, 0.5)).toBe(95);
  });

  it("1x leverage long has liquidation price near zero", () => {
    const pos: PnlPosition = { entryPrice: 100, isLong: true, size: 1000, leverage: 1 };
    // liqPrice = 100 * (1 - 0.9/1) = 10
    expect(liquidationPrice(pos)).toBeCloseTo(10, 10);
  });
});

// ── roiDecimal ──────────────────────────────────────────────────

describe("roiDecimal", () => {
  it("calculates positive ROI", () => {
    expect(roiDecimal(500, 10000)).toBe(0.05);
  });

  it("calculates negative ROI", () => {
    expect(roiDecimal(-200, 10000)).toBe(-0.02);
  });

  it("returns 0 for zero initial balance", () => {
    expect(roiDecimal(100, 0)).toBe(0);
  });

  it("returns 0 for zero PnL", () => {
    expect(roiDecimal(0, 10000)).toBe(0);
  });

  it("handles large PnL correctly", () => {
    expect(roiDecimal(1_000_000, 1_000_000)).toBe(1.0);
  });
});

// ── roiToPercent ────────────────────────────────────────────────

describe("roiToPercent", () => {
  it("converts 0.05 to 5.00", () => {
    expect(roiToPercent(0.05)).toBe(5);
  });

  it("converts 0.001 to 0.10", () => {
    expect(roiToPercent(0.001)).toBe(0.1);
  });

  it("converts -0.05 to -5.00", () => {
    expect(roiToPercent(-0.05)).toBe(-5);
  });

  it("converts 1.0 to 100.00", () => {
    expect(roiToPercent(1.0)).toBe(100);
  });

  it("rounds to 2 decimal places", () => {
    // 0.12345 → 12.35 (rounded)
    expect(roiToPercent(0.12345)).toBe(12.35);
  });

  it("handles zero", () => {
    expect(roiToPercent(0)).toBe(0);
  });
});

// ── Edge cases and integration ──────────────────────────────────

describe("PnL edge cases", () => {
  it("zero-size position returns 0 PnL", () => {
    const pos: PnlPosition = { entryPrice: 100, isLong: true, size: 0, leverage: 10 };
    expect(calculatePnl(pos, 200)).toBe(0);
  });

  it("full round-trip: PnL → ROI → percent", () => {
    const balance = 1_000_000;
    const pos: PnlPosition = { entryPrice: 50000, isLong: true, size: 100000, leverage: 5 };
    // Price up 2%: PnL = (1000 / 50000) * 100000 * 5 = 10000
    const pnl = calculatePnl(pos, 51000);
    expect(pnl).toBe(10000);

    const roi = roiDecimal(pnl, balance);
    expect(roi).toBe(0.01);

    const percent = roiToPercent(roi);
    expect(percent).toBe(1);
  });

  it("tie detection works within tolerance", () => {
    const balance = 1_000_000;
    const tieTolerance = 0.00001;

    const p1Pnl = 5000;
    const p2Pnl = 5005;

    const p1Roi = roiDecimal(p1Pnl, balance);
    const p2Roi = roiDecimal(p2Pnl, balance);

    const diff = Math.abs(p1Roi - p2Roi);
    // 5 / 1_000_000 = 0.000005, which is less than 0.00001 tolerance
    expect(diff).toBeLessThanOrEqual(tieTolerance);
  });

  it("clearly different ROIs are not ties", () => {
    const balance = 1_000_000;
    const tieTolerance = 0.00001;

    const p1Roi = roiDecimal(50000, balance);  // 5%
    const p2Roi = roiDecimal(-20000, balance); // -2%

    const diff = Math.abs(p1Roi - p2Roi);
    expect(diff).toBeGreaterThan(tieTolerance);
  });
});
