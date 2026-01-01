'use client';

import { useAccount } from 'wagmi';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { Header } from '@/components/layout/Header';
import { Footer } from '@/components/layout/Footer';
import { ChapterOverview } from '@/components/chapters';
import { getCurrentQuarter } from '@/lib/chapters';

function ChaptersContent() {
  const { isConnected } = useAccount();

  if (!isConnected) {
    return (
      <div className="text-center py-12">
        <span className="text-6xl mb-6 block">🗺️</span>
        <h2 className="text-2xl font-bold text-white mb-4">
          Connect to View Chapters
        </h2>
        <p className="text-gray-400 mb-8">
          Connect your wallet to see your chapter progress and available achievements.
        </p>
        <ConnectButton />
      </div>
    );
  }

  return <ChapterOverview />;
}

export default function ChaptersPage() {
  const { year, quarter } = getCurrentQuarter();

  return (
    <>
      <Header />
      <main className="min-h-screen pt-24 pb-16 px-6 bg-gradient-to-b from-black to-gray-900">
        <div className="max-w-7xl mx-auto">
          <div className="mb-8">
            <div className="flex items-center justify-between flex-wrap gap-4">
              <div>
                <h1 className="text-3xl font-bold text-white mb-2">
                  The Ascent: Chapters
                </h1>
                <p className="text-gray-400">
                  12 chapters spanning your 1129-day journey. Each chapter unlocks
                  exclusive achievements during its calendar quarter.
                </p>
              </div>
              <div className="bg-gray-800/50 px-4 py-2 rounded-lg border border-gray-700">
                <span className="text-sm text-gray-500">Current Quarter: </span>
                <span className="text-white font-semibold">
                  {year} Q{quarter}
                </span>
              </div>
            </div>
          </div>
          <ChaptersContent />
        </div>
      </main>
      <Footer />
    </>
  );
}
