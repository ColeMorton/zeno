import type { Address, Hex } from 'viem';
import type { AchievementType } from '../types/achievement.js';
import type {
  MinterAchievementClaimedEvent,
  MaturedAchievementClaimedEvent,
  DurationAchievementClaimedEvent,
  HodlerSupremeVaultMintedEvent,
  IndexedEvent,
} from '../events/schema.js';
import { HASH_TO_ACHIEVEMENT_TYPE, ALL_ACHIEVEMENT_TYPES } from '../constants/achievements.js';

/**
 * Achievement distribution statistics
 */
export interface AchievementDistribution {
  /** Achievement type */
  type: AchievementType;
  /** Number of unique wallets with this achievement */
  uniqueHolders: number;
  /** Total times this achievement was claimed */
  totalClaims: number;
  /** Timestamp of first claim */
  firstClaimTimestamp: bigint;
  /** Timestamp of most recent claim */
  latestClaimTimestamp: bigint;
}

/**
 * Achievement funnel metrics
 */
export interface AchievementFunnel {
  /** Number of wallets with MINTER */
  minterCount: number;
  /** Number of wallets with MATURED */
  maturedCount: number;
  /** Number of wallets with HODLER_SUPREME */
  hodlerSupremeCount: number;
  /** Conversion rate: MINTER → MATURED */
  minterToMaturedRate: number;
  /** Conversion rate: MATURED → HODLER_SUPREME */
  maturedToHodlerRate: number;
  /** Overall funnel completion rate */
  completionRate: number;
}

/**
 * Wallet achievement profile
 */
export interface WalletAchievementProfile {
  /** Wallet address */
  wallet: Address;
  /** Total achievements earned */
  totalAchievements: number;
  /** List of achievement types earned */
  achievementTypes: AchievementType[];
  /** Rarest achievement (if any) */
  rarest: AchievementType | null;
  /** Completion percentage (earned / total possible) */
  completionPercentage: number;
  /** Has completed the core funnel */
  hasMinter: boolean;
  hasMatured: boolean;
  hasHodlerSupreme: boolean;
}

/**
 * Achievement type alias for event processing
 */
type AchievementClaimedEvent =
  | MinterAchievementClaimedEvent
  | MaturedAchievementClaimedEvent
  | DurationAchievementClaimedEvent
  | HodlerSupremeVaultMintedEvent;

/**
 * Rarity ordering (higher = rarer)
 */
const RARITY_ORDER: Record<AchievementType, number> = {
  MINTER: 1,
  FIRST_MONTH: 2,
  QUARTER_STACK: 3,
  HALF_YEAR: 4,
  ANNUAL: 5,
  DIAMOND_HANDS: 6,
  MATURED: 7,
  HODLER_SUPREME: 8,
};

/**
 * Extract achievement events from all indexed events
 */
function filterAchievementEvents(events: IndexedEvent[]): AchievementClaimedEvent[] {
  return events.filter(
    (e): e is AchievementClaimedEvent =>
      e.type === 'MinterAchievementClaimed' ||
      e.type === 'MaturedAchievementClaimed' ||
      e.type === 'DurationAchievementClaimed' ||
      e.type === 'HodlerSupremeVaultMinted'
  );
}

/**
 * Get achievement type from event
 */
function getEventAchievementType(event: AchievementClaimedEvent): AchievementType {
  switch (event.type) {
    case 'MinterAchievementClaimed':
      return 'MINTER';
    case 'MaturedAchievementClaimed':
      return 'MATURED';
    case 'DurationAchievementClaimed': {
      const achievementType = HASH_TO_ACHIEVEMENT_TYPE[event.achievementType as Hex];
      if (!achievementType) {
        throw new Error(`Unknown achievement type hash: ${event.achievementType}`);
      }
      return achievementType;
    }
    case 'HodlerSupremeVaultMinted':
      return 'HODLER_SUPREME';
  }
}

/**
 * Calculate achievement distribution from events
 *
 * @param events - All indexed events (will filter for achievement events)
 * @returns Distribution for each achievement type
 *
 * @example
 * ```typescript
 * const events = indexer.getEvents();
 * const dist = calculateAchievementDistribution(events);
 * console.log(`MINTER holders: ${dist.find(d => d.type === 'MINTER')?.uniqueHolders}`);
 * ```
 */
export function calculateAchievementDistribution(
  events: IndexedEvent[]
): AchievementDistribution[] {
  const achievementEvents = filterAchievementEvents(events);

  // Group by achievement type
  const typeData = new Map<
    AchievementType,
    { wallets: Set<string>; claims: number; first: bigint; latest: bigint }
  >();

  for (const event of achievementEvents) {
    const type = getEventAchievementType(event);
    const wallet = event.wallet.toLowerCase();
    const timestamp = event.blockTimestamp;

    const existing = typeData.get(type) ?? {
      wallets: new Set<string>(),
      claims: 0,
      first: timestamp,
      latest: timestamp,
    };

    existing.wallets.add(wallet);
    existing.claims++;
    if (timestamp < existing.first) existing.first = timestamp;
    if (timestamp > existing.latest) existing.latest = timestamp;

    typeData.set(type, existing);
  }

  // Convert to distribution array
  const distribution: AchievementDistribution[] = [];

  for (const type of ALL_ACHIEVEMENT_TYPES) {
    const data = typeData.get(type);
    if (data) {
      distribution.push({
        type,
        uniqueHolders: data.wallets.size,
        totalClaims: data.claims,
        firstClaimTimestamp: data.first,
        latestClaimTimestamp: data.latest,
      });
    } else {
      distribution.push({
        type,
        uniqueHolders: 0,
        totalClaims: 0,
        firstClaimTimestamp: 0n,
        latestClaimTimestamp: 0n,
      });
    }
  }

  return distribution;
}

/**
 * Calculate achievement funnel metrics
 *
 * @param events - All indexed events (will filter for achievement events)
 * @returns Funnel conversion metrics
 *
 * @example
 * ```typescript
 * const events = indexer.getEvents();
 * const funnel = calculateAchievementFunnel(events);
 * console.log(`MINTER → MATURED: ${funnel.minterToMaturedRate.toFixed(1)}%`);
 * ```
 */
export function calculateAchievementFunnel(events: IndexedEvent[]): AchievementFunnel {
  const achievementEvents = filterAchievementEvents(events);

  // Track wallets by achievement type
  const minterWallets = new Set<string>();
  const maturedWallets = new Set<string>();
  const hodlerSupremeWallets = new Set<string>();

  for (const event of achievementEvents) {
    const wallet = event.wallet.toLowerCase();
    const type = getEventAchievementType(event);

    switch (type) {
      case 'MINTER':
        minterWallets.add(wallet);
        break;
      case 'MATURED':
        maturedWallets.add(wallet);
        break;
      case 'HODLER_SUPREME':
        hodlerSupremeWallets.add(wallet);
        break;
    }
  }

  const minterCount = minterWallets.size;
  const maturedCount = maturedWallets.size;
  const hodlerSupremeCount = hodlerSupremeWallets.size;

  const minterToMaturedRate = minterCount > 0 ? (maturedCount / minterCount) * 100 : 0;
  const maturedToHodlerRate = maturedCount > 0 ? (hodlerSupremeCount / maturedCount) * 100 : 0;
  const completionRate = minterCount > 0 ? (hodlerSupremeCount / minterCount) * 100 : 0;

  return {
    minterCount,
    maturedCount,
    hodlerSupremeCount,
    minterToMaturedRate,
    maturedToHodlerRate,
    completionRate,
  };
}

/**
 * Build wallet achievement profiles from events
 *
 * @param events - All indexed events (will filter for achievement events)
 * @returns Array of wallet profiles sorted by total achievements
 *
 * @example
 * ```typescript
 * const events = indexer.getEvents();
 * const profiles = buildWalletProfiles(events);
 * const top10 = profiles.slice(0, 10);
 * ```
 */
export function buildWalletProfiles(events: IndexedEvent[]): WalletAchievementProfile[] {
  const achievementEvents = filterAchievementEvents(events);

  // Group achievements by wallet
  const walletAchievements = new Map<string, Set<AchievementType>>();

  for (const event of achievementEvents) {
    const wallet = event.wallet.toLowerCase();
    const type = getEventAchievementType(event);

    const existing = walletAchievements.get(wallet) ?? new Set<AchievementType>();
    existing.add(type);
    walletAchievements.set(wallet, existing);
  }

  // Build profiles
  const profiles: WalletAchievementProfile[] = [];
  const totalPossible = ALL_ACHIEVEMENT_TYPES.length;

  for (const [wallet, achievements] of walletAchievements.entries()) {
    const achievementTypes = [...achievements];
    const totalAchievements = achievementTypes.length;

    // Find rarest achievement
    let rarest: AchievementType | null = null;
    let maxRarity = 0;
    for (const type of achievementTypes) {
      if (RARITY_ORDER[type] > maxRarity) {
        maxRarity = RARITY_ORDER[type];
        rarest = type;
      }
    }

    profiles.push({
      wallet: wallet as Address,
      totalAchievements,
      achievementTypes,
      rarest,
      completionPercentage: (totalAchievements / totalPossible) * 100,
      hasMinter: achievements.has('MINTER'),
      hasMatured: achievements.has('MATURED'),
      hasHodlerSupreme: achievements.has('HODLER_SUPREME'),
    });
  }

  // Sort by total achievements (descending)
  return profiles.sort((a, b) => b.totalAchievements - a.totalAchievements);
}

/**
 * Get leaderboard of top achievement collectors
 *
 * @param profiles - Wallet profiles
 * @param limit - Maximum entries to return
 * @returns Top collectors
 */
export function getAchievementLeaderboard(
  profiles: WalletAchievementProfile[],
  limit = 10
): WalletAchievementProfile[] {
  return profiles.slice(0, limit);
}

/**
 * Format achievement distribution for display
 */
export function formatAchievementDistribution(distribution: AchievementDistribution[]): string {
  const lines: string[] = [
    '=== Achievement Distribution ===',
    '',
    'Type             | Holders | Claims | First Claim',
    '-----------------+---------+--------+------------',
  ];

  for (const d of distribution) {
    const firstDate = d.firstClaimTimestamp > 0n
      ? new Date(Number(d.firstClaimTimestamp) * 1000).toISOString().split('T')[0]
      : 'N/A';

    lines.push(
      `${d.type.padEnd(16)} | ${String(d.uniqueHolders).padStart(7)} | ${String(d.totalClaims).padStart(6)} | ${firstDate}`
    );
  }

  return lines.join('\n');
}

/**
 * Format achievement funnel for display
 */
export function formatAchievementFunnel(funnel: AchievementFunnel): string {
  return `
=== Achievement Funnel ===

MINTER:         ${funnel.minterCount} wallets
    ↓ ${funnel.minterToMaturedRate.toFixed(1)}%
MATURED:        ${funnel.maturedCount} wallets
    ↓ ${funnel.maturedToHodlerRate.toFixed(1)}%
HODLER_SUPREME: ${funnel.hodlerSupremeCount} wallets

Overall Completion: ${funnel.completionRate.toFixed(2)}%
`.trim();
}
