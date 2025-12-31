'use client';

import { useChainTime } from '@/hooks/useChainTime';
import { useDevTime } from '@/hooks/useDevTime';

const TIME_BUTTONS = [
  { days: 1, label: '+1d' },
  { days: 7, label: '+7d' },
  { days: 30, label: '+30d' },
  { days: 365, label: '+1y' },
  { days: 1129, label: '+1129d' },
] as const;

function formatChainTime(timestamp: number): string {
  return new Date(timestamp * 1000).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
}

export function DevToolbar() {
  const { chainTime, isAnvil } = useChainTime();
  const { advanceTime, isAdvancing, error } = useDevTime();

  // Only render on Anvil
  if (!isAnvil) {
    return null;
  }

  return (
    <div className="fixed bottom-0 left-0 right-0 z-50 bg-amber-900/95 border-t border-amber-700 px-4 py-2">
      <div className="max-w-7xl mx-auto flex items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <span className="text-amber-200 text-sm font-mono">
            Chain Time: {formatChainTime(chainTime)}
          </span>
          {error && (
            <span className="text-red-400 text-xs">{error}</span>
          )}
        </div>

        <div className="flex items-center gap-2">
          {TIME_BUTTONS.map(({ days, label }) => (
            <button
              key={days}
              onClick={() => advanceTime(days)}
              disabled={isAdvancing}
              className="px-3 py-1 text-sm font-medium bg-amber-800 hover:bg-amber-700 disabled:bg-amber-900 disabled:opacity-50 text-amber-100 rounded transition-colors"
            >
              {label}
            </button>
          ))}
          <span className="ml-2 px-2 py-1 text-xs font-bold bg-amber-700 text-amber-200 rounded">
            DEV
          </span>
        </div>
      </div>
    </div>
  );
}
