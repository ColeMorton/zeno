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
import { getContractAddresses, ERC721_ABI } from '@/lib/contracts';

export function useTreasureApproval() {
  const { address } = useAccount();
  const chainId = useChainId();
  const publicClient = usePublicClient();
  const queryClient = useQueryClient();

  const contracts = getContractAddresses(chainId);

  const approvalQuery = useQuery({
    queryKey: ['treasureApproval', address, chainId],
    queryFn: async () => {
      if (!address) throw new Error('Wallet not connected');
      if (!publicClient) throw new Error('Public client not available');

      const isApproved = await publicClient.readContract({
        address: contracts.treasureNFT,
        abi: ERC721_ABI,
        functionName: 'isApprovedForAll',
        args: [address, contracts.vaultNFT],
      });

      return isApproved;
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
        queryKey: ['treasureApproval', address, chainId],
      });
    }
  }, [isSuccess, queryClient, address, chainId]);

  const approve = () => {
    writeContract({
      address: contracts.treasureNFT,
      abi: ERC721_ABI,
      functionName: 'setApprovalForAll',
      args: [contracts.vaultNFT, true],
      // Skip gas estimation on localhost - MetaMask has issues with eth_estimateGas on local networks
      ...(chainId === 31337 && { gas: 100_000n }),
    });
  };

  return {
    isApproved: approvalQuery.data === true,
    approve,
    isPending: isWritePending || isConfirming,
    isSuccess,
    error: writeError,
  };
}
