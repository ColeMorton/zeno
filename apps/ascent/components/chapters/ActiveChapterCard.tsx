'use client';

import Link from 'next/link';
import { useCurrentChapter } from '@/hooks/useChapterEligibility';
import { ChapterCountdownCompact } from './ChapterCountdown';
import { CHAPTER_COLORS } from '@/lib/chapters';

export function ActiveChapterCard() {
  const { data: currentChapter, isLoading } = useCurrentChapter();

  if (isLoading) {
    return <ActiveChapterCardSkeleton />;
  }

  if (!currentChapter) {
    return (
      <div className="bg-gray-800/50 rounded-xl p-6 border border-gray-700">
        <h2 className="text-xl font-semibold text-white mb-4">Active Chapter</h2>
        <div className="text-center py-4">
          <p className="text-gray-400 text-sm">
            No active chapter available
          </p>
          <Link
            href="/chapters"
            className="text-green-400 hover:text-green-300 text-sm underline mt-2 inline-block"
          >
            View all chapters →
          </Link>
        </div>
      </div>
    );
  }

  const { chapter, progress, daysHeld } = currentChapter;
  const { chapter: config, chapterId, windowEnd } = chapter;
  const colors = CHAPTER_COLORS[config.number] ?? CHAPTER_COLORS[1];

  return (
    <div className="bg-gray-800/50 rounded-xl p-6 border border-gray-700">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-xl font-semibold text-white">Active Chapter</h2>
        <span className="px-2 py-1 bg-green-500 text-black text-xs font-semibold rounded">
          Active
        </span>
      </div>

      <div className="mb-4">
        <div className="flex items-baseline gap-2 mb-1">
          <span className="text-2xl font-bold text-white">
            Ch. {config.number}
          </span>
          <span className="text-gray-400">{config.theme}</span>
        </div>
        <p className="text-sm text-gray-500">{config.description}</p>
      </div>

      {/* Progress bar */}
      <div className="mb-4">
        <div className="flex justify-between text-xs text-gray-500 mb-1">
          <span>Day {config.minDaysHeld}</span>
          <span className="text-white font-medium">Day {daysHeld}</span>
          <span>Day {config.maxDaysHeld}</span>
        </div>
        <div className="h-2 bg-gray-700 rounded-full overflow-hidden">
          <div
            className="h-full rounded-full transition-all"
            style={{
              width: `${progress}%`,
              backgroundColor: colors.primary,
            }}
          />
        </div>
      </div>

      {/* Footer */}
      <div className="flex items-center justify-between">
        <ChapterCountdownCompact windowEnd={windowEnd} />
        <Link
          href={`/chapters/${chapterId}`}
          className="text-green-400 hover:text-green-300 text-sm font-medium"
        >
          Enter Chapter →
        </Link>
      </div>
    </div>
  );
}

export function ActiveChapterCardSkeleton() {
  return (
    <div className="bg-gray-800/50 rounded-xl p-6 border border-gray-700 animate-pulse">
      <div className="flex items-center justify-between mb-4">
        <div className="h-6 w-32 bg-gray-700 rounded" />
        <div className="h-6 w-16 bg-gray-700 rounded" />
      </div>
      <div className="mb-4">
        <div className="h-8 w-48 bg-gray-700 rounded mb-2" />
        <div className="h-4 w-full bg-gray-700 rounded" />
      </div>
      <div className="mb-4">
        <div className="h-2 bg-gray-700 rounded-full" />
      </div>
      <div className="flex items-center justify-between">
        <div className="h-4 w-20 bg-gray-700 rounded" />
        <div className="h-4 w-24 bg-gray-700 rounded" />
      </div>
    </div>
  );
}
