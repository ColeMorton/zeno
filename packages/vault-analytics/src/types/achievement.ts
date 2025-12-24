import type { Address } from 'viem';

/**
 * Achievement type identifiers (mirrors contract bytes32)
 */
export type AchievementType =
  | 'MINTER'
  | 'MATURED'
  | 'HODLER_SUPREME'
  | 'FIRST_MONTH'
  | 'QUARTER_STACK'
  | 'HALF_YEAR'
  | 'ANNUAL'
  | 'DIAMOND_HANDS';

/**
 * Achievement category classification
 */
export type AchievementCategory = 'lifecycle' | 'duration' | 'composite';

/**
 * Single achievement instance
 */
export interface Achievement {
  /** Achievement type identifier */
  type: AchievementType;
  /** Achievement NFT token ID */
  tokenId: bigint;
  /** Wallet that earned the achievement */
  wallet: Address;
  /** Timestamp when achievement was earned */
  earnedAt: bigint;
}

/**
 * Aggregated achievement status for a wallet
 */
export interface AchievementStatus {
  /** Wallet address */
  wallet: Address;
  /** All earned achievements */
  achievements: Achievement[];
  /** Quick lookup: has MINTER */
  hasMinter: boolean;
  /** Quick lookup: has MATURED */
  hasMatured: boolean;
  /** Quick lookup: has HODLER_SUPREME */
  hasHodlerSupreme: boolean;
  /** Duration achievements earned */
  durationAchievements: AchievementType[];
}

/**
 * Eligibility check result for claiming an achievement
 */
export interface AchievementEligibility {
  /** Achievement type being checked */
  type: AchievementType;
  /** Whether the achievement can be claimed */
  eligible: boolean;
  /** Human-readable explanation (empty if eligible) */
  reason: string;
  /** Vault ID that qualifies (if applicable) */
  vaultId?: bigint;
}
