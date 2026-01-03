'use client';

import { useEffect } from 'react';
import { useCbBtcApproval } from '@/hooks/useCbBtcApproval';

interface ApprovalStepProps {
  collateralAmount: bigint;
  onAllApproved: () => void;
  onBack: () => void;
}

export function ApprovalStep({
  collateralAmount,
  onAllApproved,
  onBack,
}: ApprovalStepProps) {
  const cbBtcApproval = useCbBtcApproval(collateralAmount);

  useEffect(() => {
    if (cbBtcApproval.isApproved) {
      onAllApproved();
    }
  }, [cbBtcApproval.isApproved, onAllApproved]);

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-white mb-2">
          Approve cbBTC
        </h2>
        <p className="text-gray-400">
          Approve the protocol to transfer your cbBTC collateral. This is a one-time
          approval.
        </p>
      </div>

      <div
        className={`p-6 rounded-xl border-2 ${
          cbBtcApproval.isApproved
            ? 'border-green-500 bg-green-500/10'
            : 'border-gray-700 bg-gray-800/50'
        }`}
      >
        <div className="flex items-start justify-between mb-4">
          <div>
            <h3 className="text-lg font-semibold text-white">Approve cbBTC</h3>
            <p className="text-sm text-gray-400">
              Allow the Vault Mint Controller to transfer your cbBTC collateral
            </p>
          </div>
          {cbBtcApproval.isApproved && (
            <span className="text-2xl text-green-500">&#10003;</span>
          )}
        </div>

        {cbBtcApproval.error && (
          <p className="mb-4 text-sm text-red-400">{cbBtcApproval.error.message}</p>
        )}

        {!cbBtcApproval.isApproved && (
          <button
            onClick={cbBtcApproval.approve}
            disabled={cbBtcApproval.isPending}
            className="w-full px-6 py-3 bg-mountain-summit text-black font-semibold rounded-lg hover:bg-yellow-400 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {cbBtcApproval.isPending ? 'Approving...' : 'Approve'}
          </button>
        )}
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
