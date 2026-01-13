'use client';

import { useWriteContract, useChainId, useAccount } from 'wagmi';
import { type Address } from 'viem';
import { PERPETUAL_VAULT_ABI, getContracts, requireAddress } from '@/lib/contracts';

interface UseClosePositionResult {
  /** Close an existing position */
  closePosition: (positionId: bigint) => Promise<void>;
  /** Transaction pending state */
  isPending: boolean;
  /** Error state */
  error: Error | null;
}

export function useClosePosition(): UseClosePositionResult {
  const chainId = useChainId();
  const { address: userAddress } = useAccount();
  const { writeContractAsync, isPending, error } = useWriteContract();

  let perpetualVault: Address;
  try {
    const contracts = getContracts(chainId);
    perpetualVault = requireAddress(contracts.perpetualVault, 'perpetualVault');
  } catch (err) {
    return {
      closePosition: async () => {
        throw err;
      },
      isPending: false,
      error: err instanceof Error ? err : new Error('Contract not configured'),
    };
  }

  const closePosition = async (positionId: bigint) => {
    if (!userAddress) throw new Error('Wallet not connected');

    await writeContractAsync({
      address: perpetualVault,
      abi: PERPETUAL_VAULT_ABI,
      functionName: 'closePosition',
      args: [positionId],
    });
  };

  return {
    closePosition,
    isPending,
    error: error ?? null,
  };
}
