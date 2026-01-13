/**
 * Perpetual vault math utilities.
 * Port of PerpetualMath.sol to TypeScript.
 */

export const PRECISION = 10n ** 18n;
export const BPS = 10000n;

/** Minimum payout: 0.01% (dust floor) */
export const MIN_PAYOUT_BPS = 1n;

/** Maximum payout: 200% (2x cap) */
export const MAX_PAYOUT_BPS = 20000n;

/** Funding sensitivity: 50% max when fully one-sided */
export const FUNDING_SENSITIVITY_BPS = 5000n;

/** Max funding rate per period: 1% */
export const MAX_FUNDING_RATE_BPS = 100n;

export enum Side {
  LONG = 0,
  SHORT = 1,
}

export interface Position {
  collateral: bigint;
  notional: bigint;
  leverageX100: bigint;
  entryPrice: bigint;
  entryFundingAccumulator: bigint;
  openTimestamp: bigint;
  side: Side;
}

export interface GlobalState {
  longOI: bigint;
  shortOI: bigint;
  longCollateral: bigint;
  shortCollateral: bigint;
  fundingAccumulatorLong: bigint;
  fundingAccumulatorShort: bigint;
  lastFundingUpdate: bigint;
}

/**
 * Calculate funding rate based on OI imbalance.
 * @returns rateBPS - positive = longs pay shorts
 */
export function calculateFundingRate(longOI: bigint, shortOI: bigint): bigint {
  const totalOI = longOI + shortOI;
  if (totalOI === 0n) return 0n;

  const oiDelta = longOI - shortOI;
  let rateBPS = (FUNDING_SENSITIVITY_BPS * oiDelta) / totalOI;

  // Cap at max funding rate
  if (rateBPS > MAX_FUNDING_RATE_BPS) {
    rateBPS = MAX_FUNDING_RATE_BPS;
  } else if (rateBPS < -MAX_FUNDING_RATE_BPS) {
    rateBPS = -MAX_FUNDING_RATE_BPS;
  }

  return rateBPS;
}

/**
 * Calculate direction P&L based on price movement.
 */
export function calculateDirectionPnL(
  notional: bigint,
  entryPrice: bigint,
  currentPrice: bigint,
  isLong: boolean
): bigint {
  if (entryPrice === 0n) throw new Error('Zero entry price');

  if (isLong) {
    if (currentPrice >= entryPrice) {
      return (notional * (currentPrice - entryPrice)) / entryPrice;
    } else {
      return -((notional * (entryPrice - currentPrice)) / entryPrice);
    }
  } else {
    if (currentPrice <= entryPrice) {
      return (notional * (entryPrice - currentPrice)) / entryPrice;
    } else {
      return -((notional * (currentPrice - entryPrice)) / entryPrice);
    }
  }
}

/**
 * Calculate funding P&L for a position.
 */
export function calculateFundingPnL(
  notional: bigint,
  entryFundingAccumulator: bigint,
  currentFundingAccumulator: bigint
): bigint {
  const accumulatorDelta = currentFundingAccumulator - entryFundingAccumulator;
  return (notional * accumulatorDelta) / PRECISION;
}

/**
 * Calculate capped payout from collateral and P&L.
 */
export function calculateCappedPayout(
  collateral: bigint,
  totalPnL: bigint
): bigint {
  if (collateral === 0n) return 0n;

  let rawPayout: bigint;
  if (totalPnL >= 0n) {
    rawPayout = collateral + totalPnL;
  } else {
    const loss = -totalPnL;
    if (loss >= collateral) {
      rawPayout = 0n;
    } else {
      rawPayout = collateral - loss;
    }
  }

  const minPayout = (collateral * MIN_PAYOUT_BPS) / BPS;
  const maxPayout = (collateral * MAX_PAYOUT_BPS) / BPS;

  if (rawPayout <= minPayout) {
    return minPayout;
  } else if (rawPayout >= maxPayout) {
    return maxPayout;
  } else {
    return rawPayout;
  }
}

/**
 * Calculate notional from collateral and leverage.
 */
export function calculateNotional(
  collateral: bigint,
  leverageX100: bigint
): bigint {
  return (collateral * leverageX100) / 100n;
}

/**
 * Format funding rate from BPS to percentage string.
 */
export function formatFundingRate(rateBPS: bigint): string {
  const percent = Number(rateBPS) / 100;
  const sign = percent >= 0 ? '+' : '';
  return `${sign}${percent.toFixed(2)}%`;
}

/**
 * Format leverage from X100 to display string.
 */
export function formatLeverage(leverageX100: bigint): string {
  const leverage = Number(leverageX100) / 100;
  return `${leverage.toFixed(1)}x`;
}

/**
 * Calculate maximum price move before payout is capped.
 * At 3x leverage, price can move ±33% before hitting caps.
 */
export function calculateMaxPriceMove(leverageX100: bigint): number {
  // Max loss = 100% (capped at 0.01% payout)
  // Max gain = 100% (capped at 200% payout)
  // Price move = gain/loss / leverage
  const leverage = Number(leverageX100) / 100;
  return 100 / leverage;
}
