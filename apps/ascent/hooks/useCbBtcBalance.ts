'use client';

import { useQuery } from '@tanstack/react-query';
import { useAccount, useChainId, usePublicClient } from 'wagmi';
import { formatUnits } from 'viem';
import { getContractAddresses, ERC20_ABI } from '@/lib/contracts';

export function useCbBtcBalance() {
  const { address } = useAccount();
  const chainId = useChainId();
  const publicClient = usePublicClient();

  return useQuery({
    queryKey: ['cbBtcBalance', address, chainId],
    queryFn: async () => {
      if (!address) throw new Error('Wallet not connected');
      if (!publicClient) throw new Error('Public client not available');

      const contracts = getContractAddresses(chainId);

      const balance = await publicClient.readContract({
        address: contracts.cbBTC,
        abi: ERC20_ABI,
        functionName: 'balanceOf',
        args: [address],
      });

      return {
        raw: balance,
        formatted: formatUnits(balance, 8),
      };
    },
    enabled: !!address && !!publicClient,
    staleTime: 30 * 1000,
  });
}
