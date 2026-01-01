'use client';

import { type ChapterEligibility } from '@/hooks/useChapterEligibility';
import { CHAPTER_COLORS } from '@/lib/chapters';

interface ChapterProgressProps {
  eligibility: ChapterEligibility;
  showDetails?: boolean;
}

export function ChapterProgress({
  eligibility,
  showDetails = true,
}: ChapterProgressProps) {
  const { chapter, status, daysHeld, progress } = eligibility;
  const { chapter: config } = chapter;
  const colors = CHAPTER_COLORS[config.number] ?? CHAPTER_COLORS[1];

  const isActive = status === 'active';
  const daysInChapter = Math.max(0, daysHeld - config.minDaysHeld);
  const daysRemaining = Math.max(0, config.maxDaysHeld - daysHeld);

  return (
    <div className="bg-gray-800/50 rounded-xl p-6 border border-gray-700">
      {/* Header */}
      <div className="flex items-center justify-between mb-4">
        <div>
          <h3 className="text-lg font-semibold text-white">
            Chapter {config.number}: {config.theme}
          </h3>
          <p className="text-sm text-gray-400">{config.description}</p>
        </div>
        {isActive && (
          <span className="px-3 py-1 bg-green-500 text-black text-sm font-semibold rounded">
            Active
          </span>
        )}
      </div>

      {/* Progress visualization */}
      <div className="mb-4">
        <div className="flex justify-between text-sm text-gray-400 mb-2">
          <span>Day {config.minDaysHeld}</span>
          <span className="font-medium text-white">Day {daysHeld}</span>
          <span>Day {config.maxDaysHeld}</span>
        </div>
        <div className="relative h-4 bg-gray-700 rounded-full overflow-hidden">
          <div
            className="h-full rounded-full transition-all duration-500"
            style={{
              width: `${progress}%`,
              backgroundColor: colors.primary,
            }}
          />
          {/* Current position marker */}
          {progress > 0 && progress < 100 && (
            <div
              className="absolute top-0 w-1 h-full bg-white shadow-lg"
              style={{ left: `${progress}%`, transform: 'translateX(-50%)' }}
            />
          )}
        </div>
      </div>

      {/* Stats */}
      {showDetails && (
        <div className="grid grid-cols-3 gap-4 text-center">
          <div>
            <div className="text-2xl font-bold text-white">{daysInChapter}</div>
            <div className="text-xs text-gray-500">Days in Chapter</div>
          </div>
          <div>
            <div className="text-2xl font-bold text-white">{progress}%</div>
            <div className="text-xs text-gray-500">Progress</div>
          </div>
          <div>
            <div className="text-2xl font-bold text-white">{daysRemaining}</div>
            <div className="text-xs text-gray-500">Days Remaining</div>
          </div>
        </div>
      )}
    </div>
  );
}

export function ChapterProgressSkeleton() {
  return (
    <div className="bg-gray-800/50 rounded-xl p-6 border border-gray-700 animate-pulse">
      <div className="flex items-center justify-between mb-4">
        <div>
          <div className="h-6 w-48 bg-gray-700 rounded mb-2" />
          <div className="h-4 w-64 bg-gray-700 rounded" />
        </div>
        <div className="h-8 w-16 bg-gray-700 rounded" />
      </div>
      <div className="mb-4">
        <div className="flex justify-between mb-2">
          <div className="h-4 w-12 bg-gray-700 rounded" />
          <div className="h-4 w-16 bg-gray-700 rounded" />
          <div className="h-4 w-12 bg-gray-700 rounded" />
        </div>
        <div className="h-4 bg-gray-700 rounded-full" />
      </div>
      <div className="grid grid-cols-3 gap-4">
        {[1, 2, 3].map((i) => (
          <div key={i} className="text-center">
            <div className="h-8 w-12 bg-gray-700 rounded mx-auto mb-1" />
            <div className="h-3 w-16 bg-gray-700 rounded mx-auto" />
          </div>
        ))}
      </div>
    </div>
  );
}
