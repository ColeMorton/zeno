import { describe, it, expect } from 'vitest';
import {
  getTierVisualConfig,
  getHighestRarityAchievement,
  getAchievementVisuals,
  composeVisualHierarchy,
} from '../src/analytics/visual.js';
import { ACHIEVEMENT_VISUALS, TIER_VISUALS } from '../src/constants/visuals.js';
import type { AchievementStatus } from '../src/types/achievement.js';
import type { RankedVault } from '../src/types/percentile.js';
import type { Vault } from '../src/types/vault.js';

const createMockVault = (overrides: Partial<Vault> = {}): Vault => ({
  tokenId: 1n,
  owner: '0x1234567890123456789012345678901234567890',
  treasureContract: '0xabcdefabcdefabcdefabcdefabcdefabcdefabcd',
  treasureTokenId: 1n,
  collateralToken: '0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599',
  collateralAmount: 100000000n,
  mintTimestamp: BigInt(Math.floor(Date.now() / 1000) - 86400 * 100),
  lastWithdrawal: 0n,
  vestedBTCAmount: 0n,
  lastActivity: BigInt(Math.floor(Date.now() / 1000)),
  pokeTimestamp: 0n,
  windowId: 1n,
  issuer: '0x1111111111111111111111111111111111111111',
  ...overrides,
});

const createMockRankedVault = (
  overrides: Partial<RankedVault> = {}
): RankedVault => ({
  vault: createMockVault(),
  rank: 1,
  percentile: 95,
  tier: 'Diamond',
  ...overrides,
});

const createMockAchievementStatus = (
  overrides: Partial<AchievementStatus> = {}
): AchievementStatus => ({
  wallet: '0x1234567890123456789012345678901234567890',
  achievements: [],
  hasMinter: false,
  hasMatured: false,
  hasHodlerSupreme: false,
  durationAchievements: [],
  ...overrides,
});

describe('getTierVisualConfig', () => {
  it('returns Whale config for 99+ percentile', () => {
    const config = getTierVisualConfig(99.5, 'Whale');
    expect(config.tier).toBe('Whale');
    expect(config.percentile).toBe(99.5);
    expect(config.frame.style).toBe('unique');
    expect(config.frame.color).toBe('#00D4FF');
    expect(config.frame.glow).toBe(true);
    expect(config.leaderboard).toBe(true);
  });

  it('returns Diamond config', () => {
    const config = getTierVisualConfig(96, 'Diamond');
    expect(config.tier).toBe('Diamond');
    expect(config.frame.style).toBe('animated');
    expect(config.frame.animation).toBe('shimmer');
    expect(config.leaderboard).toBe(false);
  });

  it('returns Gold config', () => {
    const config = getTierVisualConfig(85, 'Gold');
    expect(config.tier).toBe('Gold');
    expect(config.frame.style).toBe('metallic');
    expect(config.frame.color).toBe('#FFD700');
  });

  it('returns Silver config', () => {
    const config = getTierVisualConfig(60, 'Silver');
    expect(config.tier).toBe('Silver');
    expect(config.frame.color).toBe('#C0C0C0');
  });

  it('returns Bronze config', () => {
    const config = getTierVisualConfig(30, 'Bronze');
    expect(config.tier).toBe('Bronze');
    expect(config.frame.style).toBe('standard');
  });

  it('returns unranked config for null tier', () => {
    const config = getTierVisualConfig(25, null);
    expect(config.tier).toBeNull();
    expect(config.badge.label).toBe('Unranked');
    expect(config.leaderboard).toBe(false);
  });
});

describe('getHighestRarityAchievement', () => {
  it('returns null for empty array', () => {
    expect(getHighestRarityAchievement([])).toBeNull();
  });

  it('returns legendary over rare', () => {
    const achievements = [
      ACHIEVEMENT_VISUALS.MATURED, // rare
      ACHIEVEMENT_VISUALS.HODLER_SUPREME, // legendary
    ];
    const highest = getHighestRarityAchievement(achievements);
    expect(highest?.type).toBe('HODLER_SUPREME');
  });

  it('returns rare over uncommon', () => {
    const achievements = [
      ACHIEVEMENT_VISUALS.QUARTER_STACK, // uncommon
      ACHIEVEMENT_VISUALS.DIAMOND_HANDS, // rare
    ];
    const highest = getHighestRarityAchievement(achievements);
    expect(highest?.type).toBe('DIAMOND_HANDS');
  });

  it('returns uncommon over common', () => {
    const achievements = [
      ACHIEVEMENT_VISUALS.MINTER, // common
      ACHIEVEMENT_VISUALS.HALF_YEAR, // uncommon
    ];
    const highest = getHighestRarityAchievement(achievements);
    expect(highest?.type).toBe('HALF_YEAR');
  });

  it('returns first achievement when equal rarity', () => {
    const achievements = [
      ACHIEVEMENT_VISUALS.MINTER, // common
      ACHIEVEMENT_VISUALS.FIRST_MONTH, // common
    ];
    const highest = getHighestRarityAchievement(achievements);
    expect(highest?.type).toBe('MINTER');
  });
});

describe('getAchievementVisuals', () => {
  it('returns empty array for no achievements', () => {
    const status = createMockAchievementStatus();
    const visuals = getAchievementVisuals(status);
    expect(visuals).toHaveLength(0);
  });

  it('maps achievements to visuals', () => {
    const status = createMockAchievementStatus({
      achievements: [
        { type: 'MINTER', tokenId: 1n, wallet: '0x123', earnedAt: 0n },
        { type: 'MATURED', tokenId: 2n, wallet: '0x123', earnedAt: 0n },
      ],
    });
    const visuals = getAchievementVisuals(status);
    expect(visuals).toHaveLength(2);
    expect(visuals[0]?.type).toBe('MINTER');
    expect(visuals[1]?.type).toBe('MATURED');
  });
});

describe('composeVisualHierarchy', () => {
  it('combines vault and achievement data', () => {
    const rankedVault = createMockRankedVault({
      vault: createMockVault({ tokenId: 42n }),
      percentile: 98,
      tier: 'Diamond',
    });

    const achievements = createMockAchievementStatus({
      hasMinter: true,
      achievements: [
        { type: 'MINTER', tokenId: 1n, wallet: '0x123', earnedAt: 0n },
      ],
    });

    const hierarchy = composeVisualHierarchy(rankedVault, achievements);

    expect(hierarchy.vaultId).toBe(42n);
    expect(hierarchy.displayTier.tier).toBe('Diamond');
    expect(hierarchy.displayTier.percentile).toBe(98);
    expect(hierarchy.achievements).toHaveLength(1);
    expect(hierarchy.highestAchievement?.type).toBe('MINTER');
    expect(hierarchy.isVeteran).toBe(false);
  });

  it('identifies veteran status correctly', () => {
    const rankedVault = createMockRankedVault();
    const achievements = createMockAchievementStatus({
      hasMatured: true,
      hasHodlerSupreme: true,
      achievements: [
        { type: 'MATURED', tokenId: 1n, wallet: '0x123', earnedAt: 0n },
        { type: 'HODLER_SUPREME', tokenId: 2n, wallet: '0x123', earnedAt: 0n },
      ],
    });

    const hierarchy = composeVisualHierarchy(rankedVault, achievements);
    expect(hierarchy.isVeteran).toBe(true);
    expect(hierarchy.highestAchievement?.type).toBe('HODLER_SUPREME');
  });

  it('handles null tier correctly', () => {
    const rankedVault = createMockRankedVault({
      percentile: 25,
      tier: null,
    });
    const achievements = createMockAchievementStatus();

    const hierarchy = composeVisualHierarchy(rankedVault, achievements);
    expect(hierarchy.displayTier.tier).toBeNull();
  });
});

describe('TIER_VISUALS', () => {
  it('defines all 5 tiers', () => {
    expect(Object.keys(TIER_VISUALS)).toHaveLength(5);
    expect(TIER_VISUALS.Whale).toBeDefined();
    expect(TIER_VISUALS.Diamond).toBeDefined();
    expect(TIER_VISUALS.Gold).toBeDefined();
    expect(TIER_VISUALS.Silver).toBeDefined();
    expect(TIER_VISUALS.Bronze).toBeDefined();
  });

  it('only Whale has leaderboard enabled', () => {
    expect(TIER_VISUALS.Whale.leaderboard).toBe(true);
    expect(TIER_VISUALS.Diamond.leaderboard).toBe(false);
    expect(TIER_VISUALS.Gold.leaderboard).toBe(false);
    expect(TIER_VISUALS.Silver.leaderboard).toBe(false);
    expect(TIER_VISUALS.Bronze.leaderboard).toBe(false);
  });
});

describe('ACHIEVEMENT_VISUALS', () => {
  it('defines all 8 achievements', () => {
    expect(Object.keys(ACHIEVEMENT_VISUALS)).toHaveLength(8);
  });

  it('categorizes achievements correctly', () => {
    expect(ACHIEVEMENT_VISUALS.MINTER.category).toBe('lifecycle');
    expect(ACHIEVEMENT_VISUALS.MATURED.category).toBe('lifecycle');
    expect(ACHIEVEMENT_VISUALS.HODLER_SUPREME.category).toBe('composite');
    expect(ACHIEVEMENT_VISUALS.FIRST_MONTH.category).toBe('duration');
    expect(ACHIEVEMENT_VISUALS.ANNUAL.category).toBe('duration');
  });

  it('assigns correct rarities', () => {
    expect(ACHIEVEMENT_VISUALS.MINTER.rarity).toBe('common');
    expect(ACHIEVEMENT_VISUALS.FIRST_MONTH.rarity).toBe('common');
    expect(ACHIEVEMENT_VISUALS.QUARTER_STACK.rarity).toBe('uncommon');
    expect(ACHIEVEMENT_VISUALS.ANNUAL.rarity).toBe('rare');
    expect(ACHIEVEMENT_VISUALS.HODLER_SUPREME.rarity).toBe('legendary');
  });
});
