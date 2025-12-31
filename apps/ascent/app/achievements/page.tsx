'use client';

import { useAccount } from 'wagmi';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { Header } from '@/components/layout/Header';
import { Footer } from '@/components/layout/Footer';
import { ALTITUDE_ZONES } from '@/lib/altitude';
import { useAchievementStatus, type AchievementStatus } from '@/hooks/useAchievementStatus';

const ACHIEVEMENTS = [
  {
    id: 'CLIMBER',
    name: 'Climber',
    description: 'Minted your first Vault NFT',
    icon: '🥾',
    zone: 'TRAILHEAD',
  },
  {
    id: 'TRAIL_HEAD',
    name: 'Trail Head',
    description: 'Held for 30 days',
    icon: '🔥',
    zone: 'FIRST_CAMP',
  },
  {
    id: 'BASE_CAMP',
    name: 'Base Camp',
    description: 'Held for 91 days',
    icon: '⛺',
    zone: 'BASE_CAMP',
  },
  {
    id: 'RIDGE_WALKER',
    name: 'Ridge Walker',
    description: 'Held for 182 days',
    icon: '🌨️',
    zone: 'RIDGE_LINE',
  },
  {
    id: 'HIGH_CAMP',
    name: 'High Camp',
    description: 'Held for 365 days',
    icon: '🏕️',
    zone: 'HIGH_CAMP',
  },
  {
    id: 'SUMMIT_PUSH',
    name: 'Summit Push',
    description: 'Held for 730 days',
    icon: '❄️',
    zone: 'DEATH_ZONE',
  },
  {
    id: 'SUMMIT',
    name: 'Summit',
    description: 'Completed 1129 day vesting',
    icon: '🏔️',
    zone: 'SUMMIT',
  },
];

function AchievementCard({
  achievement,
  status = 'locked',
}: {
  achievement: (typeof ACHIEVEMENTS)[0];
  status?: AchievementStatus;
}) {
  const zone = ALTITUDE_ZONES[achievement.zone as keyof typeof ALTITUDE_ZONES];

  const statusStyles = {
    locked: 'border-gray-700 bg-gray-800/50 opacity-60',
    available: 'border-green-500 bg-green-500/10',
    minted: 'border-mountain-summit bg-mountain-summit/10',
  };

  const statusLabel = {
    locked: <span className="text-gray-500">Locked</span>,
    available: <span className="text-green-400 font-medium">Available</span>,
    minted: <span className="text-mountain-summit font-medium">Minted</span>,
  };

  return (
    <div className={`rounded-xl p-6 border ${statusStyles[status]}`}>
      <div className="flex items-center gap-4 mb-4">
        <span className="text-4xl">{achievement.icon}</span>
        <div>
          <h3 className="text-lg font-semibold text-white">
            {achievement.name}
          </h3>
          <p className="text-sm text-gray-400">{achievement.description}</p>
        </div>
      </div>

      <div className="flex items-center justify-between text-sm">
        <span className="text-gray-500">
          Day {zone.days} • {zone.altitude}m
        </span>
        {statusLabel[status]}
      </div>
    </div>
  );
}

function AchievementCardSkeleton() {
  return (
    <div className="rounded-xl p-6 border border-gray-700 bg-gray-800/50 animate-pulse">
      <div className="flex items-center gap-4 mb-4">
        <div className="h-10 w-10 bg-gray-700 rounded" />
        <div>
          <div className="h-5 w-24 bg-gray-700 rounded mb-2" />
          <div className="h-4 w-32 bg-gray-700 rounded" />
        </div>
      </div>
      <div className="flex items-center justify-between">
        <div className="h-4 w-20 bg-gray-700 rounded" />
        <div className="h-4 w-16 bg-gray-700 rounded" />
      </div>
    </div>
  );
}

function AchievementsContent() {
  const { isConnected } = useAccount();
  const { data: achievementStatus, isLoading } = useAchievementStatus();

  if (!isConnected) {
    return (
      <div className="text-center py-12">
        <span className="text-6xl mb-6 block">🏆</span>
        <h2 className="text-2xl font-bold text-white mb-4">
          Connect to View Achievements
        </h2>
        <p className="text-gray-400 mb-8">
          Connect your wallet to see your earned achievements.
        </p>
        <ConnectButton />
      </div>
    );
  }

  if (isLoading) {
    return (
      <div className="space-y-8">
        <div>
          <h2 className="text-xl font-semibold text-white mb-4">
            Personal Journey
          </h2>
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
            {ACHIEVEMENTS.map((achievement) => (
              <AchievementCardSkeleton key={achievement.id} />
            ))}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      <div>
        <h2 className="text-xl font-semibold text-white mb-4">
          Personal Journey
        </h2>
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {ACHIEVEMENTS.map((achievement) => (
            <AchievementCard
              key={achievement.id}
              achievement={achievement}
              status={achievementStatus?.[achievement.id]?.status ?? 'locked'}
            />
          ))}
        </div>
      </div>
    </div>
  );
}

export default function AchievementsPage() {
  return (
    <>
      <Header />
      <main className="min-h-screen pt-24 pb-16 px-6 bg-gradient-to-b from-black to-gray-900">
        <div className="max-w-7xl mx-auto">
          <div className="mb-8">
            <h1 className="text-3xl font-bold text-white mb-2">Achievements</h1>
            <p className="text-gray-400">
              Earn achievements as you progress through altitude zones
            </p>
          </div>
          <AchievementsContent />
        </div>
      </main>
      <Footer />
    </>
  );
}
