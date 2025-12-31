'use client';

import { useState } from 'react';
import { parseUnits } from 'viem';
import { useCbBtcBalance } from '@/hooks/useCbBtcBalance';

interface CollateralStepProps {
  onConfirm: (amount: bigint) => void;
  onBack: () => void;
}

export function CollateralStep({ onConfirm, onBack }: CollateralStepProps) {
  const [inputValue, setInputValue] = useState('');
  const { data: balance, isLoading } = useCbBtcBalance();

  const parsedAmount = inputValue ? parseUnits(inputValue, 8) : 0n;
  const hasBalance = balance && balance.raw > 0n;
  const exceedsBalance = balance && parsedAmount > balance.raw;
  const isValidAmount = parsedAmount > 0n && !exceedsBalance;

  const handleMax = () => {
    if (balance) {
      setInputValue(balance.formatted);
    }
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (isValidAmount) {
      onConfirm(parsedAmount);
    }
  };

  if (isLoading) {
    return (
      <div className="space-y-6">
        <div>
          <h2 className="text-2xl font-bold text-white mb-2">
            Enter Collateral Amount
          </h2>
          <p className="text-gray-400">Loading balance...</p>
        </div>
        <div className="h-24 bg-gray-800/50 rounded-xl animate-pulse" />
      </div>
    );
  }

  if (!hasBalance) {
    return (
      <div className="space-y-6">
        <div>
          <h2 className="text-2xl font-bold text-white mb-2">
            Insufficient cbBTC Balance
          </h2>
          <p className="text-gray-400">
            You need cbBTC to mint a Vault. Your current balance is 0 cbBTC.
          </p>
        </div>
        <button
          onClick={onBack}
          className="px-6 py-3 border border-gray-600 text-gray-300 rounded-lg hover:bg-gray-800 transition-colors"
        >
          Back
        </button>
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-white mb-2">
          Enter Collateral Amount
        </h2>
        <p className="text-gray-400">
          How much cbBTC would you like to lock in your Vault?
        </p>
      </div>

      <div className="bg-gray-800/50 rounded-xl p-6 border border-gray-700">
        <div className="flex items-center justify-between mb-2">
          <label htmlFor="amount" className="text-sm text-gray-400">
            Amount
          </label>
          <span className="text-sm text-gray-400">
            Balance: {balance?.formatted} cbBTC
          </span>
        </div>
        <div className="flex items-center gap-4">
          <input
            id="amount"
            type="text"
            inputMode="decimal"
            placeholder="0.0"
            value={inputValue}
            onChange={(e) => setInputValue(e.target.value)}
            className="flex-1 bg-transparent text-3xl font-bold text-white outline-none placeholder:text-gray-600"
          />
          <button
            type="button"
            onClick={handleMax}
            className="px-3 py-1 bg-gray-700 text-sm text-gray-300 rounded hover:bg-gray-600 transition-colors"
          >
            Max
          </button>
          <span className="text-xl text-gray-400">cbBTC</span>
        </div>
        {exceedsBalance && (
          <p className="mt-2 text-sm text-red-400">
            Amount exceeds your balance
          </p>
        )}
      </div>

      <div className="flex gap-4">
        <button
          type="button"
          onClick={onBack}
          className="px-6 py-3 border border-gray-600 text-gray-300 rounded-lg hover:bg-gray-800 transition-colors"
        >
          Back
        </button>
        <button
          type="submit"
          disabled={!isValidAmount}
          className="flex-1 px-8 py-3 bg-mountain-summit text-black font-semibold rounded-lg hover:bg-yellow-400 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        >
          Continue
        </button>
      </div>
    </form>
  );
}
