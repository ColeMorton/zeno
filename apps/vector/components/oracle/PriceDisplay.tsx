'use client';

import { useVBTCPrice } from '@/hooks/useVBTCPrice';

/**
 * Displays the current vBTC/cbBTC price and discount from the Curve pool.
 */
export function PriceDisplay() {
  const { priceFormatted, discountPercent, isLoading, error } = useVBTCPrice();

  if (error) {
    return (
      <div className="bg-vector-card border border-vector-border rounded-lg p-6">
        <div className="text-vector-danger text-sm">
          Price unavailable: {error.message}
        </div>
      </div>
    );
  }

  return (
    <div className="bg-vector-card border border-vector-border rounded-lg p-6">
      <h3 className="text-sm text-vector-muted mb-4">vBTC / cbBTC</h3>

      <div className="space-y-4">
        {/* Price */}
        <div>
          <div className="text-2xl font-mono font-bold">
            {isLoading || priceFormatted === undefined ? (
              <span className="text-vector-muted">--</span>
            ) : (
              priceFormatted.toFixed(4)
            )}
          </div>
          <div className="text-xs text-vector-muted mt-1">Oracle Price (EMA)</div>
        </div>

        {/* Discount */}
        <div className="flex items-center justify-between pt-4 border-t border-vector-border">
          <span className="text-sm text-vector-muted">Discount</span>
          <span
            className={`font-mono text-lg ${
              discountPercent !== undefined && discountPercent > 0
                ? 'text-vector-primary'
                : 'text-vector-neutral'
            }`}
          >
            {isLoading || discountPercent === undefined ? (
              '--'
            ) : (
              `${discountPercent.toFixed(2)}%`
            )}
          </span>
        </div>
      </div>
    </div>
  );
}
