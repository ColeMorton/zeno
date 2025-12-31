'use client';

import Link from 'next/link';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { cn } from '@/lib/utils';

interface HeaderProps {
  transparent?: boolean;
}

export function Header({ transparent = false }: HeaderProps) {
  return (
    <header
      className={cn(
        'fixed top-0 left-0 right-0 z-50 px-6 py-4',
        transparent ? 'bg-transparent' : 'bg-black/80 backdrop-blur-md'
      )}
    >
      <nav className="max-w-7xl mx-auto flex items-center justify-between">
        <Link href="/" className="flex items-center gap-2">
          <span className="text-2xl">⛰️</span>
          <span className="font-bold text-xl text-white">The Ascent</span>
        </Link>

        <div className="hidden md:flex items-center gap-8">
          <Link
            href="/mint"
            className="text-gray-300 hover:text-white transition-colors"
          >
            Mint
          </Link>
          <Link
            href="/dashboard"
            className="text-gray-300 hover:text-white transition-colors"
          >
            Dashboard
          </Link>
          <Link
            href="/achievements"
            className="text-gray-300 hover:text-white transition-colors"
          >
            Achievements
          </Link>
          <Link
            href="/leaderboard"
            className="text-gray-300 hover:text-white transition-colors"
          >
            Leaderboard
          </Link>
        </div>

        <ConnectButton
          chainStatus="none"
          showBalance={false}
          accountStatus={{
            smallScreen: 'avatar',
            largeScreen: 'full',
          }}
        />
      </nav>
    </header>
  );
}
