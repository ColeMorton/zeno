import type { Vault } from '../types/vault.js';
import type { RankedVault, PercentileTier } from '../types/percentile.js';
import { BTC_DECIMALS } from '../constants/protocol.js';

/**
 * Collateral distribution buckets
 */
export interface Distribution {
  /** Bucket boundaries (in BTC) */
  buckets: number[];
  /** Count per bucket */
  counts: number[];
  /** Total collateral per bucket */
  totals: bigint[];
}

/**
 * Portfolio-level statistics
 */
export interface PortfolioStats {
  /** Total number of vaults */
  totalVaults: number;
  /** Total collateral across all vaults (satoshis) */
  totalCollateral: bigint;
  /** Average collateral per vault (satoshis) */
  averageCollateral: bigint;
  /** Median collateral (satoshis) */
  medianCollateral: bigint;
  /** Standard deviation of collateral */
  standardDeviation: bigint;
  /** Number of unique holder addresses */
  uniqueHolders: number;
  /** Collateral distribution across buckets */
  collateralDistribution: Distribution;
}

/**
 * Tier distribution statistics
 */
export interface TierDistribution {
  /** Count per tier */
  counts: Record<PercentileTier, number>;
  /** Total collateral per tier (satoshis) */
  totals: Record<PercentileTier, bigint>;
  /** Percentage of vaults per tier */
  percentages: Record<PercentileTier, number>;
}

/**
 * Vesting distribution statistics
 */
export interface VestingDistribution {
  /** Number of vested vaults */
  vestedCount: number;
  /** Number of vesting vaults */
  vestingCount: number;
  /** Collateral in vested vaults (satoshis) */
  vestedCollateral: bigint;
  /** Collateral in vesting vaults (satoshis) */
  vestingCollateral: bigint;
  /** Average days remaining for vesting vaults */
  averageDaysRemaining: number;
  /** Distribution by remaining days buckets */
  daysBuckets: {
    /** 0-30 days */
    imminent: number;
    /** 31-90 days */
    soon: number;
    /** 91-365 days */
    medium: number;
    /** 366+ days */
    long: number;
  };
}

const VESTING_PERIOD_SECONDS = 1129n * 24n * 60n * 60n;

/**
 * Calculate portfolio-level statistics from a list of vaults
 *
 * @param vaults - Array of vault data
 * @returns Portfolio statistics
 *
 * @example
 * ```typescript
 * const vaults = await client.getAllVaults();
 * const stats = calculatePortfolioStats(vaults);
 * console.log(`Total BTC: ${Number(stats.totalCollateral) / 1e8}`);
 * ```
 */
export function calculatePortfolioStats(vaults: Vault[]): PortfolioStats {
  if (vaults.length === 0) {
    return {
      totalVaults: 0,
      totalCollateral: 0n,
      averageCollateral: 0n,
      medianCollateral: 0n,
      standardDeviation: 0n,
      uniqueHolders: 0,
      collateralDistribution: { buckets: [], counts: [], totals: [] },
    };
  }

  // Calculate basic stats
  const totalVaults = vaults.length;
  const totalCollateral = vaults.reduce((sum, v) => sum + v.collateralAmount, 0n);
  const averageCollateral = totalCollateral / BigInt(totalVaults);

  // Calculate median
  const sortedCollaterals = vaults.map((v) => v.collateralAmount).sort((a, b) => (a < b ? -1 : 1));
  const midIndex = Math.floor(sortedCollaterals.length / 2);
  let medianCollateral: bigint;
  if (sortedCollaterals.length % 2 === 0) {
    const left = sortedCollaterals[midIndex - 1] ?? 0n;
    const right = sortedCollaterals[midIndex] ?? 0n;
    medianCollateral = (left + right) / 2n;
  } else {
    medianCollateral = sortedCollaterals[midIndex] ?? 0n;
  }

  // Calculate standard deviation
  const avgNum = Number(averageCollateral);
  const variance =
    vaults.reduce((sum, v) => {
      const diff = Number(v.collateralAmount) - avgNum;
      return sum + diff * diff;
    }, 0) / totalVaults;
  const standardDeviation = BigInt(Math.floor(Math.sqrt(variance)));

  // Count unique holders
  const uniqueHolders = new Set(vaults.map((v) => v.owner.toLowerCase())).size;

  // Calculate distribution
  const collateralDistribution = calculateDistribution(vaults);

  return {
    totalVaults,
    totalCollateral,
    averageCollateral,
    medianCollateral,
    standardDeviation,
    uniqueHolders,
    collateralDistribution,
  };
}

/**
 * Calculate collateral distribution across buckets
 */
function calculateDistribution(vaults: Vault[]): Distribution {
  // Default buckets in BTC: 0-0.1, 0.1-0.5, 0.5-1, 1-5, 5-10, 10+
  const buckets = [0.1, 0.5, 1, 5, 10, Infinity];
  const counts = new Array(buckets.length).fill(0);
  const totals = new Array(buckets.length).fill(0n);

  const btcDecimals = 10 ** Number(BTC_DECIMALS);

  for (const vault of vaults) {
    const btcAmount = Number(vault.collateralAmount) / btcDecimals;

    for (let i = 0; i < buckets.length; i++) {
      const bucketLimit = buckets[i];
      if (bucketLimit !== undefined && btcAmount < bucketLimit) {
        counts[i]++;
        const currentTotal = totals[i] as bigint;
        totals[i] = currentTotal + vault.collateralAmount;
        break;
      }
    }
  }

  return { buckets, counts, totals };
}

/**
 * Calculate tier distribution from ranked vaults
 *
 * @param vaults - Array of ranked vault data
 * @returns Distribution across tiers
 *
 * @example
 * ```typescript
 * const ranked = rankByCollateral(vaults);
 * const tierDist = calculateTierDistribution(ranked);
 * console.log(`Diamond vaults: ${tierDist.counts.Diamond}`);
 * ```
 */
export function calculateTierDistribution(vaults: RankedVault[]): TierDistribution {
  const tiers: PercentileTier[] = ['Diamond', 'Platinum', 'Gold', 'Silver', 'Bronze'];

  const counts: Record<PercentileTier, number> = {
    Diamond: 0,
    Platinum: 0,
    Gold: 0,
    Silver: 0,
    Bronze: 0,
  };

  const totals: Record<PercentileTier, bigint> = {
    Diamond: 0n,
    Platinum: 0n,
    Gold: 0n,
    Silver: 0n,
    Bronze: 0n,
  };

  for (const rankedVault of vaults) {
    const tier = rankedVault.tier;
    if (tier !== null) {
      counts[tier]++;
      totals[tier] = totals[tier] + rankedVault.vault.collateralAmount;
    }
  }

  const percentages: Record<PercentileTier, number> = {
    Diamond: 0,
    Platinum: 0,
    Gold: 0,
    Silver: 0,
    Bronze: 0,
  };

  if (vaults.length > 0) {
    for (const tier of tiers) {
      percentages[tier] = (counts[tier] / vaults.length) * 100;
    }
  }

  return { counts, totals, percentages };
}

/**
 * Calculate vesting distribution
 *
 * @param vaults - Array of vault data
 * @param currentTimestamp - Current timestamp (seconds), defaults to now
 * @returns Vesting distribution statistics
 *
 * @example
 * ```typescript
 * const vestDist = calculateVestingDistribution(vaults);
 * console.log(`Vested: ${vestDist.vestedCount}, Vesting: ${vestDist.vestingCount}`);
 * ```
 */
export function calculateVestingDistribution(
  vaults: Vault[],
  currentTimestamp: bigint = BigInt(Math.floor(Date.now() / 1000))
): VestingDistribution {
  let vestedCount = 0;
  let vestingCount = 0;
  let vestedCollateral = 0n;
  let vestingCollateral = 0n;
  let totalDaysRemaining = 0;

  const daysBuckets = {
    imminent: 0,
    soon: 0,
    medium: 0,
    long: 0,
  };

  for (const vault of vaults) {
    const vestingEndsAt = vault.mintTimestamp + VESTING_PERIOD_SECONDS;

    if (currentTimestamp >= vestingEndsAt) {
      vestedCount++;
      vestedCollateral += vault.collateralAmount;
    } else {
      vestingCount++;
      vestingCollateral += vault.collateralAmount;

      const secondsRemaining = vestingEndsAt - currentTimestamp;
      const daysRemaining = Number(secondsRemaining) / (24 * 60 * 60);
      totalDaysRemaining += daysRemaining;

      if (daysRemaining <= 30) {
        daysBuckets.imminent++;
      } else if (daysRemaining <= 90) {
        daysBuckets.soon++;
      } else if (daysRemaining <= 365) {
        daysBuckets.medium++;
      } else {
        daysBuckets.long++;
      }
    }
  }

  const averageDaysRemaining = vestingCount > 0 ? totalDaysRemaining / vestingCount : 0;

  return {
    vestedCount,
    vestingCount,
    vestedCollateral,
    vestingCollateral,
    averageDaysRemaining,
    daysBuckets,
  };
}

/**
 * Format portfolio stats for display
 */
export function formatPortfolioStats(stats: PortfolioStats): string {
  const btcDecimals = 10 ** Number(BTC_DECIMALS);
  const formatBtc = (value: bigint) => (Number(value) / btcDecimals).toFixed(8);

  return `
=== Portfolio Statistics ===
Total Vaults:     ${stats.totalVaults}
Unique Holders:   ${stats.uniqueHolders}
Total Collateral: ${formatBtc(stats.totalCollateral)} BTC
Average:          ${formatBtc(stats.averageCollateral)} BTC
Median:           ${formatBtc(stats.medianCollateral)} BTC
Std Deviation:    ${formatBtc(stats.standardDeviation)} BTC
`.trim();
}
