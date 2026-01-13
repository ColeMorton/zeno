'use client';

import Link from 'next/link';
import { useVBTCPrice } from '@/hooks/useVBTCPrice';

export default function HomePage() {
  const { priceFormatted, discountPercent, isLoading } = useVBTCPrice();

  return (
    <div className="space-y-12">
      {/* Hero */}
      <section className="text-center py-16">
        <h1 className="text-4xl md:text-5xl font-bold mb-4">
          vestedBTC Derivatives
        </h1>
        <p className="text-vector-neutral text-lg max-w-2xl mx-auto">
          Perpetual leverage, yield farming, and volatility exposure.
          Single collateral. No liquidations.
        </p>
      </section>

      {/* Product Cards */}
      <section className="grid md:grid-cols-3 gap-6">
        {/* Perpetual */}
        <Link
          href="/perpetual"
          className="bg-vector-card border border-vector-border rounded-lg p-6 hover:border-vector-primary transition-colors group"
        >
          <div className="flex items-center gap-3 mb-4">
            <div className="w-3 h-3 rounded-full bg-vector-primary" />
            <h2 className="text-xl font-semibold">Perpetual</h2>
          </div>
          <p className="text-vector-neutral mb-4">
            Long or short vBTC price with 1-5x leverage. OI-based funding rate.
            Enter and exit anytime.
          </p>
          <div className="flex items-center justify-between text-sm">
            <span className="text-vector-muted">Leverage</span>
            <span className="font-mono">1-5x</span>
          </div>
        </Link>

        {/* Yield */}
        <Link
          href="/yield"
          className="bg-vector-card border border-vector-border rounded-lg p-6 hover:border-position-yield transition-colors group"
        >
          <div className="flex items-center gap-3 mb-4">
            <div className="w-3 h-3 rounded-full bg-position-yield" />
            <h2 className="text-xl font-semibold">Yield</h2>
          </div>
          <p className="text-vector-neutral mb-4">
            Deposit vBTC to earn Curve LP fees and CRV rewards.
            Auto-compounding ERC-4626 vault.
          </p>
          <div className="flex items-center justify-between text-sm">
            <span className="text-vector-muted">Strategy</span>
            <span className="font-mono">Curve LP</span>
          </div>
        </Link>

        {/* Volatility */}
        <Link
          href="/volatility"
          className="bg-vector-card border border-vector-border rounded-lg p-6 hover:border-position-volLong transition-colors group"
        >
          <div className="flex items-center gap-3 mb-4">
            <div className="w-3 h-3 rounded-full bg-position-volLong" />
            <h2 className="text-xl font-semibold">Volatility</h2>
          </div>
          <p className="text-vector-neutral mb-4">
            Long or short volatility via socialized pools.
            Daily settlement based on realized variance.
          </p>
          <div className="flex items-center justify-between text-sm">
            <span className="text-vector-muted">Settlement</span>
            <span className="font-mono">Daily</span>
          </div>
        </Link>
      </section>

      {/* Stats */}
      <section className="bg-vector-card border border-vector-border rounded-lg p-6">
        <div className="grid md:grid-cols-4 gap-6 text-center">
          <div>
            <div className="text-vector-muted text-sm mb-1">vBTC Price</div>
            <div className="text-2xl font-mono">
              {isLoading || priceFormatted === undefined
                ? '--'
                : priceFormatted.toFixed(4)}
            </div>
          </div>
          <div>
            <div className="text-vector-muted text-sm mb-1">Discount</div>
            <div
              className={`text-2xl font-mono ${
                discountPercent !== undefined && discountPercent > 0
                  ? 'text-vector-primary'
                  : ''
              }`}
            >
              {isLoading || discountPercent === undefined
                ? '--'
                : `${discountPercent.toFixed(2)}%`}
            </div>
          </div>
          <div>
            <div className="text-vector-muted text-sm mb-1">Total TVL</div>
            <div className="text-2xl font-mono">--</div>
          </div>
          <div>
            <div className="text-vector-muted text-sm mb-1">Funding Rate</div>
            <div className="text-2xl font-mono">--</div>
          </div>
        </div>
      </section>
    </div>
  );
}
