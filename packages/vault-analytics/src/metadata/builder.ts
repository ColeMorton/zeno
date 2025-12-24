import type { AchievementType, AchievementStatus } from '../types/achievement.js';
import type { DisplayTier } from '../types/visual.js';
import type { RankedVault } from '../types/percentile.js';
import { BTC_DECIMALS } from '../constants/protocol.js';
import { ACHIEVEMENT_VISUALS } from '../constants/visuals.js';

/**
 * OpenSea-compatible metadata attribute
 */
export interface MetadataAttribute {
  trait_type: string;
  value: string | number;
  display_type?: 'number' | 'date' | 'boost_percentage';
}

/**
 * Complete Treasure NFT metadata structure
 */
export interface TreasureMetadata {
  name: string;
  description: string;
  image: string;
  external_url: string;
  attributes: MetadataAttribute[];
  tier_data: {
    display_tier: DisplayTier;
    percentile: number;
    rank: number;
  };
  achievement_data: {
    earned: AchievementType[];
    highest: AchievementType | null;
  };
}

/**
 * MetadataBuilder configuration
 */
export interface MetadataBuilderConfig {
  /** Base URL for external links */
  externalUrlBase: string;
  /** Protocol name for descriptions */
  protocolName?: string;
}

/**
 * Builder for NFT metadata generation.
 *
 * Generates OpenSea-compatible metadata combining vault state,
 * display tier, and achievements.
 *
 * @example
 * ```typescript
 * const builder = new MetadataBuilder({
 *   externalUrlBase: 'https://btcnft.io/vault'
 * });
 *
 * const metadata = builder.buildTreasureMetadata(
 *   rankedVault,
 *   achievements,
 *   'https://ipfs.io/ipfs/...'
 * );
 * ```
 */
export class MetadataBuilder {
  private readonly externalUrlBase: string;
  private readonly protocolName: string;

  constructor(config: MetadataBuilderConfig) {
    this.externalUrlBase = config.externalUrlBase;
    this.protocolName = config.protocolName ?? 'BTCNFT Protocol';
  }

  /**
   * Build complete Treasure NFT metadata.
   *
   * @param vault - Ranked vault data
   * @param achievements - Achievement status for vault owner
   * @param treasureImageUri - URI to Treasure artwork
   * @returns Complete metadata object
   */
  buildTreasureMetadata(
    vault: RankedVault,
    achievements: AchievementStatus,
    treasureImageUri: string
  ): TreasureMetadata {
    const { vault: v, rank, percentile, tier } = vault;
    const highestType = this.getHighestAchievement(achievements);

    const attributes: MetadataAttribute[] = [
      ...this.buildVaultAttributes(vault),
      ...this.buildTierAttributes(percentile, tier),
      ...this.buildAchievementAttributes(achievements),
    ];

    return {
      name: `Vault #${v.tokenId}`,
      description: this.buildDescription(vault, achievements),
      image: treasureImageUri,
      external_url: `${this.externalUrlBase}/${v.tokenId}`,
      attributes,
      tier_data: {
        display_tier: tier,
        percentile,
        rank,
      },
      achievement_data: {
        earned: achievements.achievements.map((a) => a.type),
        highest: highestType,
      },
    };
  }

  /**
   * Build vault-related attributes.
   */
  buildVaultAttributes(vault: RankedVault): MetadataAttribute[] {
    const { vault: v, rank } = vault;
    const btcAmount = Number(v.collateralAmount) / 10 ** BTC_DECIMALS;

    return [
      { trait_type: 'Token ID', value: Number(v.tokenId) },
      { trait_type: 'Collateral (BTC)', value: btcAmount },
      { trait_type: 'Rank', value: rank },
      {
        trait_type: 'Mint Date',
        value: Number(v.mintTimestamp),
        display_type: 'date',
      },
    ];
  }

  /**
   * Build tier-related attributes.
   */
  buildTierAttributes(percentile: number, tier: DisplayTier): MetadataAttribute[] {
    const attributes: MetadataAttribute[] = [
      { trait_type: 'Percentile', value: Math.round(percentile * 10) / 10 },
    ];

    if (tier !== null) {
      attributes.push({ trait_type: 'Display Tier', value: tier });
    }

    return attributes;
  }

  /**
   * Build achievement-related attributes.
   */
  buildAchievementAttributes(achievements: AchievementStatus): MetadataAttribute[] {
    const attributes: MetadataAttribute[] = [
      { trait_type: 'Achievement Count', value: achievements.achievements.length },
    ];

    if (achievements.hasMinter) {
      attributes.push({ trait_type: 'Minter', value: 'Yes' });
    }
    if (achievements.hasMatured) {
      attributes.push({ trait_type: 'Matured', value: 'Yes' });
    }
    if (achievements.hasHodlerSupreme) {
      attributes.push({ trait_type: 'Hodler Supreme', value: 'Yes' });
    }

    for (const type of achievements.durationAchievements) {
      const visual = ACHIEVEMENT_VISUALS[type];
      attributes.push({ trait_type: visual.label, value: 'Earned' });
    }

    return attributes;
  }

  /**
   * Get highest achievement type by rarity.
   */
  private getHighestAchievement(achievements: AchievementStatus): AchievementType | null {
    if (achievements.hasHodlerSupreme) return 'HODLER_SUPREME';
    if (achievements.hasMatured) return 'MATURED';
    if (achievements.durationAchievements.includes('DIAMOND_HANDS')) return 'DIAMOND_HANDS';
    if (achievements.durationAchievements.includes('ANNUAL')) return 'ANNUAL';
    if (achievements.durationAchievements.includes('HALF_YEAR')) return 'HALF_YEAR';
    if (achievements.durationAchievements.includes('QUARTER_STACK')) return 'QUARTER_STACK';
    if (achievements.durationAchievements.includes('FIRST_MONTH')) return 'FIRST_MONTH';
    if (achievements.hasMinter) return 'MINTER';
    return null;
  }

  /**
   * Build description text.
   */
  private buildDescription(vault: RankedVault, achievements: AchievementStatus): string {
    const { vault: v, tier } = vault;
    const btcAmount = Number(v.collateralAmount) / 10 ** BTC_DECIMALS;

    let desc = `${this.protocolName} Vault #${v.tokenId} containing ${btcAmount.toFixed(8)} BTC.`;

    if (tier) {
      desc += ` ${tier} tier.`;
    }

    const achievementCount = achievements.achievements.length;
    if (achievementCount > 0) {
      desc += ` ${achievementCount} achievement${achievementCount > 1 ? 's' : ''} earned.`;
    }

    return desc;
  }
}

/**
 * Create a metadata builder.
 */
export function createMetadataBuilder(config: MetadataBuilderConfig): MetadataBuilder {
  return new MetadataBuilder(config);
}
