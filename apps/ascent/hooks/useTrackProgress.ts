'use client';

import { useCallback } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useAccount } from 'wagmi';
import { type TrackId } from '@/lib/education';

const TRACK_PROGRESS_KEY = 'track_progress';

/**
 * Get track progress from localStorage
 */
function getStoredTrackProgress(address: string): Record<TrackId, string[]> {
  if (typeof window === 'undefined') return {} as Record<TrackId, string[]>;

  try {
    const stored = localStorage.getItem(`${TRACK_PROGRESS_KEY}_${address}`);
    if (stored) {
      return JSON.parse(stored);
    }
  } catch {
    // Ignore parse errors
  }

  return {} as Record<TrackId, string[]>;
}

/**
 * Save track progress to localStorage
 */
function saveTrackProgress(address: string, progress: Record<TrackId, string[]>): void {
  if (typeof window === 'undefined') return;

  try {
    localStorage.setItem(`${TRACK_PROGRESS_KEY}_${address}`, JSON.stringify(progress));
  } catch {
    // Ignore storage errors
  }
}

interface CompleteLesonParams {
  trackId: TrackId;
  lessonId: string;
}

/**
 * Hook to mark a lesson as completed
 */
export function useCompleteLesson() {
  const { address } = useAccount();
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: async ({ trackId, lessonId }: CompleteLesonParams) => {
      if (!address) {
        throw new Error('Wallet not connected');
      }

      const progress = getStoredTrackProgress(address);
      const trackProgress = progress[trackId] || [];

      // Don't add if already completed
      if (trackProgress.includes(lessonId)) {
        return { trackId, lessonId, alreadyCompleted: true };
      }

      // Add lesson to completed list
      progress[trackId] = [...trackProgress, lessonId];
      saveTrackProgress(address, progress);

      return { trackId, lessonId, alreadyCompleted: false };
    },
    onSuccess: () => {
      // Invalidate tracks query to refetch with new progress
      queryClient.invalidateQueries({ queryKey: ['tracks', address] });
    },
  });

  const completeLesson = useCallback(
    (trackId: TrackId, lessonId: string) => {
      return mutation.mutateAsync({ trackId, lessonId });
    },
    [mutation]
  );

  return {
    completeLesson,
    isLoading: mutation.isPending,
    error: mutation.error,
  };
}

/**
 * Hook to reset progress for a specific track
 */
export function useResetTrackProgress() {
  const { address } = useAccount();
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: async (trackId: TrackId) => {
      if (!address) {
        throw new Error('Wallet not connected');
      }

      const progress = getStoredTrackProgress(address);
      delete progress[trackId];
      saveTrackProgress(address, progress);

      return { trackId };
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tracks', address] });
    },
  });

  const resetProgress = useCallback(
    (trackId: TrackId) => {
      return mutation.mutateAsync(trackId);
    },
    [mutation]
  );

  return {
    resetProgress,
    isLoading: mutation.isPending,
    error: mutation.error,
  };
}

/**
 * Hook to check if a specific lesson is completed
 */
export function useLessonStatus(trackId: TrackId, lessonId: string) {
  const { address } = useAccount();

  if (!address) {
    return { isCompleted: false };
  }

  const progress = getStoredTrackProgress(address);
  const trackProgress = progress[trackId] || [];

  return {
    isCompleted: trackProgress.includes(lessonId),
  };
}
