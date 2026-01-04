'use client';

import { useQuery } from '@tanstack/react-query';
import { useAccount } from 'wagmi';
import {
  getAllTracks,
  TRACK_IDS,
  TRACK_METADATA,
  calculateTrackProgress,
  isTrackGraduated,
  type Track,
  type TrackId,
  type TrackProgress,
} from '@/lib/education';

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

export interface TrackWithProgress {
  track: Track;
  metadata: (typeof TRACK_METADATA)[TrackId];
  completedLessons: string[];
  progressPercent: number;
  graduated: boolean;
}

/**
 * Hook to fetch all tracks with their progress for the connected wallet
 */
export function useTracks() {
  const { address } = useAccount();

  return useQuery({
    queryKey: ['tracks', address],
    queryFn: async (): Promise<TrackWithProgress[]> => {
      const tracks = await getAllTracks();
      const storedProgress = address ? getStoredTrackProgress(address) : {} as Record<TrackId, string[]>;

      return tracks.map((track) => {
        const trackId = track.id as TrackId;
        const completedLessons = storedProgress[trackId] || [];
        const metadata = TRACK_METADATA[trackId];

        return {
          track,
          metadata,
          completedLessons,
          progressPercent: calculateTrackProgress(track, completedLessons),
          graduated: isTrackGraduated(track, completedLessons),
        };
      });
    },
    enabled: true,
    staleTime: 30 * 1000,
  });
}

/**
 * Hook to get a specific track by ID with progress
 */
export function useTrack(trackId: TrackId | undefined) {
  const { data: tracks, isLoading, error, refetch } = useTracks();

  const trackWithProgress = tracks?.find((t) => t.track.id === trackId);

  return {
    data: trackWithProgress,
    isLoading,
    error,
    refetch,
  };
}

/**
 * Hook to get overall track completion stats
 */
export function useTrackStats() {
  const { data: tracks, isLoading, error } = useTracks();

  if (!tracks) {
    return {
      data: undefined,
      isLoading,
      error,
    };
  }

  const totalTracks = tracks.length;
  const graduatedTracks = tracks.filter((t) => t.graduated).length;
  const totalLessons = tracks.reduce((sum, t) => sum + t.track.lessons.length, 0);
  const completedLessons = tracks.reduce((sum, t) => sum + t.completedLessons.length, 0);
  const overallProgress = totalLessons > 0 ? Math.round((completedLessons / totalLessons) * 100) : 0;

  return {
    data: {
      totalTracks,
      graduatedTracks,
      totalLessons,
      completedLessons,
      overallProgress,
    },
    isLoading,
    error,
  };
}
