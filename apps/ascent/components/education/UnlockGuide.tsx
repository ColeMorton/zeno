'use client';

import { CATEGORY_ICONS, CONCEPT_COLORS } from '@/lib/education';

interface UnlockGuideProps {
  achievementName: string;
  category: string;
  defiConcept: string;
  unlockHint: string;
  prerequisites?: string[];
}

export function UnlockGuide({
  achievementName,
  category,
  defiConcept,
  unlockHint,
  prerequisites,
}: UnlockGuideProps) {
  const icon = CATEGORY_ICONS[category] ?? '📋';
  const conceptColor = CONCEPT_COLORS[defiConcept] ?? '#4A90A4';

  return (
    <div className="bg-gray-800/50 rounded-lg p-5 border border-gray-700">
      {/* Header */}
      <div className="flex items-center gap-3 mb-4">
        <span className="text-2xl">{icon}</span>
        <div>
          <h3 className="text-lg font-bold text-white">{achievementName}</h3>
          <span
            className="text-xs px-2 py-0.5 rounded-full"
            style={{ backgroundColor: `${conceptColor}30`, color: conceptColor }}
          >
            {category}
          </span>
        </div>
      </div>

      {/* Locked indicator */}
      <div className="flex items-center gap-2 mb-4 text-gray-400">
        <svg
          className="w-5 h-5"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"
          />
        </svg>
        <span className="text-sm">Achievement Locked</span>
      </div>

      {/* How to unlock */}
      <div className="space-y-3">
        <div>
          <h4 className="text-sm font-semibold text-gray-300 mb-1">How to unlock:</h4>
          <p className="text-gray-400">{unlockHint}</p>
        </div>

        {/* Prerequisites if any */}
        {prerequisites && prerequisites.length > 0 && (
          <div>
            <h4 className="text-sm font-semibold text-gray-300 mb-1">Prerequisites:</h4>
            <ul className="space-y-1">
              {prerequisites.map((prereq) => (
                <li key={prereq} className="flex items-center gap-2 text-gray-400 text-sm">
                  <span className="w-2 h-2 rounded-full bg-gray-600" />
                  {prereq}
                </li>
              ))}
            </ul>
          </div>
        )}
      </div>
    </div>
  );
}

export function UnlockGuideSkeleton() {
  return (
    <div className="bg-gray-800/50 rounded-lg p-5 border border-gray-700 animate-pulse">
      <div className="flex items-center gap-3 mb-4">
        <div className="w-8 h-8 bg-gray-700 rounded" />
        <div>
          <div className="h-5 w-32 bg-gray-700 rounded mb-1" />
          <div className="h-4 w-16 bg-gray-700 rounded" />
        </div>
      </div>
      <div className="h-4 w-24 bg-gray-700 rounded mb-4" />
      <div className="space-y-2">
        <div className="h-4 w-20 bg-gray-700 rounded" />
        <div className="h-4 w-full bg-gray-700 rounded" />
      </div>
    </div>
  );
}
