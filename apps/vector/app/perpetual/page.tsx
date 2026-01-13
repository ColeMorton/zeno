'use client';

import { OpenPositionForm } from '@/components/perpetual/OpenPositionForm';
import { FundingRateDisplay } from '@/components/perpetual/FundingRateDisplay';
import { usePerpetualVault } from '@/hooks/usePerpetualVault';

export default function PerpetualPage() {
  const { priceFormatted, isLoading } = usePerpetualVault();

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold mb-2">Perpetual Trading</h1>
        <p className="text-vector-neutral">
          Open long or short positions with up to 5x leverage. No liquidations.
        </p>
      </div>

      <div className="grid lg:grid-cols-3 gap-6">
        {/* Trading Panel */}
        <div className="lg:col-span-2">
          <OpenPositionForm />
        </div>

        {/* Stats Panel */}
        <div className="space-y-4">
          {/* Current Price */}
          <div className="bg-vector-card border border-vector-border rounded-lg p-4">
            <div className="text-vector-muted text-sm mb-1">Current Price</div>
            <div className="text-xl font-mono">
              {isLoading ? '--' : priceFormatted?.toFixed(4) ?? '--'}
            </div>
          </div>

          {/* Funding Rate */}
          <FundingRateDisplay />
        </div>
      </div>
    </div>
  );
}
