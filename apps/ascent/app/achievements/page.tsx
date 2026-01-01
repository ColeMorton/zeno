'use client';

import { useAccount } from 'wagmi';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { useRouter } from 'next/navigation';
import { Header } from '@/components/layout/Header';
import { Footer } from '@/components/layout/Footer';
import { CHAPTER_1_ACHIEVEMENTS, getCurrentQuarter, getChapterVersionId } from '@/lib/chapters';
import { useChapterAchievements, type ChapterAchievement } from '@/hooks/useChapterAchievements';
import { useTreasureNfts } from '@/hooks/useTreasureNfts';

// Category icons for Chapter 1 achievements
const CATEGORY_ICONS: Record<string, string> = {
  Registration: '📝',
  Milestone: '🎯',
  Activity: '⚡',
  Identity: '🔑',
  Referral: '👥',
  Preparation: '🛠️',
  Consistency: '📊',
  Commitment: '🤝',
  Learning: '📚',
  Completion: '🏆',
};

type AchievementStatus = 'locked' | 'available' | 'minted';

function AchievementCard({
  achievement,
  onMintVault,
  hasTreasure,
}: {
  achievement: ChapterAchievement;
  onMintVault?: () => void;
  hasTreasure: boolean;
}) {
  const staticAch = CHAPTER_1_ACHIEVEMENTS.find(a => a.name === achievement.name);
  const category = staticAch?.category ?? 'Activity';
  const icon = CATEGORY_ICONS[category] ?? '⭐';

  // Determine status
  let status: AchievementStatus = 'locked';
  if (achievement.isClaimed) {
    status = 'minted';
  } else if (achievement.canClaim) {
    status = 'available';
  }

  const statusStyles = {
    locked: 'border-gray-700 bg-gray-800/50 opacity-60',
    available: 'border-green-500 bg-green-500/10',
    minted: 'border-mountain-summit bg-mountain-summit/10',
  };

  const statusLabel = {
    locked: <span className="text-gray-500">Locked</span>,
    available: <span className="text-green-400 font-medium">Available</span>,
    minted: <span className="text-mountain-summit font-medium">Claimed</span>,
  };

  return (
    <div className={`rounded-xl p-6 border ${statusStyles[status]}`}>
      <div className="flex items-center gap-4 mb-4">
        <span className="text-4xl">{icon}</span>
        <div className="flex-1">
          <div className="flex items-center gap-2 mb-1">
            <span className="text-xs text-gray-500">Week {achievement.week}</span>
            <span className="text-xs text-gray-600">•</span>
            <span className="text-xs text-gray-500">{category}</span>
          </div>
          <h3 className="text-lg font-semibold text-white">
            {achievement.name.replace(/_/g, ' ')}
          </h3>
        </div>
      </div>

      <p className="text-sm text-gray-400 mb-4">{achievement.description}</p>

      <div className="flex items-center justify-between">
        {statusLabel[status]}
        {status === 'minted' && hasTreasure && onMintVault && (
          <button
            onClick={onMintVault}
            className="px-4 py-2 bg-mountain-summit text-black text-sm font-medium rounded-lg hover:bg-yellow-400 transition-colors"
          >
            Create Vault
          </button>
        )}
      </div>
    </div>
  );
}

function AchievementCardSkeleton() {
  return (
    <div className="rounded-xl p-6 border border-gray-700 bg-gray-800/50 animate-pulse">
      <div className="flex items-center gap-4 mb-4">
        <div className="h-10 w-10 bg-gray-700 rounded" />
        <div className="flex-1">
          <div className="h-3 w-24 bg-gray-700 rounded mb-2" />
          <div className="h-5 w-32 bg-gray-700 rounded" />
        </div>
      </div>
      <div className="h-4 w-full bg-gray-700 rounded mb-4" />
      <div className="flex items-center justify-between">
        <div className="h-4 w-16 bg-gray-700 rounded" />
      </div>
    </div>
  );
}

function Chapter1Achievements() {
  const router = useRouter();

  // Get current chapter version ID
  const { year, quarter } = getCurrentQuarter();
  const chapterId = getChapterVersionId(1, year, quarter);

  // Fetch Chapter 1 achievements from on-chain or mock
  const { data: mapConfig, isLoading, error } = useChapterAchievements(chapterId);

  // Check if user has treasures available for vault minting
  const { data: treasures } = useTreasureNfts();
  const hasTreasure = (treasures?.length ?? 0) > 0;

  const handleMintVault = () => {
    router.push('/mint');
  };

  if (isLoading) {
    return (
      <div className="space-y-8">
        <div>
          <h2 className="text-xl font-semibold text-white mb-2">
            Chapter 1: Frozen Tundra
          </h2>
          <p className="text-gray-400 text-sm mb-4">
            13 achievements across 13 weeks (Days 0-90)
          </p>
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
            {CHAPTER_1_ACHIEVEMENTS.map((ach) => (
              <AchievementCardSkeleton key={ach.name} />
            ))}
          </div>
        </div>
      </div>
    );
  }

  if (error || !mapConfig) {
    return (
      <div className="text-center py-12">
        <span className="text-6xl mb-6 block">⚠️</span>
        <h2 className="text-2xl font-bold text-white mb-4">
          Could Not Load Achievements
        </h2>
        <p className="text-gray-400 mb-8">
          {error?.message ?? 'Chapter data not available.'}
        </p>
      </div>
    );
  }

  // Count claimed achievements
  const claimedCount = mapConfig.achievements.filter(a => a.isClaimed).length;
  const totalCount = mapConfig.achievements.length;

  return (
    <div className="space-y-8">
      <div>
        <div className="flex items-center justify-between mb-4">
          <div>
            <h2 className="text-xl font-semibold text-white mb-1">
              Chapter 1: Frozen Tundra
            </h2>
            <p className="text-gray-400 text-sm">
              {claimedCount} / {totalCount} achievements claimed
            </p>
          </div>
          <div className="text-sm text-gray-500">
            Days 0-90 • Q{quarter} {year}
          </div>
        </div>

        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {mapConfig.achievements.map((achievement) => (
            <AchievementCard
              key={achievement.id}
              achievement={achievement}
              onMintVault={handleMintVault}
              hasTreasure={hasTreasure}
            />
          ))}
        </div>
      </div>

      {hasTreasure && (
        <div className="bg-green-500/10 rounded-xl p-6 border border-green-500/50">
          <h3 className="font-semibold text-white mb-2">Ready to Create a Vault</h3>
          <p className="text-sm text-gray-400 mb-4">
            You have {treasures?.length} Treasure NFT{(treasures?.length ?? 0) !== 1 ? 's' : ''} available.
            Create a vault to lock your treasure with cbBTC collateral and begin your 1129-day journey.
          </p>
          <button
            onClick={handleMintVault}
            className="px-6 py-3 bg-mountain-summit text-black font-semibold rounded-lg hover:bg-yellow-400 transition-colors"
          >
            Create Vault
          </button>
        </div>
      )}
    </div>
  );
}

function AchievementsContent() {
  const { isConnected } = useAccount();

  if (!isConnected) {
    return (
      <div className="text-center py-12">
        <span className="text-6xl mb-6 block">🏆</span>
        <h2 className="text-2xl font-bold text-white mb-4">
          Connect to View Achievements
        </h2>
        <p className="text-gray-400 mb-8">
          Connect your wallet to see your Chapter 1 achievements.
        </p>
        <ConnectButton />
      </div>
    );
  }

  return <Chapter1Achievements />;
}

export default function AchievementsPage() {
  return (
    <>
      <Header />
      <main className="min-h-screen pt-24 pb-16 px-6 bg-gradient-to-b from-black to-gray-900">
        <div className="max-w-7xl mx-auto">
          <div className="mb-8">
            <h1 className="text-3xl font-bold text-white mb-2">Chapter 1 Achievements</h1>
            <p className="text-gray-400">
              Complete achievements as you progress through Chapter 1 of The Ascent.
              Each achievement can only be claimed once during the chapter window.
            </p>
          </div>
          <AchievementsContent />
        </div>
      </main>
      <Footer />
    </>
  );
}
