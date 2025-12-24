import { describe, it, expect } from 'vitest';
import {
  isVested,
  isSeparated,
  getDormancyStatus,
  getVestingDaysRemaining,
  filterVaults,
  deriveVaultStatus,
} from '../src/analytics/filters.js';
import { VESTING_PERIOD, DORMANCY_THRESHOLD, GRACE_PERIOD } from '../src/constants/protocol.js';
import type { Vault } from '../src/types/vault.js';

const createMockVault = (overrides: Partial<Vault> = {}): Vault => ({
  tokenId: 1n,
  owner: '0x1234567890123456789012345678901234567890',
  treasureContract: '0xabcdefabcdefabcdefabcdefabcdefabcdefabcd',
  treasureTokenId: 1n,
  collateralToken: '0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599',
  collateralAmount: 100000000n,
  mintTimestamp: BigInt(Math.floor(Date.now() / 1000)),
  lastWithdrawal: 0n,
  vestedBTCAmount: 0n,
  lastActivity: BigInt(Math.floor(Date.now() / 1000)),
  pokeTimestamp: 0n,
  windowId: 1n,
  issuer: '0x1111111111111111111111111111111111111111',
  ...overrides,
});

describe('isVested', () => {
  it('returns false for newly minted vault', () => {
    const now = BigInt(Math.floor(Date.now() / 1000));
    const vault = createMockVault({ mintTimestamp: now });

    expect(isVested(vault, now)).toBe(false);
  });

  it('returns true for vault past vesting period', () => {
    const now = BigInt(Math.floor(Date.now() / 1000));
    const vault = createMockVault({ mintTimestamp: now - VESTING_PERIOD - 1n });

    expect(isVested(vault, now)).toBe(true);
  });

  it('returns true for vault exactly at vesting completion', () => {
    const now = BigInt(Math.floor(Date.now() / 1000));
    const vault = createMockVault({ mintTimestamp: now - VESTING_PERIOD });

    expect(isVested(vault, now)).toBe(true);
  });
});

describe('isSeparated', () => {
  it('returns false for combined vault', () => {
    const vault = createMockVault({ vestedBTCAmount: 0n });
    expect(isSeparated(vault)).toBe(false);
  });

  it('returns true for separated vault', () => {
    const vault = createMockVault({ vestedBTCAmount: 100000000n });
    expect(isSeparated(vault)).toBe(true);
  });
});

describe('getDormancyStatus', () => {
  it('returns active for normal vault', () => {
    const now = BigInt(Math.floor(Date.now() / 1000));
    const vault = createMockVault({
      pokeTimestamp: 0n,
      lastActivity: now,
    });

    expect(getDormancyStatus(vault, now)).toBe('active');
  });

  it('returns poke_pending when poked within grace period', () => {
    const now = BigInt(Math.floor(Date.now() / 1000));
    const vault = createMockVault({
      pokeTimestamp: now - 86400n, // 1 day ago
    });

    expect(getDormancyStatus(vault, now)).toBe('poke_pending');
  });

  it('returns claimable when grace period expired', () => {
    const now = BigInt(Math.floor(Date.now() / 1000));
    const vault = createMockVault({
      pokeTimestamp: now - GRACE_PERIOD - 1n,
    });

    expect(getDormancyStatus(vault, now)).toBe('claimable');
  });
});

describe('getVestingDaysRemaining', () => {
  it('returns 0 for vested vault', () => {
    const now = BigInt(Math.floor(Date.now() / 1000));
    const vault = createMockVault({ mintTimestamp: now - VESTING_PERIOD - 86400n });

    expect(getVestingDaysRemaining(vault, now)).toBe(0);
  });

  it('returns correct days for unvested vault', () => {
    const now = BigInt(Math.floor(Date.now() / 1000));
    const vault = createMockVault({ mintTimestamp: now - 86400n * 100n }); // 100 days ago

    const remaining = getVestingDaysRemaining(vault, now);
    expect(remaining).toBe(1129 - 100);
  });
});

describe('filterVaults', () => {
  const now = BigInt(Math.floor(Date.now() / 1000));

  it('filters by vesting status - vested', () => {
    const vaults = [
      createMockVault({ tokenId: 1n, mintTimestamp: now }), // vesting
      createMockVault({ tokenId: 2n, mintTimestamp: now - VESTING_PERIOD - 1n }), // vested
    ];

    const filtered = filterVaults(vaults, { vestingStatus: 'vested' }, now);

    expect(filtered).toHaveLength(1);
    expect(filtered[0]?.tokenId).toBe(2n);
  });

  it('filters by vesting status - vesting', () => {
    const vaults = [
      createMockVault({ tokenId: 1n, mintTimestamp: now }), // vesting
      createMockVault({ tokenId: 2n, mintTimestamp: now - VESTING_PERIOD - 1n }), // vested
    ];

    const filtered = filterVaults(vaults, { vestingStatus: 'vesting' }, now);

    expect(filtered).toHaveLength(1);
    expect(filtered[0]?.tokenId).toBe(1n);
  });

  it('filters by separation status - combined', () => {
    const vaults = [
      createMockVault({ tokenId: 1n, vestedBTCAmount: 0n }), // combined
      createMockVault({ tokenId: 2n, vestedBTCAmount: 100000000n }), // separated
    ];

    const filtered = filterVaults(vaults, { separationStatus: 'combined' }, now);

    expect(filtered).toHaveLength(1);
    expect(filtered[0]?.tokenId).toBe(1n);
  });

  it('filters by separation status - separated', () => {
    const vaults = [
      createMockVault({ tokenId: 1n, vestedBTCAmount: 0n }), // combined
      createMockVault({ tokenId: 2n, vestedBTCAmount: 100000000n }), // separated
    ];

    const filtered = filterVaults(vaults, { separationStatus: 'separated' }, now);

    expect(filtered).toHaveLength(1);
    expect(filtered[0]?.tokenId).toBe(2n);
  });

  it('applies multiple filters', () => {
    const vaults = [
      createMockVault({ tokenId: 1n, mintTimestamp: now, vestedBTCAmount: 0n }),
      createMockVault({ tokenId: 2n, mintTimestamp: now - VESTING_PERIOD - 1n, vestedBTCAmount: 0n }),
      createMockVault({ tokenId: 3n, mintTimestamp: now - VESTING_PERIOD - 1n, vestedBTCAmount: 100n }),
    ];

    const filtered = filterVaults(
      vaults,
      { vestingStatus: 'vested', separationStatus: 'combined' },
      now
    );

    expect(filtered).toHaveLength(1);
    expect(filtered[0]?.tokenId).toBe(2n);
  });

  it('returns all vaults when filter is "all"', () => {
    const vaults = [
      createMockVault({ tokenId: 1n }),
      createMockVault({ tokenId: 2n }),
    ];

    const filtered = filterVaults(vaults, { vestingStatus: 'all' }, now);

    expect(filtered).toHaveLength(2);
  });
});

describe('deriveVaultStatus', () => {
  it('returns complete status object', () => {
    const now = BigInt(Math.floor(Date.now() / 1000));
    const vault = createMockVault({
      mintTimestamp: now - 86400n * 100n,
      vestedBTCAmount: 0n,
      pokeTimestamp: 0n,
    });

    const status = deriveVaultStatus(vault, now);

    expect(status.isVested).toBe(false);
    expect(status.isSeparated).toBe(false);
    expect(status.dormancyStatus).toBe('active');
    expect(status.vestingDaysRemaining).toBe(1029);
    expect(status.vestingEndsAt).toBe(vault.mintTimestamp + VESTING_PERIOD);
  });
});
