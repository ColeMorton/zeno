import type { Vault } from '../types/vault.js';
import type { VaultFilter, DormancyStatus } from '../types/filter.js';
import { VESTING_PERIOD, DORMANCY_THRESHOLD, GRACE_PERIOD } from '../constants/protocol.js';

/**
 * Check if a vault is vested.
 *
 * A vault is vested when 1093 days have passed since mint.
 *
 * @param vault - Vault to check
 * @param currentTimestamp - Current block timestamp (defaults to now)
 * @returns true if vesting period has completed
 *
 * @example Check vesting status
 * ```typescript
 * if (isVested(vault)) {
 *   console.log('Vault is vested, withdrawals enabled');
 * }
 * ```
 *
 * @example With specific timestamp
 * ```typescript
 * const futureTime = BigInt(Date.now() / 1000) + 86400n * 1000n;
 * if (isVested(vault, futureTime)) {
 *   console.log('Vault will be vested by then');
 * }
 * ```
 */
export function isVested(vault: Vault, currentTimestamp?: bigint): boolean {
  const now = currentTimestamp ?? BigInt(Math.floor(Date.now() / 1000));
  return now >= vault.mintTimestamp + VESTING_PERIOD;
}

/**
 * Check if a vault's collateral is separated.
 *
 * A vault is separated when vestedBTC tokens have been minted against
 * the vault's collateral.
 *
 * @param vault - Vault to check
 * @returns true if vestedBTC has been minted from this vault
 *
 * @example Check separation status
 * ```typescript
 * if (isSeparated(vault)) {
 *   console.log(`Vault has ${vault.vestedBTCAmount} vBTC minted`);
 * } else {
 *   console.log('Collateral is still combined');
 * }
 * ```
 */
export function isSeparated(vault: Vault): boolean {
  return vault.vestedBTCAmount > 0n;
}

/**
 * Get the dormancy status of a vault.
 *
 * Dormancy states:
 * - `active`: Normal operating state
 * - `poke_pending`: Vault has been poked, owner has 30-day grace period
 * - `claimable`: Grace period expired, dormant claim available
 *
 * @param vault - Vault to check
 * @param currentTimestamp - Current block timestamp (defaults to now)
 * @returns Dormancy status
 *
 * @example Check dormancy
 * ```typescript
 * const status = getDormancyStatus(vault);
 * if (status === 'claimable') {
 *   console.log('Vault collateral can be claimed via dormancy');
 * }
 * ```
 */
export function getDormancyStatus(
  vault: Vault,
  currentTimestamp?: bigint
): DormancyStatus {
  const now = currentTimestamp ?? BigInt(Math.floor(Date.now() / 1000));

  // If poked, check grace period
  if (vault.pokeTimestamp > 0n) {
    const graceExpiry = vault.pokeTimestamp + GRACE_PERIOD;
    if (now >= graceExpiry) {
      return 'claimable';
    }
    return 'poke_pending';
  }

  // Check if dormant-eligible (all conditions must be met)
  const vested = now >= vault.mintTimestamp + VESTING_PERIOD;
  const separated = vault.vestedBTCAmount > 0n;
  const inactive = now >= vault.lastActivity + DORMANCY_THRESHOLD;

  if (vested && separated && inactive) {
    // Dormant-eligible but not yet poked, still considered active
    return 'active';
  }

  return 'active';
}

/**
 * Calculate days remaining until vesting completes.
 *
 * Returns 0 if the vault is already vested.
 *
 * @param vault - Vault to check
 * @param currentTimestamp - Current block timestamp (defaults to now)
 * @returns Days remaining (0 if vested)
 *
 * @example Display vesting countdown
 * ```typescript
 * const days = getVestingDaysRemaining(vault);
 * if (days > 0) {
 *   console.log(`${days} days until vesting`);
 * } else {
 *   console.log('Fully vested');
 * }
 * ```
 */
export function getVestingDaysRemaining(
  vault: Vault,
  currentTimestamp?: bigint
): number {
  const now = currentTimestamp ?? BigInt(Math.floor(Date.now() / 1000));
  const vestingEnds = vault.mintTimestamp + VESTING_PERIOD;

  if (now >= vestingEnds) {
    return 0;
  }

  const remaining = vestingEnds - now;
  return Number(remaining / 86400n);
}

/**
 * Filter vaults by status criteria.
 *
 * Supports filtering by vesting status, separation status, and dormancy status.
 * Filters can be combined - all conditions must match.
 *
 * @param vaults - Array of vaults to filter
 * @param filter - Filter criteria
 * @param filter.vestingStatus - 'vesting' | 'vested' | 'all'
 * @param filter.separationStatus - 'combined' | 'separated' | 'all'
 * @param filter.dormancyStatus - 'active' | 'poke_pending' | 'claimable' | 'all'
 * @param currentTimestamp - Current block timestamp (defaults to now)
 * @returns Filtered vault array
 *
 * @example Filter by vesting status
 * ```typescript
 * const vestedVaults = filterVaults(vaults, { vestingStatus: 'vested' });
 * ```
 *
 * @example Combine multiple filters
 * ```typescript
 * const target = filterVaults(vaults, {
 *   vestingStatus: 'vested',
 *   separationStatus: 'combined',
 *   dormancyStatus: 'active'
 * });
 * ```
 *
 * @example Use 'all' to skip a filter
 * ```typescript
 * const allVesting = filterVaults(vaults, {
 *   vestingStatus: 'all',
 *   separationStatus: 'combined'
 * });
 * ```
 */
export function filterVaults(
  vaults: Vault[],
  filter: VaultFilter,
  currentTimestamp?: bigint
): Vault[] {
  const now = currentTimestamp ?? BigInt(Math.floor(Date.now() / 1000));

  return vaults.filter((vault) => {
    // Vesting status filter
    if (filter.vestingStatus && filter.vestingStatus !== 'all') {
      const vested = isVested(vault, now);
      if (filter.vestingStatus === 'vested' && !vested) return false;
      if (filter.vestingStatus === 'vesting' && vested) return false;
    }

    // Separation status filter
    if (filter.separationStatus && filter.separationStatus !== 'all') {
      const separated = isSeparated(vault);
      if (filter.separationStatus === 'separated' && !separated) return false;
      if (filter.separationStatus === 'combined' && separated) return false;
    }

    // Dormancy status filter
    if (filter.dormancyStatus && filter.dormancyStatus !== 'all') {
      const dormancy = getDormancyStatus(vault, now);
      if (filter.dormancyStatus !== dormancy) return false;
    }

    return true;
  });
}

/**
 * Derive complete vault status.
 *
 * Calculates all status fields for a vault in a single call.
 *
 * @param vault - Vault to analyze
 * @param currentTimestamp - Current block timestamp (defaults to now)
 * @returns Status object containing:
 *   - `isVested`: Whether vesting period is complete
 *   - `isSeparated`: Whether collateral has been separated
 *   - `dormancyStatus`: Current dormancy state
 *   - `vestingDaysRemaining`: Days until vesting (0 if vested)
 *   - `vestingEndsAt`: Timestamp when vesting completes
 *
 * @example Get complete vault status
 * ```typescript
 * const status = deriveVaultStatus(vault);
 * console.log(`Vested: ${status.isVested}`);
 * console.log(`Days remaining: ${status.vestingDaysRemaining}`);
 * console.log(`Dormancy: ${status.dormancyStatus}`);
 * ```
 *
 * @example Display in UI
 * ```typescript
 * const { isVested, vestingDaysRemaining, dormancyStatus } = deriveVaultStatus(vault);
 * const label = isVested
 *   ? dormancyStatus === 'active' ? 'Active' : 'At Risk'
 *   : `${vestingDaysRemaining} days left`;
 * ```
 */
export function deriveVaultStatus(vault: Vault, currentTimestamp?: bigint) {
  const now = currentTimestamp ?? BigInt(Math.floor(Date.now() / 1000));

  return {
    isVested: isVested(vault, now),
    isSeparated: isSeparated(vault),
    dormancyStatus: getDormancyStatus(vault, now),
    vestingDaysRemaining: getVestingDaysRemaining(vault, now),
    vestingEndsAt: vault.mintTimestamp + VESTING_PERIOD,
  };
}
