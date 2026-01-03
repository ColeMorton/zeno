'use client';

import { useState, useEffect } from 'react';
import { LessonViewer, LessonViewerSkeleton } from './LessonViewer';
import { QuizCard, QuizCardSkeleton } from './QuizCard';
import { UnlockGuide } from './UnlockGuide';
import {
  type AchievementContent,
  getAchievementContent,
  CATEGORY_ICONS,
} from '@/lib/education';

type AchievementStatus = 'locked' | 'available' | 'claimed';

interface AchievementDetailModalProps {
  achievementName: string;
  category: string;
  status: AchievementStatus;
  prerequisites?: string[];
  onClose: () => void;
  onQuizComplete?: (passed: boolean) => void;
}

type TabType = 'lesson' | 'quiz';

export function AchievementDetailModal({
  achievementName,
  category,
  status,
  prerequisites,
  onClose,
  onQuizComplete,
}: AchievementDetailModalProps) {
  const [content, setContent] = useState<AchievementContent | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<TabType>('lesson');
  const [lessonComplete, setLessonComplete] = useState(false);
  const [quizPassed, setQuizPassed] = useState(false);

  useEffect(() => {
    async function loadContent() {
      setIsLoading(true);
      const data = await getAchievementContent(achievementName);
      setContent(data);
      setIsLoading(false);
    }
    loadContent();
  }, [achievementName]);

  const handleLessonComplete = () => {
    setLessonComplete(true);
    setActiveTab('quiz');
  };

  const handleQuizComplete = (passed: boolean, _score: number) => {
    if (passed) {
      setQuizPassed(true);
      onQuizComplete?.(passed);
    }
  };

  const icon = CATEGORY_ICONS[category] ?? '📋';

  // If locked, show unlock guide
  if (status === 'locked' && content) {
    return (
      <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80">
        <div className="relative w-full max-w-2xl max-h-[90vh] overflow-y-auto rounded-xl bg-gray-900 border border-gray-700">
          {/* Close button */}
          <button
            onClick={onClose}
            className="absolute top-4 right-4 text-gray-400 hover:text-white"
          >
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>

          <div className="p-6">
            <UnlockGuide
              achievementName={achievementName.replace(/_/g, ' ')}
              category={category}
              defiConcept={content.defiConcept}
              unlockHint={content.unlockHint}
              prerequisites={prerequisites}
            />
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80">
      <div className="relative w-full max-w-2xl max-h-[90vh] overflow-y-auto rounded-xl bg-gray-900 border border-gray-700">
        {/* Close button */}
        <button
          onClick={onClose}
          className="absolute top-4 right-4 text-gray-400 hover:text-white z-10"
        >
          <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>

        {/* Header */}
        <div className="p-6 border-b border-gray-700">
          <div className="flex items-center gap-4">
            <span className="text-4xl">{icon}</span>
            <div>
              <h2 className="text-xl font-bold text-white">
                {achievementName.replace(/_/g, ' ')}
              </h2>
              <div className="flex items-center gap-2 text-sm">
                <span className="text-gray-400">{category}</span>
                {status === 'claimed' && (
                  <span className="px-2 py-0.5 rounded-full bg-mountain-summit/20 text-mountain-summit text-xs">
                    Claimed
                  </span>
                )}
                {quizPassed && (
                  <span className="px-2 py-0.5 rounded-full bg-green-500/20 text-green-400 text-xs">
                    Quiz Passed
                  </span>
                )}
              </div>
            </div>
          </div>
        </div>

        {/* Tabs */}
        <div className="flex border-b border-gray-700">
          <button
            onClick={() => setActiveTab('lesson')}
            className={`flex-1 py-3 text-sm font-medium transition-colors ${
              activeTab === 'lesson'
                ? 'text-white border-b-2 border-blue-500'
                : 'text-gray-400 hover:text-white'
            }`}
          >
            Lesson {lessonComplete && '✓'}
          </button>
          <button
            onClick={() => setActiveTab('quiz')}
            className={`flex-1 py-3 text-sm font-medium transition-colors ${
              activeTab === 'quiz'
                ? 'text-white border-b-2 border-blue-500'
                : 'text-gray-400 hover:text-white'
            }`}
          >
            Quiz {quizPassed && '✓'}
          </button>
        </div>

        {/* Content */}
        <div className="p-6">
          {isLoading ? (
            activeTab === 'lesson' ? (
              <LessonViewerSkeleton />
            ) : (
              <QuizCardSkeleton />
            )
          ) : content ? (
            activeTab === 'lesson' ? (
              <LessonViewer
                lesson={content.lesson}
                defiConcept={content.defiConcept}
                onComplete={handleLessonComplete}
              />
            ) : (
              <QuizCard
                quiz={content.quiz}
                achievementName={achievementName}
                onComplete={handleQuizComplete}
              />
            )
          ) : (
            <div className="text-center py-8 text-gray-400">
              Content not available for this achievement.
            </div>
          )}
        </div>

        {/* Next Steps (shown after quiz passed) */}
        {quizPassed && content?.nextSteps && (
          <div className="p-6 border-t border-gray-700 bg-gray-800/50">
            <h4 className="text-sm font-semibold text-gray-300 mb-2">Next Steps</h4>
            <ul className="space-y-1">
              {content.nextSteps.map((step, i) => (
                <li key={i} className="text-sm text-gray-400 flex items-start gap-2">
                  <span className="text-green-400">→</span>
                  {step}
                </li>
              ))}
            </ul>
          </div>
        )}
      </div>
    </div>
  );
}
