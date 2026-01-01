'use client';

import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useChainId, usePublicClient } from 'wagmi';
import { ANVIL_CHAIN_ID } from '@/lib/wagmi';

/**
 * Hook to get current blockchain timestamp.
 * On Anvil, polls every 5 seconds to catch time skips.
 * On mainnet, uses Date.now() (no polling needed).
 */
export function useChainTime() {
  const chainId = useChainId();
  const publicClient = usePublicClient();
  const queryClient = useQueryClient();
  const isAnvil = chainId === ANVIL_CHAIN_ID;

  const { data: chainTime, isLoading } = useQuery({
    queryKey: ['chainTime', chainId],
    queryFn: async () => {
      if (!publicClient) {
        return Math.floor(Date.now() / 1000);
      }
      const block = await publicClient.getBlock({ blockTag: 'latest' });
      return Number(block.timestamp);
    },
    enabled: !!publicClient,
    refetchInterval: isAnvil ? 10000 : false,
    staleTime: isAnvil ? 10000 : 60000,
  });

  const refresh = () => {
    queryClient.invalidateQueries({ queryKey: ['chainTime', chainId] });
  };

  return {
    chainTime: chainTime ?? Math.floor(Date.now() / 1000),
    isLoading,
    refresh,
    isAnvil,
  };
}
