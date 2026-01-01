import { keccak256, toBytes } from 'viem';

// Achievement type hashes matching MockTreasure.sol
export const ACHIEVEMENT_TYPES = {
  TRAILHEAD: keccak256(toBytes('TRAILHEAD')),
  FIRST_STEPS: keccak256(toBytes('FIRST_STEPS')),
  WALLET_WARMED: keccak256(toBytes('WALLET_WARMED')),
  IDENTIFIED: keccak256(toBytes('IDENTIFIED')),
  STEADY_PACE: keccak256(toBytes('STEADY_PACE')),
  EXPLORER: keccak256(toBytes('EXPLORER')),
  GUIDE: keccak256(toBytes('GUIDE')),
  PREPARED: keccak256(toBytes('PREPARED')),
  REGULAR: keccak256(toBytes('REGULAR')),
  COMMITTED: keccak256(toBytes('COMMITTED')),
  RESOLUTE: keccak256(toBytes('RESOLUTE')),
  STUDENT: keccak256(toBytes('STUDENT')),
  CHAPTER_COMPLETE: keccak256(toBytes('CHAPTER_COMPLETE')),
} as const;

export type AchievementName = keyof typeof ACHIEVEMENT_TYPES;

// Human-readable display names
export const ACHIEVEMENT_DISPLAY_NAMES: Record<AchievementName, string> = {
  TRAILHEAD: 'Trailhead',
  FIRST_STEPS: 'First Steps',
  WALLET_WARMED: 'Wallet Warmed',
  IDENTIFIED: 'Identified',
  STEADY_PACE: 'Steady Pace',
  EXPLORER: 'Explorer',
  GUIDE: 'Guide',
  PREPARED: 'Prepared',
  REGULAR: 'Regular',
  COMMITTED: 'Committed',
  RESOLUTE: 'Resolute',
  STUDENT: 'Student',
  CHAPTER_COMPLETE: 'Chapter Complete',
};

// Get achievement type hash from name
export function getAchievementTypeHash(name: AchievementName): `0x${string}` {
  return ACHIEVEMENT_TYPES[name];
}

// Get display name from achievement name
export function getAchievementDisplayName(name: AchievementName): string {
  return ACHIEVEMENT_DISPLAY_NAMES[name];
}
