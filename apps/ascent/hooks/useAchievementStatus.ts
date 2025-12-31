'use client';

import { useQuery } from '@tanstack/react-query';
import { useAccount, useChainId } from 'wagmi';
import { useVaults } from './useVaults';
import { useChainTime } from './useChainTime';

export type AchievementStatus = 'locked' | 'available' | 'minted';

export interface AchievementState {
  id: string;
  status: AchievementStatus;
  daysRequired: number;
  daysHeld: number;
}

// Achievement definitions with duration requirements
const ACHIEVEMENT_DEFINITIONS = [
  { id: 'CLIMBER', daysRequired: 0 },
  { id: 'TRAIL_HEAD', daysRequired: 30 },
  { id: 'BASE_CAMP', daysRequired: 91 },
  { id: 'RIDGE_WALKER', daysRequired: 182 },
  { id: 'HIGH_CAMP', daysRequired: 365 },
  { id: 'SUMMIT_PUSH', daysRequired: 730 },
  { id: 'SUMMIT', daysRequired: 1129 },
] as const;

export function useAchievementStatus() {
  const { address } = useAccount();
  const chainId = useChainId();
  const { data: vaults, isLoading: vaultsLoading } = useVaults();
  const { chainTime } = useChainTime();

  return useQuery({
    queryKey: ['achievementStatus', address, chainId, vaults?.length, chainTime],
    queryFn: async (): Promise<Record<string, AchievementState>> => {
      if (!address) {
        throw new Error('Wallet not connected');
      }

      const results: Record<string, AchievementState> = {};

      // Calculate max days held across all vaults
      let maxDaysHeld = 0;
      const now = chainTime ?? Math.floor(Date.now() / 1000);

      if (vaults && vaults.length > 0) {
        for (const vault of vaults) {
          const daysHeld = Math.floor((now - Number(vault.mintTimestamp)) / 86400);
          maxDaysHeld = Math.max(maxDaysHeld, daysHeld);
        }
      }

      const hasVault = vaults && vaults.length > 0;

      for (const achievement of ACHIEVEMENT_DEFINITIONS) {
        let status: AchievementStatus;

        if (!hasVault) {
          // No vault = all achievements locked
          status = 'locked';
        } else if (maxDaysHeld >= achievement.daysRequired) {
          // User meets the duration requirement = available to claim
          // Note: In a full implementation, we'd check if already minted on-chain
          status = 'available';
        } else {
          // Has vault but duration not met = locked
          status = 'locked';
        }

        results[achievement.id] = {
          id: achievement.id,
          status,
          daysRequired: achievement.daysRequired,
          daysHeld: maxDaysHeld,
        };
      }

      return results;
    },
    enabled: !!address && !vaultsLoading,
    staleTime: 30 * 1000,
  });
}
