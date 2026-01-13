'use client';

import { useState } from 'react';
import { useAccount } from 'wagmi';
import { formatUnits } from 'viem';
import { useYieldVault } from '@/hooks/useYieldVault';
import { useVBTCBalance } from '@/hooks/useVBTCBalance';

const VBTC_DECIMALS = 8;

type Mode = 'deposit' | 'withdraw';

export function DepositWithdrawForm() {
  const { isConnected } = useAccount();
  const { balance: vbtcBalance } = useVBTCBalance();
  const {
    userShares,
    userAssetsFormatted,
    deposit,
    withdraw,
    redeem,
    previewDeposit,
    isPending,
    error: vaultError,
  } = useYieldVault();

  const [mode, setMode] = useState<Mode>('deposit');
  const [amount, setAmount] = useState('');
  const [txError, setTxError] = useState<string | null>(null);

  if (!isConnected) {
    return (
      <div className="bg-vector-card border border-vector-border rounded-lg p-6">
        <h2 className="text-lg font-semibold mb-4">Deposit / Withdraw</h2>
        <p className="text-vector-muted">Connect wallet to interact</p>
      </div>
    );
  }

  if (vaultError) {
    const isNotConfigured = vaultError.message.includes('not configured');
    return (
      <div className="bg-vector-card border border-vector-border rounded-lg p-6">
        <h2 className="text-lg font-semibold mb-4">Deposit / Withdraw</h2>
        <p className="text-vector-muted text-sm">
          {isNotConfigured
            ? 'Contracts not deployed. Configure addresses in .env.local'
            : vaultError.message}
        </p>
      </div>
    );
  }

  const maxDeposit = vbtcBalance !== undefined
    ? formatUnits(vbtcBalance, VBTC_DECIMALS)
    : '0';

  const maxWithdraw = userAssetsFormatted ?? '0';

  const handleMax = () => {
    setAmount(mode === 'deposit' ? maxDeposit : maxWithdraw);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setTxError(null);

    if (!amount || parseFloat(amount) <= 0) {
      setTxError('Enter a valid amount');
      return;
    }

    try {
      if (mode === 'deposit') {
        await deposit(amount);
      } else {
        // Use redeem with shares for withdrawals (simpler)
        if (userShares && userShares > 0n) {
          await redeem(formatUnits(userShares, VBTC_DECIMALS));
        } else {
          await withdraw(amount);
        }
      }
      setAmount('');
    } catch (err) {
      setTxError(err instanceof Error ? err.message : 'Transaction failed');
    }
  };

  const previewShares = mode === 'deposit' && amount
    ? previewDeposit(amount)
    : undefined;

  const previewSharesFormatted = previewShares !== undefined
    ? Number(formatUnits(previewShares, VBTC_DECIMALS)).toFixed(4)
    : '--';

  return (
    <div className="bg-vector-card border border-vector-border rounded-lg p-6">
      <h2 className="text-lg font-semibold mb-4">Deposit / Withdraw</h2>

      {/* Mode Toggle */}
      <div className="flex gap-2 mb-6">
        <button
          onClick={() => setMode('deposit')}
          className={`flex-1 py-2 px-4 rounded-lg font-medium transition-colors ${
            mode === 'deposit'
              ? 'bg-position-yield text-black'
              : 'bg-vector-surface text-vector-muted hover:text-white'
          }`}
        >
          Deposit
        </button>
        <button
          onClick={() => setMode('withdraw')}
          className={`flex-1 py-2 px-4 rounded-lg font-medium transition-colors ${
            mode === 'withdraw'
              ? 'bg-vector-primary text-black'
              : 'bg-vector-surface text-vector-muted hover:text-white'
          }`}
        >
          Withdraw
        </button>
      </div>

      <form onSubmit={handleSubmit} className="space-y-4">
        {/* Amount Input */}
        <div>
          <div className="flex justify-between text-sm mb-2">
            <span className="text-vector-muted">
              {mode === 'deposit' ? 'vBTC Balance' : 'Vault Balance'}
            </span>
            <button
              type="button"
              onClick={handleMax}
              className="text-vector-primary hover:underline"
            >
              Max: {mode === 'deposit' ? maxDeposit : maxWithdraw}
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

        {/* Preview */}
        {mode === 'deposit' && amount && (
          <div className="flex justify-between text-sm">
            <span className="text-vector-muted">You will receive</span>
            <span className="font-mono">{previewSharesFormatted} yvBTC</span>
          </div>
        )}

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
              : mode === 'deposit'
                ? 'bg-position-yield text-black hover:opacity-90'
                : 'bg-vector-primary text-black hover:opacity-90'
          }`}
        >
          {isPending ? 'Processing...' : mode === 'deposit' ? 'Deposit' : 'Withdraw'}
        </button>
      </form>
    </div>
  );
}
