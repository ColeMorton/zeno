'use client';

import { useQuery } from '@tanstack/react-query';
import { useAccount, useChainId, usePublicClient } from 'wagmi';
import type { Address, PublicClient } from 'viem';
import { getContractAddresses, CHAPTER_REGISTRY_ABI, CHAPTER_ACHIEVEMENT_NFT_ABI, CHAPTER_MINTER_ABI, TREASURE_NFT_ABI, ERC721_ABI } from '@/lib/contracts';
import { CHAPTER_1_ACHIEVEMENTS } from '@/lib/chapters';
import { ACHIEVEMENT_TYPES } from '@/lib/achievements';
import { useChainTime } from './useChainTime';

export interface ChapterAchievement {
  id: string;
  achievementId: `0x${string}`;
  name: string;
  description: string;
  prerequisites: string[];
  position: { x: number; y: number };
  isClaimed: boolean;
  canClaim: boolean;
  week: number;
}

export interface ChapterMapConfig {
  chapterId: string;
  chapterIdBytes: `0x${string}`;
  theme: string;
  backgroundUrl: string;
  achievements: ChapterAchievement[];
}

/**
 * Hook to fetch achievements for a specific chapter version
 * Fetches from on-chain ChapterRegistry when contracts are configured
 * Falls back to mock data when contracts are not available
 */
export function useChapterAchievements(chapterId: string | undefined) {
  const { address } = useAccount();
  const chainId = useChainId();
  const publicClient = usePublicClient();
  const { chainTime } = useChainTime();

  return useQuery({
    queryKey: ['chapterAchievements', chapterId, address, chainId, chainTime],
    queryFn: async (): Promise<ChapterMapConfig | null> => {
      if (!chapterId) return null;

      // Parse chapter number from ID (e.g., "CH1_2025Q1" -> 1)
      const match = chapterId.match(/^CH(\d+)_/);
      if (!match) return null;
      const chapterNumber = parseInt(match[1], 10);

      let contracts;
      try {
        contracts = getContractAddresses(chainId);
      } catch {
        // Chain not configured, use mock data with empty claimed set
        return getMockChapterConfig(chapterNumber, chapterId, new Set());
      }

      // If chapter contracts not deployed, use mock data but query vaults for claimed status
      if (!contracts.chapterRegistry || !contracts.chapterAchievementNFT) {
        let claimedTypes = new Set<`0x${string}`>();
        let maxDaysHeld = 0;
        if (publicClient && address && contracts.vaultNFT && contracts.treasureNFT) {
          try {
            const result = await getUserVaultData(
              publicClient,
              contracts.vaultNFT,
              contracts.treasureNFT,
              address,
              chainTime ?? Math.floor(Date.now() / 1000)
            );
            claimedTypes = result.claimedTypes;
            maxDaysHeld = result.maxDaysHeld;
          } catch {
            // Vault query failed, use defaults
          }
        }
        return getMockChapterConfig(chapterNumber, chapterId, claimedTypes, maxDaysHeld);
      }

      if (!publicClient) {
        return getMockChapterConfig(chapterNumber, chapterId, new Set());
      }

      // Convert chapter ID string to bytes32
      const chapterIdBytes = stringToBytes32(chapterId);

      // Fetch achievements from ChapterRegistry
      const achievements = await publicClient.readContract({
        address: contracts.chapterRegistry,
        abi: CHAPTER_REGISTRY_ABI,
        functionName: 'getChapterAchievements',
        args: [chapterIdBytes],
      }) as Array<{
        achievementId: `0x${string}`;
        name: string;
        prerequisites: `0x${string}`[];
        verifier: `0x${string}`;
      }>;

      // Check claimed status for each achievement
      const achievementsWithStatus = await Promise.all(
        achievements.map(async (ach, index) => {
          let isClaimed = false;
          let canClaim = false;

          if (address) {
            // Check if already claimed
            isClaimed = await publicClient.readContract({
              address: contracts.chapterAchievementNFT!,
              abi: CHAPTER_ACHIEVEMENT_NFT_ABI,
              functionName: 'hasAchievement',
              args: [address, ach.achievementId],
            }) as boolean;

            // Check if can claim (only if not already claimed)
            if (!isClaimed && contracts.chapterMinter) {
              try {
                const [claimable] = await publicClient.readContract({
                  address: contracts.chapterMinter,
                  abi: CHAPTER_MINTER_ABI,
                  functionName: 'canClaimChapterAchievement',
                  args: [address, chapterIdBytes, ach.achievementId, 0n, contracts.cbBTC, '0x'],
                }) as [boolean, string];
                canClaim = claimable;
              } catch {
                // Minter check failed, default to false
              }
            }
          }

          // Get description from static config
          const staticAch = CHAPTER_1_ACHIEVEMENTS.find(a => a.name === ach.name);

          return {
            id: `${chapterId}_${ach.name}`,
            achievementId: ach.achievementId,
            name: ach.name,
            description: staticAch?.description ?? '',
            prerequisites: ach.prerequisites.map(p => bytes32ToString(p)),
            position: getAchievementPosition(index, achievements.length),
            isClaimed,
            canClaim,
            week: staticAch?.week ?? index + 1,
          };
        })
      );

      return {
        chapterId,
        chapterIdBytes,
        theme: getChapterTheme(chapterNumber),
        backgroundUrl: `/chapters/ch${chapterNumber}/${chapterId.split('_')[1].toLowerCase()}/background.png`,
        achievements: achievementsWithStatus,
      };
    },
    enabled: !!chapterId,
    staleTime: 30 * 1000, // 30 seconds - check claim status more frequently
  });
}

const VAULT_NFT_QUERY_ABI = [
  {
    name: 'ownerOf',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'tokenId', type: 'uint256' }],
    outputs: [{ type: 'address' }],
  },
  {
    name: 'getVaultInfo',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'tokenId', type: 'uint256' }],
    outputs: [
      { name: 'treasureContract', type: 'address' },
      { name: 'treasureTokenId', type: 'uint256' },
      { name: 'collateralToken', type: 'address' },
      { name: 'collateralAmount', type: 'uint256' },
      { name: 'mintTimestamp', type: 'uint256' },
      { name: 'lastWithdrawal', type: 'uint256' },
      { name: 'lastActivity', type: 'uint256' },
      { name: 'btcTokenAmount', type: 'uint256' },
      { name: 'originalMintedAmount', type: 'uint256' },
    ],
  },
] as const;

interface UserVaultData {
  claimedTypes: Set<`0x${string}`>;
  maxDaysHeld: number;
}

/**
 * Query user's vaults to find achievement types and calculate max days held
 * Iterates through vault IDs since VaultNFT doesn't implement ERC721Enumerable
 */
async function getUserVaultData(
  publicClient: PublicClient,
  vaultNFT: Address,
  treasureNFT: Address,
  userAddress: Address,
  currentTime: number
): Promise<UserVaultData> {
  const claimedTypes = new Set<`0x${string}`>();
  const normalizedUser = userAddress.toLowerCase();
  let maxDaysHeld = 0;

  // Iterate through vault IDs until we hit a non-existent token
  let tokenId = 0n;
  while (true) {
    try {
      const owner = await publicClient.readContract({
        address: vaultNFT,
        abi: VAULT_NFT_QUERY_ABI,
        functionName: 'ownerOf',
        args: [tokenId],
      }) as Address;

      // If this vault belongs to the user, get its info
      if (owner.toLowerCase() === normalizedUser) {
        const vaultInfo = await publicClient.readContract({
          address: vaultNFT,
          abi: VAULT_NFT_QUERY_ABI,
          functionName: 'getVaultInfo',
          args: [tokenId],
        }) as [Address, bigint, Address, bigint, bigint, bigint, bigint, bigint, bigint];

        const treasureTokenId = vaultInfo[1];
        const mintTimestamp = Number(vaultInfo[4]);

        // Calculate days held for this vault
        const daysHeld = Math.floor((currentTime - mintTimestamp) / 86400);
        maxDaysHeld = Math.max(maxDaysHeld, daysHeld);

        const achievementType = await publicClient.readContract({
          address: treasureNFT,
          abi: TREASURE_NFT_ABI,
          functionName: 'achievementType',
          args: [treasureTokenId],
        }) as `0x${string}`;

        // Skip zero bytes32 (no achievement type)
        if (achievementType !== '0x0000000000000000000000000000000000000000000000000000000000000000') {
          claimedTypes.add(achievementType);
        }
      }

      tokenId++;
    } catch {
      // Token doesn't exist - we've enumerated all vaults
      break;
    }
  }

  return { claimedTypes, maxDaysHeld };
}

function getMockChapterConfig(
  chapterNumber: number,
  chapterId: string,
  claimedAchievementTypes: Set<`0x${string}`>,
  daysHeld: number = 0
): ChapterMapConfig {
  const mockAchievements = generateMockAchievements(chapterNumber, chapterId, claimedAchievementTypes, daysHeld);
  return {
    chapterId,
    chapterIdBytes: stringToBytes32(chapterId),
    theme: getChapterTheme(chapterNumber),
    backgroundUrl: `/chapters/ch${chapterNumber}/${chapterId.split('_')[1].toLowerCase()}/background.png`,
    achievements: mockAchievements,
  };
}

function stringToBytes32(str: string): `0x${string}` {
  const hex = Buffer.from(str).toString('hex').padEnd(64, '0');
  return `0x${hex}` as `0x${string}`;
}

function bytes32ToString(bytes32: `0x${string}`): string {
  const hex = bytes32.slice(2);
  let str = '';
  for (let i = 0; i < hex.length; i += 2) {
    const code = parseInt(hex.substr(i, 2), 16);
    if (code === 0) break;
    str += String.fromCharCode(code);
  }
  return str;
}

function getAchievementPosition(index: number, total: number): { x: number; y: number } {
  // Arrange in a vertical path with some horizontal variation
  const row = Math.floor(index / 2);
  const col = index % 2;
  return {
    x: 40 + col * 20,
    y: 10 + row * (80 / Math.ceil(total / 2)),
  };
}

function getChapterTheme(chapterNumber: number): string {
  const themes: Record<number, string> = {
    1: 'Frozen Tundra',
    2: 'Ice Caves',
    3: 'Glacier Fields',
    4: 'Mountain Base',
    5: 'Forest Trail',
    6: 'Rocky Ascent',
    7: 'Ridge Line',
    8: 'High Camp',
    9: 'Storm Zone',
    10: 'Death Zone',
    11: 'Final Ascent',
    12: 'Summit',
  };
  return themes[chapterNumber] ?? 'Unknown';
}

function generateMockAchievements(
  chapterNumber: number,
  chapterId: string,
  claimedAchievementTypes: Set<`0x${string}`>,
  daysHeld: number = 0
): ChapterAchievement[] {
  // For Chapter 1, use the defined achievements
  if (chapterNumber === 1) {
    return CHAPTER_1_ACHIEVEMENTS.map((ach, index) => {
      // Check if user has claimed this achievement by checking TreasureNFT ownership
      const achievementTypeHash = ACHIEVEMENT_TYPES[ach.name as keyof typeof ACHIEVEMENT_TYPES];
      const isClaimed = achievementTypeHash ? claimedAchievementTypes.has(achievementTypeHash) : false;

      // Determine if user can claim based on time requirements
      const requiredDays = ach.requiredDays ?? 0;
      const meetsTimeRequirement = daysHeld >= requiredDays;
      const canClaim = !isClaimed && meetsTimeRequirement;

      return {
        id: `${chapterId}_${ach.name}`,
        achievementId: stringToBytes32(`${chapterId}_${ach.name}`),
        name: ach.name,
        description: ach.description,
        prerequisites: [],
        position: getAchievementPosition(index, CHAPTER_1_ACHIEVEMENTS.length),
        isClaimed,
        canClaim,
        week: ach.week,
      };
    });
  }

  // Generic achievements for other chapters
  const baseAchievements = [
    { name: 'First Steps', description: 'Begin the chapter journey' },
    { name: 'Pathfinder', description: 'Discover the hidden trail' },
    { name: 'Explorer', description: 'Map the terrain' },
    { name: 'Trailblazer', description: 'Complete the main path' },
    { name: 'Master', description: 'Conquer all challenges' },
  ];

  return baseAchievements.slice(0, 3 + (chapterNumber % 3)).map((ach, index) => ({
    id: `${chapterId}_${ach.name.toUpperCase().replace(/\s+/g, '_')}`,
    achievementId: stringToBytes32(`${chapterId}_${ach.name.toUpperCase().replace(/\s+/g, '_')}`),
    name: ach.name,
    description: ach.description,
    prerequisites: index > 0
      ? [`${chapterId}_${baseAchievements[index - 1].name.toUpperCase().replace(/\s+/g, '_')}`]
      : [],
    position: getAchievementPosition(index, 3 + (chapterNumber % 3)),
    isClaimed: false,
    canClaim: index === 0,
    week: index + 1,
  }));
}

/**
 * Hook to get all claimed chapter achievements for a wallet
 */
export function useClaimedChapterAchievements() {
  const { address } = useAccount();
  const chainId = useChainId();

  return useQuery({
    queryKey: ['claimedChapterAchievements', address, chainId],
    queryFn: async (): Promise<string[]> => {
      if (!address) return [];

      // In production, this would query:
      // 1. ChapterAchievementNFT.hasAchievement(address, achievementId)
      // 2. Or fetch from a subgraph indexing achievement mints
      return [];
    },
    enabled: !!address,
    staleTime: 30 * 1000,
  });
}
