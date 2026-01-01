'use client';

import { useQuery } from '@tanstack/react-query';
import { usePublicClient } from 'wagmi';
import type { Address } from 'viem';

interface TreasureMetadata {
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

function parseTokenURI(uri: string): TreasureMetadata {
  if (uri.startsWith('data:application/json;base64,')) {
    const base64Data = uri.replace('data:application/json;base64,', '');
    const json = atob(base64Data);
    return JSON.parse(json);
  }

  throw new Error(`Unsupported token URI format: ${uri.slice(0, 50)}`);
}

/**
 * Hook to fetch the name of a TreasureNFT by parsing its tokenURI metadata
 */
export function useTreasureName(
  treasureContract: Address | undefined,
  treasureTokenId: bigint | undefined
) {
  const publicClient = usePublicClient();

  return useQuery({
    queryKey: ['treasureName', treasureContract, treasureTokenId?.toString()],
    queryFn: async (): Promise<string> => {
      if (!treasureContract || treasureTokenId === undefined || !publicClient) {
        throw new Error('Missing treasure contract, token ID, or public client');
      }

      const tokenURI = await publicClient.readContract({
        address: treasureContract,
        abi: ERC721_METADATA_ABI,
        functionName: 'tokenURI',
        args: [treasureTokenId],
      });

      const metadata = parseTokenURI(tokenURI);
      return metadata.name;
    },
    enabled: !!treasureContract && treasureTokenId !== undefined && !!publicClient,
    staleTime: Infinity,
  });
}
