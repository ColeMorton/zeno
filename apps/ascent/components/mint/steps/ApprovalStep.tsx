'use client';

import { useEffect } from 'react';
import { useCbBtcApproval } from '@/hooks/useCbBtcApproval';
import { useAchievementApproval } from '@/hooks/useAchievementApproval';

interface ApprovalStepProps {
  collateralAmount: bigint;
  onAllApproved: () => void;
  onBack: () => void;
}

function ApprovalCard({
  title,
  description,
  isApproved,
  isPending,
  error,
  onApprove,
}: {
  title: string;
  description: string;
  isApproved: boolean;
  isPending: boolean;
  error: Error | null;
  onApprove: () => void;
}) {
  return (
    <div
      className={`p-6 rounded-xl border-2 ${
        isApproved
          ? 'border-green-500 bg-green-500/10'
          : 'border-gray-700 bg-gray-800/50'
      }`}
    >
      <div className="flex items-start justify-between mb-4">
        <div>
          <h3 className="text-lg font-semibold text-white">{title}</h3>
          <p className="text-sm text-gray-400">{description}</p>
        </div>
        {isApproved && (
          <span className="text-2xl text-green-500">&#10003;</span>
        )}
      </div>

      {error && (
        <p className="mb-4 text-sm text-red-400">{error.message}</p>
      )}

      {!isApproved && (
        <button
          onClick={onApprove}
          disabled={isPending}
          className="w-full px-6 py-3 bg-mountain-summit text-black font-semibold rounded-lg hover:bg-yellow-400 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {isPending ? 'Approving...' : 'Approve'}
        </button>
      )}
    </div>
  );
}

export function ApprovalStep({
  collateralAmount,
  onAllApproved,
  onBack,
}: ApprovalStepProps) {
  const cbBtcApproval = useCbBtcApproval(collateralAmount);
  const achievementApproval = useAchievementApproval();

  const allApproved = cbBtcApproval.isApproved && achievementApproval.isApproved;

  useEffect(() => {
    if (allApproved) {
      onAllApproved();
    }
  }, [allApproved, onAllApproved]);

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-white mb-2">
          Approve Transactions
        </h2>
        <p className="text-gray-400">
          Approve the protocol to transfer your assets. This is a one-time
          approval per token.
        </p>
      </div>

      <div className="grid gap-4">
        <ApprovalCard
          title="Approve cbBTC"
          description="Allow the Vault contract to transfer your cbBTC collateral"
          isApproved={cbBtcApproval.isApproved}
          isPending={cbBtcApproval.isPending}
          error={cbBtcApproval.error}
          onApprove={cbBtcApproval.approve}
        />

        <ApprovalCard
          title="Approve Achievement NFT"
          description="Allow the Vault contract to transfer your Achievement NFT"
          isApproved={achievementApproval.isApproved}
          isPending={achievementApproval.isPending}
          error={achievementApproval.error}
          onApprove={achievementApproval.approve}
        />
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
