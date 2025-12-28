import type {
  VaultMintedEvent,
  WithdrawnEvent,
  EarlyRedemptionEvent,
} from '../events/schema.js';

/**
 * Time interval for grouping data
 */
export type TimeInterval = 'hour' | 'day' | 'week' | 'month';

/**
 * Single point in a growth time series
 */
export interface GrowthTimeSeriesPoint {
  /** Interval start timestamp (Unix seconds) */
  timestamp: bigint;
  /** Date string (ISO format) */
  date: string;
  /** Number of vaults minted in this period */
  periodMints: number;
  /** Collateral deposited in this period (satoshis) */
  periodCollateral: bigint;
  /** Cumulative vault count up to this point */
  cumulativeVaults: number;
  /** Cumulative collateral up to this point (satoshis) */
  cumulativeCollateral: bigint;
}

/**
 * Single point in a withdrawal time series
 */
export interface WithdrawalTimeSeriesPoint {
  /** Interval start timestamp (Unix seconds) */
  timestamp: bigint;
  /** Date string (ISO format) */
  date: string;
  /** Number of withdrawals in this period */
  periodWithdrawals: number;
  /** Amount withdrawn in this period (satoshis) */
  periodAmount: bigint;
  /** Cumulative withdrawal count */
  cumulativeWithdrawals: number;
  /** Cumulative amount withdrawn (satoshis) */
  cumulativeAmount: bigint;
}

/**
 * Single point in a redemption time series
 */
export interface RedemptionTimeSeriesPoint {
  /** Interval start timestamp (Unix seconds) */
  timestamp: bigint;
  /** Date string (ISO format) */
  date: string;
  /** Number of early redemptions in this period */
  periodRedemptions: number;
  /** Amount returned in this period (satoshis) */
  periodReturned: bigint;
  /** Amount forfeited in this period (satoshis) */
  periodForfeited: bigint;
  /** Cumulative redemption count */
  cumulativeRedemptions: number;
}

/**
 * Get interval duration in seconds
 */
function getIntervalSeconds(interval: TimeInterval): bigint {
  switch (interval) {
    case 'hour':
      return 3600n;
    case 'day':
      return 86400n;
    case 'week':
      return 604800n;
    case 'month':
      return 2592000n; // 30 days approximation
  }
}

/**
 * Round timestamp down to interval boundary
 */
function roundToInterval(timestamp: bigint, interval: TimeInterval): bigint {
  const seconds = getIntervalSeconds(interval);
  return (timestamp / seconds) * seconds;
}

/**
 * Format timestamp to ISO date string
 */
function formatTimestamp(timestamp: bigint): string {
  const iso = new Date(Number(timestamp) * 1000).toISOString();
  return iso.split('T')[0] ?? iso;
}

/**
 * Build a growth time series from vault minted events
 *
 * @param events - Array of VaultMinted events
 * @param interval - Time interval for grouping
 * @returns Array of time series points
 *
 * @example
 * ```typescript
 * const events = indexer.getEvents({ types: ['VaultMinted'] });
 * const series = buildGrowthTimeSeries(events as VaultMintedEvent[], 'day');
 * ```
 */
export function buildGrowthTimeSeries(
  events: VaultMintedEvent[],
  interval: TimeInterval = 'day'
): GrowthTimeSeriesPoint[] {
  if (events.length === 0) return [];

  // Sort events by timestamp
  const sorted = [...events].sort((a, b) =>
    a.blockTimestamp < b.blockTimestamp ? -1 : 1
  );

  // Group by interval
  const buckets = new Map<
    bigint,
    { mints: number; collateral: bigint }
  >();

  for (const event of sorted) {
    const bucket = roundToInterval(event.blockTimestamp, interval);
    const existing = buckets.get(bucket) ?? { mints: 0, collateral: 0n };
    buckets.set(bucket, {
      mints: existing.mints + 1,
      collateral: existing.collateral + event.collateral,
    });
  }

  // Convert to time series
  const result: GrowthTimeSeriesPoint[] = [];
  let cumulativeVaults = 0;
  let cumulativeCollateral = 0n;

  const sortedBuckets = [...buckets.entries()].sort((a, b) =>
    a[0] < b[0] ? -1 : 1
  );

  for (const [timestamp, data] of sortedBuckets) {
    cumulativeVaults += data.mints;
    cumulativeCollateral += data.collateral;

    result.push({
      timestamp,
      date: formatTimestamp(timestamp),
      periodMints: data.mints,
      periodCollateral: data.collateral,
      cumulativeVaults,
      cumulativeCollateral,
    });
  }

  return result;
}

/**
 * Build a withdrawal time series from withdrawn events
 *
 * @param events - Array of Withdrawn events
 * @param interval - Time interval for grouping
 * @returns Array of time series points
 *
 * @example
 * ```typescript
 * const events = indexer.getEvents({ types: ['Withdrawn'] });
 * const series = buildWithdrawalTimeSeries(events as WithdrawnEvent[], 'week');
 * ```
 */
export function buildWithdrawalTimeSeries(
  events: WithdrawnEvent[],
  interval: TimeInterval = 'day'
): WithdrawalTimeSeriesPoint[] {
  if (events.length === 0) return [];

  // Sort events by timestamp
  const sorted = [...events].sort((a, b) =>
    a.blockTimestamp < b.blockTimestamp ? -1 : 1
  );

  // Group by interval
  const buckets = new Map<
    bigint,
    { withdrawals: number; amount: bigint }
  >();

  for (const event of sorted) {
    const bucket = roundToInterval(event.blockTimestamp, interval);
    const existing = buckets.get(bucket) ?? { withdrawals: 0, amount: 0n };
    buckets.set(bucket, {
      withdrawals: existing.withdrawals + 1,
      amount: existing.amount + event.amount,
    });
  }

  // Convert to time series
  const result: WithdrawalTimeSeriesPoint[] = [];
  let cumulativeWithdrawals = 0;
  let cumulativeAmount = 0n;

  const sortedBuckets = [...buckets.entries()].sort((a, b) =>
    a[0] < b[0] ? -1 : 1
  );

  for (const [timestamp, data] of sortedBuckets) {
    cumulativeWithdrawals += data.withdrawals;
    cumulativeAmount += data.amount;

    result.push({
      timestamp,
      date: formatTimestamp(timestamp),
      periodWithdrawals: data.withdrawals,
      periodAmount: data.amount,
      cumulativeWithdrawals,
      cumulativeAmount,
    });
  }

  return result;
}

/**
 * Build a redemption time series from early redemption events
 *
 * @param events - Array of EarlyRedemption events
 * @param interval - Time interval for grouping
 * @returns Array of time series points
 *
 * @example
 * ```typescript
 * const events = indexer.getEvents({ types: ['EarlyRedemption'] });
 * const series = buildRedemptionTimeSeries(events as EarlyRedemptionEvent[], 'month');
 * ```
 */
export function buildRedemptionTimeSeries(
  events: EarlyRedemptionEvent[],
  interval: TimeInterval = 'day'
): RedemptionTimeSeriesPoint[] {
  if (events.length === 0) return [];

  // Sort events by timestamp
  const sorted = [...events].sort((a, b) =>
    a.blockTimestamp < b.blockTimestamp ? -1 : 1
  );

  // Group by interval
  const buckets = new Map<
    bigint,
    { redemptions: number; returned: bigint; forfeited: bigint }
  >();

  for (const event of sorted) {
    const bucket = roundToInterval(event.blockTimestamp, interval);
    const existing = buckets.get(bucket) ?? {
      redemptions: 0,
      returned: 0n,
      forfeited: 0n,
    };
    buckets.set(bucket, {
      redemptions: existing.redemptions + 1,
      returned: existing.returned + event.returned,
      forfeited: existing.forfeited + event.forfeited,
    });
  }

  // Convert to time series
  const result: RedemptionTimeSeriesPoint[] = [];
  let cumulativeRedemptions = 0;

  const sortedBuckets = [...buckets.entries()].sort((a, b) =>
    a[0] < b[0] ? -1 : 1
  );

  for (const [timestamp, data] of sortedBuckets) {
    cumulativeRedemptions += data.redemptions;

    result.push({
      timestamp,
      date: formatTimestamp(timestamp),
      periodRedemptions: data.redemptions,
      periodReturned: data.returned,
      periodForfeited: data.forfeited,
      cumulativeRedemptions,
    });
  }

  return result;
}

/**
 * Calculate growth rate between two time series points
 *
 * @param previous - Previous point value
 * @param current - Current point value
 * @returns Growth rate as percentage (-100 to +infinity)
 */
export function calculateGrowthRate(previous: bigint, current: bigint): number {
  if (previous === 0n) {
    return current > 0n ? 100 : 0;
  }
  return (Number(current - previous) / Number(previous)) * 100;
}

/**
 * Calculate moving average for a time series
 *
 * @param values - Array of numeric values
 * @param window - Moving average window size
 * @returns Array of moving averages (shorter by window-1)
 */
export function calculateMovingAverage(values: bigint[], window: number): number[] {
  if (values.length < window) return [];

  const result: number[] = [];

  for (let i = window - 1; i < values.length; i++) {
    let sum = 0n;
    for (let j = 0; j < window; j++) {
      const value = values[i - j];
      if (value !== undefined) {
        sum += value;
      }
    }
    result.push(Number(sum) / window);
  }

  return result;
}
