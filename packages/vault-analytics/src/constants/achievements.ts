import { keccak256, toBytes, type Hex } from 'viem';
import type { AchievementType, AchievementCategory } from '../types/achievement.js';

/**
 * Achievement type to bytes32 mapping (mirrors contract constants)
 */
export const ACHIEVEMENT_TYPE_HASHES: Record<AchievementType, Hex> = {
  MINTER: keccak256(toBytes('MINTER')),
  MATURED: keccak256(toBytes('MATURED')),
  HODLER_SUPREME: keccak256(toBytes('HODLER_SUPREME')),
  FIRST_MONTH: keccak256(toBytes('FIRST_MONTH')),
  QUARTER_STACK: keccak256(toBytes('QUARTER_STACK')),
  HALF_YEAR: keccak256(toBytes('HALF_YEAR')),
  ANNUAL: keccak256(toBytes('ANNUAL')),
  DIAMOND_HANDS: keccak256(toBytes('DIAMOND_HANDS')),
} as const;

/**
 * Reverse mapping: bytes32 to achievement type
 */
export const HASH_TO_ACHIEVEMENT_TYPE: Record<Hex, AchievementType> = Object.fromEntries(
  Object.entries(ACHIEVEMENT_TYPE_HASHES).map(([type, hash]) => [hash, type as AchievementType])
) as Record<Hex, AchievementType>;

/**
 * Duration thresholds in seconds (mirrors contract constants)
 */
export const DURATION_THRESHOLDS: Partial<Record<AchievementType, bigint>> = {
  FIRST_MONTH: 30n * 24n * 60n * 60n,        // 30 days
  QUARTER_STACK: 91n * 24n * 60n * 60n,      // 91 days
  HALF_YEAR: 182n * 24n * 60n * 60n,         // 182 days
  ANNUAL: 365n * 24n * 60n * 60n,            // 365 days
  DIAMOND_HANDS: 730n * 24n * 60n * 60n,     // 730 days
} as const;

/**
 * Duration thresholds in days (human-readable)
 */
export const DURATION_THRESHOLDS_DAYS: Partial<Record<AchievementType, number>> = {
  FIRST_MONTH: 30,
  QUARTER_STACK: 91,
  HALF_YEAR: 182,
  ANNUAL: 365,
  DIAMOND_HANDS: 730,
} as const;

/**
 * Achievement category mapping
 */
export const ACHIEVEMENT_CATEGORIES: Record<AchievementType, AchievementCategory> = {
  MINTER: 'lifecycle',
  MATURED: 'lifecycle',
  HODLER_SUPREME: 'composite',
  FIRST_MONTH: 'duration',
  QUARTER_STACK: 'duration',
  HALF_YEAR: 'duration',
  ANNUAL: 'duration',
  DIAMOND_HANDS: 'duration',
} as const;

/**
 * All achievement types in order of progression
 */
export const ALL_ACHIEVEMENT_TYPES: readonly AchievementType[] = [
  'MINTER',
  'FIRST_MONTH',
  'QUARTER_STACK',
  'HALF_YEAR',
  'ANNUAL',
  'DIAMOND_HANDS',
  'MATURED',
  'HODLER_SUPREME',
] as const;

/**
 * Duration achievement types in chronological order
 */
export const DURATION_ACHIEVEMENT_TYPES: readonly AchievementType[] = [
  'FIRST_MONTH',
  'QUARTER_STACK',
  'HALF_YEAR',
  'ANNUAL',
  'DIAMOND_HANDS',
] as const;

/**
 * Check if an achievement type is a duration achievement
 */
export function isDurationAchievement(type: AchievementType): boolean {
  return type in DURATION_THRESHOLDS;
}

/**
 * Get duration threshold for an achievement type
 * @throws Error if not a duration achievement
 */
export function getDurationThreshold(type: AchievementType): bigint {
  const threshold = DURATION_THRESHOLDS[type];
  if (threshold === undefined) {
    throw new Error(`${type} is not a duration achievement`);
  }
  return threshold;
}
