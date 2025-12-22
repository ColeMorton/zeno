/**
 * @btcnft/vault-analytics
 *
 * Framework-agnostic TypeScript SDK for BTCNFT Protocol vault analytics.
 * Provides utilities for fetching, filtering, and ranking Vault NFTs by
 * collateral percentile.
 *
 * @packageDocumentation
 * @module @btcnft/vault-analytics
 *
 * @example Quick Start
 * ```typescript
 * import { createVaultClient, filterVaults, rankByCollateral } from '@btcnft/vault-analytics';
 *
 * // Initialize client
 * const client = createVaultClient({ chainId: 1 });
 *
 * // Fetch and analyze vaults
 * const vaults = await client.getVaults({
 *   scope: { type: 'issuer', address: '0x...' }
 * });
 * const vested = filterVaults(vaults, { vestingStatus: 'vested' });
 * const ranked = rankByCollateral(vested);
 *
 * console.log(ranked[0]); // Top vault with percentile tier
 * ```
 *
 * @example All-in-One Analytics
 * ```typescript
 * const result = await client.getAnalytics({
 *   scope: { type: 'issuer', address: '0x...' },
 *   filters: { vestingStatus: 'vested' },
 *   pagination: { page: 1, pageSize: 25 }
 * });
 * // result.vaults: RankedVault[]
 * // result.total: number
 * // result.totalPages: number
 * ```
 *
 * @see {@link https://github.com/btcnft/vault-analytics | GitHub Repository}
 */

// Client exports
export { VaultClient, createVaultClient, SubgraphClient } from './client/index.js';

// Analytics exports
export {
  getPercentileTier,
  calculatePercentile,
  rankByCollateral,
  getVaultRanking,
  isVested,
  isSeparated,
  getDormancyStatus,
  getVestingDaysRemaining,
  filterVaults,
  deriveVaultStatus,
} from './analytics/index.js';

// Constants exports
export {
  VESTING_PERIOD,
  VESTING_PERIOD_DAYS,
  WITHDRAWAL_PERIOD,
  WITHDRAWAL_RATE,
  WITHDRAWAL_RATE_DENOMINATOR,
  DORMANCY_THRESHOLD,
  GRACE_PERIOD,
  BTC_DECIMALS,
  DEFAULT_PERCENTILE_THRESHOLDS,
  MIN_VAULTS_FOR_PERCENTILE,
  CHAIN_CONFIGS,
  getChainConfig,
} from './constants/index.js';

// Type exports
export type {
  Vault,
  RawVaultData,
  VestingStatus,
  SeparationStatus,
  DormancyStatus,
  VaultFilter,
  ScopeFilter,
  SortField,
  SortOrder,
  PaginationOptions,
  VaultQueryOptions,
  PercentileTier,
  RankedVault,
  PercentileThresholds,
  RankingOptions,
  AnalyticsResult,
  SupportedChainId,
  ChainConfig,
  VaultClientConfig,
  SubgraphResponse,
} from './types/index.js';
