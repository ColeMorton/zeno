import type { Address } from 'viem';
import type { Vault } from '../types/vault.js';
import type { RankedVault, PercentileThresholds, RankingOptions } from '../types/percentile.js';
import type { VaultQueryOptions } from '../types/filter.js';
import type { IndexedEvent } from '../events/schema.js';
import type { DataSourceAdapter, AdapterEventFilter } from './adapters.js';
import type { PortfolioStats, TierDistribution, VestingDistribution } from '../analytics/aggregation.js';
import type { GrowthTimeSeriesPoint, WithdrawalTimeSeriesPoint, RedemptionTimeSeriesPoint, TimeInterval } from '../analytics/timeseries.js';
import type { Cohort, CohortAnalysis } from '../analytics/cohorts.js';
import type { RiskLevel, DormancyRisk, EcosystemHealth } from '../analytics/health.js';
import type { AchievementDistribution, AchievementFunnel, WalletAchievementProfile } from '../analytics/achievement-analytics.js';
import type { VaultMintedEvent, WithdrawnEvent, EarlyRedemptionEvent } from '../events/schema.js';

import { rankByCollateral, getVaultRanking } from '../analytics/percentile.js';
import {
  calculatePortfolioStats,
  calculateTierDistribution,
  calculateVestingDistribution,
} from '../analytics/aggregation.js';
import {
  buildGrowthTimeSeries,
  buildWithdrawalTimeSeries,
  buildRedemptionTimeSeries,
} from '../analytics/timeseries.js';
import { buildCohortAnalysis } from '../analytics/cohorts.js';
import {
  analyzeDormancyRisks,
  calculateEcosystemHealth,
} from '../analytics/health.js';
import {
  calculateAchievementDistribution,
  calculateAchievementFunnel,
  buildWalletProfiles,
  getAchievementLeaderboard,
} from '../analytics/achievement-analytics.js';

/**
 * Analytics API configuration
 */
export interface AnalyticsAPIConfig {
  /** Data source adapter */
  adapter: DataSourceAdapter;
  /** Default percentile thresholds */
  percentileThresholds?: PercentileThresholds | undefined;
}

/**
 * Leaderboard options
 */
export interface LeaderboardOptions {
  /** Maximum entries to return */
  limit?: number | undefined;
}

/**
 * Unified Analytics API
 *
 * Provides a consistent interface for analytics operations
 * regardless of the underlying data source.
 *
 * @example
 * ```typescript
 * const indexer = createAnvilIndexer('http://localhost:8545');
 * const adapter = createAnvilAdapter(indexer);
 * const api = createAnalyticsAPI({ adapter });
 *
 * const stats = await api.getPortfolioStats();
 * const risks = await api.getDormancyRisks('HIGH');
 * ```
 */
export class AnalyticsAPI {
  private adapter: DataSourceAdapter;
  private thresholds?: PercentileThresholds | undefined;

  constructor(config: AnalyticsAPIConfig) {
    this.adapter = config.adapter;
    this.thresholds = config.percentileThresholds;
  }

  /**
   * Build ranking options with thresholds if defined
   */
  private getRankingOptions(): RankingOptions {
    return this.thresholds ? { thresholds: this.thresholds } : {};
  }

  // ============================================================
  // Portfolio Analytics
  // ============================================================

  /**
   * Get portfolio statistics for vaults
   */
  async getPortfolioStats(filter?: VaultQueryOptions): Promise<PortfolioStats> {
    const vaults = await this.adapter.getVaults(filter);
    return calculatePortfolioStats(vaults);
  }

  /**
   * Get tier distribution from ranked vaults
   */
  async getTierDistribution(filter?: VaultQueryOptions): Promise<TierDistribution> {
    const vaults = await this.adapter.getVaults(filter);
    const ranked = rankByCollateral(vaults, this.getRankingOptions());
    return calculateTierDistribution(ranked);
  }

  /**
   * Get vesting status distribution
   */
  async getVestingDistribution(
    filter?: VaultQueryOptions,
    currentTimestamp?: bigint
  ): Promise<VestingDistribution> {
    const vaults = await this.adapter.getVaults(filter);
    return calculateVestingDistribution(vaults, currentTimestamp);
  }

  // ============================================================
  // Time-Series Analytics
  // ============================================================

  /**
   * Get vault growth time series
   */
  async getGrowthTimeSeries(
    interval: TimeInterval = 'day',
    filter?: AdapterEventFilter
  ): Promise<GrowthTimeSeriesPoint[]> {
    const events = await this.adapter.getEvents({
      ...filter,
      types: ['VaultMinted'],
    });
    const mintEvents = events.filter(
      (e): e is VaultMintedEvent => e.type === 'VaultMinted'
    );
    return buildGrowthTimeSeries(mintEvents, interval);
  }

  /**
   * Get withdrawal time series
   */
  async getWithdrawalTimeSeries(
    interval: TimeInterval = 'day',
    filter?: AdapterEventFilter
  ): Promise<WithdrawalTimeSeriesPoint[]> {
    const events = await this.adapter.getEvents({
      ...filter,
      types: ['Withdrawn'],
    });
    const withdrawEvents = events.filter(
      (e): e is WithdrawnEvent => e.type === 'Withdrawn'
    );
    return buildWithdrawalTimeSeries(withdrawEvents, interval);
  }

  /**
   * Get redemption time series
   */
  async getRedemptionTimeSeries(
    interval: TimeInterval = 'day',
    filter?: AdapterEventFilter
  ): Promise<RedemptionTimeSeriesPoint[]> {
    const events = await this.adapter.getEvents({
      ...filter,
      types: ['EarlyRedemption'],
    });
    const redemptionEvents = events.filter(
      (e): e is EarlyRedemptionEvent => e.type === 'EarlyRedemption'
    );
    return buildRedemptionTimeSeries(redemptionEvents, interval);
  }

  // ============================================================
  // Cohort Analytics
  // ============================================================

  /**
   * Get cohort retention analysis
   */
  async getCohortAnalysis(filter?: AdapterEventFilter): Promise<CohortAnalysis> {
    const allEvents = await this.adapter.getEvents(filter);
    const mintEvents = allEvents.filter(
      (e): e is VaultMintedEvent => e.type === 'VaultMinted'
    );
    const redemptionEvents = allEvents.filter(
      (e): e is EarlyRedemptionEvent => e.type === 'EarlyRedemption'
    );
    return buildCohortAnalysis(mintEvents, redemptionEvents);
  }

  /**
   * Get cohorts as flat array
   */
  async getCohorts(filter?: AdapterEventFilter): Promise<Cohort[]> {
    const analysis = await this.getCohortAnalysis(filter);
    return analysis.cohorts;
  }

  // ============================================================
  // Health Analytics
  // ============================================================

  /**
   * Get ecosystem health metrics
   */
  async getEcosystemHealth(
    filter?: VaultQueryOptions,
    currentTimestamp?: bigint
  ): Promise<EcosystemHealth> {
    const vaults = await this.adapter.getVaults(filter);
    const events = await this.adapter.getEvents();
    return calculateEcosystemHealth(events, vaults, currentTimestamp);
  }

  /**
   * Get dormancy risks for vaults
   */
  async getDormancyRisks(
    minRiskLevel: RiskLevel = 'MEDIUM',
    filter?: VaultQueryOptions,
    currentTimestamp?: bigint
  ): Promise<DormancyRisk[]> {
    const vaults = await this.adapter.getVaults(filter);
    return analyzeDormancyRisks(vaults, currentTimestamp, minRiskLevel);
  }

  // ============================================================
  // Achievement Analytics
  // ============================================================

  /**
   * Get achievement distribution
   */
  async getAchievementDistribution(
    filter?: AdapterEventFilter
  ): Promise<AchievementDistribution[]> {
    const events = await this.adapter.getEvents(filter);
    return calculateAchievementDistribution(events);
  }

  /**
   * Get achievement funnel metrics
   */
  async getAchievementFunnel(filter?: AdapterEventFilter): Promise<AchievementFunnel> {
    const events = await this.adapter.getEvents(filter);
    return calculateAchievementFunnel(events);
  }

  /**
   * Get wallet achievement profiles
   */
  async getWalletProfiles(filter?: AdapterEventFilter): Promise<WalletAchievementProfile[]> {
    const events = await this.adapter.getEvents(filter);
    return buildWalletProfiles(events);
  }

  // ============================================================
  // Leaderboards
  // ============================================================

  /**
   * Get collateral leaderboard (top vaults by collateral)
   */
  async getCollateralLeaderboard(
    options: LeaderboardOptions = {},
    filter?: VaultQueryOptions
  ): Promise<RankedVault[]> {
    const { limit = 10 } = options;
    const vaults = await this.adapter.getVaults(filter);
    const ranked = rankByCollateral(vaults, this.getRankingOptions());
    return ranked.slice(0, limit);
  }

  /**
   * Get achievement leaderboard (top collectors)
   */
  async getAchievementLeaderboard(
    options: LeaderboardOptions = {},
    filter?: AdapterEventFilter
  ): Promise<WalletAchievementProfile[]> {
    const { limit = 10 } = options;
    const profiles = await this.getWalletProfiles(filter);
    return getAchievementLeaderboard(profiles, limit);
  }

  // ============================================================
  // Vault Queries
  // ============================================================

  /**
   * Get all vaults with optional filtering
   */
  async getVaults(filter?: VaultQueryOptions): Promise<Vault[]> {
    return this.adapter.getVaults(filter);
  }

  /**
   * Get ranked vaults with percentile tiers
   */
  async getRankedVaults(filter?: VaultQueryOptions): Promise<RankedVault[]> {
    const vaults = await this.adapter.getVaults(filter);
    return rankByCollateral(vaults, this.getRankingOptions());
  }

  /**
   * Get vault ranking by token ID
   */
  async getVaultRanking(tokenId: bigint, filter?: VaultQueryOptions): Promise<RankedVault | null> {
    const vaults = await this.adapter.getVaults(filter);
    return getVaultRanking(vaults, tokenId, this.getRankingOptions());
  }

  /**
   * Get vaults by owner
   */
  async getVaultsByOwner(owner: Address, filter?: VaultQueryOptions): Promise<Vault[]> {
    const vaults = await this.adapter.getVaults(filter);
    const normalizedOwner = owner.toLowerCase();
    return vaults.filter((v) => v.owner.toLowerCase() === normalizedOwner);
  }

  // ============================================================
  // Events
  // ============================================================

  /**
   * Get all indexed events
   */
  async getEvents(filter?: AdapterEventFilter): Promise<IndexedEvent[]> {
    return this.adapter.getEvents(filter);
  }

  // ============================================================
  // Utilities
  // ============================================================

  /**
   * Check if the data source is ready
   */
  isReady(): boolean {
    return this.adapter.isReady();
  }

  /**
   * Get the data source type
   */
  getDataSource(): string {
    return this.adapter.source;
  }
}

/**
 * Create an Analytics API instance
 */
export function createAnalyticsAPI(config: AnalyticsAPIConfig): AnalyticsAPI {
  return new AnalyticsAPI(config);
}
