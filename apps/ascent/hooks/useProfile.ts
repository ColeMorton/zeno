'use client';

import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useAccount, useChainId, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { getContractAddresses, PROFILE_REGISTRY_ABI } from '@/lib/contracts';

/**
 * Hook to check and manage on-chain profile for TRAILHEAD achievement
 */
export function useProfile() {
  const { address } = useAccount();
  const chainId = useChainId();
  const queryClient = useQueryClient();

  let profileRegistry: `0x${string}` | undefined;
  try {
    const contracts = getContractAddresses(chainId);
    profileRegistry = contracts.profileRegistry;
  } catch {
    // Chain not configured
  }

  const { data: hasProfile, isLoading: isCheckingProfile } = useReadContract({
    address: profileRegistry,
    abi: PROFILE_REGISTRY_ABI,
    functionName: 'hasProfile',
    args: address ? [address] : undefined,
    query: { enabled: !!address && !!profileRegistry },
  });

  const { data: registeredAt } = useReadContract({
    address: profileRegistry,
    abi: PROFILE_REGISTRY_ABI,
    functionName: 'registeredAt',
    args: address ? [address] : undefined,
    query: { enabled: !!address && !!profileRegistry },
  });

  const { data: daysRegistered } = useReadContract({
    address: profileRegistry,
    abi: PROFILE_REGISTRY_ABI,
    functionName: 'getDaysRegistered',
    args: address ? [address] : undefined,
    query: { enabled: !!address && !!profileRegistry },
  });

  const { writeContract, data: hash, isPending: isCreating } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const createProfile = async () => {
    if (!profileRegistry) {
      throw new Error('ProfileRegistry contract not configured');
    }

    writeContract({
      address: profileRegistry,
      abi: PROFILE_REGISTRY_ABI,
      functionName: 'createProfile',
    });
  };

  // Invalidate queries on success
  if (isSuccess) {
    queryClient.invalidateQueries({ queryKey: ['profile'] });
    queryClient.invalidateQueries({ queryKey: ['achievementStatus'] });
  }

  return {
    hasProfile: hasProfile as boolean | undefined,
    registeredAt: registeredAt as bigint | undefined,
    daysRegistered: daysRegistered ? Number(daysRegistered) : undefined,
    isCheckingProfile,
    createProfile,
    isCreating,
    isConfirming,
    isSuccess,
    hash,
    isConfigured: !!profileRegistry,
  };
}
