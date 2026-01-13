'use client';

import { usePerpetualVault } from '@/hooks/usePerpetualVault';

export function FundingRateDisplay() {
  const {
    fundingRateFormatted,
    fundingRateBPS,
    longOIFormatted,
    shortOIFormatted,
    oiImbalancePercent,
    isLoading,
    error,
  } = usePerpetualVault();

  if (error) {
    const isNotConfigured = error.message.includes('not configured');
    return (
      <div className="bg-vector-card border border-vector-border rounded-lg p-6">
        <h3 className="text-sm text-vector-muted mb-4">Funding Rate</h3>
        <div className="text-vector-muted text-sm">
          {isNotConfigured
            ? 'Contracts not deployed. Configure addresses in .env.local'
            : error.message}
        </div>
      </div>
    );
  }

  const isPositiveFunding = fundingRateBPS !== undefined && fundingRateBPS > 0n;

  return (
    <div className="bg-vector-card border border-vector-border rounded-lg p-6">
      <h3 className="text-sm text-vector-muted mb-4">Funding Rate</h3>

      {/* Funding Rate */}
      <div className="mb-6">
        <div
          className={`text-2xl font-mono font-bold ${
            isPositiveFunding ? 'text-vector-danger' : 'text-vector-primary'
          }`}
        >
          {isLoading ? '--' : fundingRateFormatted ?? '--'}
        </div>
        <div className="text-xs text-vector-muted mt-1">
          {isPositiveFunding ? 'Longs pay Shorts' : 'Shorts pay Longs'}
        </div>
      </div>

      {/* OI Imbalance Bar */}
      <div className="space-y-2">
        <div className="flex justify-between text-xs text-vector-muted">
          <span>Long OI</span>
          <span>Short OI</span>
        </div>
        <div className="relative h-2 bg-vector-surface rounded-full overflow-hidden">
          <div
            className="absolute left-0 top-0 h-full bg-vector-primary transition-all"
            style={{
              width: oiImbalancePercent !== undefined
                ? `${Math.max(0, 50 + oiImbalancePercent / 2)}%`
                : '50%',
            }}
          />
          <div
            className="absolute right-0 top-0 h-full bg-vector-danger transition-all"
            style={{
              width: oiImbalancePercent !== undefined
                ? `${Math.max(0, 50 - oiImbalancePercent / 2)}%`
                : '50%',
            }}
          />
        </div>
        <div className="flex justify-between text-xs font-mono">
          <span className="text-vector-primary">
            {isLoading ? '--' : longOIFormatted ?? '--'}
          </span>
          <span className="text-vector-danger">
            {isLoading ? '--' : shortOIFormatted ?? '--'}
          </span>
        </div>
      </div>
    </div>
  );
}
