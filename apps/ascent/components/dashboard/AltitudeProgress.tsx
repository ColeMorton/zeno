'use client';

import { calculateAltitude, formatAltitude, ALTITUDE_ZONES } from '@/lib/altitude';
import { useChainTime } from '@/hooks/useChainTime';

interface Vault {
  tokenId: bigint;
  mintTimestamp: bigint;
  collateralAmount: bigint;
}

interface AltitudeProgressProps {
  vault: Vault;
}

export function AltitudeProgress({ vault }: AltitudeProgressProps) {
  const { chainTime } = useChainTime();
  const altitudeInfo = calculateAltitude(vault.mintTimestamp, chainTime);
  const currentZone = ALTITUDE_ZONES[altitudeInfo.currentZone];
  const nextZone = altitudeInfo.nextZone
    ? ALTITUDE_ZONES[altitudeInfo.nextZone]
    : null;

  const progressPercent = altitudeInfo.nextZone
    ? (altitudeInfo.altitude / ALTITUDE_ZONES.SUMMIT.altitude) * 100
    : 100;

  return (
    <div className="bg-gray-800/50 rounded-xl p-6 border border-gray-700">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-xl font-semibold text-white">Your Altitude</h2>
        <span className="text-2xl">⛰️</span>
      </div>

      {/* Current zone display */}
      <div className="mb-6">
        <div className="text-4xl font-bold text-mountain-summit mb-1">
          {formatAltitude(altitudeInfo.altitude)}
        </div>
        <div className="text-gray-400">
          {currentZone.name} • Day {altitudeInfo.daysHeld}
        </div>
      </div>

      {/* Progress bar */}
      <div className="relative mb-4">
        <div className="h-3 bg-gray-700 rounded-full overflow-hidden">
          <div
            className="h-full bg-gradient-to-r from-mountain-trailhead via-mountain-ridgeline to-mountain-summit transition-all duration-500"
            style={{ width: `${progressPercent}%` }}
          />
        </div>

        {/* Zone markers */}
        <div className="absolute top-5 left-0 right-0 flex justify-between text-xs text-gray-500">
          <span>0m</span>
          <span>Summit</span>
        </div>
      </div>

      {/* Next milestone */}
      {nextZone && (
        <div className="mt-6 pt-4 border-t border-gray-700">
          <div className="flex items-center justify-between">
            <div>
              <div className="text-sm text-gray-400">Next Milestone</div>
              <div className="text-white font-medium">{nextZone.name}</div>
            </div>
            <div className="text-right">
              <div className="text-sm text-gray-400">In</div>
              <div className="text-mountain-summit font-medium">
                {altitudeInfo.daysToNextZone} days
              </div>
            </div>
          </div>

          {/* Progress to next zone */}
          <div className="mt-3 h-1.5 bg-gray-700 rounded-full overflow-hidden">
            <div
              className="h-full bg-mountain-summit/50 transition-all duration-500"
              style={{ width: `${altitudeInfo.progressToNextZone * 100}%` }}
            />
          </div>
        </div>
      )}
    </div>
  );
}

export function AltitudeProgressSkeleton() {
  return (
    <div className="bg-gray-800/50 rounded-xl p-6 border border-gray-700 animate-pulse">
      <div className="flex items-center justify-between mb-4">
        <div className="h-6 w-32 bg-gray-700 rounded" />
        <div className="h-8 w-8 bg-gray-700 rounded" />
      </div>
      <div className="h-10 w-24 bg-gray-700 rounded mb-2" />
      <div className="h-4 w-40 bg-gray-700 rounded mb-6" />
      <div className="h-3 bg-gray-700 rounded-full" />
    </div>
  );
}
