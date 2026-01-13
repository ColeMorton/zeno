'use client';

import { useReadContract, useChainId, useAccount } from 'wagmi';
import { formatUnits, type Address } from 'viem';
import { ERC20_ABI, getContracts, requireAddress } from '@/lib/contracts';

const VBTC_DECIMALS = 8;
const REFRESH_INTERVAL = 10_000;

interface VBTCBalanceData {
  /** Raw balance in wei */
  balance: bigint | undefined;
  /** Formatted balance as string */
  balanceFormatted: string | undefined;
  /** Loading state */
  isLoading: boolean;
  /** Error state */
  error: Error | null;
  /** Refetch function */
  refetch: () => void;
}

export function useVBTCBalance(): VBTCBalanceData {
  const chainId = useChainId();
  const { address: userAddress } = useAccount();

  let vBTC: Address;
  try {
    const contracts = getContracts(chainId);
    vBTC = requireAddress(contracts.vBTC, 'vBTC');
  } catch (err) {
    return {
      balance: undefined,
      balanceFormatted: undefined,
      isLoading: false,
      error: err instanceof Error ? err : new Error('vBTC not configured'),
      refetch: () => {},
    };
  }

  const { data, isLoading, error, refetch } = useReadContract({
    address: vBTC,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: [userAddress ?? '0x0000000000000000000000000000000000000000'],
    query: {
      refetchInterval: REFRESH_INTERVAL,
      enabled: !!userAddress,
    },
  });

  const balance = data as bigint | undefined;
  const balanceFormatted = balance !== undefined
    ? formatUnits(balance, VBTC_DECIMALS)
    : undefined;

  return {
    balance,
    balanceFormatted,
    isLoading,
    error: error ?? null,
    refetch,
  };
}
