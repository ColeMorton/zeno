'use client';

import { useAccount } from 'wagmi';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { Header } from '@/components/layout/Header';
import { Footer } from '@/components/layout/Footer';
import { MintStepper } from '@/components/mint/MintStepper';

function MintContent() {
  const { isConnected } = useAccount();

  if (!isConnected) {
    return (
      <div className="min-h-[60vh] flex flex-col items-center justify-center text-center px-6">
        <span className="text-6xl mb-6">⛰️</span>
        <h2 className="text-2xl font-bold text-white mb-4">
          Connect to Mint Your Vault
        </h2>
        <p className="text-gray-400 mb-8 max-w-md">
          Connect your wallet to begin your journey to the summit. You&apos;ll
          need an Achievement NFT and cbBTC to mint a Vault.
        </p>
        <ConnectButton />
      </div>
    );
  }

  return <MintStepper />;
}

export default function MintPage() {
  return (
    <>
      <Header />
      <main className="min-h-screen pt-24 pb-16 px-6 bg-gradient-to-b from-black to-gray-900">
        <div className="max-w-7xl mx-auto">
          <div className="mb-8 text-center">
            <h1 className="text-3xl font-bold text-white mb-2">
              Mint Your Vault
            </h1>
            <p className="text-gray-400">
              Lock your Achievement NFT and cbBTC to begin your ascent
            </p>
          </div>
          <MintContent />
        </div>
      </main>
      <Footer />
    </>
  );
}
