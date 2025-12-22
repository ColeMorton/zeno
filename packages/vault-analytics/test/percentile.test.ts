import { describe, it, expect } from 'vitest';
import {
  getPercentileTier,
  calculatePercentile,
  rankByCollateral,
  getVaultRanking,
} from '../src/analytics/percentile.js';
import type { Vault } from '../src/types/vault.js';

const createMockVault = (overrides: Partial<Vault> = {}): Vault => ({
  tokenId: 1n,
  owner: '0x1234567890123456789012345678901234567890',
  treasureContract: '0xabcdefabcdefabcdefabcdefabcdefabcdefabcd',
  treasureTokenId: 1n,
  collateralToken: '0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599',
  collateralAmount: 100000000n, // 1 BTC
  mintTimestamp: BigInt(Math.floor(Date.now() / 1000) - 86400 * 100),
  lastWithdrawal: 0n,
  vestedBTCAmount: 0n,
  lastActivity: BigInt(Math.floor(Date.now() / 1000)),
  pokeTimestamp: 0n,
  windowId: 1n,
  issuer: '0x1111111111111111111111111111111111111111',
  ...overrides,
});

describe('getPercentileTier', () => {
  it('returns Whale for 99th percentile and above', () => {
    expect(getPercentileTier(99)).toBe('Whale');
    expect(getPercentileTier(99.5)).toBe('Whale');
    expect(getPercentileTier(100)).toBe('Whale');
  });

  it('returns Diamond for 95th-98th percentile', () => {
    expect(getPercentileTier(95)).toBe('Diamond');
    expect(getPercentileTier(98)).toBe('Diamond');
    expect(getPercentileTier(98.9)).toBe('Diamond');
  });

  it('returns Gold for 90th-94th percentile', () => {
    expect(getPercentileTier(90)).toBe('Gold');
    expect(getPercentileTier(94)).toBe('Gold');
  });

  it('returns Silver for 75th-89th percentile', () => {
    expect(getPercentileTier(75)).toBe('Silver');
    expect(getPercentileTier(89)).toBe('Silver');
  });

  it('returns Bronze for 50th-74th percentile', () => {
    expect(getPercentileTier(50)).toBe('Bronze');
    expect(getPercentileTier(74)).toBe('Bronze');
  });

  it('returns null for below 50th percentile', () => {
    expect(getPercentileTier(49)).toBeNull();
    expect(getPercentileTier(0)).toBeNull();
  });

  it('respects custom thresholds', () => {
    const customThresholds = {
      whale: 98,
      diamond: 90,
      gold: 80,
      silver: 60,
      bronze: 40,
    };
    expect(getPercentileTier(98, customThresholds)).toBe('Whale');
    expect(getPercentileTier(97, customThresholds)).toBe('Diamond');
    expect(getPercentileTier(85, customThresholds)).toBe('Gold');
    expect(getPercentileTier(65, customThresholds)).toBe('Silver');
    expect(getPercentileTier(45, customThresholds)).toBe('Bronze');
    expect(getPercentileTier(39, customThresholds)).toBeNull();
  });
});

describe('calculatePercentile', () => {
  it('calculates correct percentile for various ranks', () => {
    expect(calculatePercentile(1, 100)).toBe(99);
    expect(calculatePercentile(10, 100)).toBe(90);
    expect(calculatePercentile(50, 100)).toBe(50);
    expect(calculatePercentile(100, 100)).toBe(0);
  });

  it('returns 0 for empty dataset', () => {
    expect(calculatePercentile(1, 0)).toBe(0);
  });

  it('handles single item dataset', () => {
    expect(calculatePercentile(1, 1)).toBe(0);
  });
});

describe('rankByCollateral', () => {
  it('ranks vaults by collateral descending', () => {
    const vaults = [
      createMockVault({ tokenId: 1n, collateralAmount: 100000000n }),
      createMockVault({ tokenId: 2n, collateralAmount: 500000000n }),
      createMockVault({ tokenId: 3n, collateralAmount: 200000000n }),
    ];

    const ranked = rankByCollateral(vaults);

    expect(ranked[0]?.vault.tokenId).toBe(2n);
    expect(ranked[0]?.rank).toBe(1);
    expect(ranked[1]?.vault.tokenId).toBe(3n);
    expect(ranked[1]?.rank).toBe(2);
    expect(ranked[2]?.vault.tokenId).toBe(1n);
    expect(ranked[2]?.rank).toBe(3);
  });

  it('uses mintTimestamp as tie-breaker (earlier = higher rank)', () => {
    const now = Math.floor(Date.now() / 1000);
    const vaults = [
      createMockVault({ tokenId: 1n, collateralAmount: 100000000n, mintTimestamp: BigInt(now - 100) }),
      createMockVault({ tokenId: 2n, collateralAmount: 100000000n, mintTimestamp: BigInt(now - 200) }),
    ];

    const ranked = rankByCollateral(vaults);

    // Token 2 minted earlier, should rank higher
    expect(ranked[0]?.vault.tokenId).toBe(2n);
    expect(ranked[1]?.vault.tokenId).toBe(1n);
  });

  it('does not show percentile for small datasets', () => {
    const vaults = [
      createMockVault({ tokenId: 1n, collateralAmount: 100000000n }),
    ];

    const ranked = rankByCollateral(vaults);

    expect(ranked[0]?.percentile).toBe(0);
    expect(ranked[0]?.tier).toBeNull();
  });

  it('shows percentile for datasets >= 10 vaults', () => {
    const vaults = Array.from({ length: 10 }, (_, i) =>
      createMockVault({ tokenId: BigInt(i + 1), collateralAmount: BigInt((i + 1) * 10000000) })
    );

    const ranked = rankByCollateral(vaults);

    expect(ranked[0]?.percentile).toBe(90);
    expect(ranked[0]?.tier).toBe('Gold');
  });
});

describe('getVaultRanking', () => {
  it('finds and returns ranking for specific vault', () => {
    const vaults = [
      createMockVault({ tokenId: 1n, collateralAmount: 100000000n }),
      createMockVault({ tokenId: 2n, collateralAmount: 500000000n }),
      createMockVault({ tokenId: 3n, collateralAmount: 200000000n }),
    ];

    const ranking = getVaultRanking(vaults, 3n);

    expect(ranking).not.toBeNull();
    expect(ranking?.vault.tokenId).toBe(3n);
    expect(ranking?.rank).toBe(2);
  });

  it('returns null for non-existent vault', () => {
    const vaults = [createMockVault({ tokenId: 1n })];
    const ranking = getVaultRanking(vaults, 999n);

    expect(ranking).toBeNull();
  });
});
