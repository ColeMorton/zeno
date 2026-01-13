'use client';

import { YieldVaultCard } from '@/components/yield/YieldVaultCard';
import { DepositWithdrawForm } from '@/components/yield/DepositWithdrawForm';

export default function YieldPage() {
  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold mb-2">Yield Vault</h1>
        <p className="text-vector-neutral">
          Deposit vBTC to earn Curve LP fees and CRV rewards.
        </p>
      </div>

      <div className="grid lg:grid-cols-2 gap-6">
        <YieldVaultCard />
        <DepositWithdrawForm />
      </div>
    </div>
  );
}
