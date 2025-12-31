'use client';

import { useEffect } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import {
  useAccount,
  useChainId,
  usePublicClient,
  useWriteContract,
  useWaitForTransactionReceipt,
} from 'wagmi';
import { getContractAddresses, ERC20_ABI } from '@/lib/contracts';

export function useCbBtcApproval(amount: bigint) {
  const { address } = useAccount();
  const chainId = useChainId();
  const publicClient = usePublicClient();
  const queryClient = useQueryClient();

  const contracts = getContractAddresses(chainId);

  const allowanceQuery = useQuery({
    queryKey: ['cbBtcAllowance', address, chainId],
    queryFn: async () => {
      if (!address) throw new Error('Wallet not connected');
      if (!publicClient) throw new Error('Public client not available');

      const allowance = await publicClient.readContract({
        address: contracts.cbBTC,
        abi: ERC20_ABI,
        functionName: 'allowance',
        args: [address, contracts.vaultNFT],
      });

      return allowance;
    },
    enabled: !!address && !!publicClient,
  });

  const {
    writeContract,
    data: txHash,
    isPending: isWritePending,
    error: writeError,
  } = useWriteContract();

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash: txHash,
  });

  useEffect(() => {
    if (isSuccess) {
      queryClient.invalidateQueries({
        queryKey: ['cbBtcAllowance', address, chainId],
      });
    }
  }, [isSuccess, queryClient, address, chainId]);

  const approve = () => {
    writeContract({
      address: contracts.cbBTC,
      abi: ERC20_ABI,
      functionName: 'approve',
      args: [contracts.vaultNFT, amount],
      // Skip gas estimation on localhost - MetaMask has issues with eth_estimateGas on local networks
      ...(chainId === 31337 && { gas: 100_000n }),
    });
  };

  const isApproved =
    allowanceQuery.data !== undefined && allowanceQuery.data >= amount;

  return {
    allowance: allowanceQuery.data,
    isApproved,
    approve,
    isPending: isWritePending || isConfirming,
    isSuccess,
    error: writeError,
  };
}
