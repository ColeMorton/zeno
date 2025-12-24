import type { RankedVault, PercentileTier } from '../types/percentile.js';
import type { AchievementStatus } from '../types/achievement.js';
import type {
  TierVisualConfig,
  AchievementVisual,
  VaultVisualHierarchy,
} from '../types/visual.js';
import { TIER_VISUALS, ACHIEVEMENT_VISUALS, RARITY_ORDER } from '../constants/visuals.js';

/**
 * Get tier visual configuration from percentile value.
 *
 * @param percentile - Percentile value (0-100)
 * @param tier - Pre-calculated tier (from rankByCollateral)
 * @returns Complete visual configuration for the tier
 *
 * @example
 * ```typescript
 * const config = getTierVisualConfig(98.5, 'Diamond');
 * console.log(config.frame.color); // '#B9F2FF'
 * ```
 */
export function getTierVisualConfig(
  percentile: number,
  tier: PercentileTier | null
): TierVisualConfig {
  if (tier === null) {
    return {
      tier: null,
      percentile,
      frame: { style: 'standard', color: '#808080', glow: false },
      badge: { icon: '/badges/none.svg', label: 'Unranked' },
      leaderboard: false,
    };
  }

  const defaults = TIER_VISUALS[tier];

  return {
    tier,
    percentile,
    ...defaults,
  };
}

/**
 * Get the highest rarity achievement from a list.
 *
 * @param achievements - Array of achievement visuals
 * @returns Highest rarity achievement or null if empty
 */
export function getHighestRarityAchievement(
  achievements: AchievementVisual[]
): AchievementVisual | null {
  if (achievements.length === 0) return null;

  return achievements.reduce((highest, current) =>
    RARITY_ORDER[current.rarity] > RARITY_ORDER[highest.rarity] ? current : highest
  );
}

/**
 * Convert achievement status to achievement visuals.
 *
 * @param status - Achievement status from AchievementClient
 * @returns Array of achievement visual configurations
 */
export function getAchievementVisuals(status: AchievementStatus): AchievementVisual[] {
  return status.achievements.map((achievement) => ACHIEVEMENT_VISUALS[achievement.type]);
}

/**
 * Compose complete visual hierarchy for a vault.
 *
 * Combines wealth-based display tier with merit-based achievements.
 *
 * @param rankedVault - Vault with calculated rank and percentile
 * @param achievements - Achievement status for the vault owner
 * @returns Complete visual hierarchy
 *
 * @example
 * ```typescript
 * const rankedVault = ranked[0];
 * const achievements = await achievementClient.getAchievements(rankedVault.vault.owner);
 * const hierarchy = composeVisualHierarchy(rankedVault, achievements);
 *
 * console.log(hierarchy.displayTier.tier); // 'Diamond'
 * console.log(hierarchy.achievements.length); // 3
 * console.log(hierarchy.isVeteran); // false
 * ```
 */
export function composeVisualHierarchy(
  rankedVault: RankedVault,
  achievements: AchievementStatus
): VaultVisualHierarchy {
  const { vault, percentile, tier } = rankedVault;

  const displayTier = getTierVisualConfig(percentile, tier);
  const achievementVisuals = getAchievementVisuals(achievements);
  const highestAchievement = getHighestRarityAchievement(achievementVisuals);

  const isVeteran = achievements.hasMatured && achievements.hasHodlerSupreme;

  return {
    vaultId: vault.tokenId,
    treasureContract: vault.treasureContract,
    treasureTokenId: vault.treasureTokenId,
    displayTier,
    achievements: achievementVisuals,
    highestAchievement,
    isVeteran,
  };
}
