'use client';

import { useQuery } from '@tanstack/react-query';
import { useAccount, useChainId, usePublicClient } from 'wagmi';
import { getContractAddresses, ERC721_ABI } from '@/lib/contracts';

export interface AchievementNft {
  tokenId: bigint;
  contract: `0x${string}`;
}

export function useAchievementNfts() {
  const { address } = useAccount();
  const chainId = useChainId();
  const publicClient = usePublicClient();

  return useQuery({
    queryKey: ['achievementNfts', address, chainId],
    queryFn: async (): Promise<AchievementNft[]> => {
      if (!address) throw new Error('Wallet not connected');
      if (!publicClient) throw new Error('Public client not available');

      const contracts = getContractAddresses(chainId);
      const achievementAddress = contracts.achievementNFT;

      const balance = await publicClient.readContract({
        address: achievementAddress,
        abi: ERC721_ABI,
        functionName: 'balanceOf',
        args: [address],
      });

      const nfts: AchievementNft[] = [];
      for (let i = 0n; i < balance; i++) {
        const tokenId = await publicClient.readContract({
          address: achievementAddress,
          abi: ERC721_ABI,
          functionName: 'tokenOfOwnerByIndex',
          args: [address, i],
        });
        nfts.push({ tokenId, contract: achievementAddress });
      }

      return nfts;
    },
    enabled: !!address && !!publicClient,
    staleTime: 30 * 1000,
  });
}
