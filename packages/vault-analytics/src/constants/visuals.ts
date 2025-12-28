import type { PercentileTier } from '../types/percentile.js';
import type { AchievementType } from '../types/achievement.js';
import type { TierVisualConfig, AchievementVisual, AchievementRarity } from '../types/visual.js';

/**
 * Tier visual configuration defaults (without tier and percentile)
 */
type TierVisualDefaults = Omit<TierVisualConfig, 'tier' | 'percentile'>;

/**
 * Display tier visual configurations
 */
export const TIER_VISUALS: Record<PercentileTier, TierVisualDefaults> = {
  Diamond: {
    frame: { style: 'crystalline', color: '#E8F4FF', glow: true, animation: 'prismatic' },
    badge: { icon: '/badges/diamond.svg', label: 'Diamond' },
    leaderboard: true,
  },
  Platinum: {
    frame: { style: 'metallic', color: '#E5E4E2', glow: true, animation: 'shimmer' },
    badge: { icon: '/badges/platinum.svg', label: 'Platinum' },
    leaderboard: false,
  },
  Gold: {
    frame: { style: 'metallic', color: '#FFD700', glow: false },
    badge: { icon: '/badges/gold.svg', label: 'Gold' },
    leaderboard: false,
  },
  Silver: {
    frame: { style: 'metallic', color: '#C0C0C0', glow: false },
    badge: { icon: '/badges/silver.svg', label: 'Silver' },
    leaderboard: false,
  },
  Bronze: {
    frame: { style: 'standard', color: '#CD7F32', glow: false },
    badge: { icon: '/badges/bronze.svg', label: 'Bronze' },
    leaderboard: false,
  },
} as const;

/**
 * Achievement rarity mapping
 */
const ACHIEVEMENT_RARITIES: Record<AchievementType, AchievementRarity> = {
  MINTER: 'common',
  FIRST_MONTH: 'common',
  QUARTER_STACK: 'uncommon',
  HALF_YEAR: 'uncommon',
  ANNUAL: 'rare',
  DIAMOND_HANDS: 'rare',
  MATURED: 'rare',
  HODLER_SUPREME: 'legendary',
} as const;

/**
 * Achievement visual configurations (Tier 0 blueprints)
 */
export const ACHIEVEMENT_VISUALS: Record<AchievementType, AchievementVisual> = {
  MINTER: {
    type: 'MINTER',
    svgUri: '/achievements/minter.svg',
    label: 'Minter',
    category: 'lifecycle',
    rarity: ACHIEVEMENT_RARITIES.MINTER,
  },
  MATURED: {
    type: 'MATURED',
    svgUri: '/achievements/matured.svg',
    label: 'Matured',
    category: 'lifecycle',
    rarity: ACHIEVEMENT_RARITIES.MATURED,
  },
  HODLER_SUPREME: {
    type: 'HODLER_SUPREME',
    svgUri: '/achievements/hodler-supreme.svg',
    label: 'Hodler Supreme',
    category: 'composite',
    rarity: ACHIEVEMENT_RARITIES.HODLER_SUPREME,
  },
  FIRST_MONTH: {
    type: 'FIRST_MONTH',
    svgUri: '/achievements/first-month.svg',
    label: 'First Month',
    category: 'duration',
    rarity: ACHIEVEMENT_RARITIES.FIRST_MONTH,
  },
  QUARTER_STACK: {
    type: 'QUARTER_STACK',
    svgUri: '/achievements/quarter-stack.svg',
    label: 'Quarter Stack',
    category: 'duration',
    rarity: ACHIEVEMENT_RARITIES.QUARTER_STACK,
  },
  HALF_YEAR: {
    type: 'HALF_YEAR',
    svgUri: '/achievements/half-year.svg',
    label: 'Half Year',
    category: 'duration',
    rarity: ACHIEVEMENT_RARITIES.HALF_YEAR,
  },
  ANNUAL: {
    type: 'ANNUAL',
    svgUri: '/achievements/annual.svg',
    label: 'Annual',
    category: 'duration',
    rarity: ACHIEVEMENT_RARITIES.ANNUAL,
  },
  DIAMOND_HANDS: {
    type: 'DIAMOND_HANDS',
    svgUri: '/achievements/diamond-hands.svg',
    label: 'Diamond Hands',
    category: 'duration',
    rarity: ACHIEVEMENT_RARITIES.DIAMOND_HANDS,
  },
} as const;

/**
 * Rarity ordering (for comparison)
 */
export const RARITY_ORDER: Record<AchievementRarity, number> = {
  common: 0,
  uncommon: 1,
  rare: 2,
  legendary: 3,
} as const;
