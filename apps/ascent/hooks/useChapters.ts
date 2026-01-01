'use client';

import { useQuery } from '@tanstack/react-query';
import { useChainId } from 'wagmi';
import {
  CHAPTERS,
  getCurrentQuarter,
  getChapterVersionId,
  getQuarterStart,
  getQuarterEnd,
  type ChapterConfig,
  type ChapterState,
  type ChapterStatus,
} from '@/lib/chapters';

export interface ChapterVersion {
  chapterId: string;
  chapter: ChapterConfig;
  year: number;
  quarter: number;
  windowStart: number;
  windowEnd: number;
  isActive: boolean;
  isWithinWindow: boolean;
}

/**
 * Hook to fetch all chapter configurations and their current status
 * Determines which chapters are active, locked, or completed based on current time
 */
export function useChapters() {
  const chainId = useChainId();

  return useQuery({
    queryKey: ['chapters', chainId],
    queryFn: async (): Promise<ChapterVersion[]> => {
      const { year, quarter } = getCurrentQuarter();
      const now = Math.floor(Date.now() / 1000);

      // Generate chapter versions for the current quarter
      return CHAPTERS.map((chapter) => {
        const chapterId = getChapterVersionId(chapter.number, year, quarter);
        const windowStart = getQuarterStart(year, quarter);
        const windowEnd = getQuarterEnd(year, quarter);
        const isWithinWindow = now >= windowStart && now <= windowEnd;

        return {
          chapterId,
          chapter,
          year,
          quarter,
          windowStart,
          windowEnd,
          isActive: true, // All chapters are active during their quarter
          isWithinWindow,
        };
      });
    },
    staleTime: 60 * 1000,
    structuralSharing: (oldData, newData) => {
      if (!oldData || !newData) return newData;
      return JSON.stringify(oldData) === JSON.stringify(newData) ? oldData : newData;
    },
  });
}

/**
 * Hook to get a specific chapter by its version ID
 */
export function useChapter(chapterId: string | undefined) {
  const { data: chapters, isLoading, error } = useChapters();

  const chapter = chapters?.find((ch) => ch.chapterId === chapterId);

  return {
    data: chapter,
    isLoading,
    error,
  };
}

/**
 * Hook to get the current active chapter for a given days held
 */
export function useActiveChapter(daysHeld: number | undefined) {
  const { data: chapters, isLoading, error } = useChapters();

  if (!chapters || daysHeld === undefined) {
    return { data: undefined, isLoading, error };
  }

  // Find the chapter that matches the holder's journey progress
  const activeChapter = chapters.find(
    (ch) =>
      daysHeld >= ch.chapter.minDaysHeld && daysHeld <= ch.chapter.maxDaysHeld
  );

  return {
    data: activeChapter,
    isLoading,
    error,
  };
}
