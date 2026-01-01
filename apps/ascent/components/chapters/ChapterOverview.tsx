'use client';

import { ChapterCard, ChapterCardSkeleton } from './ChapterCard';
import { useChapterEligibility } from '@/hooks/useChapterEligibility';

export function ChapterOverview() {
  const { data: eligibilities, isLoading, error } = useChapterEligibility();

  if (error) {
    return (
      <div className="text-center py-12">
        <p className="text-red-400">Failed to load chapters</p>
        <p className="text-gray-500 text-sm mt-2">{error.message}</p>
      </div>
    );
  }

  if (isLoading || !eligibilities) {
    return (
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
        {Array.from({ length: 12 }).map((_, i) => (
          <ChapterCardSkeleton key={i} />
        ))}
      </div>
    );
  }

  // Group by status for display ordering
  const active = eligibilities.filter((e) => e.status === 'active');
  const locked = eligibilities.filter((e) => e.status === 'locked');
  const completed = eligibilities.filter((e) => e.status === 'completed');
  const missed = eligibilities.filter((e) => e.status === 'missed');

  // Display order: active first, then locked, completed, missed
  const ordered = [...active, ...locked, ...completed, ...missed];

  return (
    <div className="space-y-8">
      {/* Summary stats */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <StatCard
          label="Active"
          value={active.length}
          color="text-green-400"
        />
        <StatCard
          label="Available"
          value={locked.filter((e) => e.daysHeld < e.chapter.chapter.minDaysHeld).length}
          color="text-yellow-400"
        />
        <StatCard
          label="Completed"
          value={completed.length}
          color="text-blue-400"
        />
        <StatCard
          label="Total"
          value={eligibilities.length}
          color="text-gray-400"
        />
      </div>

      {/* Chapter grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
        {ordered.map((eligibility) => (
          <ChapterCard
            key={eligibility.chapter.chapterId}
            eligibility={eligibility}
          />
        ))}
      </div>
    </div>
  );
}

function StatCard({
  label,
  value,
  color,
}: {
  label: string;
  value: number;
  color: string;
}) {
  return (
    <div className="bg-gray-800/50 rounded-lg p-4 border border-gray-700">
      <div className={`text-2xl font-bold ${color}`}>{value}</div>
      <div className="text-sm text-gray-500">{label}</div>
    </div>
  );
}
