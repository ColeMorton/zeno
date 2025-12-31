'use client';

import {
  useChainId,
  useWriteContract,
  useWaitForTransactionReceipt,
} from 'wagmi';
import { getContractAddresses, VAULT_NFT_ABI } from '@/lib/contracts';

interface MintParams {
  achievementContract: `0x${string}`;
  achievementTokenId: bigint;
  collateralAmount: bigint;
}

export function useVaultMint() {
  const chainId = useChainId();
  const contracts = getContractAddresses(chainId);

  const {
    writeContract,
    data: txHash,
    isPending: isWritePending,
    error: writeError,
    reset,
  } = useWriteContract();

  const {
    isLoading: isConfirming,
    isSuccess,
    data: receipt,
  } = useWaitForTransactionReceipt({
    hash: txHash,
  });

  const mint = (params: MintParams) => {
    writeContract({
      address: contracts.vaultNFT,
      abi: VAULT_NFT_ABI,
      functionName: 'mint',
      args: [
        params.achievementContract,
        params.achievementTokenId,
        contracts.cbBTC,
        params.collateralAmount,
      ],
      // Skip gas estimation on localhost - MetaMask has issues with eth_estimateGas on local networks
      ...(chainId === 31337 && { gas: 500_000n }),
    });
  };

  return {
    mint,
    isPending: isWritePending || isConfirming,
    isSuccess,
    txHash,
    receipt,
    error: writeError,
    reset,
  };
}
