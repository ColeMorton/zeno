'use client';

import { useTracks, useTrackStats } from '@/hooks/useTracks';
import { type TrackId } from '@/lib/education';

interface TrackCardProps {
  trackId: TrackId;
  name: string;
  description: string;
  icon: string;
  lessonsCount: number;
  completedLessons: number;
  progressPercent: number;
  graduated: boolean;
  onSelect: (trackId: TrackId) => void;
}

function TrackCard({
  trackId,
  name,
  description,
  icon,
  lessonsCount,
  completedLessons,
  progressPercent,
  graduated,
  onSelect,
}: TrackCardProps) {
  return (
    <button
      onClick={() => onSelect(trackId)}
      className="group relative flex flex-col gap-3 rounded-lg border border-gray-700 bg-gray-800/50 p-4 text-left transition-all hover:border-gray-600 hover:bg-gray-800"
    >
      {graduated && (
        <div className="absolute -right-2 -top-2 flex h-6 w-6 items-center justify-center rounded-full bg-green-500 text-xs">
          ✓
        </div>
      )}

      <div className="flex items-center gap-3">
        <span className="text-2xl">{icon}</span>
        <div>
          <h3 className="font-medium text-gray-100">{name}</h3>
          <p className="text-sm text-gray-400">
            {completedLessons}/{lessonsCount} lessons
          </p>
        </div>
      </div>

      <p className="text-sm text-gray-400">{description}</p>

      <div className="mt-auto">
        <div className="flex items-center justify-between text-xs text-gray-500">
          <span>{progressPercent}% complete</span>
          {graduated && <span className="text-green-400">Graduated</span>}
        </div>
        <div className="mt-1 h-1.5 w-full overflow-hidden rounded-full bg-gray-700">
          <div
            className={`h-full transition-all ${graduated ? 'bg-green-500' : 'bg-blue-500'}`}
            style={{ width: `${progressPercent}%` }}
          />
        </div>
      </div>
    </button>
  );
}

export function TrackListSkeleton() {
  return (
    <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
      {Array.from({ length: 6 }).map((_, i) => (
        <div
          key={i}
          className="flex animate-pulse flex-col gap-3 rounded-lg border border-gray-700 bg-gray-800/50 p-4"
        >
          <div className="flex items-center gap-3">
            <div className="h-8 w-8 rounded bg-gray-700" />
            <div className="flex-1">
              <div className="h-4 w-24 rounded bg-gray-700" />
              <div className="mt-1 h-3 w-16 rounded bg-gray-700" />
            </div>
          </div>
          <div className="h-3 w-full rounded bg-gray-700" />
          <div className="h-1.5 w-full rounded bg-gray-700" />
        </div>
      ))}
    </div>
  );
}

interface TrackListProps {
  onSelectTrack: (trackId: TrackId) => void;
}

export function TrackList({ onSelectTrack }: TrackListProps) {
  const { data: tracks, isLoading, error } = useTracks();
  const { data: stats } = useTrackStats();

  if (isLoading) {
    return <TrackListSkeleton />;
  }

  if (error) {
    return (
      <div className="rounded-lg border border-red-900/50 bg-red-900/20 p-4 text-red-400">
        Failed to load tracks: {error.message}
      </div>
    );
  }

  if (!tracks || tracks.length === 0) {
    return (
      <div className="rounded-lg border border-gray-700 bg-gray-800/50 p-8 text-center">
        <p className="text-gray-400">No education tracks available yet.</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {stats && (
        <div className="flex flex-wrap gap-4 rounded-lg border border-gray-700 bg-gray-800/30 p-4">
          <div className="flex-1 min-w-[120px]">
            <p className="text-2xl font-bold text-gray-100">{stats.overallProgress}%</p>
            <p className="text-sm text-gray-400">Overall Progress</p>
          </div>
          <div className="flex-1 min-w-[120px]">
            <p className="text-2xl font-bold text-gray-100">
              {stats.completedLessons}/{stats.totalLessons}
            </p>
            <p className="text-sm text-gray-400">Lessons Completed</p>
          </div>
          <div className="flex-1 min-w-[120px]">
            <p className="text-2xl font-bold text-gray-100">
              {stats.graduatedTracks}/{stats.totalTracks}
            </p>
            <p className="text-sm text-gray-400">Tracks Graduated</p>
          </div>
        </div>
      )}

      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        {tracks.map((trackWithProgress) => (
          <TrackCard
            key={trackWithProgress.track.id}
            trackId={trackWithProgress.track.id as TrackId}
            name={trackWithProgress.metadata.name}
            description={trackWithProgress.metadata.description}
            icon={trackWithProgress.metadata.icon}
            lessonsCount={trackWithProgress.track.lessons.length}
            completedLessons={trackWithProgress.completedLessons.length}
            progressPercent={trackWithProgress.progressPercent}
            graduated={trackWithProgress.graduated}
            onSelect={onSelectTrack}
          />
        ))}
      </div>
    </div>
  );
}
