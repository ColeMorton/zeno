'use client';

import { useEffect } from 'react';
import { formatUnits } from 'viem';
import { useVaultMint } from '@/hooks/useVaultMint';
import type { SelectedAchievement } from './AchievementStep';

interface MintStepProps {
  achievement: SelectedAchievement;
  collateralAmount: bigint;
  onSuccess: () => void;
  onBack: () => void;
}

export function MintStep({
  achievement,
  collateralAmount,
  onSuccess,
  onBack,
}: MintStepProps) {
  const { mint, isPending, isSuccess, txHash, receipt, error } = useVaultMint();

  useEffect(() => {
    if (isSuccess && receipt) {
      onSuccess();
    }
  }, [isSuccess, receipt, onSuccess]);

  const handleMint = () => {
    mint({
      achievementType: achievement.achievementType,
      collateralAmount,
    });
  };

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-white mb-2">Mint Your Vault</h2>
        <p className="text-gray-400">
          Review and confirm your Vault creation.
        </p>
      </div>

      <div className="bg-gray-800/50 rounded-xl p-6 border border-gray-700 space-y-4">
        <div className="flex justify-between">
          <span className="text-gray-400">Achievement</span>
          <span className="text-white font-medium">{achievement.displayName}</span>
        </div>
        <div className="flex justify-between">
          <span className="text-gray-400">Collateral</span>
          <span className="text-white font-mono">
            {formatUnits(collateralAmount, 8)} cbBTC
          </span>
        </div>
        <div className="flex justify-between">
          <span className="text-gray-400">Vesting Period</span>
          <span className="text-white">1129 days</span>
        </div>
        <div className="flex justify-between">
          <span className="text-gray-400">Withdrawal Rate</span>
          <span className="text-white">1% / month (after vesting)</span>
        </div>
      </div>

      {error && (
        <div className="p-4 bg-red-500/10 border border-red-500 rounded-lg">
          <p className="text-sm text-red-400">{error.message}</p>
        </div>
      )}

      {txHash && !isSuccess && (
        <div className="p-4 bg-blue-500/10 border border-blue-500 rounded-lg">
          <p className="text-sm text-blue-400">
            Transaction submitted. Waiting for confirmation...
          </p>
          <p className="text-xs text-gray-400 font-mono mt-1 truncate">
            {txHash}
          </p>
        </div>
      )}

      <div className="flex gap-4">
        <button
          onClick={onBack}
          disabled={isPending}
          className="px-6 py-3 border border-gray-600 text-gray-300 rounded-lg hover:bg-gray-800 transition-colors disabled:opacity-50"
        >
          Back
        </button>
        <button
          onClick={handleMint}
          disabled={isPending}
          className="flex-1 px-8 py-3 bg-mountain-summit text-black font-semibold rounded-lg hover:bg-yellow-400 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {isPending ? 'Minting...' : 'Mint Vault'}
        </button>
      </div>
    </div>
  );
}
