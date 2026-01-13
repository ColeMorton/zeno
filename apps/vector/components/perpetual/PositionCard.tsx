'use client';

import { usePosition } from '@/hooks/usePosition';
import { useClosePosition } from '@/hooks/useClosePosition';
import { Side } from '@/lib/perpetual';

interface PositionCardProps {
  positionId: bigint;
  onClose?: () => void;
}

export function PositionCard({ positionId, onClose }: PositionCardProps) {
  const {
    position,
    collateralFormatted,
    notionalFormatted,
    entryPriceFormatted,
    leverageFormatted,
    pnlFormatted,
    payoutFormatted,
    pnlPercent,
    isProfitable,
    isLoading,
    error,
  } = usePosition(positionId);

  const { closePosition, isPending } = useClosePosition();

  if (error) {
    return (
      <div className="bg-vector-card border border-vector-border rounded-lg p-4">
        <div className="text-vector-danger text-sm">{error.message}</div>
      </div>
    );
  }

  if (isLoading || !position) {
    return (
      <div className="bg-vector-card border border-vector-border rounded-lg p-4">
        <div className="text-vector-muted">Loading...</div>
      </div>
    );
  }

  const isLong = position.side === Side.LONG;

  const handleClose = async () => {
    try {
      await closePosition(positionId);
      onClose?.();
    } catch (err) {
      console.error('Failed to close position:', err);
    }
  };

  return (
    <div className="bg-vector-card border border-vector-border rounded-lg p-4">
      {/* Header */}
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <div
            className={`w-3 h-3 rounded-full ${
              isLong ? 'bg-vector-primary' : 'bg-vector-danger'
            }`}
          />
          <span className="font-semibold">
            {isLong ? 'Long' : 'Short'} {leverageFormatted}
          </span>
        </div>
        <div className="text-xs text-vector-muted font-mono">
          #{positionId.toString()}
        </div>
      </div>

      {/* Position Details */}
      <div className="space-y-2 mb-4">
        <div className="flex justify-between text-sm">
          <span className="text-vector-muted">Collateral</span>
          <span className="font-mono">{collateralFormatted} vBTC</span>
        </div>
        <div className="flex justify-between text-sm">
          <span className="text-vector-muted">Notional</span>
          <span className="font-mono">{notionalFormatted} vBTC</span>
        </div>
        <div className="flex justify-between text-sm">
          <span className="text-vector-muted">Entry Price</span>
          <span className="font-mono">{entryPriceFormatted?.toFixed(4)}</span>
        </div>
      </div>

      {/* P&L */}
      <div className="bg-vector-surface rounded-lg p-3 mb-4">
        <div className="flex justify-between items-center">
          <span className="text-vector-muted text-sm">P&L</span>
          <div className="text-right">
            <div
              className={`font-mono font-semibold ${
                isProfitable ? 'text-vector-primary' : 'text-vector-danger'
              }`}
            >
              {isProfitable ? '+' : ''}
              {pnlFormatted} vBTC
            </div>
            {pnlPercent !== undefined && (
              <div
                className={`text-xs ${
                  isProfitable ? 'text-vector-primary' : 'text-vector-danger'
                }`}
              >
                {isProfitable ? '+' : ''}
                {pnlPercent.toFixed(2)}%
              </div>
            )}
          </div>
        </div>
        <div className="flex justify-between text-sm mt-2">
          <span className="text-vector-muted">Payout</span>
          <span className="font-mono">{payoutFormatted} vBTC</span>
        </div>
      </div>

      {/* Close Button */}
      <button
        onClick={handleClose}
        disabled={isPending}
        className={`w-full py-2 px-4 rounded-lg font-medium transition-colors ${
          isPending
            ? 'bg-vector-border text-vector-muted cursor-not-allowed'
            : 'bg-vector-surface text-white hover:bg-vector-border'
        }`}
      >
        {isPending ? 'Closing...' : 'Close Position'}
      </button>
    </div>
  );
}
