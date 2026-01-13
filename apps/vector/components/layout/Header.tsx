'use client';

import Link from 'next/link';
import { ConnectButton } from '@rainbow-me/rainbowkit';

export function Header() {
  return (
    <header className="border-b border-vector-border">
      <div className="container mx-auto px-4 py-4 flex items-center justify-between">
        <div className="flex items-center gap-8">
          <Link href="/" className="text-xl font-bold text-vector-primary">
            Vector
          </Link>
          <nav className="hidden md:flex items-center gap-6">
            <Link
              href="/perpetual"
              className="text-vector-neutral hover:text-white transition-colors"
            >
              Perpetual
            </Link>
            <Link
              href="/yield"
              className="text-vector-neutral hover:text-white transition-colors"
            >
              Yield
            </Link>
            <Link
              href="/volatility"
              className="text-vector-neutral hover:text-white transition-colors"
            >
              Volatility
            </Link>
            <Link
              href="/positions"
              className="text-vector-neutral hover:text-white transition-colors"
            >
              Positions
            </Link>
          </nav>
        </div>
        <ConnectButton />
      </div>
    </header>
  );
}
