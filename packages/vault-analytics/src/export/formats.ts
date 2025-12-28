import type { Vault } from '../types/vault.js';
import type { RankedVault } from '../types/percentile.js';
import type { IndexedEvent } from '../events/schema.js';
import type { PortfolioStats } from '../analytics/aggregation.js';
import type { EcosystemHealth, DormancyRisk } from '../analytics/health.js';
import type { AchievementDistribution } from '../analytics/achievement-analytics.js';
import type { Cohort } from '../analytics/cohorts.js';
import { BTC_DECIMALS } from '../constants/protocol.js';

/**
 * Export format options
 */
export type ExportFormat = 'json' | 'csv';

/**
 * Export options
 */
export interface ExportOptions {
  /** Output format */
  format: ExportFormat;
  /** Include timestamps in ISO format */
  includeTimestamps?: boolean | undefined;
  /** Include metadata (export time, version) */
  includeMetadata?: boolean | undefined;
  /** Pretty print JSON */
  prettyPrint?: boolean | undefined;
}

/**
 * Export metadata
 */
interface ExportMetadata {
  exportedAt: string;
  format: ExportFormat;
  version: string;
}

/**
 * Default export options
 */
const DEFAULT_OPTIONS: Required<ExportOptions> = {
  format: 'json',
  includeTimestamps: true,
  includeMetadata: true,
  prettyPrint: true,
};

/**
 * Serialize bigint values to strings
 */
function serializeBigints<T>(obj: T): unknown {
  if (obj === null || obj === undefined) return obj;
  if (typeof obj === 'bigint') return obj.toString();
  if (Array.isArray(obj)) return obj.map(serializeBigints);
  if (typeof obj === 'object') {
    const result: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(obj)) {
      result[key] = serializeBigints(value);
    }
    return result;
  }
  return obj;
}

/**
 * Format BTC value for display
 */
function formatBtc(value: bigint): string {
  return (Number(value) / 10 ** Number(BTC_DECIMALS)).toFixed(8);
}

/**
 * Create export metadata
 */
function createMetadata(format: ExportFormat): ExportMetadata {
  return {
    exportedAt: new Date().toISOString(),
    format,
    version: '1.0.0',
  };
}

/**
 * Export vaults to JSON or CSV
 *
 * @param vaults - Array of vault data
 * @param options - Export options
 * @returns Formatted string
 */
export function exportVaults(
  vaults: Vault[],
  options: Partial<ExportOptions> = {}
): string {
  const opts = { ...DEFAULT_OPTIONS, ...options };

  if (opts.format === 'json') {
    const data = opts.includeMetadata
      ? { metadata: createMetadata('json'), vaults: serializeBigints(vaults) }
      : serializeBigints(vaults);
    return JSON.stringify(data, null, opts.prettyPrint ? 2 : 0);
  }

  // CSV format
  const headers = [
    'tokenId',
    'owner',
    'treasureContract',
    'treasureTokenId',
    'collateralToken',
    'collateralAmount',
    'collateralBTC',
    'mintTimestamp',
    'lastWithdrawal',
    'vestedBTCAmount',
    'lastActivity',
    'windowId',
    'issuer',
  ];

  const rows = vaults.map((v) => [
    v.tokenId.toString(),
    v.owner,
    v.treasureContract,
    v.treasureTokenId.toString(),
    v.collateralToken,
    v.collateralAmount.toString(),
    formatBtc(v.collateralAmount),
    opts.includeTimestamps ? new Date(Number(v.mintTimestamp) * 1000).toISOString() : v.mintTimestamp.toString(),
    v.lastWithdrawal.toString(),
    v.vestedBTCAmount.toString(),
    v.lastActivity.toString(),
    v.windowId.toString(),
    v.issuer,
  ]);

  return [headers.join(','), ...rows.map((r) => r.join(','))].join('\n');
}

/**
 * Export ranked vaults to JSON or CSV
 *
 * @param vaults - Array of ranked vault data
 * @param options - Export options
 * @returns Formatted string
 */
export function exportRankedVaults(
  vaults: RankedVault[],
  options: Partial<ExportOptions> = {}
): string {
  const opts = { ...DEFAULT_OPTIONS, ...options };

  if (opts.format === 'json') {
    const data = opts.includeMetadata
      ? { metadata: createMetadata('json'), vaults: serializeBigints(vaults) }
      : serializeBigints(vaults);
    return JSON.stringify(data, null, opts.prettyPrint ? 2 : 0);
  }

  // CSV format
  const headers = [
    'rank',
    'percentile',
    'tier',
    'tokenId',
    'owner',
    'collateralBTC',
    'mintTimestamp',
  ];

  const rows = vaults.map((rv) => [
    rv.rank.toString(),
    rv.percentile.toFixed(2),
    rv.tier ?? 'None',
    rv.vault.tokenId.toString(),
    rv.vault.owner,
    formatBtc(rv.vault.collateralAmount),
    opts.includeTimestamps
      ? new Date(Number(rv.vault.mintTimestamp) * 1000).toISOString()
      : rv.vault.mintTimestamp.toString(),
  ]);

  return [headers.join(','), ...rows.map((r) => r.join(','))].join('\n');
}

/**
 * Export indexed events to JSON or CSV
 *
 * @param events - Array of indexed events
 * @param options - Export options
 * @returns Formatted string
 */
export function exportEvents(
  events: IndexedEvent[],
  options: Partial<ExportOptions> = {}
): string {
  const opts = { ...DEFAULT_OPTIONS, ...options };

  if (opts.format === 'json') {
    const data = opts.includeMetadata
      ? { metadata: createMetadata('json'), events: serializeBigints(events) }
      : serializeBigints(events);
    return JSON.stringify(data, null, opts.prettyPrint ? 2 : 0);
  }

  // CSV format - generic columns
  const headers = [
    'type',
    'blockNumber',
    'blockTimestamp',
    'transactionHash',
    'logIndex',
    'data',
  ];

  const rows = events.map((e) => {
    const { type, blockNumber, blockTimestamp, transactionHash, logIndex, ...rest } = e;
    return [
      type,
      blockNumber.toString(),
      opts.includeTimestamps
        ? new Date(Number(blockTimestamp) * 1000).toISOString()
        : blockTimestamp.toString(),
      transactionHash,
      logIndex.toString(),
      JSON.stringify(serializeBigints(rest)),
    ];
  });

  return [headers.join(','), ...rows.map((r) => r.join(','))].join('\n');
}

/**
 * Export portfolio stats to JSON or CSV
 */
export function exportPortfolioStats(
  stats: PortfolioStats,
  options: Partial<ExportOptions> = {}
): string {
  const opts = { ...DEFAULT_OPTIONS, ...options };

  if (opts.format === 'json') {
    const data = opts.includeMetadata
      ? { metadata: createMetadata('json'), stats: serializeBigints(stats) }
      : serializeBigints(stats);
    return JSON.stringify(data, null, opts.prettyPrint ? 2 : 0);
  }

  // CSV format
  return [
    'metric,value',
    `totalVaults,${stats.totalVaults}`,
    `totalCollateral,${formatBtc(stats.totalCollateral)}`,
    `averageCollateral,${formatBtc(stats.averageCollateral)}`,
    `medianCollateral,${formatBtc(stats.medianCollateral)}`,
    `standardDeviation,${formatBtc(stats.standardDeviation)}`,
    `uniqueHolders,${stats.uniqueHolders}`,
  ].join('\n');
}

/**
 * Export ecosystem health to JSON or CSV
 */
export function exportEcosystemHealth(
  health: EcosystemHealth,
  options: Partial<ExportOptions> = {}
): string {
  const opts = { ...DEFAULT_OPTIONS, ...options };

  if (opts.format === 'json') {
    const data = opts.includeMetadata
      ? { metadata: createMetadata('json'), health: serializeBigints(health) }
      : serializeBigints(health);
    return JSON.stringify(data, null, opts.prettyPrint ? 2 : 0);
  }

  // CSV format
  return [
    'metric,value',
    `totalVaults,${health.totalVaults}`,
    `totalCollateral,${formatBtc(health.totalCollateral)}`,
    `matchPoolBalance,${formatBtc(health.matchPoolBalance)}`,
    `matchPoolUtilization,${health.matchPoolUtilization.toFixed(2)}%`,
    `earlyRedemptionRate,${health.earlyRedemptionRate.toFixed(2)}%`,
    `vestedBTCSeparationRate,${health.vestedBTCSeparationRate.toFixed(2)}%`,
    `dormancyRiskScore,${health.dormancyRiskScore.toFixed(2)}`,
    `achievementAdoptionRate,${health.achievementAdoptionRate.toFixed(2)}%`,
  ].join('\n');
}

/**
 * Export dormancy risks to JSON or CSV
 */
export function exportDormancyRisks(
  risks: DormancyRisk[],
  options: Partial<ExportOptions> = {}
): string {
  const opts = { ...DEFAULT_OPTIONS, ...options };

  if (opts.format === 'json') {
    const data = opts.includeMetadata
      ? { metadata: createMetadata('json'), risks: serializeBigints(risks) }
      : serializeBigints(risks);
    return JSON.stringify(data, null, opts.prettyPrint ? 2 : 0);
  }

  // CSV format
  const headers = [
    'tokenId',
    'daysInactive',
    'daysUntilDormant',
    'riskLevel',
    'collateralAtRisk',
  ];

  const rows = risks.map((r) => [
    r.tokenId.toString(),
    r.daysInactive.toFixed(1),
    r.daysUntilDormant.toFixed(1),
    r.riskLevel,
    formatBtc(r.collateralAtRisk),
  ]);

  return [headers.join(','), ...rows.map((row) => row.join(','))].join('\n');
}

/**
 * Export achievement distribution to JSON or CSV
 */
export function exportAchievementDistribution(
  distribution: AchievementDistribution[],
  options: Partial<ExportOptions> = {}
): string {
  const opts = { ...DEFAULT_OPTIONS, ...options };

  if (opts.format === 'json') {
    const data = opts.includeMetadata
      ? { metadata: createMetadata('json'), distribution: serializeBigints(distribution) }
      : serializeBigints(distribution);
    return JSON.stringify(data, null, opts.prettyPrint ? 2 : 0);
  }

  // CSV format
  const headers = ['type', 'uniqueHolders', 'totalClaims', 'firstClaim', 'latestClaim'];

  const rows = distribution.map((d) => [
    d.type,
    d.uniqueHolders.toString(),
    d.totalClaims.toString(),
    d.firstClaimTimestamp > 0n
      ? new Date(Number(d.firstClaimTimestamp) * 1000).toISOString()
      : 'N/A',
    d.latestClaimTimestamp > 0n
      ? new Date(Number(d.latestClaimTimestamp) * 1000).toISOString()
      : 'N/A',
  ]);

  return [headers.join(','), ...rows.map((row) => row.join(','))].join('\n');
}

/**
 * Export cohorts to JSON or CSV
 */
export function exportCohorts(
  cohorts: Cohort[],
  options: Partial<ExportOptions> = {}
): string {
  const opts = { ...DEFAULT_OPTIONS, ...options };

  if (opts.format === 'json') {
    const data = opts.includeMetadata
      ? { metadata: createMetadata('json'), cohorts: serializeBigints(cohorts) }
      : serializeBigints(cohorts);
    return JSON.stringify(data, null, opts.prettyPrint ? 2 : 0);
  }

  // CSV format
  const headers = [
    'cohortMonth',
    'mintCount',
    'activeCount',
    'redeemedCount',
    'retentionRate',
    'totalCollateral',
    'activeCollateral',
    'avgDaysToRedemption',
  ];

  const rows = cohorts.map((c) => [
    c.cohortMonth,
    c.mintCount.toString(),
    c.activeCount.toString(),
    c.redeemedCount.toString(),
    c.retentionRate.toFixed(2) + '%',
    formatBtc(c.totalCollateral),
    formatBtc(c.activeCollateral),
    c.avgDaysToRedemption.toFixed(1),
  ]);

  return [headers.join(','), ...rows.map((row) => row.join(','))].join('\n');
}
