import type { Vault } from '../types/vault.js';
import type {
  EarlyRedemptionEvent,
  MatchClaimedEvent,
  MatchPoolFundedEvent,
  IndexedEvent,
  MinterAchievementClaimedEvent,
  MaturedAchievementClaimedEvent,
  DurationAchievementClaimedEvent,
} from '../events/schema.js';
import {
  DORMANCY_THRESHOLD,
  BTC_DECIMALS,
} from '../constants/protocol.js';

/**
 * Risk level for dormancy analysis
 */
export type RiskLevel = 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';

/**
 * Dormancy risk assessment for a single vault
 */
export interface DormancyRisk {
  /** Vault token ID */
  tokenId: bigint;
  /** Days since last activity */
  daysInactive: number;
  /** Days until dormancy threshold */
  daysUntilDormant: number;
  /** Risk level classification */
  riskLevel: RiskLevel;
  /** Timestamp of last activity */
  lastActivityTimestamp: bigint;
  /** Collateral at risk (satoshis) */
  collateralAtRisk: bigint;
}

/**
 * Risk thresholds for dormancy classification
 */
export interface DormancyThresholds {
  /** Days inactive for CRITICAL (default: 1099) */
  critical: number;
  /** Days inactive for HIGH (default: 1000) */
  high: number;
  /** Days inactive for MEDIUM (default: 730) */
  medium: number;
}

/**
 * Ecosystem health metrics
 */
export interface EcosystemHealth {
  /** Match pool current balance (satoshis) */
  matchPoolBalance: bigint;
  /** Match pool utilization (claimed / forfeited) */
  matchPoolUtilization: number;
  /** Early redemption rate (redemptions / total mints) */
  earlyRedemptionRate: number;
  /** vestedBTC separation rate (separations / vested vaults) */
  vestedBTCSeparationRate: number;
  /** Weighted dormancy risk score (0-100) */
  dormancyRiskScore: number;
  /** Achievement adoption rate (wallets with achievements / unique holders) */
  achievementAdoptionRate: number;
  /** Total vaults analyzed */
  totalVaults: number;
  /** Total collateral (satoshis) */
  totalCollateral: bigint;
}

/**
 * Default dormancy risk thresholds (in days)
 */
export const DEFAULT_DORMANCY_THRESHOLDS: DormancyThresholds = {
  critical: 1099, // 30 days before dormancy
  high: 1000,     // ~4 months before dormancy
  medium: 730,    // 2 years of inactivity
};

/**
 * Calculate dormancy risk for a single vault
 *
 * @param vault - Vault data
 * @param currentTimestamp - Current Unix timestamp (seconds)
 * @param thresholds - Custom risk thresholds
 * @returns Dormancy risk assessment
 *
 * @example
 * ```typescript
 * const risk = calculateDormancyRisk(vault, BigInt(Date.now() / 1000));
 * if (risk.riskLevel === 'CRITICAL') {
 *   console.log(`Vault ${risk.tokenId} needs attention!`);
 * }
 * ```
 */
export function calculateDormancyRisk(
  vault: Vault,
  currentTimestamp: bigint,
  thresholds: DormancyThresholds = DEFAULT_DORMANCY_THRESHOLDS
): DormancyRisk {
  const lastActivity = vault.lastActivity > 0n ? vault.lastActivity : vault.mintTimestamp;
  const secondsInactive = currentTimestamp - lastActivity;
  const daysInactive = Number(secondsInactive) / (24 * 60 * 60);

  const dormancyThresholdDays = Number(DORMANCY_THRESHOLD) / (24 * 60 * 60);
  const daysUntilDormant = dormancyThresholdDays - daysInactive;

  let riskLevel: RiskLevel;
  if (daysInactive >= thresholds.critical) {
    riskLevel = 'CRITICAL';
  } else if (daysInactive >= thresholds.high) {
    riskLevel = 'HIGH';
  } else if (daysInactive >= thresholds.medium) {
    riskLevel = 'MEDIUM';
  } else {
    riskLevel = 'LOW';
  }

  return {
    tokenId: vault.tokenId,
    daysInactive,
    daysUntilDormant,
    riskLevel,
    lastActivityTimestamp: lastActivity,
    collateralAtRisk: vault.collateralAmount,
  };
}

/**
 * Analyze dormancy risks for multiple vaults
 *
 * @param vaults - Array of vault data
 * @param currentTimestamp - Current Unix timestamp (seconds)
 * @param minRiskLevel - Minimum risk level to include (default: 'MEDIUM')
 * @returns Array of vaults with dormancy risk
 */
export function analyzeDormancyRisks(
  vaults: Vault[],
  currentTimestamp: bigint = BigInt(Math.floor(Date.now() / 1000)),
  minRiskLevel: RiskLevel = 'MEDIUM'
): DormancyRisk[] {
  const riskOrder: Record<RiskLevel, number> = {
    LOW: 0,
    MEDIUM: 1,
    HIGH: 2,
    CRITICAL: 3,
  };

  const minOrder = riskOrder[minRiskLevel];

  return vaults
    .map((vault) => calculateDormancyRisk(vault, currentTimestamp))
    .filter((risk) => riskOrder[risk.riskLevel] >= minOrder)
    .sort((a, b) => b.daysInactive - a.daysInactive);
}

/**
 * Calculate ecosystem health metrics from events
 *
 * @param events - All indexed events
 * @param vaults - Current vault states
 * @param currentTimestamp - Current Unix timestamp (seconds)
 * @returns Ecosystem health metrics
 *
 * @example
 * ```typescript
 * const events = indexer.getEvents();
 * const vaults = await client.getAllVaults();
 * const health = calculateEcosystemHealth(events, vaults);
 * console.log(`Redemption rate: ${health.earlyRedemptionRate.toFixed(2)}%`);
 * ```
 */
export function calculateEcosystemHealth(
  events: IndexedEvent[],
  vaults: Vault[],
  currentTimestamp: bigint = BigInt(Math.floor(Date.now() / 1000))
): EcosystemHealth {
  // Count event types
  let mintCount = 0;
  let redemptionCount = 0;
  let matchClaimedTotal = 0n;
  let matchPoolFundedTotal = 0n;
  let separationCount = 0;
  const achievementWallets = new Set<string>();

  for (const event of events) {
    switch (event.type) {
      case 'VaultMinted':
        mintCount++;
        break;
      case 'EarlyRedemption':
        redemptionCount++;
        matchPoolFundedTotal += (event as EarlyRedemptionEvent).forfeited;
        break;
      case 'MatchClaimed':
        matchClaimedTotal += (event as MatchClaimedEvent).amount;
        break;
      case 'MatchPoolFunded':
        matchPoolFundedTotal += (event as MatchPoolFundedEvent).amount;
        break;
      case 'BtcTokenMinted':
        separationCount++;
        break;
      case 'MinterAchievementClaimed':
        achievementWallets.add((event as MinterAchievementClaimedEvent).wallet.toLowerCase());
        break;
      case 'MaturedAchievementClaimed':
        achievementWallets.add((event as MaturedAchievementClaimedEvent).wallet.toLowerCase());
        break;
      case 'DurationAchievementClaimed':
        achievementWallets.add((event as DurationAchievementClaimedEvent).wallet.toLowerCase());
        break;
    }
  }

  // Calculate vault metrics
  const totalVaults = vaults.length;
  const totalCollateral = vaults.reduce((sum, v) => sum + v.collateralAmount, 0n);
  const uniqueHolders = new Set(vaults.map((v) => v.owner.toLowerCase())).size;

  // Count vested vaults
  const vestingPeriod = 1129n * 24n * 60n * 60n;
  const vestedVaults = vaults.filter(
    (v) => currentTimestamp >= v.mintTimestamp + vestingPeriod
  );

  // Calculate rates
  const earlyRedemptionRate = mintCount > 0 ? (redemptionCount / mintCount) * 100 : 0;

  const vestedBTCSeparationRate =
    vestedVaults.length > 0 ? (separationCount / vestedVaults.length) * 100 : 0;

  const matchPoolBalance = matchPoolFundedTotal - matchClaimedTotal;
  const matchPoolUtilization =
    matchPoolFundedTotal > 0n
      ? (Number(matchClaimedTotal) / Number(matchPoolFundedTotal)) * 100
      : 0;

  const achievementAdoptionRate =
    uniqueHolders > 0 ? (achievementWallets.size / uniqueHolders) * 100 : 0;

  // Calculate dormancy risk score
  const dormancyRisks = analyzeDormancyRisks(vaults, currentTimestamp, 'LOW');
  const riskWeights: Record<RiskLevel, number> = {
    LOW: 0,
    MEDIUM: 25,
    HIGH: 50,
    CRITICAL: 100,
  };

  let weightedRiskSum = 0;
  let totalWeight = 0n;

  for (const risk of dormancyRisks) {
    const weight = risk.collateralAtRisk;
    weightedRiskSum += Number(weight) * riskWeights[risk.riskLevel];
    totalWeight += weight;
  }

  const dormancyRiskScore = totalWeight > 0n ? weightedRiskSum / Number(totalWeight) : 0;

  return {
    matchPoolBalance,
    matchPoolUtilization,
    earlyRedemptionRate,
    vestedBTCSeparationRate,
    dormancyRiskScore,
    achievementAdoptionRate,
    totalVaults,
    totalCollateral,
  };
}

/**
 * Format ecosystem health for display
 */
export function formatEcosystemHealth(health: EcosystemHealth): string {
  const btcDecimals = 10 ** Number(BTC_DECIMALS);
  const formatBtc = (value: bigint) => (Number(value) / btcDecimals).toFixed(8);

  const riskLabel = (score: number): string => {
    if (score >= 75) return 'CRITICAL';
    if (score >= 50) return 'HIGH';
    if (score >= 25) return 'MEDIUM';
    return 'LOW';
  };

  return `
=== Ecosystem Health ===
Total Vaults:           ${health.totalVaults}
Total Collateral:       ${formatBtc(health.totalCollateral)} BTC

Match Pool Balance:     ${formatBtc(health.matchPoolBalance)} BTC
Match Pool Utilization: ${health.matchPoolUtilization.toFixed(1)}%

Early Redemption Rate:  ${health.earlyRedemptionRate.toFixed(2)}%
vestedBTC Separation:   ${health.vestedBTCSeparationRate.toFixed(2)}%
Achievement Adoption:   ${health.achievementAdoptionRate.toFixed(2)}%

Dormancy Risk Score:    ${health.dormancyRiskScore.toFixed(1)} (${riskLabel(health.dormancyRiskScore)})
`.trim();
}

/**
 * Get vaults grouped by risk level
 */
export function groupByRiskLevel(
  risks: DormancyRisk[]
): Record<RiskLevel, DormancyRisk[]> {
  const result: Record<RiskLevel, DormancyRisk[]> = {
    LOW: [],
    MEDIUM: [],
    HIGH: [],
    CRITICAL: [],
  };

  for (const risk of risks) {
    result[risk.riskLevel].push(risk);
  }

  return result;
}

/**
 * Calculate total collateral at each risk level
 */
export function calculateCollateralAtRisk(
  risks: DormancyRisk[]
): Record<RiskLevel, bigint> {
  const result: Record<RiskLevel, bigint> = {
    LOW: 0n,
    MEDIUM: 0n,
    HIGH: 0n,
    CRITICAL: 0n,
  };

  for (const risk of risks) {
    result[risk.riskLevel] = result[risk.riskLevel] + risk.collateralAtRisk;
  }

  return result;
}
