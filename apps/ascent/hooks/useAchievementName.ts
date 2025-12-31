'use client';

import { useQuery } from '@tanstack/react-query';
import { usePublicClient } from 'wagmi';
import type { Address } from 'viem';

interface AchievementMetadata {
  name: string;
  description?: string;
  image?: string;
}

const ERC721_METADATA_ABI = [
  {
    name: 'tokenURI',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'tokenId', type: 'uint256' }],
    outputs: [{ type: 'string' }],
  },
] as const;

function parseTokenURI(uri: string): AchievementMetadata {
  if (uri.startsWith('data:application/json;base64,')) {
    const base64Data = uri.replace('data:application/json;base64,', '');
    const json = atob(base64Data);
    return JSON.parse(json);
  }

  throw new Error(`Unsupported token URI format: ${uri.slice(0, 50)}`);
}

export function useAchievementName(
  achievementContract: Address | undefined,
  achievementTokenId: bigint | undefined
) {
  const publicClient = usePublicClient();

  return useQuery({
    queryKey: ['achievementName', achievementContract, achievementTokenId?.toString()],
    queryFn: async (): Promise<string> => {
      if (!achievementContract || achievementTokenId === undefined || !publicClient) {
        throw new Error('Missing achievement contract, token ID, or public client');
      }

      const tokenURI = await publicClient.readContract({
        address: achievementContract,
        abi: ERC721_METADATA_ABI,
        functionName: 'tokenURI',
        args: [achievementTokenId],
      });

      const metadata = parseTokenURI(tokenURI);
      return metadata.name;
    },
    enabled: !!achievementContract && achievementTokenId !== undefined && !!publicClient,
    staleTime: Infinity,
  });
}
