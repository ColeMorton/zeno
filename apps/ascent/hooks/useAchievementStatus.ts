'use client';

import { useQuery } from '@tanstack/react-query';
import { useAccount, useChainId } from 'wagmi';
import { useVaults } from './useVaults';
import { useChainTime } from './useChainTime';
import { ALTITUDE_ZONES, ZONES_ORDERED, type ZoneName } from '@/lib/altitude';

export type AchievementStatus = 'locked' | 'available' | 'minted';

export interface AchievementState {
  id: string;
  status: AchievementStatus;
  chapterStart: number;
  chapterEnd: number | undefined;
  daysHeld: number;
}

// Chapter achievement definitions - each can ONLY be minted during its chapter window
const CHAPTER_ACHIEVEMENTS = ZONES_ORDERED.map((zone, index) => {
  const zoneData = ALTITUDE_ZONES[zone];
  const nextZone = ZONES_ORDERED[index + 1];
  const endDay = nextZone ? ALTITUDE_ZONES[nextZone].days - 1 : undefined;

  return {
    id: zone,
    chapterStart: zoneData.days,
    chapterEnd: endDay,
  };
});

function isInChapter(daysHeld: number, chapterStart: number, chapterEnd: number | undefined): boolean {
  if (chapterEnd === undefined) {
    // Summit chapter - no end
    return daysHeld >= chapterStart;
  }
  return daysHeld >= chapterStart && daysHeld <= chapterEnd;
}

export function useAchievementStatus() {
  const { address } = useAccount();
  const chainId = useChainId();
  const { data: vaults, isLoading: vaultsLoading } = useVaults();
  const { chainTime } = useChainTime();

  return useQuery({
    queryKey: ['achievementStatus', address, chainId, vaults?.length],
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

      for (const achievement of CHAPTER_ACHIEVEMENTS) {
        let status: AchievementStatus;

        if (!hasVault) {
          // No vault = all achievements locked
          status = 'locked';
        } else if (isInChapter(maxDaysHeld, achievement.chapterStart, achievement.chapterEnd)) {
          // User is currently IN this chapter = available to mint
          // Note: In a full implementation, we'd check if already minted on-chain
          status = 'available';
        } else {
          // User is not in this chapter (either before or after) = locked
          status = 'locked';
        }

        results[achievement.id] = {
          id: achievement.id,
          status,
          chapterStart: achievement.chapterStart,
          chapterEnd: achievement.chapterEnd,
          daysHeld: maxDaysHeld,
        };
      }

      return results;
    },
    enabled: !!address && !vaultsLoading,
    staleTime: 30 * 1000,
    structuralSharing: (oldData, newData) => {
      if (!oldData || !newData) return newData;
      return JSON.stringify(oldData) === JSON.stringify(newData) ? oldData : newData;
    },
  });
}
