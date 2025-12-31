'use client';

import { useAchievementNfts, type AchievementNft } from '@/hooks/useAchievementNfts';
import { useAchievementName } from '@/hooks/useAchievementName';

interface AchievementStepProps {
  onSelect: (achievement: AchievementNft) => void;
}

function AchievementCard({
  achievement,
  onSelect,
}: {
  achievement: AchievementNft;
  onSelect: () => void;
}) {
  const { data: achievementName, isLoading: isLoadingName } = useAchievementName(
    achievement.contract,
    achievement.tokenId
  );

  return (
    <button
      onClick={onSelect}
      className="w-full p-6 rounded-xl border-2 border-gray-700 bg-gray-800/50 hover:border-mountain-summit hover:bg-gray-800 transition-all text-left"
    >
      <div className="text-sm text-gray-400">Achievement</div>
      <div className="text-2xl font-bold text-white">
        {isLoadingName ? (
          <span className="inline-block h-7 w-24 bg-gray-700 rounded animate-pulse" />
        ) : (
          achievementName
        )}
      </div>
      <div className="mt-4 text-xs text-gray-500 font-mono truncate">
        {achievement.contract}
      </div>
    </button>
  );
}

function AchievementCardSkeleton() {
  return (
    <div className="p-6 rounded-xl border-2 border-gray-700 bg-gray-800/50 animate-pulse">
      <div className="h-4 w-24 bg-gray-700 rounded mb-2" />
      <div className="h-8 w-16 bg-gray-700 rounded" />
      <div className="mt-4 h-4 w-full bg-gray-700 rounded" />
    </div>
  );
}

export function AchievementStep({ onSelect }: AchievementStepProps) {
  const { data: achievements, isLoading, error } = useAchievementNfts();

  if (isLoading) {
    return (
      <div className="space-y-6">
        <div>
          <h2 className="text-2xl font-bold text-white mb-2">
            Select Your Achievement
          </h2>
          <p className="text-gray-400">
            Choose which Achievement to lock in your Vault.
          </p>
        </div>
        <div className="grid gap-4 md:grid-cols-2">
          <AchievementCardSkeleton />
          <AchievementCardSkeleton />
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="text-center py-12">
        <span className="text-4xl mb-4 block">⚠️</span>
        <h2 className="text-xl font-bold text-white mb-2">Error Loading Achievements</h2>
        <p className="text-gray-400">{error.message}</p>
      </div>
    );
  }

  if (!achievements || achievements.length === 0) {
    return (
      <div className="text-center py-12">
        <span className="text-6xl mb-6 block">🎁</span>
        <h2 className="text-2xl font-bold text-white mb-4">
          No Achievements Found
        </h2>
        <p className="text-gray-400 max-w-md mx-auto">
          You need an Achievement NFT to mint a Vault. Achievements are issued
          during minting events.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-white mb-2">
          Select Your Achievement
        </h2>
        <p className="text-gray-400">
          Choose which Achievement to lock in your Vault. You have{' '}
          {achievements.length} Achievement{achievements.length !== 1 ? 's' : ''}{' '}
          available.
        </p>
      </div>
      <div className="grid gap-4 md:grid-cols-2">
        {achievements.map((achievement) => (
          <AchievementCard
            key={achievement.tokenId.toString()}
            achievement={achievement}
            onSelect={() => onSelect(achievement)}
          />
        ))}
      </div>
    </div>
  );
}
