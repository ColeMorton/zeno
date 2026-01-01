'use client';

import { useQuery } from '@tanstack/react-query';
import { useAccount, useChainId, usePublicClient } from 'wagmi';
import { getContractAddresses, ERC721_ABI } from '@/lib/contracts';

export interface TreasureNft {
  tokenId: bigint;
  contract: `0x${string}`;
}

/**
 * Hook to fetch TreasureNFTs owned by the connected wallet
 * TreasureNFTs are locked inside vaults when minting
 */
export function useTreasureNfts() {
  const { address } = useAccount();
  const chainId = useChainId();
  const publicClient = usePublicClient();

  return useQuery({
    queryKey: ['treasureNfts', address, chainId],
    queryFn: async (): Promise<TreasureNft[]> => {
      if (!address) throw new Error('Wallet not connected');
      if (!publicClient) throw new Error('Public client not available');

      const contracts = getContractAddresses(chainId);
      const treasureAddress = contracts.treasureNFT;

      const balance = await publicClient.readContract({
        address: treasureAddress,
        abi: ERC721_ABI,
        functionName: 'balanceOf',
        args: [address],
      });

      const nfts: TreasureNft[] = [];
      for (let i = 0n; i < balance; i++) {
        const tokenId = await publicClient.readContract({
          address: treasureAddress,
          abi: ERC721_ABI,
          functionName: 'tokenOfOwnerByIndex',
          args: [address, i],
        });
        nfts.push({ tokenId, contract: treasureAddress });
      }

      return nfts;
    },
    enabled: !!address && !!publicClient,
    staleTime: 30 * 1000,
  });
}
