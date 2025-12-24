import type { Address, PublicClient } from 'viem';
import type {
  AchievementType,
  Achievement,
  AchievementStatus,
  AchievementEligibility,
} from '../types/achievement.js';
import {
  ACHIEVEMENT_TYPE_HASHES,
  ALL_ACHIEVEMENT_TYPES,
  DURATION_ACHIEVEMENT_TYPES,
} from '../constants/achievements.js';

/**
 * AchievementClient configuration
 */
export interface AchievementClientConfig {
  /** AchievementNFT contract address */
  achievementNFT: Address;
  /** AchievementMinter contract address */
  achievementMinter: Address;
  /** viem PublicClient for contract reads */
  publicClient: PublicClient;
}

/**
 * ABI fragments for contract calls
 */
const ACHIEVEMENT_NFT_ABI = [
  {
    name: 'hasAchievement',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'wallet', type: 'address' },
      { name: 'type_', type: 'bytes32' },
    ],
    outputs: [{ type: 'bool' }],
  },
] as const;

const ACHIEVEMENT_MINTER_ABI = [
  {
    name: 'canClaimMinterAchievement',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'wallet', type: 'address' },
      { name: 'vaultId', type: 'uint256' },
    ],
    outputs: [
      { name: 'canClaim', type: 'bool' },
      { name: 'reason', type: 'string' },
    ],
  },
  {
    name: 'canClaimMaturedAchievement',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'wallet', type: 'address' },
      { name: 'vaultId', type: 'uint256' },
    ],
    outputs: [
      { name: 'canClaim', type: 'bool' },
      { name: 'reason', type: 'string' },
    ],
  },
  {
    name: 'canClaimDurationAchievement',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'wallet', type: 'address' },
      { name: 'vaultId', type: 'uint256' },
      { name: 'achievementType', type: 'bytes32' },
    ],
    outputs: [
      { name: 'canClaim', type: 'bool' },
      { name: 'reason', type: 'string' },
    ],
  },
  {
    name: 'canMintHodlerSupremeVault',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'wallet', type: 'address' }],
    outputs: [
      { name: 'canMint', type: 'bool' },
      { name: 'reason', type: 'string' },
    ],
  },
] as const;

/**
 * Client for querying achievement state from contracts.
 *
 * Uses viem for direct contract calls to AchievementNFT and AchievementMinter.
 *
 * @example Query wallet achievements
 * ```typescript
 * const client = new AchievementClient({
 *   achievementNFT: '0x...',
 *   achievementMinter: '0x...',
 *   publicClient,
 * });
 *
 * const status = await client.getAchievements(walletAddress);
 * console.log(status.hasMinter, status.hasMatured);
 * ```
 */
export class AchievementClient {
  private readonly achievementNFT: Address;
  private readonly achievementMinter: Address;
  private readonly publicClient: PublicClient;

  constructor(config: AchievementClientConfig) {
    this.achievementNFT = config.achievementNFT;
    this.achievementMinter = config.achievementMinter;
    this.publicClient = config.publicClient;
  }

  /**
   * Check if a wallet has a specific achievement.
   */
  async hasAchievement(wallet: Address, type: AchievementType): Promise<boolean> {
    const hash = ACHIEVEMENT_TYPE_HASHES[type];

    const result = await this.publicClient.readContract({
      address: this.achievementNFT,
      abi: ACHIEVEMENT_NFT_ABI,
      functionName: 'hasAchievement',
      args: [wallet, hash],
    });

    return result;
  }

  /**
   * Get aggregated achievement status for a wallet.
   *
   * Queries all achievement types and returns consolidated status.
   */
  async getAchievements(wallet: Address): Promise<AchievementStatus> {
    const results = await Promise.all(
      ALL_ACHIEVEMENT_TYPES.map(async (type) => ({
        type,
        has: await this.hasAchievement(wallet, type),
      }))
    );

    const earnedTypes = results.filter((r) => r.has).map((r) => r.type);

    const achievements: Achievement[] = earnedTypes.map((type) => ({
      type,
      tokenId: 0n, // Token ID not available via hasAchievement
      wallet,
      earnedAt: 0n, // Timestamp not available via hasAchievement
    }));

    const durationAchievements = earnedTypes.filter((type) =>
      DURATION_ACHIEVEMENT_TYPES.includes(type)
    );

    return {
      wallet,
      achievements,
      hasMinter: earnedTypes.includes('MINTER'),
      hasMatured: earnedTypes.includes('MATURED'),
      hasHodlerSupreme: earnedTypes.includes('HODLER_SUPREME'),
      durationAchievements,
    };
  }

  /**
   * Check if a wallet can claim MINTER achievement for a vault.
   */
  async canClaimMinter(wallet: Address, vaultId: bigint): Promise<AchievementEligibility> {
    const [canClaim, reason] = await this.publicClient.readContract({
      address: this.achievementMinter,
      abi: ACHIEVEMENT_MINTER_ABI,
      functionName: 'canClaimMinterAchievement',
      args: [wallet, vaultId],
    });

    return {
      type: 'MINTER',
      eligible: canClaim,
      reason,
      vaultId,
    };
  }

  /**
   * Check if a wallet can claim MATURED achievement for a vault.
   */
  async canClaimMatured(wallet: Address, vaultId: bigint): Promise<AchievementEligibility> {
    const [canClaim, reason] = await this.publicClient.readContract({
      address: this.achievementMinter,
      abi: ACHIEVEMENT_MINTER_ABI,
      functionName: 'canClaimMaturedAchievement',
      args: [wallet, vaultId],
    });

    return {
      type: 'MATURED',
      eligible: canClaim,
      reason,
      vaultId,
    };
  }

  /**
   * Check if a wallet can claim a duration achievement for a vault.
   */
  async canClaimDuration(
    wallet: Address,
    vaultId: bigint,
    type: AchievementType
  ): Promise<AchievementEligibility> {
    const hash = ACHIEVEMENT_TYPE_HASHES[type];

    const [canClaim, reason] = await this.publicClient.readContract({
      address: this.achievementMinter,
      abi: ACHIEVEMENT_MINTER_ABI,
      functionName: 'canClaimDurationAchievement',
      args: [wallet, vaultId, hash],
    });

    return {
      type,
      eligible: canClaim,
      reason,
      vaultId,
    };
  }

  /**
   * Check if a wallet can mint HODLER_SUPREME vault.
   */
  async canMintHodlerSupreme(wallet: Address): Promise<AchievementEligibility> {
    const [canMint, reason] = await this.publicClient.readContract({
      address: this.achievementMinter,
      abi: ACHIEVEMENT_MINTER_ABI,
      functionName: 'canMintHodlerSupremeVault',
      args: [wallet],
    });

    return {
      type: 'HODLER_SUPREME',
      eligible: canMint,
      reason,
    };
  }

  /**
   * Get all eligible achievements for a wallet and vault.
   *
   * Checks MINTER, MATURED, and all duration achievements.
   */
  async getEligibleAchievements(
    wallet: Address,
    vaultId: bigint
  ): Promise<AchievementEligibility[]> {
    const [minter, matured, hodlerSupreme, ...duration] = await Promise.all([
      this.canClaimMinter(wallet, vaultId),
      this.canClaimMatured(wallet, vaultId),
      this.canMintHodlerSupreme(wallet),
      ...DURATION_ACHIEVEMENT_TYPES.map((type) => this.canClaimDuration(wallet, vaultId, type)),
    ]);

    return [minter, matured, hodlerSupreme, ...duration];
  }
}

/**
 * Create an achievement client.
 */
export function createAchievementClient(config: AchievementClientConfig): AchievementClient {
  return new AchievementClient(config);
}
