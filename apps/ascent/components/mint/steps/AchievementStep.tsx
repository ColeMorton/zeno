'use client';

import { CHAPTER_1_ACHIEVEMENTS, type Chapter1Achievement } from '@/lib/chapters';
import { ACHIEVEMENT_TYPES, ACHIEVEMENT_DISPLAY_NAMES, type AchievementName } from '@/lib/achievements';

export interface SelectedAchievement {
  name: AchievementName;
  displayName: string;
  description: string;
  achievementType: `0x${string}`;
}

interface AchievementStepProps {
  onSelect: (achievement: SelectedAchievement) => void;
}

// Category icons for Chapter 1 achievements
const CATEGORY_ICONS: Record<string, string> = {
  Registration: '📝',
  Milestone: '🎯',
  Activity: '⚡',
  Identity: '🔑',
  Referral: '👥',
  Preparation: '🛠️',
  Consistency: '📊',
  Commitment: '🤝',
  Learning: '📚',
  Completion: '🏆',
};

function AchievementCard({
  achievement,
  onSelect,
}: {
  achievement: Chapter1Achievement;
  onSelect: () => void;
}) {
  const icon = CATEGORY_ICONS[achievement.category] ?? '⭐';
  const displayName = ACHIEVEMENT_DISPLAY_NAMES[achievement.name as AchievementName] ?? achievement.name;

  return (
    <button
      onClick={onSelect}
      className="w-full p-6 rounded-xl border-2 border-gray-700 bg-gray-800/50 hover:border-mountain-summit hover:bg-gray-800 transition-all text-left"
    >
      <div className="flex items-start gap-4">
        <span className="text-3xl">{icon}</span>
        <div className="flex-1">
          <div className="flex items-center gap-2 mb-1">
            <span className="text-xs text-gray-500">Week {achievement.week}</span>
            <span className="text-xs text-gray-600">•</span>
            <span className="text-xs text-gray-500">{achievement.category}</span>
          </div>
          <div className="text-lg font-bold text-white">{displayName}</div>
          <div className="text-sm text-gray-400 mt-1">{achievement.description}</div>
        </div>
      </div>
    </button>
  );
}


export function AchievementStep({ onSelect }: AchievementStepProps) {
  // For now, show all Chapter 1 achievements as available
  // TODO: Filter based on actual eligibility once contract integration is complete
  const availableAchievements = CHAPTER_1_ACHIEVEMENTS;

  const handleSelect = (achievement: Chapter1Achievement) => {
    const name = achievement.name as AchievementName;
    const achievementType = ACHIEVEMENT_TYPES[name];

    if (!achievementType) {
      console.error(`Unknown achievement type: ${name}`);
      return;
    }

    onSelect({
      name,
      displayName: ACHIEVEMENT_DISPLAY_NAMES[name],
      description: achievement.description,
      achievementType,
    });
  };

  if (availableAchievements.length === 0) {
    return (
      <div className="text-center py-12">
        <span className="text-6xl mb-6 block">🏔️</span>
        <h2 className="text-2xl font-bold text-white mb-4">
          No Achievements Available
        </h2>
        <p className="text-gray-400 max-w-md mx-auto">
          Complete Chapter 1 objectives to unlock achievements that can be
          minted into Vaults.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-white mb-2">
          Select Your Achievement
        </h2>
        <p className="text-gray-400">
          Choose which Chapter 1 achievement to mint into your Vault. You have{' '}
          {availableAchievements.length} achievement
          {availableAchievements.length !== 1 ? 's' : ''} available.
        </p>
      </div>
      <div className="grid gap-4 md:grid-cols-2">
        {availableAchievements.map((achievement) => (
          <AchievementCard
            key={achievement.name}
            achievement={achievement}
            onSelect={() => handleSelect(achievement)}
          />
        ))}
      </div>
    </div>
  );
}

// Keep TreasureStep as an alias for backwards compatibility
export { AchievementStep as TreasureStep };
