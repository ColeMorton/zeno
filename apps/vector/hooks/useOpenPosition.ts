'use client';

import { useWriteContract, useChainId, useAccount } from 'wagmi';
import { parseUnits, type Address } from 'viem';
import { PERPETUAL_VAULT_ABI, ERC20_ABI, getContracts, requireAddress } from '@/lib/contracts';
import { Side } from '@/lib/perpetual';

const VBTC_DECIMALS = 8;

interface UseOpenPositionResult {
  /** Open a new position */
  openPosition: (
    collateralAmount: string,
    leverageX100: number,
    side: Side
  ) => Promise<void>;
  /** Transaction pending state */
  isPending: boolean;
  /** Error state */
  error: Error | null;
}

export function useOpenPosition(): UseOpenPositionResult {
  const chainId = useChainId();
  const { address: userAddress } = useAccount();
  const { writeContractAsync, isPending, error } = useWriteContract();

  let perpetualVault: Address;
  let vBTC: Address;
  try {
    const contracts = getContracts(chainId);
    perpetualVault = requireAddress(contracts.perpetualVault, 'perpetualVault');
    vBTC = requireAddress(contracts.vBTC, 'vBTC');
  } catch (err) {
    return {
      openPosition: async () => {
        throw err;
      },
      isPending: false,
      error: err instanceof Error ? err : new Error('Contract not configured'),
    };
  }

  const openPosition = async (
    collateralAmount: string,
    leverageX100: number,
    side: Side
  ) => {
    if (!userAddress) throw new Error('Wallet not connected');

    const collateral = parseUnits(collateralAmount, VBTC_DECIMALS);

    // First approve vBTC spending
    await writeContractAsync({
      address: vBTC,
      abi: ERC20_ABI,
      functionName: 'approve',
      args: [perpetualVault, collateral],
    });

    // Then open position
    await writeContractAsync({
      address: perpetualVault,
      abi: PERPETUAL_VAULT_ABI,
      functionName: 'openPosition',
      args: [collateral, BigInt(leverageX100), side],
    });
  };

  return {
    openPosition,
    isPending,
    error: error ?? null,
  };
}
