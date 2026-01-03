'use client';

import { useCallback, useMemo } from 'react';
import {
  useChainId,
  useAccount,
  useWriteContract,
  useWaitForTransactionReceipt,
} from 'wagmi';
import { getContractAddresses, VAULT_MINT_CONTROLLER_ABI } from '@/lib/contracts';

interface MintParams {
  achievementType: `0x${string}`;
  collateralAmount: bigint;
}

export function useVaultMint() {
  const chainId = useChainId();
  const { address } = useAccount();
  const contracts = useMemo(() => getContractAddresses(chainId), [chainId]);

  const {
    writeContract,
    data: txHash,
    isPending,
    error,
    reset,
  } = useWriteContract();

  const {
    isLoading: isConfirming,
    isSuccess,
    data: receipt,
  } = useWaitForTransactionReceipt({
    hash: txHash,
  });

  const mint = useCallback(
    (params: MintParams) => {
      if (!address) {
        throw new Error('Wallet not connected');
      }

      writeContract({
        address: contracts.vaultMintController,
        abi: VAULT_MINT_CONTROLLER_ABI,
        functionName: 'mintVault',
        args: [params.achievementType, params.collateralAmount],
      });
    },
    [writeContract, contracts, address]
  );

  return {
    mint,
    isPending: isPending || isConfirming,
    isSuccess,
    txHash,
    receipt,
    error,
    reset,
  };
}
