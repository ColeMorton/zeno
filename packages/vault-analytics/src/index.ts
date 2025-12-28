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
export {
  VaultClient,
  createVaultClient,
  SubgraphClient,
  AchievementClient,
  createAchievementClient,
  type AchievementClientConfig,
} from './client/index.js';

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
  getTierVisualConfig,
  getHighestRarityAchievement,
  getAchievementVisuals,
  composeVisualHierarchy,
  // Aggregation
  calculatePortfolioStats,
  calculateTierDistribution,
  calculateVestingDistribution,
  formatPortfolioStats,
  type PortfolioStats,
  type TierDistribution,
  type VestingDistribution,
  type Distribution,
  // Time-series
  buildGrowthTimeSeries,
  buildWithdrawalTimeSeries,
  buildRedemptionTimeSeries,
  calculateGrowthRate,
  calculateMovingAverage,
  type TimeInterval,
  type GrowthTimeSeriesPoint,
  type WithdrawalTimeSeriesPoint,
  type RedemptionTimeSeriesPoint,
  // Cohorts
  buildCohortAnalysis,
  buildRetentionMatrix,
  formatCohortAnalysis,
  type Cohort,
  type CohortAnalysis,
  // Health
  calculateDormancyRisk,
  analyzeDormancyRisks,
  calculateEcosystemHealth,
  formatEcosystemHealth,
  groupByRiskLevel,
  calculateCollateralAtRisk,
  DEFAULT_DORMANCY_THRESHOLDS,
  type RiskLevel,
  type DormancyRisk,
  type DormancyThresholds,
  type EcosystemHealth,
  // Achievement Analytics
  calculateAchievementDistribution,
  calculateAchievementFunnel,
  buildWalletProfiles,
  getAchievementLeaderboard,
  formatAchievementDistribution,
  formatAchievementFunnel,
  type AchievementDistribution,
  type AchievementFunnel,
  type WalletAchievementProfile,
} from './analytics/index.js';

// Metadata exports
export {
  MetadataBuilder,
  createMetadataBuilder,
  type MetadataAttribute,
  type TreasureMetadata,
  type MetadataBuilderConfig,
} from './metadata/index.js';

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
  ACHIEVEMENT_TYPE_HASHES,
  HASH_TO_ACHIEVEMENT_TYPE,
  DURATION_THRESHOLDS,
  DURATION_THRESHOLDS_DAYS,
  ACHIEVEMENT_CATEGORIES,
  ALL_ACHIEVEMENT_TYPES,
  DURATION_ACHIEVEMENT_TYPES,
  isDurationAchievement,
  getDurationThreshold,
  TIER_VISUALS,
  ACHIEVEMENT_VISUALS,
  RARITY_ORDER,
} from './constants/index.js';

// Event schema exports
export type {
  EventMetadata,
  DormancyState,
  EventType,
  IndexedEvent,
  ProtocolEvent,
  VaultMintedEvent,
  WithdrawnEvent,
  EarlyRedemptionEvent,
  BtcTokenMintedEvent,
  BtcTokenReturnedEvent,
  MatchClaimedEvent,
  MatchPoolFundedEvent,
  DormantPokedEvent,
  DormancyStateChangedEvent,
  ActivityProvenEvent,
  DormantCollateralClaimedEvent,
  WithdrawalDelegateGrantedEvent,
  WithdrawalDelegateRevokedEvent,
  AllWithdrawalDelegatesRevokedEvent,
  DelegatedWithdrawalEvent,
  AchievementEvent,
  MinterAchievementClaimedEvent,
  MaturedAchievementClaimedEvent,
  DurationAchievementClaimedEvent,
  HodlerSupremeVaultMintedEvent,
  AuctionEvent,
  DutchAuctionCreatedEvent,
  DutchPurchaseEvent,
  EnglishAuctionCreatedEvent,
  BidPlacedEvent,
  BidRefundedEvent,
  SlotSettledEvent,
  AuctionFinalizedEvent,
} from './events/index.js';

export { EVENT_TYPES, parseDormancyState } from './events/index.js';

// Indexer exports
export {
  AnvilIndexer,
  createAnvilIndexer,
  type ContractAddresses,
  type EventFilter,
  type AnvilIndexerConfig,
} from './indexer/index.js';

// Simulation exports
export {
  SimulationReporter,
  createSimulationReporter,
  type SimulationReport,
  type SimulationSummary,
  type SimulationReporterConfig,
  readGhostVariables,
  formatGhostVariables,
  calculateConservation,
  type GhostVariables,
  type ProtocolGhostVariables,
  type CrossLayerGhostVariables,
  type CallCounterVariables,
} from './simulation/index.js';

// Export utilities
export {
  exportVaults,
  exportRankedVaults,
  exportEvents,
  exportPortfolioStats,
  exportEcosystemHealth,
  exportDormancyRisks,
  exportAchievementDistribution,
  exportCohorts,
  type ExportFormat,
  type ExportOptions,
} from './export/index.js';

// Unified API exports
export {
  AnalyticsAPI,
  createAnalyticsAPI,
  AnvilAdapter,
  SubgraphAdapter,
  createAnvilAdapter,
  createSubgraphAdapter,
  type AnalyticsAPIConfig,
  type LeaderboardOptions,
  type DataSource,
  type DataSourceAdapter,
  type AdapterEventFilter,
  type AnvilAdapterConfig,
  type SubgraphAdapterConfig,
} from './api/index.js';

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
  AchievementType,
  AchievementCategory,
  Achievement,
  AchievementStatus,
  AchievementEligibility,
  DisplayTier,
  FrameStyle,
  FrameAnimation,
  TierVisualConfig,
  AchievementRarity,
  AchievementVisual,
  VaultVisualHierarchy,
} from './types/index.js';
