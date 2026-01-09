import { type TrackId } from '@/lib/education';

const TRACK_PROGRESS_KEY = 'track_progress';

/**
 * Get track progress from localStorage
 */
export function getStoredTrackProgress(address: string): Record<TrackId, string[]> {
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
export function saveTrackProgress(address: string, progress: Record<TrackId, string[]>): void {
  if (typeof window === 'undefined') return;

  try {
    localStorage.setItem(`${TRACK_PROGRESS_KEY}_${address}`, JSON.stringify(progress));
  } catch {
    // Ignore storage errors
  }
}
