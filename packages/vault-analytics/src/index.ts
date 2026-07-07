/**
 * @btcnft/vault-analytics
 *
 * Framework-agnostic TypeScript SDK for BTCNFT Protocol vault analytics.
 */

// Client
export { VaultClient, createVaultClient } from './client/VaultClient.js';
export { SubgraphClient, type SubgraphQueryOptions } from './client/SubgraphClient.js';

// Analytics
export {
  getPercentileTier,
  calculatePercentile,
  rankByCollateral,
  getVaultRanking,
} from './analytics/percentile.js';
export {
  isVested,
  isStripped,
  getDormancyStatus,
  getVestingDaysRemaining,
  filterVaults,
  deriveVaultStatus,
} from './analytics/filters.js';

// Indexer
export {
  AnvilIndexer,
  createAnvilIndexer,
  type ContractAddresses,
  type EventFilter,
  type AnvilIndexerConfig,
} from './indexer/anvil.js';

// Adapters
export {
  AnvilAdapter,
  SubgraphAdapter,
  createAnvilAdapter,
  createSubgraphAdapter,
  type DataSource,
  type DataSourceAdapter,
  type AdapterEventFilter,
  type AnvilAdapterConfig,
  type SubgraphAdapterConfig,
} from './api/adapters.js';

// Constants
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
} from './constants/protocol.js';
export { CHAIN_CONFIGS, getChainConfig } from './constants/chains.js';

// Events
export { EVENT_TYPES, parseDormancyState } from './events/schema.js';
export type {
  EventMetadata,
  DormancyState,
  EventType,
  IndexedEvent,
  ProtocolEvent,
} from './events/schema.js';

// Types
export type { Vault, RawVaultData } from './types/vault.js';
export type {
  VestingStatus,
  StripStatus,
  DormancyStatus,
  VaultFilter,
  ScopeFilter,
  SortField,
  SortOrder,
  PaginationOptions,
  VaultQueryOptions,
} from './types/filter.js';
export type {
  PercentileTier,
  RankedVault,
  PercentileThresholds,
  RankingOptions,
  AnalyticsResult,
} from './types/percentile.js';
export type {
  SupportedChainId,
  ChainConfig,
  VaultClientConfig,
  SubgraphResponse,
} from './types/client.js';
