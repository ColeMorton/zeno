'use client';

import { useState, useCallback } from 'react';
import { AchievementStep, type SelectedAchievement } from './steps/AchievementStep';
import { CollateralStep } from './steps/CollateralStep';
import { ApprovalStep } from './steps/ApprovalStep';
import { MintStep } from './steps/MintStep';
import { MintSuccess } from './MintSuccess';

type Step = 'achievement' | 'collateral' | 'approval' | 'mint' | 'success';

const STEP_CONFIG: Record<Step, { label: string; number: number }> = {
  achievement: { label: 'Select Achievement', number: 1 },
  collateral: { label: 'Enter Amount', number: 2 },
  approval: { label: 'Approve', number: 3 },
  mint: { label: 'Mint', number: 4 },
  success: { label: 'Complete', number: 4 },
};

function StepIndicator({ currentStep }: { currentStep: Step }) {
  const steps: Step[] = ['achievement', 'collateral', 'approval', 'mint'];
  const currentNumber = STEP_CONFIG[currentStep].number;

  return (
    <div className="flex items-center justify-center gap-2 mb-8">
      {steps.map((step, index) => {
        const config = STEP_CONFIG[step];
        const isActive = config.number === currentNumber;
        const isCompleted = config.number < currentNumber;

        return (
          <div key={step} className="flex items-center">
            <div
              className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium ${
                isActive
                  ? 'bg-mountain-summit text-black'
                  : isCompleted
                    ? 'bg-green-500 text-white'
                    : 'bg-gray-700 text-gray-400'
              }`}
            >
              {isCompleted ? '✓' : config.number}
            </div>
            {index < steps.length - 1 && (
              <div
                className={`w-12 h-0.5 mx-2 ${
                  isCompleted ? 'bg-green-500' : 'bg-gray-700'
                }`}
              />
            )}
          </div>
        );
      })}
    </div>
  );
}

export function MintStepper() {
  const [step, setStep] = useState<Step>('achievement');
  const [selectedAchievement, setSelectedAchievement] = useState<SelectedAchievement | null>(null);
  const [collateralAmount, setCollateralAmount] = useState<bigint>(0n);

  const handleAchievementSelect = (achievement: SelectedAchievement) => {
    setSelectedAchievement(achievement);
    setStep('collateral');
  };

  const handleCollateralConfirm = (amount: bigint) => {
    setCollateralAmount(amount);
    setStep('approval');
  };

  const handleAllApproved = useCallback(() => {
    setStep('mint');
  }, []);

  const handleMintSuccess = () => {
    setStep('success');
  };

  return (
    <div className="max-w-2xl mx-auto">
      {step !== 'success' && <StepIndicator currentStep={step} />}

      {step === 'achievement' && (
        <AchievementStep onSelect={handleAchievementSelect} />
      )}

      {step === 'collateral' && (
        <CollateralStep
          onConfirm={handleCollateralConfirm}
          onBack={() => setStep('achievement')}
        />
      )}

      {step === 'approval' && selectedAchievement && (
        <ApprovalStep
          collateralAmount={collateralAmount}
          onAllApproved={handleAllApproved}
          onBack={() => setStep('collateral')}
        />
      )}

      {step === 'mint' && selectedAchievement && (
        <MintStep
          achievement={selectedAchievement}
          collateralAmount={collateralAmount}
          onSuccess={handleMintSuccess}
          onBack={() => setStep('approval')}
        />
      )}

      {step === 'success' && selectedAchievement && (
        <MintSuccess
          achievementName={selectedAchievement.displayName}
        />
      )}
    </div>
  );
}
