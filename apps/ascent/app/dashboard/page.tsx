'use client';

import { useAccount } from 'wagmi';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { Header } from '@/components/layout/Header';
import { Footer } from '@/components/layout/Footer';
import { useVaults } from '@/hooks/useVaults';
import {
  AltitudeProgress,
  AltitudeProgressSkeleton,
} from '@/components/dashboard/AltitudeProgress';
import { VaultCard, VaultCardSkeleton } from '@/components/dashboard/VaultCard';
import { ActiveChapterCard, ActiveChapterCardSkeleton } from '@/components/chapters';

function DashboardContent() {
  const { isConnected } = useAccount();
  const { data: vaults, isLoading, error } = useVaults();

  if (!isConnected) {
    return (
      <div className="min-h-[60vh] flex flex-col items-center justify-center text-center px-6">
        <span className="text-6xl mb-6">⛰️</span>
        <h2 className="text-2xl font-bold text-white mb-4">
          Connect to View Your Journey
        </h2>
        <p className="text-gray-400 mb-8 max-w-md">
          Connect your wallet to view your altitude, track achievements, and see
          your position on the mountain.
        </p>
        <ConnectButton />
      </div>
    );
  }

  if (isLoading) {
    return (
      <div className="space-y-6">
        <div className="grid gap-6 lg:grid-cols-2">
          <AltitudeProgressSkeleton />
          <VaultCardSkeleton />
        </div>
        <ActiveChapterCardSkeleton />
      </div>
    );
  }

  if (error) {
    return (
      <div className="text-center py-12">
        <span className="text-4xl mb-4 block">⚠️</span>
        <h2 className="text-xl font-bold text-white mb-2">Error Loading Data</h2>
        <p className="text-gray-400">{error.message}</p>
      </div>
    );
  }

  if (!vaults || vaults.length === 0) {
    return (
      <div className="min-h-[60vh] flex flex-col items-center justify-center text-center px-6">
        <span className="text-6xl mb-6">🏔️</span>
        <h2 className="text-2xl font-bold text-white mb-4">
          No Vaults Found
        </h2>
        <p className="text-gray-400 mb-8 max-w-md">
          You don&apos;t have any vaults yet. Mint a Vault NFT to begin your
          ascent.
        </p>
        <a
          href="/mint"
          className="px-8 py-4 bg-mountain-summit text-black font-semibold rounded-lg hover:bg-yellow-400 transition-colors"
        >
          Mint Your First Vault
        </a>
      </div>
    );
  }

  const primaryVault = vaults[0];

  return (
    <div className="space-y-8">
      {/* Primary vault altitude display */}
      <div className="grid gap-6 lg:grid-cols-2">
        <AltitudeProgress vault={primaryVault} />

        {/* Quick stats */}
        <div className="bg-gray-800/50 rounded-xl p-6 border border-gray-700">
          <h2 className="text-xl font-semibold text-white mb-6">Quick Stats</h2>
          <div className="grid grid-cols-2 gap-6">
            <div>
              <div className="text-3xl font-bold text-white">{vaults.length}</div>
              <div className="text-gray-400">Total Vaults</div>
            </div>
            <div>
              <div className="text-3xl font-bold text-mountain-summit">
                {vaults.reduce(
                  (sum, v) => sum + Number(v.collateralAmount) / 1e8,
                  0
                ).toFixed(4)}
              </div>
              <div className="text-gray-400">Total BTC</div>
            </div>
          </div>
        </div>
      </div>

      {/* Active Chapter */}
      <ActiveChapterCard />

      {/* All vaults */}
      <div>
        <h2 className="text-xl font-semibold text-white mb-4">Your Vaults</h2>
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {vaults.map((vault) => (
            <VaultCard key={vault.tokenId.toString()} vault={vault} />
          ))}
        </div>
      </div>
    </div>
  );
}

export default function DashboardPage() {
  return (
    <>
      <Header />
      <main className="min-h-screen pt-24 pb-16 px-6 bg-gradient-to-b from-black to-gray-900">
        <div className="max-w-7xl mx-auto">
          <div className="mb-8">
            <h1 className="text-3xl font-bold text-white mb-2">Dashboard</h1>
            <p className="text-gray-400">Track your journey to the summit</p>
          </div>
          <DashboardContent />
        </div>
      </main>
      <Footer />
    </>
  );
}
