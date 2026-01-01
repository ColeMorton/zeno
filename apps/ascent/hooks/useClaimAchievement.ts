'use client';

import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useAccount, useChainId, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { getContractAddresses, CHAPTER_MINTER_ABI } from '@/lib/contracts';

interface ClaimAchievementParams {
  chapterId: `0x${string}`;
  achievementId: `0x${string}`;
  vaultId: bigint;
  collateralToken: `0x${string}`;
  verificationData?: `0x${string}`;
}

export function useClaimAchievement() {
  const { address } = useAccount();
  const chainId = useChainId();
  const queryClient = useQueryClient();

  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const claim = async (params: ClaimAchievementParams) => {
    const contracts = getContractAddresses(chainId);
    if (!contracts.chapterMinter) {
      throw new Error('ChapterMinter contract not configured');
    }

    writeContract({
      address: contracts.chapterMinter,
      abi: CHAPTER_MINTER_ABI,
      functionName: 'claimChapterAchievement',
      args: [
        params.chapterId,
        params.achievementId,
        params.vaultId,
        params.collateralToken,
        params.verificationData ?? '0x',
      ],
    });
  };

  // Invalidate queries on success
  if (isSuccess) {
    queryClient.invalidateQueries({ queryKey: ['chapterAchievements'] });
    queryClient.invalidateQueries({ queryKey: ['achievementStatus'] });
    queryClient.invalidateQueries({ queryKey: ['claimedChapterAchievements'] });
  }

  return {
    claim,
    isPending,
    isConfirming,
    isSuccess,
    error,
    hash,
  };
}
