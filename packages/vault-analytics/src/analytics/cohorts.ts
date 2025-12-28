import type { VaultMintedEvent, EarlyRedemptionEvent } from '../events/schema.js';

/**
 * Single cohort data
 */
export interface Cohort {
  /** Cohort identifier (YYYY-MM format) */
  cohortMonth: string;
  /** Number of vaults minted in this cohort */
  mintCount: number;
  /** Number of still active vaults */
  activeCount: number;
  /** Number of early redeemed vaults */
  redeemedCount: number;
  /** Retention rate (active / total) as percentage */
  retentionRate: number;
  /** Total collateral in this cohort (satoshis) */
  totalCollateral: bigint;
  /** Active collateral (satoshis) */
  activeCollateral: bigint;
  /** Average days held before redemption (for redeemed vaults) */
  avgDaysToRedemption: number;
}

/**
 * Cohort analysis result
 */
export interface CohortAnalysis {
  /** Array of cohorts sorted by month */
  cohorts: Cohort[];
  /** Overall retention rate */
  overallRetentionRate: number;
  /** Best performing cohort */
  bestCohort: string | undefined;
  /** Worst performing cohort */
  worstCohort: string | undefined;
}

/**
 * Extract month string from timestamp
 */
function getMonthKey(timestamp: bigint): string {
  const date = new Date(Number(timestamp) * 1000);
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
}

/**
 * Build cohort analysis from mint and redemption events
 *
 * @param mintEvents - Array of VaultMinted events
 * @param redemptionEvents - Array of EarlyRedemption events
 * @returns Cohort analysis with retention metrics
 *
 * @example
 * ```typescript
 * const mints = indexer.getEvents({ types: ['VaultMinted'] });
 * const redemptions = indexer.getEvents({ types: ['EarlyRedemption'] });
 * const analysis = buildCohortAnalysis(mints, redemptions);
 * console.log(`Overall retention: ${analysis.overallRetentionRate}%`);
 * ```
 */
export function buildCohortAnalysis(
  mintEvents: VaultMintedEvent[],
  redemptionEvents: EarlyRedemptionEvent[]
): CohortAnalysis {
  if (mintEvents.length === 0) {
    return {
      cohorts: [],
      overallRetentionRate: 0,
      bestCohort: undefined,
      worstCohort: undefined,
    };
  }

  // Build redemption lookup by tokenId
  const redemptions = new Map<
    bigint,
    { timestamp: bigint; returned: bigint; forfeited: bigint }
  >();

  for (const event of redemptionEvents) {
    redemptions.set(event.tokenId, {
      timestamp: event.blockTimestamp,
      returned: event.returned,
      forfeited: event.forfeited,
    });
  }

  // Group mints by cohort month
  const cohortData = new Map<
    string,
    {
      mints: VaultMintedEvent[];
      redeemed: { tokenId: bigint; mintTimestamp: bigint; redeemTimestamp: bigint }[];
    }
  >();

  for (const event of mintEvents) {
    const monthKey = getMonthKey(event.blockTimestamp);
    const existing = cohortData.get(monthKey) ?? { mints: [], redeemed: [] };
    existing.mints.push(event);

    // Check if this vault was later redeemed
    const redemption = redemptions.get(event.tokenId);
    if (redemption) {
      existing.redeemed.push({
        tokenId: event.tokenId,
        mintTimestamp: event.blockTimestamp,
        redeemTimestamp: redemption.timestamp,
      });
    }

    cohortData.set(monthKey, existing);
  }

  // Build cohort array
  const cohorts: Cohort[] = [];
  let totalActive = 0;
  let totalMinted = 0;

  for (const [cohortMonth, data] of cohortData.entries()) {
    const mintCount = data.mints.length;
    const redeemedCount = data.redeemed.length;
    const activeCount = mintCount - redeemedCount;

    const totalCollateral = data.mints.reduce(
      (sum, m) => sum + m.collateral,
      0n
    );

    // Calculate active collateral (mints minus redeemed)
    const redeemedTokenIds = new Set(data.redeemed.map((r) => r.tokenId));
    const activeCollateral = data.mints
      .filter((m) => !redeemedTokenIds.has(m.tokenId))
      .reduce((sum, m) => sum + m.collateral, 0n);

    const retentionRate = mintCount > 0 ? (activeCount / mintCount) * 100 : 0;

    // Calculate average days to redemption
    let avgDaysToRedemption = 0;
    if (data.redeemed.length > 0) {
      const totalDays = data.redeemed.reduce((sum, r) => {
        const seconds = Number(r.redeemTimestamp - r.mintTimestamp);
        return sum + seconds / (24 * 60 * 60);
      }, 0);
      avgDaysToRedemption = totalDays / data.redeemed.length;
    }

    cohorts.push({
      cohortMonth,
      mintCount,
      activeCount,
      redeemedCount,
      retentionRate,
      totalCollateral,
      activeCollateral,
      avgDaysToRedemption,
    });

    totalActive += activeCount;
    totalMinted += mintCount;
  }

  // Sort by cohort month
  cohorts.sort((a, b) => a.cohortMonth.localeCompare(b.cohortMonth));

  // Find best and worst cohorts
  let bestCohort: string | undefined;
  let worstCohort: string | undefined;
  let bestRate = -1;
  let worstRate = 101;

  for (const cohort of cohorts) {
    // Only consider cohorts with enough data
    if (cohort.mintCount >= 5) {
      if (cohort.retentionRate > bestRate) {
        bestRate = cohort.retentionRate;
        bestCohort = cohort.cohortMonth;
      }
      if (cohort.retentionRate < worstRate) {
        worstRate = cohort.retentionRate;
        worstCohort = cohort.cohortMonth;
      }
    }
  }

  const overallRetentionRate =
    totalMinted > 0 ? (totalActive / totalMinted) * 100 : 0;

  return {
    cohorts,
    overallRetentionRate,
    bestCohort,
    worstCohort,
  };
}

/**
 * Calculate cohort retention matrix (month-over-month retention)
 *
 * @param cohorts - Array of cohort data
 * @returns Retention percentages for each cohort at each month since mint
 */
export function buildRetentionMatrix(
  cohorts: Cohort[]
): Record<string, number[]> {
  // For now, return simple retention rates
  // A full implementation would track month-over-month activity
  const matrix: Record<string, number[]> = {};

  for (const cohort of cohorts) {
    // Initial retention (month 0) is always 100%
    // Final retention is the current retention rate
    matrix[cohort.cohortMonth] = [100, cohort.retentionRate];
  }

  return matrix;
}

/**
 * Format cohort analysis for display
 */
export function formatCohortAnalysis(analysis: CohortAnalysis): string {
  const lines: string[] = [
    '=== Cohort Analysis ===',
    `Overall Retention: ${analysis.overallRetentionRate.toFixed(1)}%`,
    `Best Cohort: ${analysis.bestCohort ?? 'N/A'}`,
    `Worst Cohort: ${analysis.worstCohort ?? 'N/A'}`,
    '',
    'Cohort     | Minted | Active | Redeemed | Retention',
    '-----------+--------+--------+----------+----------',
  ];

  for (const cohort of analysis.cohorts) {
    lines.push(
      `${cohort.cohortMonth}   | ${String(cohort.mintCount).padStart(6)} | ${String(cohort.activeCount).padStart(6)} | ${String(cohort.redeemedCount).padStart(8)} | ${cohort.retentionRate.toFixed(1)}%`
    );
  }

  return lines.join('\n');
}
