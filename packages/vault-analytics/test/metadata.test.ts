import { describe, it, expect } from 'vitest';
import { MetadataBuilder, createMetadataBuilder } from '../src/metadata/builder.js';
import type { AchievementStatus } from '../src/types/achievement.js';
import type { RankedVault } from '../src/types/percentile.js';
import type { Vault } from '../src/types/vault.js';

const createMockVault = (overrides: Partial<Vault> = {}): Vault => ({
  tokenId: 42n,
  owner: '0x1234567890123456789012345678901234567890',
  treasureContract: '0xabcdefabcdefabcdefabcdefabcdefabcdefabcd',
  treasureTokenId: 1n,
  collateralToken: '0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599',
  collateralAmount: 100000000n, // 1 BTC
  mintTimestamp: 1700000000n,
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
  rank: 5,
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

describe('MetadataBuilder', () => {
  const builder = new MetadataBuilder({
    externalUrlBase: 'https://btcnft.io/vault',
  });

  describe('buildTreasureMetadata', () => {
    it('generates complete metadata structure', () => {
      const vault = createMockRankedVault();
      const achievements = createMockAchievementStatus();
      const imageUri = 'https://ipfs.io/ipfs/QmTest';

      const metadata = builder.buildTreasureMetadata(vault, achievements, imageUri);

      expect(metadata.name).toBe('Vault #42');
      expect(metadata.image).toBe(imageUri);
      expect(metadata.external_url).toBe('https://btcnft.io/vault/42');
      expect(metadata.tier_data.display_tier).toBe('Diamond');
      expect(metadata.tier_data.percentile).toBe(95);
      expect(metadata.tier_data.rank).toBe(5);
    });

    it('includes vault attributes', () => {
      const vault = createMockRankedVault();
      const achievements = createMockAchievementStatus();

      const metadata = builder.buildTreasureMetadata(vault, achievements, 'https://test.com');

      const tokenIdAttr = metadata.attributes.find((a) => a.trait_type === 'Token ID');
      const collateralAttr = metadata.attributes.find((a) => a.trait_type === 'Collateral (BTC)');
      const rankAttr = metadata.attributes.find((a) => a.trait_type === 'Rank');
      const mintDateAttr = metadata.attributes.find((a) => a.trait_type === 'Mint Date');

      expect(tokenIdAttr?.value).toBe(42);
      expect(collateralAttr?.value).toBe(1); // 1 BTC
      expect(rankAttr?.value).toBe(5);
      expect(mintDateAttr?.display_type).toBe('date');
    });

    it('includes tier attributes', () => {
      const vault = createMockRankedVault({ percentile: 98, tier: 'Diamond' });
      const achievements = createMockAchievementStatus();

      const metadata = builder.buildTreasureMetadata(vault, achievements, 'https://test.com');

      const percentileAttr = metadata.attributes.find((a) => a.trait_type === 'Percentile');
      const tierAttr = metadata.attributes.find((a) => a.trait_type === 'Display Tier');

      expect(percentileAttr?.value).toBe(98);
      expect(tierAttr?.value).toBe('Diamond');
    });

    it('omits tier attribute when null', () => {
      const vault = createMockRankedVault({ tier: null });
      const achievements = createMockAchievementStatus();

      const metadata = builder.buildTreasureMetadata(vault, achievements, 'https://test.com');

      const tierAttr = metadata.attributes.find((a) => a.trait_type === 'Display Tier');
      expect(tierAttr).toBeUndefined();
    });

    it('includes achievement attributes', () => {
      const vault = createMockRankedVault();
      const achievements = createMockAchievementStatus({
        hasMinter: true,
        hasMatured: true,
        durationAchievements: ['FIRST_MONTH', 'ANNUAL'],
        achievements: [
          { type: 'MINTER', tokenId: 1n, wallet: '0x123', earnedAt: 0n },
          { type: 'MATURED', tokenId: 2n, wallet: '0x123', earnedAt: 0n },
          { type: 'FIRST_MONTH', tokenId: 3n, wallet: '0x123', earnedAt: 0n },
          { type: 'ANNUAL', tokenId: 4n, wallet: '0x123', earnedAt: 0n },
        ],
      });

      const metadata = builder.buildTreasureMetadata(vault, achievements, 'https://test.com');

      const countAttr = metadata.attributes.find((a) => a.trait_type === 'Achievement Count');
      const minterAttr = metadata.attributes.find((a) => a.trait_type === 'Minter');
      const maturedAttr = metadata.attributes.find((a) => a.trait_type === 'Matured');
      const firstMonthAttr = metadata.attributes.find((a) => a.trait_type === 'First Month');
      const annualAttr = metadata.attributes.find((a) => a.trait_type === 'Annual');

      expect(countAttr?.value).toBe(4);
      expect(minterAttr?.value).toBe('Yes');
      expect(maturedAttr?.value).toBe('Yes');
      expect(firstMonthAttr?.value).toBe('Earned');
      expect(annualAttr?.value).toBe('Earned');
    });

    it('populates achievement_data correctly', () => {
      const vault = createMockRankedVault();
      const achievements = createMockAchievementStatus({
        hasMatured: true,
        achievements: [
          { type: 'MINTER', tokenId: 1n, wallet: '0x123', earnedAt: 0n },
          { type: 'MATURED', tokenId: 2n, wallet: '0x123', earnedAt: 0n },
        ],
      });

      const metadata = builder.buildTreasureMetadata(vault, achievements, 'https://test.com');

      expect(metadata.achievement_data.earned).toContain('MINTER');
      expect(metadata.achievement_data.earned).toContain('MATURED');
      expect(metadata.achievement_data.highest).toBe('MATURED');
    });

    it('returns null for highest when no achievements', () => {
      const vault = createMockRankedVault();
      const achievements = createMockAchievementStatus();

      const metadata = builder.buildTreasureMetadata(vault, achievements, 'https://test.com');

      expect(metadata.achievement_data.earned).toHaveLength(0);
      expect(metadata.achievement_data.highest).toBeNull();
    });

    it('generates description with tier and achievements', () => {
      const vault = createMockRankedVault({ tier: 'Gold' });
      const achievements = createMockAchievementStatus({
        achievements: [
          { type: 'MINTER', tokenId: 1n, wallet: '0x123', earnedAt: 0n },
          { type: 'FIRST_MONTH', tokenId: 2n, wallet: '0x123', earnedAt: 0n },
        ],
      });

      const metadata = builder.buildTreasureMetadata(vault, achievements, 'https://test.com');

      expect(metadata.description).toContain('Vault #42');
      expect(metadata.description).toContain('1.00000000 BTC');
      expect(metadata.description).toContain('Gold tier');
      expect(metadata.description).toContain('2 achievements');
    });
  });

  describe('buildVaultAttributes', () => {
    it('formats BTC with 8 decimals', () => {
      const vault = createMockRankedVault({
        vault: createMockVault({ collateralAmount: 12345678n }), // 0.12345678 BTC
      });

      const attrs = builder.buildVaultAttributes(vault);
      const btcAttr = attrs.find((a) => a.trait_type === 'Collateral (BTC)');

      expect(btcAttr?.value).toBe(0.12345678);
    });
  });
});

describe('createMetadataBuilder', () => {
  it('creates MetadataBuilder instance', () => {
    const builder = createMetadataBuilder({
      externalUrlBase: 'https://example.com',
    });

    expect(builder).toBeInstanceOf(MetadataBuilder);
  });

  it('respects custom protocol name', () => {
    const builder = createMetadataBuilder({
      externalUrlBase: 'https://example.com',
      protocolName: 'Custom Protocol',
    });

    const vault = createMockRankedVault();
    const achievements = createMockAchievementStatus();
    const metadata = builder.buildTreasureMetadata(vault, achievements, 'https://test.com');

    expect(metadata.description).toContain('Custom Protocol');
  });
});
