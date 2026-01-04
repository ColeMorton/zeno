'use client';

import { useParams } from 'next/navigation';
import Link from 'next/link';
import { useAccount, useChainId } from 'wagmi';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { Header } from '@/components/layout/Header';
import { Footer } from '@/components/layout/Footer';
import {
  ChapterProgress,
  ChapterProgressSkeleton,
  ChapterCountdown,
} from '@/components/chapters';
import { useChapter } from '@/hooks/useChapters';
import { useChapterEligibilityById } from '@/hooks/useChapterEligibility';
import {
  useChapterAchievements,
  type ChapterAchievement,
} from '@/hooks/useChapterAchievements';
import { useClaimAchievement } from '@/hooks/useClaimAchievement';
import { useVaults } from '@/hooks/useVaults';
import { CHAPTER_COLORS } from '@/lib/chapters';
import { getContractAddresses } from '@/lib/contracts';

function AchievementNode({
  achievement,
  chapterIdBytes,
  vaultId,
  collateralToken,
  onClaim,
  isClaiming,
}: {
  achievement: ChapterAchievement;
  chapterIdBytes: `0x${string}`;
  vaultId: bigint;
  collateralToken: `0x${string}`;
  onClaim: (params: {
    chapterId: `0x${string}`;
    achievementId: `0x${string}`;
    vaultId: bigint;
    collateralToken: `0x${string}`;
  }) => void;
  isClaiming: boolean;
}) {
  const isClaimable = achievement.canClaim && !isClaiming;
  const statusStyles = achievement.isClaimed
    ? 'border-green-500 bg-green-500/20'
    : isClaimable
      ? 'border-yellow-500 bg-yellow-500/10 hover:bg-yellow-500/20 cursor-pointer'
      : 'border-gray-700 bg-gray-800/50 opacity-60';

  const handleClick = () => {
    if (!isClaimable) return;
    onClaim({
      chapterId: chapterIdBytes,
      achievementId: achievement.achievementId,
      vaultId,
      collateralToken,
    });
  };

  return (
    <button
      onClick={handleClick}
      disabled={!isClaimable}
      className={`rounded-lg p-4 border-2 transition-all text-left ${statusStyles}`}
      style={{
        position: 'absolute',
        left: `${achievement.position.x}%`,
        top: `${achievement.position.y}%`,
        transform: 'translate(-50%, -50%)',
        minWidth: '160px',
      }}
    >
      <h4 className="font-semibold text-white text-sm">{achievement.name}</h4>
      <p className="text-xs text-gray-400 mt-1">{achievement.description}</p>
      <div className="mt-2 text-xs">
        {achievement.isClaimed ? (
          <span className="text-green-400">Claimed</span>
        ) : isClaiming ? (
          <span className="text-yellow-400 animate-pulse">Claiming...</span>
        ) : achievement.canClaim ? (
          <span className="text-yellow-400">Click to Claim</span>
        ) : (
          <span className="text-gray-500">Locked</span>
        )}
      </div>
    </button>
  );
}

function SkillTreeMap({ chapterId }: { chapterId: string }) {
  const chainId = useChainId();
  const { data: mapConfig, isLoading, error } = useChapterAchievements(chapterId);
  const { data: vaults } = useVaults();
  const { claim, isPending, isConfirming } = useClaimAchievement();

  // Get collateral token address
  let collateralToken: `0x${string}` = '0x0000000000000000000000000000000000000000';
  try {
    const contracts = getContractAddresses(chainId);
    collateralToken = contracts.cbBTC;
  } catch {
    // Chain not configured
  }

  // Use first vault if available
  const vaultId = vaults?.[0]?.tokenId ?? 0n;
  const isClaiming = isPending || isConfirming;

  if (isLoading) {
    return (
      <div className="bg-gray-800/50 rounded-xl p-8 border border-gray-700 animate-pulse">
        <div className="h-64 flex items-center justify-center">
          <span className="text-gray-500">Loading map...</span>
        </div>
      </div>
    );
  }

  if (error || !mapConfig) {
    return (
      <div className="bg-gray-800/50 rounded-xl p-8 border border-gray-700">
        <div className="text-center text-gray-500">
          <p>Map not available</p>
        </div>
      </div>
    );
  }

  // Parse chapter number for colors
  const match = chapterId.match(/^CH(\d+)_/);
  const chapterNumber = match ? parseInt(match[1], 10) : 1;
  const colors = CHAPTER_COLORS[chapterNumber] ?? CHAPTER_COLORS[1];

  return (
    <div className="bg-gray-800/50 rounded-xl border border-gray-700 overflow-hidden">
      <div className="p-4 border-b border-gray-700">
        <h3 className="font-semibold text-white">{mapConfig.theme} Map</h3>
        <p className="text-sm text-gray-400">
          {mapConfig.achievements.filter(a => a.isClaimed).length} / {mapConfig.achievements.length} achievements claimed
        </p>
      </div>

      {/* Skill tree visualization */}
      <div
        className="relative bg-gradient-to-b from-gray-900 to-gray-800"
        style={{ height: '500px' }}
      >
        {/* Connection lines (simplified) */}
        <svg
          className="absolute inset-0 w-full h-full pointer-events-none"
          style={{ zIndex: 0 }}
        >
          {mapConfig.achievements.map((ach) =>
            ach.prerequisites.map((prereqId) => {
              const prereq = mapConfig.achievements.find((a) => a.id === prereqId);
              if (!prereq) return null;
              return (
                <line
                  key={`${prereqId}-${ach.id}`}
                  x1={`${prereq.position.x}%`}
                  y1={`${prereq.position.y}%`}
                  x2={`${ach.position.x}%`}
                  y2={`${ach.position.y}%`}
                  stroke={colors.primary}
                  strokeWidth="2"
                  strokeOpacity="0.5"
                />
              );
            })
          )}
        </svg>

        {/* Achievement nodes */}
        {mapConfig.achievements.map((ach) => (
          <AchievementNode
            key={ach.id}
            achievement={ach}
            chapterIdBytes={mapConfig.chapterIdBytes}
            vaultId={vaultId}
            collateralToken={collateralToken}
            onClaim={claim}
            isClaiming={isClaiming}
          />
        ))}
      </div>
    </div>
  );
}

function ChapterDetailContent({ chapterId }: { chapterId: string }) {
  const { isConnected } = useAccount();
  const { data: chapter, isLoading: chapterLoading } = useChapter(chapterId);
  const { data: eligibility, isLoading: eligibilityLoading } =
    useChapterEligibilityById(chapterId);

  if (!isConnected) {
    return (
      <div className="text-center py-12">
        <span className="text-6xl mb-6 block">🏔️</span>
        <h2 className="text-2xl font-bold text-white mb-4">
          Connect to View Chapter
        </h2>
        <p className="text-gray-400 mb-8">
          Connect your wallet to see your progress and claim achievements.
        </p>
        <ConnectButton />
      </div>
    );
  }

  const isLoading = chapterLoading || eligibilityLoading;

  if (isLoading) {
    return (
      <div className="space-y-6">
        <ChapterProgressSkeleton />
        <div className="bg-gray-800/50 rounded-xl p-8 border border-gray-700 animate-pulse h-96" />
      </div>
    );
  }

  if (!chapter || !eligibility) {
    return (
      <div className="text-center py-12">
        <span className="text-6xl mb-6 block">❌</span>
        <h2 className="text-2xl font-bold text-white mb-4">Chapter Not Found</h2>
        <p className="text-gray-400 mb-8">
          This chapter doesn&apos;t exist or isn&apos;t available yet.
        </p>
        <Link
          href="/chapters"
          className="text-green-400 hover:text-green-300 underline"
        >
          ← Back to Chapters
        </Link>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Progress card */}
      <ChapterProgress eligibility={eligibility} />

      {/* Countdown if active */}
      {eligibility.status === 'active' && (
        <div className="bg-gray-800/50 rounded-xl p-6 border border-gray-700">
          <ChapterCountdown windowEnd={chapter.windowEnd} />
        </div>
      )}

      {/* Skill tree map */}
      <SkillTreeMap chapterId={chapterId} />

      {/* Actions */}
      {eligibility.canParticipate && (
        <div className="bg-green-500/10 rounded-xl p-6 border border-green-500/50">
          <h3 className="font-semibold text-white mb-2">Ready to Claim</h3>
          <p className="text-sm text-gray-400">
            You&apos;re eligible to claim achievements in this chapter. Click on
            an available (yellow) achievement above to claim it.
          </p>
        </div>
      )}
    </div>
  );
}

export default function ChapterDetailClient() {
  const params = useParams();
  const chapterId = params.chapterId as string;

  // Parse chapter info from ID
  const match = chapterId?.match(/^CH(\d+)_(\d+)Q(\d+)$/);
  const chapterNumber = match ? parseInt(match[1], 10) : null;
  const year = match ? parseInt(match[2], 10) : null;
  const quarter = match ? parseInt(match[3], 10) : null;

  return (
    <>
      <Header />
      <main className="min-h-screen pt-24 pb-16 px-6 bg-gradient-to-b from-black to-gray-900">
        <div className="max-w-5xl mx-auto">
          {/* Breadcrumb */}
          <div className="mb-6">
            <Link
              href="/chapters"
              className="text-gray-400 hover:text-white transition-colors"
            >
              ← All Chapters
            </Link>
          </div>

          {/* Header */}
          <div className="mb-8">
            <div className="flex items-center gap-3 mb-2">
              <h1 className="text-3xl font-bold text-white">
                Chapter {chapterNumber ?? '?'}
              </h1>
              {year && quarter && (
                <span className="px-3 py-1 bg-gray-800 text-gray-400 text-sm rounded">
                  {year} Q{quarter}
                </span>
              )}
            </div>
            <p className="text-gray-400">
              Complete achievements to progress through this chapter&apos;s skill tree.
            </p>
          </div>

          <ChapterDetailContent chapterId={chapterId} />
        </div>
      </main>
      <Footer />
    </>
  );
}
