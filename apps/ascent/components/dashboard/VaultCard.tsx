'use client';

import { formatCohortDisplay, deriveCohortId } from '@/lib/cohort';
import { calculateAltitude } from '@/lib/altitude';
import { useAchievementName } from '@/hooks/useAchievementName';
import { useChainTime } from '@/hooks/useChainTime';
import type { Address } from 'viem';

// Vault interface matches SDK schema (uses treasureContract/treasureTokenId internally)
// UI displays these as "Achievement" for The Ascent campaign
interface Vault {
  tokenId: bigint;
  mintTimestamp: bigint;
  collateralAmount: bigint;
  treasureContract: Address;
  treasureTokenId: bigint;
}

interface VaultCardProps {
  vault: Vault;
  percentile?: number;
}

const TIER_CONFIG = {
  DIAMOND: { color: 'border-tier-diamond', bg: 'bg-tier-diamond/10', label: 'Diamond' },
  PLATINUM: { color: 'border-tier-platinum', bg: 'bg-tier-platinum/10', label: 'Platinum' },
  GOLD: { color: 'border-tier-gold', bg: 'bg-tier-gold/10', label: 'Gold' },
  SILVER: { color: 'border-tier-silver', bg: 'bg-tier-silver/10', label: 'Silver' },
  BRONZE: { color: 'border-tier-bronze', bg: 'bg-tier-bronze/10', label: 'Bronze' },
};

function getTier(percentile: number) {
  if (percentile >= 99) return 'DIAMOND';
  if (percentile >= 90) return 'PLATINUM';
  if (percentile >= 75) return 'GOLD';
  if (percentile >= 50) return 'SILVER';
  return 'BRONZE';
}

function formatBTC(amount: bigint): string {
  const btc = Number(amount) / 1e8;
  return btc.toFixed(8);
}

export function VaultCard({ vault, percentile = 50 }: VaultCardProps) {
  const { chainTime } = useChainTime();
  const cohortId = deriveCohortId(vault.mintTimestamp);
  const cohortDisplay = formatCohortDisplay(cohortId);
  const altitudeInfo = calculateAltitude(vault.mintTimestamp, chainTime);
  const tier = getTier(percentile);
  const tierConfig = TIER_CONFIG[tier];
  // SDK uses treasureContract/treasureTokenId, UI displays as "Achievement"
  const { data: achievementName, isLoading: isLoadingName } = useAchievementName(
    vault.treasureContract,
    vault.treasureTokenId
  );

  return (
    <div
      className={`rounded-xl p-6 border-2 ${tierConfig.color} ${tierConfig.bg} transition-all hover:scale-[1.02]`}
    >
      <div className="flex items-start justify-between mb-4">
        <div>
          <div className="text-sm text-gray-400">Vault</div>
          <div className="text-xl font-bold text-white">
            {isLoadingName ? (
              <span className="inline-block h-6 w-20 bg-gray-700 rounded animate-pulse" />
            ) : (
              achievementName
            )}
          </div>
        </div>
        <span
          className={`px-3 py-1 rounded-full text-xs font-medium ${tierConfig.bg} border ${tierConfig.color}`}
        >
          {tierConfig.label}
        </span>
      </div>

      <div className="grid grid-cols-2 gap-4 mb-4">
        <div>
          <div className="text-sm text-gray-400">Collateral</div>
          <div className="text-white font-mono">
            {formatBTC(vault.collateralAmount)} BTC
          </div>
        </div>
        <div>
          <div className="text-sm text-gray-400">Days Held</div>
          <div className="text-white">{altitudeInfo.daysHeld}</div>
        </div>
      </div>

      <div className="pt-4 border-t border-gray-700">
        <div className="flex items-center justify-between text-sm">
          <span className="text-gray-400">{cohortDisplay}</span>
          <span className="text-gray-500">
            {isLoadingName ? (
              <span className="inline-block h-4 w-16 bg-gray-700 rounded animate-pulse" />
            ) : (
              achievementName
            )}
          </span>
        </div>
      </div>
    </div>
  );
}

export function VaultCardSkeleton() {
  return (
    <div className="rounded-xl p-6 border-2 border-gray-700 bg-gray-800/50 animate-pulse">
      <div className="flex items-start justify-between mb-4">
        <div>
          <div className="h-4 w-12 bg-gray-700 rounded mb-2" />
          <div className="h-6 w-16 bg-gray-700 rounded" />
        </div>
        <div className="h-6 w-16 bg-gray-700 rounded-full" />
      </div>
      <div className="grid grid-cols-2 gap-4 mb-4">
        <div>
          <div className="h-4 w-16 bg-gray-700 rounded mb-2" />
          <div className="h-5 w-24 bg-gray-700 rounded" />
        </div>
        <div>
          <div className="h-4 w-16 bg-gray-700 rounded mb-2" />
          <div className="h-5 w-12 bg-gray-700 rounded" />
        </div>
      </div>
      <div className="pt-4 border-t border-gray-700">
        <div className="h-4 w-full bg-gray-700 rounded" />
      </div>
    </div>
  );
}
