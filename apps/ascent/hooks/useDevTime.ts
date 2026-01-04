'use client';

import { useState, useCallback } from 'react';
import { usePublicClient, useChainId } from 'wagmi';
import { useQueryClient } from '@tanstack/react-query';
import { ANVIL_CHAIN_ID } from '@/lib/wagmi';

const SECONDS_PER_DAY = 86400;

/**
 * Hook for advancing time on local Anvil chain.
 * Only functional when connected to Anvil (chain ID 31337).
 */
export function useDevTime() {
  const chainId = useChainId();
  const publicClient = usePublicClient();
  const queryClient = useQueryClient();
  const [isAdvancing, setIsAdvancing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const isAnvil = chainId === ANVIL_CHAIN_ID;

  const advanceTime = useCallback(
    async (days: number) => {
      if (!isAnvil) {
        setError('Time advancement only available on Anvil');
        return;
      }

      if (!publicClient) {
        setError('No public client available');
        return;
      }

      setIsAdvancing(true);
      setError(null);

      try {
        const seconds = days * SECONDS_PER_DAY;

        // Advance time using Anvil-specific RPC methods
        await (publicClient as any).request({
          method: 'evm_increaseTime',
          params: [seconds],
        });

        // Mine a block to apply the time change
        await (publicClient as any).request({
          method: 'evm_mine',
          params: [],
        });

        // Invalidate all time-dependent queries
        await queryClient.invalidateQueries({ queryKey: ['chainTime'] });
        await queryClient.invalidateQueries({ queryKey: ['vaults'] });
        await queryClient.invalidateQueries({ queryKey: ['vault'] });
        await queryClient.invalidateQueries({ queryKey: ['vaultRanking'] });
        await queryClient.invalidateQueries({ queryKey: ['chapterAchievements'] });
        await queryClient.invalidateQueries({ queryKey: ['chapterEligibility'] });
        await queryClient.invalidateQueries({ queryKey: ['achievementStatus'] });
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Failed to advance time';
        setError(message);
        throw err;
      } finally {
        setIsAdvancing(false);
      }
    },
    [isAnvil, publicClient, queryClient]
  );

  return {
    advanceTime,
    isAdvancing,
    error,
    isAnvil,
  };
}
