'use client';

import { useRouter } from 'next/navigation';

interface MintSuccessProps {
  achievementName: string;
}

export function MintSuccess({ achievementName }: MintSuccessProps) {
  const router = useRouter();

  return (
    <div className="text-center py-12">
      <span className="text-6xl mb-6 block">🎉</span>
      <h2 className="text-3xl font-bold text-white mb-4">
        Vault Minted Successfully!
      </h2>
      <p className="text-gray-400 mb-2">Your journey to the summit begins now.</p>
      <p className="text-2xl font-bold text-mountain-summit mb-8">
        {achievementName}
      </p>

      <div className="bg-gray-800/50 rounded-xl p-6 border border-gray-700 max-w-md mx-auto mb-8">
        <h3 className="text-lg font-semibold text-white mb-4">What happens next?</h3>
        <ul className="text-left text-gray-400 space-y-3">
          <li className="flex items-start gap-3">
            <span className="text-mountain-summit">1.</span>
            <span>Your 1129-day vesting period has started</span>
          </li>
          <li className="flex items-start gap-3">
            <span className="text-mountain-summit">2.</span>
            <span>Track your altitude progress on the dashboard</span>
          </li>
          <li className="flex items-start gap-3">
            <span className="text-mountain-summit">3.</span>
            <span>After vesting, withdraw 1% of collateral monthly</span>
          </li>
        </ul>
      </div>

      <button
        onClick={() => router.push('/dashboard')}
        className="px-8 py-4 bg-mountain-summit text-black font-semibold rounded-lg hover:bg-yellow-400 transition-colors"
      >
        View Dashboard
      </button>
    </div>
  );
}
