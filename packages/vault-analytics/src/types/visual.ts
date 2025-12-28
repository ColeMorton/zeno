import type { Address } from 'viem';
import type { AchievementType, AchievementCategory } from './achievement.js';
import type { PercentileTier } from './percentile.js';

/**
 * Display tier (wealth-based, dynamic)
 * Re-exports PercentileTier for visual context
 */
export type DisplayTier = PercentileTier | null;

/**
 * Frame style for tier visualization
 */
export type FrameStyle = 'standard' | 'metallic' | 'animated' | 'crystalline';

/**
 * Frame animation type
 */
export type FrameAnimation = 'pulse' | 'shimmer' | 'sparkle' | 'prismatic';

/**
 * Visual tier configuration for rendering
 */
export interface TierVisualConfig {
  /** Display tier name */
  tier: DisplayTier;
  /** Percentile value (0-100) */
  percentile: number;
  /** Frame visual properties */
  frame: {
    /** Frame style type */
    style: FrameStyle;
    /** Frame color (hex) */
    color: string;
    /** Whether frame has glow effect */
    glow: boolean;
    /** Optional animation type */
    animation?: FrameAnimation;
  };
  /** Badge properties */
  badge: {
    /** SVG icon path or URI */
    icon: string;
    /** Display label */
    label: string;
  };
  /** Whether eligible for leaderboard feature (Diamond only) */
  leaderboard: boolean;
}

/**
 * Achievement rarity classification
 */
export type AchievementRarity = 'common' | 'uncommon' | 'rare' | 'legendary';

/**
 * Achievement visual configuration (Tier 0 blueprint)
 */
export interface AchievementVisual {
  /** Achievement type */
  type: AchievementType;
  /** Base SVG URI (Tier 0 blueprint) */
  svgUri: string;
  /** Display label */
  label: string;
  /** Achievement category */
  category: AchievementCategory;
  /** Rarity classification */
  rarity: AchievementRarity;
}

/**
 * Combined visual hierarchy for a vault
 */
export interface VaultVisualHierarchy {
  /** Vault NFT token ID */
  vaultId: bigint;
  /** Treasure contract address */
  treasureContract: Address;
  /** Treasure token ID */
  treasureTokenId: bigint;
  /** Display tier configuration (wealth-based) */
  displayTier: TierVisualConfig;
  /** Achievement visuals (merit-based, Tier 0) */
  achievements: AchievementVisual[];
  /** Highest rarity achievement (if any) */
  highestAchievement: AchievementVisual | null;
  /** Veteran status (has MATURED + HODLER_SUPREME) */
  isVeteran: boolean;
}
