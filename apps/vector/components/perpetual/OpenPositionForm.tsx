'use client';

import { useState } from 'react';
import { useAccount } from 'wagmi';
import { useOpenPosition } from '@/hooks/useOpenPosition';
import { useVBTCBalance } from '@/hooks/useVBTCBalance';
import { usePerpetualVault } from '@/hooks/usePerpetualVault';
import { Side, calculateMaxPriceMove, calculateNotional } from '@/lib/perpetual';
import { parseUnits, formatUnits } from 'viem';

const VBTC_DECIMALS = 8;
const MIN_LEVERAGE = 100; // 1x
const MAX_LEVERAGE = 500; // 5x

export function OpenPositionForm() {
  const { isConnected } = useAccount();
  const { balance: vbtcBalance, balanceFormatted } = useVBTCBalance();
  const { openPosition, isPending, error: hookError } = useOpenPosition();
  const { priceFormatted, refetch: refetchVault, error: vaultError } = usePerpetualVault();

  const [side, setSide] = useState<Side>(Side.LONG);
  const [amount, setAmount] = useState('');
  const [leverageX100, setLeverageX100] = useState(100);
  const [txError, setTxError] = useState<string | null>(null);

  const contractError = hookError || vaultError;
  const isNotConfigured = contractError?.message.includes('not configured');

  if (!isConnected) {
    return (
      <div className="bg-vector-card border border-vector-border rounded-lg p-6">
        <h2 className="text-lg font-semibold mb-4">Open Position</h2>
        <p className="text-vector-muted">Connect wallet to trade</p>
      </div>
    );
  }

  if (isNotConfigured) {
    return (
      <div className="bg-vector-card border border-vector-border rounded-lg p-6">
        <h2 className="text-lg font-semibold mb-4">Open Position</h2>
        <p className="text-vector-muted">
          Contracts not deployed. Configure addresses in .env.local
        </p>
      </div>
    );
  }

  const maxAmount = balanceFormatted ?? '0';
  const leverage = leverageX100 / 100;
  const maxPriceMove = calculateMaxPriceMove(BigInt(leverageX100));

  const handleMax = () => {
    setAmount(maxAmount);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setTxError(null);

    if (!amount || parseFloat(amount) <= 0) {
      setTxError('Enter a valid amount');
      return;
    }

    try {
      await openPosition(amount, leverageX100, side);
      setAmount('');
      setLeverageX100(100);
      refetchVault();
    } catch (err) {
      setTxError(err instanceof Error ? err.message : 'Transaction failed');
    }
  };

  // Calculate notional preview
  let notionalPreview = '--';
  if (amount && parseFloat(amount) > 0) {
    const collateral = parseUnits(amount, VBTC_DECIMALS);
    const notional = calculateNotional(collateral, BigInt(leverageX100));
    notionalPreview = Number(formatUnits(notional, VBTC_DECIMALS)).toFixed(4);
  }

  return (
    <div className="bg-vector-card border border-vector-border rounded-lg p-6">
      <h2 className="text-lg font-semibold mb-4">Open Position</h2>

      {/* Side Toggle */}
      <div className="flex gap-2 mb-6">
        <button
          onClick={() => setSide(Side.LONG)}
          className={`flex-1 py-2 px-4 rounded-lg font-medium transition-colors ${
            side === Side.LONG
              ? 'bg-vector-primary text-black'
              : 'bg-vector-surface text-vector-muted hover:text-white'
          }`}
        >
          Long
        </button>
        <button
          onClick={() => setSide(Side.SHORT)}
          className={`flex-1 py-2 px-4 rounded-lg font-medium transition-colors ${
            side === Side.SHORT
              ? 'bg-vector-danger text-white'
              : 'bg-vector-surface text-vector-muted hover:text-white'
          }`}
        >
          Short
        </button>
      </div>

      <form onSubmit={handleSubmit} className="space-y-4">
        {/* Amount Input */}
        <div>
          <div className="flex justify-between text-sm mb-2">
            <span className="text-vector-muted">Collateral (vBTC)</span>
            <button
              type="button"
              onClick={handleMax}
              className="text-vector-primary hover:underline"
            >
              Max: {maxAmount}
            </button>
          </div>
          <input
            type="number"
            step="any"
            min="0"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="0.0"
            className="w-full bg-vector-surface border border-vector-border rounded-lg px-4 py-3 font-mono text-lg focus:outline-none focus:border-vector-primary"
          />
        </div>

        {/* Leverage Slider */}
        <div>
          <div className="flex justify-between text-sm mb-2">
            <span className="text-vector-muted">Leverage</span>
            <span className="font-mono">{leverage.toFixed(1)}x</span>
          </div>
          <input
            type="range"
            min={MIN_LEVERAGE}
            max={MAX_LEVERAGE}
            step={50}
            value={leverageX100}
            onChange={(e) => setLeverageX100(parseInt(e.target.value))}
            className="w-full accent-vector-primary"
          />
          <div className="flex justify-between text-xs text-vector-muted mt-1">
            <span>1x</span>
            <span>5x</span>
          </div>
        </div>

        {/* Position Preview */}
        <div className="bg-vector-surface rounded-lg p-4 space-y-2">
          <div className="flex justify-between text-sm">
            <span className="text-vector-muted">Notional</span>
            <span className="font-mono">{notionalPreview} vBTC</span>
          </div>
          <div className="flex justify-between text-sm">
            <span className="text-vector-muted">Entry Price</span>
            <span className="font-mono">{priceFormatted?.toFixed(4) ?? '--'}</span>
          </div>
          <div className="flex justify-between text-sm">
            <span className="text-vector-muted">Max Price Move</span>
            <span className="font-mono">±{maxPriceMove.toFixed(1)}%</span>
          </div>
        </div>

        {/* Error */}
        {txError && (
          <div className="text-vector-danger text-sm">{txError}</div>
        )}

        {/* Submit */}
        <button
          type="submit"
          disabled={isPending || !amount}
          className={`w-full py-3 px-4 rounded-lg font-semibold transition-colors ${
            isPending || !amount
              ? 'bg-vector-border text-vector-muted cursor-not-allowed'
              : side === Side.LONG
                ? 'bg-vector-primary text-black hover:opacity-90'
                : 'bg-vector-danger text-white hover:opacity-90'
          }`}
        >
          {isPending
            ? 'Processing...'
            : `Open ${side === Side.LONG ? 'Long' : 'Short'}`}
        </button>
      </form>
    </div>
  );
}
