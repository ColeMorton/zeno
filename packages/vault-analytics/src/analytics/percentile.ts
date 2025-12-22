import type { Vault } from '../types/vault.js';
import type {
  PercentileTier,
  RankedVault,
  PercentileThresholds,
  RankingOptions,
} from '../types/percentile.js';
import {
  DEFAULT_PERCENTILE_THRESHOLDS,
  MIN_VAULTS_FOR_PERCENTILE,
} from '../constants/protocol.js';

/**
 * Get the percentile tier for a given percentile value.
 *
 * Maps percentile values to tier names based on configurable thresholds.
 * Default tiers: Whale (99+), Diamond (95+), Gold (90+), Silver (75+), Bronze (50+).
 *
 * @param percentile - Percentile value (0-100)
 * @param thresholds - Custom tier thresholds (optional)
 * @returns Tier name or null if below Bronze threshold
 *
 * @example Get tier for percentile
 * ```typescript
 * getPercentileTier(99.5); // 'Whale'
 * getPercentileTier(95);   // 'Diamond'
 * getPercentileTier(49);   // null
 * ```
 *
 * @example Custom thresholds
 * ```typescript
 * getPercentileTier(97, { whale: 98, diamond: 90 }); // 'Diamond'
 * ```
 */
export function getPercentileTier(
  percentile: number,
  thresholds: PercentileThresholds = DEFAULT_PERCENTILE_THRESHOLDS
): PercentileTier | null {
  if (percentile >= thresholds.whale) return 'Whale';
  if (percentile >= thresholds.diamond) return 'Diamond';
  if (percentile >= thresholds.gold) return 'Gold';
  if (percentile >= thresholds.silver) return 'Silver';
  if (percentile >= thresholds.bronze) return 'Bronze';
  return null;
}

/**
 * Calculate percentile for a given rank within a dataset.
 *
 * Uses the formula: ((total - rank) / total) * 100
 *
 * @param rank - Position in sorted list (1 = highest)
 * @param total - Total items in dataset
 * @returns Percentile value (0-100)
 *
 * @example Calculate percentile
 * ```typescript
 * calculatePercentile(1, 100);   // 99 (top 1%)
 * calculatePercentile(10, 100);  // 90 (top 10%)
 * calculatePercentile(50, 100);  // 50 (median)
 * ```
 */
export function calculatePercentile(rank: number, total: number): number {
  if (total === 0) return 0;
  return ((total - rank) / total) * 100;
}

/**
 * Rank vaults by collateral amount and calculate percentiles.
 *
 * Vaults are sorted by `collateralAmount` descending. Ties are broken by
 * `mintTimestamp` (earlier mint = higher rank).
 *
 * @param vaults - Array of vaults to rank
 * @param options - Ranking options (custom thresholds, minimum vault count)
 * @returns Array of ranked vaults, each containing:
 *   - `vault`: Original vault data
 *   - `rank`: Position (1 = highest collateral)
 *   - `percentile`: Value from 0-100
 *   - `tier`: 'Whale' | 'Diamond' | 'Gold' | 'Silver' | 'Bronze' | null
 *
 * @example Basic ranking
 * ```typescript
 * const ranked = rankByCollateral(vaults);
 * console.log(ranked[0]);
 * // { vault: {...}, rank: 1, percentile: 99.5, tier: 'Whale' }
 * ```
 *
 * @example Custom thresholds
 * ```typescript
 * const ranked = rankByCollateral(vaults, {
 *   thresholds: { whale: 98, diamond: 90, gold: 80, silver: 60, bronze: 40 }
 * });
 * ```
 *
 * @remarks
 * - Percentile display requires minimum 10 vaults (configurable via `minVaultsForPercentile`)
 * - Returns empty array if input is empty
 */
export function rankByCollateral(
  vaults: Vault[],
  options: RankingOptions = {}
): RankedVault[] {
  const {
    thresholds = DEFAULT_PERCENTILE_THRESHOLDS,
    minVaultsForPercentile = MIN_VAULTS_FOR_PERCENTILE,
  } = options;

  const mergedThresholds: PercentileThresholds = {
    ...DEFAULT_PERCENTILE_THRESHOLDS,
    ...thresholds,
  };

  // Sort by collateral descending, then by mintTimestamp ascending (earlier = higher rank)
  const sorted = [...vaults].sort((a, b) => {
    const collateralDiff = b.collateralAmount - a.collateralAmount;
    if (collateralDiff !== 0n) {
      return collateralDiff > 0n ? 1 : -1;
    }
    // Tie-breaker: earlier mint gets higher rank
    return a.mintTimestamp < b.mintTimestamp ? -1 : 1;
  });

  const total = sorted.length;
  const showPercentile = total >= minVaultsForPercentile;

  return sorted.map((vault, index) => {
    const rank = index + 1;
    const percentile = showPercentile ? calculatePercentile(rank, total) : 0;
    const tier = showPercentile ? getPercentileTier(percentile, mergedThresholds) : null;

    return {
      vault,
      rank,
      percentile,
      tier,
    };
  });
}

/**
 * Get ranking for a specific vault within a dataset.
 *
 * Calculates rankings for all vaults, then returns the entry for the
 * specified token ID.
 *
 * @param vaults - Full dataset of vaults
 * @param tokenId - Token ID to find
 * @param options - Ranking options
 * @returns Ranked vault or null if not found
 *
 * @example Look up vault ranking
 * ```typescript
 * const ranking = getVaultRanking(vaults, 42n);
 * if (ranking) {
 *   console.log(`Vault #42 is rank ${ranking.rank} (${ranking.tier})`);
 * }
 * ```
 */
export function getVaultRanking(
  vaults: Vault[],
  tokenId: bigint,
  options: RankingOptions = {}
): RankedVault | null {
  const ranked = rankByCollateral(vaults, options);
  return ranked.find((r) => r.vault.tokenId === tokenId) ?? null;
}
