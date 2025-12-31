'use client';

import { Header } from '@/components/layout/Header';
import { Footer } from '@/components/layout/Footer';
import { useLeaderboard, type LeaderboardTier } from '@/hooks/useLeaderboard';
import { useAccount } from 'wagmi';

const TIER_COLORS: Record<LeaderboardTier, string> = {
  DIAMOND: 'text-tier-diamond',
  PLATINUM: 'text-tier-platinum',
  GOLD: 'text-tier-gold',
  SILVER: 'text-tier-silver',
  BRONZE: 'text-tier-bronze',
};

function LeaderboardSkeleton() {
  return (
    <div className="bg-gray-800/50 rounded-xl border border-gray-700 overflow-hidden">
      <table className="w-full">
        <thead>
          <tr className="border-b border-gray-700">
            <th className="px-6 py-4 text-left text-sm font-medium text-gray-400">Rank</th>
            <th className="px-6 py-4 text-left text-sm font-medium text-gray-400">Address</th>
            <th className="px-6 py-4 text-right text-sm font-medium text-gray-400">Days Held</th>
            <th className="px-6 py-4 text-right text-sm font-medium text-gray-400">BTC</th>
            <th className="px-6 py-4 text-right text-sm font-medium text-gray-400">Tier</th>
          </tr>
        </thead>
        <tbody>
          {Array.from({ length: 5 }).map((_, i) => (
            <tr key={i} className="border-b border-gray-700/50">
              <td className="px-6 py-4"><div className="h-5 w-8 bg-gray-700 rounded animate-pulse" /></td>
              <td className="px-6 py-4"><div className="h-5 w-32 bg-gray-700 rounded animate-pulse" /></td>
              <td className="px-6 py-4 text-right"><div className="h-5 w-16 bg-gray-700 rounded animate-pulse ml-auto" /></td>
              <td className="px-6 py-4 text-right"><div className="h-5 w-20 bg-gray-700 rounded animate-pulse ml-auto" /></td>
              <td className="px-6 py-4 text-right"><div className="h-5 w-16 bg-gray-700 rounded animate-pulse ml-auto" /></td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function EmptyState() {
  return (
    <div className="text-center py-16 bg-gray-800/50 rounded-xl border border-gray-700">
      <span className="text-6xl mb-6 block">🏔️</span>
      <h2 className="text-2xl font-bold text-white mb-4">No Climbers Yet</h2>
      <p className="text-gray-400">
        Be the first to mint a vault and start your climb!
      </p>
    </div>
  );
}

export default function LeaderboardPage() {
  const { data: leaderboard, isLoading, error } = useLeaderboard();
  const { address: connectedAddress } = useAccount();

  return (
    <>
      <Header />
      <main className="min-h-screen pt-24 pb-16 px-6 bg-gradient-to-b from-black to-gray-900">
        <div className="max-w-4xl mx-auto">
          <div className="mb-8">
            <h1 className="text-3xl font-bold text-white mb-2">Leaderboard</h1>
            <p className="text-gray-400">The longest climbers on the mountain</p>
          </div>

          {isLoading && <LeaderboardSkeleton />}

          {error && (
            <div className="p-4 bg-red-500/10 border border-red-500 rounded-lg">
              <p className="text-red-400">Failed to load leaderboard data</p>
            </div>
          )}

          {!isLoading && !error && leaderboard?.length === 0 && <EmptyState />}

          {!isLoading && !error && leaderboard && leaderboard.length > 0 && (
            <div className="bg-gray-800/50 rounded-xl border border-gray-700 overflow-hidden">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-gray-700">
                    <th className="px-6 py-4 text-left text-sm font-medium text-gray-400">Rank</th>
                    <th className="px-6 py-4 text-left text-sm font-medium text-gray-400">Address</th>
                    <th className="px-6 py-4 text-right text-sm font-medium text-gray-400">Days Held</th>
                    <th className="px-6 py-4 text-right text-sm font-medium text-gray-400">BTC</th>
                    <th className="px-6 py-4 text-right text-sm font-medium text-gray-400">Tier</th>
                  </tr>
                </thead>
                <tbody>
                  {leaderboard.map((entry) => {
                    const isCurrentUser = connectedAddress?.toLowerCase() === entry.fullAddress.toLowerCase();
                    return (
                      <tr
                        key={entry.fullAddress}
                        className={`border-b border-gray-700/50 hover:bg-gray-700/30 ${
                          isCurrentUser ? 'bg-mountain-summit/10' : ''
                        }`}
                      >
                        <td className="px-6 py-4">
                          <span
                            className={`font-bold ${
                              entry.rank <= 3 ? 'text-mountain-summit' : 'text-white'
                            }`}
                          >
                            #{entry.rank}
                          </span>
                        </td>
                        <td className="px-6 py-4 font-mono text-white">
                          {entry.address}
                          {isCurrentUser && (
                            <span className="ml-2 text-xs text-mountain-summit">(You)</span>
                          )}
                        </td>
                        <td className="px-6 py-4 text-right text-white">{entry.daysHeld}</td>
                        <td className="px-6 py-4 text-right font-mono text-white">{entry.collateral}</td>
                        <td className="px-6 py-4 text-right">
                          <span className={`font-medium ${TIER_COLORS[entry.tier]}`}>
                            {entry.tier}
                          </span>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}

          <p className="text-center text-gray-500 text-sm mt-8">
            Leaderboard ranked by longest vault holding duration.
          </p>
        </div>
      </main>
      <Footer />
    </>
  );
}
