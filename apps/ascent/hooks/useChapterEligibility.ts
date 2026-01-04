'use client';

import { useQuery } from '@tanstack/react-query';
import { useAccount, useChainId } from 'wagmi';
import { useVaults } from './useVaults';
import { useChainTime } from './useChainTime';
import { useChapters, type ChapterVersion } from './useChapters';
import {
  CHAPTERS,
  getChapterProgress,
  type ChapterConfig,
  type ChapterStatus,
} from '@/lib/chapters';

export interface ChapterEligibility {
  chapter: ChapterVersion;
  status: ChapterStatus;
  daysHeld: number;
  progress: number; // 0-100
  canParticipate: boolean;
  reason: string | null;
}

/**
 * Hook to determine chapter eligibility for the connected wallet
 * Combines journey progress (days held) with calendar window status
 */
export function useChapterEligibility() {
  const { address } = useAccount();
  const chainId = useChainId();
  const { data: vaults, isLoading: vaultsLoading } = useVaults();
  const { data: chapters, isLoading: chaptersLoading } = useChapters();
  const { chainTime } = useChainTime();

  return useQuery({
    queryKey: ['chapterEligibility', address, chainId, vaults?.length, chainTime],
    queryFn: async (): Promise<ChapterEligibility[]> => {
      if (!address || !chapters) {
        throw new Error('Data not available');
      }

      const now = chainTime ?? Math.floor(Date.now() / 1000);

      // Calculate max days held across all vaults
      let maxDaysHeld = 0;
      if (vaults && vaults.length > 0) {
        for (const vault of vaults) {
          const daysHeld = Math.floor((now - Number(vault.mintTimestamp)) / 86400);
          maxDaysHeld = Math.max(maxDaysHeld, daysHeld);
        }
      }

      const hasVault = vaults && vaults.length > 0;

      return chapters.map((chapterVersion) => {
        const { chapter, windowStart, windowEnd } = chapterVersion;
        const isWithinWindow = now >= windowStart && now <= windowEnd;
        const isWithinJourneyRange =
          maxDaysHeld >= chapter.minDaysHeld && maxDaysHeld <= chapter.maxDaysHeld;

        let status: ChapterStatus;
        let canParticipate = false;
        let reason: string | null = null;

        if (!hasVault) {
          status = 'locked';
          reason = 'No vault owned';
        } else if (!isWithinWindow) {
          if (now < windowStart) {
            status = 'locked';
            reason = 'Chapter window not open yet';
          } else {
            status = 'missed';
            reason = 'Chapter window has closed';
          }
        } else if (maxDaysHeld < chapter.minDaysHeld) {
          status = 'locked';
          reason = `Need ${chapter.minDaysHeld - maxDaysHeld} more days held`;
        } else if (maxDaysHeld > chapter.maxDaysHeld) {
          status = 'completed';
          reason = 'Journey has progressed past this chapter';
        } else {
          status = 'active';
          canParticipate = true;
        }

        return {
          chapter: chapterVersion,
          status,
          daysHeld: maxDaysHeld,
          progress: getChapterProgress(maxDaysHeld, chapter),
          canParticipate,
          reason,
        };
      });
    },
    enabled: !!address && !vaultsLoading && !chaptersLoading && !!chapters,
    staleTime: 30 * 1000,
    structuralSharing: (oldData, newData) => {
      if (!oldData || !newData) return newData;
      return JSON.stringify(oldData) === JSON.stringify(newData) ? oldData : newData;
    },
  });
}

/**
 * Hook to get eligibility for a specific chapter
 */
export function useChapterEligibilityById(chapterId: string | undefined) {
  const { data: eligibilities, isLoading, error } = useChapterEligibility();

  const eligibility = eligibilities?.find(
    (e) => e.chapter.chapterId === chapterId
  );

  return {
    data: eligibility,
    isLoading,
    error,
  };
}

/**
 * Hook to get the currently active/participatable chapter for the user
 */
export function useCurrentChapter() {
  const { data: eligibilities, isLoading, error } = useChapterEligibility();

  const currentChapter = eligibilities?.find((e) => e.status === 'active');

  return {
    data: currentChapter,
    isLoading,
    error,
  };
}
