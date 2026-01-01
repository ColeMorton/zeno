'use client';

import Link from 'next/link';
import { type ChapterEligibility } from '@/hooks/useChapterEligibility';
import { CHAPTER_COLORS, formatTimeRemaining } from '@/lib/chapters';

interface ChapterCardProps {
  eligibility: ChapterEligibility;
}

const statusConfig: Record<
  string,
  { label: string; border: string; bg: string; badge: string }
> = {
  locked: {
    label: 'Locked',
    border: 'border-gray-700',
    bg: 'bg-gray-800/30',
    badge: 'bg-gray-700 text-gray-400',
  },
  active: {
    label: 'Active',
    border: 'border-green-500',
    bg: 'bg-green-500/10',
    badge: 'bg-green-500 text-black',
  },
  completed: {
    label: 'Completed',
    border: 'border-blue-500',
    bg: 'bg-blue-500/10',
    badge: 'bg-blue-500 text-white',
  },
  missed: {
    label: 'Missed',
    border: 'border-red-500/50',
    bg: 'bg-red-500/5',
    badge: 'bg-red-500/50 text-red-200',
  },
};

export function ChapterCard({ eligibility }: ChapterCardProps) {
  const { chapter, status, progress, canParticipate, reason } = eligibility;
  const { chapter: chapterConfig, chapterId, windowEnd } = chapter;
  const config = statusConfig[status] ?? statusConfig.locked;
  const colors = CHAPTER_COLORS[chapterConfig.number] ?? CHAPTER_COLORS[1];

  const now = Math.floor(Date.now() / 1000);
  const timeRemaining = windowEnd - now;

  return (
    <Link
      href={canParticipate ? `/chapters/${chapterId}` : '#'}
      className={`block rounded-xl p-5 border-2 transition-all ${config.border} ${config.bg} ${
        canParticipate
          ? 'hover:scale-[1.02] hover:shadow-lg cursor-pointer'
          : 'opacity-60 cursor-not-allowed'
      }`}
    >
      {/* Header */}
      <div className="flex items-center justify-between mb-3">
        <span className="text-2xl font-bold text-white">
          Ch. {chapterConfig.number}
        </span>
        <span
          className={`px-2 py-1 rounded text-xs font-semibold ${config.badge}`}
        >
          {config.label}
        </span>
      </div>

      {/* Theme */}
      <h3 className="text-lg font-semibold text-white mb-1">
        {chapterConfig.theme}
      </h3>
      <p className="text-sm text-gray-400 mb-4">{chapterConfig.description}</p>

      {/* Progress bar */}
      <div className="mb-3">
        <div className="flex justify-between text-xs text-gray-500 mb-1">
          <span>Day {chapterConfig.minDaysHeld}</span>
          <span>Day {chapterConfig.maxDaysHeld}</span>
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

      {/* Footer info */}
      <div className="flex items-center justify-between text-xs">
        {status === 'active' && timeRemaining > 0 && (
          <span className="text-green-400">
            {formatTimeRemaining(timeRemaining)} remaining
          </span>
        )}
        {reason && status !== 'active' && (
          <span className="text-gray-500">{reason}</span>
        )}
        {canParticipate && (
          <span className="text-green-400 font-medium">Enter Chapter →</span>
        )}
      </div>
    </Link>
  );
}

export function ChapterCardSkeleton() {
  return (
    <div className="rounded-xl p-5 border-2 border-gray-700 bg-gray-800/30 animate-pulse">
      <div className="flex items-center justify-between mb-3">
        <div className="h-8 w-16 bg-gray-700 rounded" />
        <div className="h-6 w-16 bg-gray-700 rounded" />
      </div>
      <div className="h-6 w-32 bg-gray-700 rounded mb-1" />
      <div className="h-4 w-full bg-gray-700 rounded mb-4" />
      <div className="h-2 bg-gray-700 rounded-full mb-3" />
      <div className="h-4 w-24 bg-gray-700 rounded" />
    </div>
  );
}
