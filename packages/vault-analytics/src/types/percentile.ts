import type { Vault } from './vault.js';

/**
 * Percentile tier names
 */
export type PercentileTier = 'Diamond' | 'Platinum' | 'Gold' | 'Silver' | 'Bronze';

/**
 * Vault with calculated rank and percentile
 */
export interface RankedVault {
  /** Original vault data */
  vault: Vault;
  /** Rank position (1 = highest collateral) */
  rank: number;
  /** Percentile value (0-100) */
  percentile: number;
  /** Tier badge (null if below Bronze threshold) */
  tier: PercentileTier | null;
}

/**
 * Percentile tier thresholds
 */
export interface PercentileThresholds {
  /** Minimum percentile for Diamond tier (default: 99) */
  diamond: number;
  /** Minimum percentile for Platinum tier (default: 95) */
  platinum: number;
  /** Minimum percentile for Gold tier (default: 90) */
  gold: number;
  /** Minimum percentile for Silver tier (default: 75) */
  silver: number;
  /** Minimum percentile for Bronze tier (default: 50) */
  bronze: number;
}

/**
 * Ranking options
 */
export interface RankingOptions {
  /** Custom tier thresholds */
  thresholds?: Partial<PercentileThresholds>;
  /** Minimum vaults required for percentile display */
  minVaultsForPercentile?: number;
}

/**
 * Analytics result with pagination info
 */
export interface AnalyticsResult {
  /** Ranked vaults for current page */
  vaults: RankedVault[];
  /** Total vaults matching filters (before pagination) */
  total: number;
  /** Current page number */
  page: number;
  /** Page size */
  pageSize: number;
  /** Total pages */
  totalPages: number;
}
