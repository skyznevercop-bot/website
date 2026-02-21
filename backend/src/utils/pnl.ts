/**
 * Single source of truth for all PnL and ROI calculations.
 *
 * Used by: settlement, WS handler (SL/TP monitor, close_position,
 * opponent broadcast), REST match endpoint.
 */

export interface PnlPosition {
  entryPrice: number;
  exitPrice?: number;
  isLong: boolean;
  size: number;
  leverage: number;
}

/**
 * Calculate PnL for a position.
 *
 * Formula: (priceDiff / entryPrice) × size × leverage
 * Losses are capped at -size (can't lose more than margin).
 */
export function calculatePnl(pos: PnlPosition, currentPrice: number): number {
  const exitPrice = pos.exitPrice ?? currentPrice;
  const priceDiff = pos.isLong
    ? exitPrice - pos.entryPrice
    : pos.entryPrice - exitPrice;
  const rawPnl = (priceDiff / pos.entryPrice) * pos.size * pos.leverage;
  return Math.max(rawPnl, -pos.size);
}

/**
 * Liquidation price for a position.
 * @param threshold — fraction of margin loss that triggers liquidation (default 0.9 = 90%).
 */
export function liquidationPrice(pos: PnlPosition, threshold = 0.9): number {
  return pos.isLong
    ? pos.entryPrice * (1 - threshold / pos.leverage)
    : pos.entryPrice * (1 + threshold / pos.leverage);
}

/**
 * ROI as a decimal (e.g. 0.05 = 5%).
 */
export function roiDecimal(totalPnl: number, initialBalance: number): number {
  return initialBalance > 0 ? totalPnl / initialBalance : 0;
}

/**
 * Convert ROI decimal → display percentage, rounded to 2 dp.
 * 0.05 → 5.00
 */
export function roiToPercent(roiDec: number): number {
  return Math.round(roiDec * 10000) / 100;
}
