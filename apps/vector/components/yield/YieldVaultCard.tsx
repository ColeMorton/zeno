'use client';

import { formatUnits } from 'viem';
import { useYieldVault } from '@/hooks/useYieldVault';

const VBTC_DECIMALS = 8;

export function YieldVaultCard() {
  const { totalAssets, totalSupply, exchangeRate, isLoading, error } = useYieldVault();

  if (error) {
    const isNotConfigured = error.message.includes('not configured');
    return (
      <div className="bg-vector-card border border-vector-border rounded-lg p-6">
        <div className="flex items-center gap-3 mb-6">
          <div className="w-4 h-4 rounded-full bg-position-yield" />
          <h2 className="text-xl font-semibold">yvBTC Vault</h2>
        </div>
        <div className="text-vector-muted text-sm">
          {isNotConfigured
            ? 'Contracts not deployed. Configure addresses in .env.local'
            : error.message}
        </div>
      </div>
    );
  }

  const totalAssetsFormatted = totalAssets !== undefined
    ? Number(formatUnits(totalAssets, VBTC_DECIMALS)).toFixed(4)
    : '--';

  const totalSupplyFormatted = totalSupply !== undefined
    ? Number(formatUnits(totalSupply, VBTC_DECIMALS)).toFixed(4)
    : '--';

  const exchangeRateFormatted = exchangeRate !== undefined
    ? exchangeRate.toFixed(6)
    : '--';

  return (
    <div className="bg-vector-card border border-vector-border rounded-lg p-6">
      <div className="flex items-center gap-3 mb-6">
        <div className="w-4 h-4 rounded-full bg-position-yield" />
        <h2 className="text-xl font-semibold">yvBTC Vault</h2>
      </div>

      <div className="space-y-4">
        <div className="flex justify-between">
          <span className="text-vector-muted">Exchange Rate</span>
          <span className="font-mono">
            {isLoading ? (
              <span className="text-vector-muted">...</span>
            ) : (
              exchangeRateFormatted
            )}
          </span>
        </div>

        <div className="flex justify-between">
          <span className="text-vector-muted">Total Assets (vBTC)</span>
          <span className="font-mono">
            {isLoading ? (
              <span className="text-vector-muted">...</span>
            ) : (
              totalAssetsFormatted
            )}
          </span>
        </div>

        <div className="flex justify-between">
          <span className="text-vector-muted">Total Shares (yvBTC)</span>
          <span className="font-mono">
            {isLoading ? (
              <span className="text-vector-muted">...</span>
            ) : (
              totalSupplyFormatted
            )}
          </span>
        </div>

        <div className="pt-4 border-t border-vector-border">
          <div className="flex justify-between">
            <span className="text-vector-muted">Strategy</span>
            <span className="text-position-yield font-medium">Curve LP</span>
          </div>
        </div>
      </div>
    </div>
  );
}
