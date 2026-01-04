'use client';

import { useState } from 'react';
import { useTrack } from '@/hooks/useTracks';
import { useCompleteLesson, useLessonStatus } from '@/hooks/useTrackProgress';
import { LessonViewer, LessonViewerSkeleton } from './LessonViewer';
import { QuizCard } from './QuizCard';
import { type TrackId, type TrackLesson } from '@/lib/education';

interface LessonItemProps {
  lesson: TrackLesson;
  trackId: TrackId;
  isActive: boolean;
  onSelect: () => void;
}

function LessonItem({ lesson, trackId, isActive, onSelect }: LessonItemProps) {
  const { isCompleted } = useLessonStatus(trackId, lesson.id);

  return (
    <button
      onClick={onSelect}
      className={`flex w-full items-center gap-3 rounded-lg border p-3 text-left transition-all ${
        isActive
          ? 'border-blue-500 bg-blue-500/10'
          : isCompleted
            ? 'border-green-700/50 bg-green-900/10 hover:border-green-600/50'
            : 'border-gray-700 bg-gray-800/30 hover:border-gray-600'
      }`}
    >
      <div
        className={`flex h-6 w-6 items-center justify-center rounded-full text-xs ${
          isCompleted
            ? 'bg-green-500 text-white'
            : 'border border-gray-600 bg-gray-800 text-gray-400'
        }`}
      >
        {isCompleted ? '✓' : ''}
      </div>
      <div className="flex-1 min-w-0">
        <p
          className={`truncate font-medium ${isCompleted ? 'text-green-300' : 'text-gray-200'}`}
        >
          {lesson.title}
        </p>
        <p className="truncate text-xs text-gray-500">{lesson.objective}</p>
      </div>
    </button>
  );
}

interface TrackProgressProps {
  trackId: TrackId;
  onBack: () => void;
}

export function TrackProgress({ trackId, onBack }: TrackProgressProps) {
  const { data: trackWithProgress, isLoading, error, refetch } = useTrack(trackId);
  const { completeLesson } = useCompleteLesson();
  const [selectedLessonId, setSelectedLessonId] = useState<string | null>(null);
  const [showQuiz, setShowQuiz] = useState(false);

  if (isLoading) {
    return (
      <div className="space-y-4">
        <div className="h-8 w-48 animate-pulse rounded bg-gray-700" />
        <LessonViewerSkeleton />
      </div>
    );
  }

  if (error || !trackWithProgress) {
    return (
      <div className="space-y-4">
        <button
          onClick={onBack}
          className="text-sm text-gray-400 hover:text-gray-200"
        >
          ← Back to tracks
        </button>
        <div className="rounded-lg border border-red-900/50 bg-red-900/20 p-4 text-red-400">
          Failed to load track: {error?.message || 'Track not found'}
        </div>
      </div>
    );
  }

  const { track, metadata, progressPercent, graduated, completedLessons } = trackWithProgress;
  const selectedLesson = selectedLessonId
    ? track.lessons.find((l) => l.id === selectedLessonId)
    : track.lessons[0];

  const handleQuizComplete = async (passed: boolean) => {
    if (passed && selectedLesson) {
      await completeLesson(trackId, selectedLesson.id);
      setShowQuiz(false);
      refetch();
    }
  };

  const isCurrentLessonCompleted = selectedLesson
    ? completedLessons.includes(selectedLesson.id)
    : false;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-4">
          <button
            onClick={onBack}
            className="text-sm text-gray-400 hover:text-gray-200"
          >
            ← Back
          </button>
          <div className="flex items-center gap-2">
            <span className="text-2xl">{metadata.icon}</span>
            <div>
              <h2 className="font-semibold text-gray-100">{metadata.name}</h2>
              <p className="text-sm text-gray-400">
                {progressPercent}% complete
                {graduated && <span className="ml-2 text-green-400">• Graduated</span>}
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Progress bar */}
      <div className="h-2 w-full overflow-hidden rounded-full bg-gray-700">
        <div
          className={`h-full transition-all ${graduated ? 'bg-green-500' : 'bg-blue-500'}`}
          style={{ width: `${progressPercent}%` }}
        />
      </div>

      {/* Main content */}
      <div className="grid gap-6 lg:grid-cols-3">
        {/* Lesson list */}
        <div className="space-y-2">
          <h3 className="text-sm font-medium text-gray-300">Lessons</h3>
          <div className="space-y-2">
            {track.lessons.map((lesson) => (
              <LessonItem
                key={lesson.id}
                lesson={lesson}
                trackId={trackId}
                isActive={selectedLesson?.id === lesson.id}
                onSelect={() => {
                  setSelectedLessonId(lesson.id);
                  setShowQuiz(false);
                }}
              />
            ))}
          </div>
        </div>

        {/* Lesson content */}
        <div className="lg:col-span-2">
          {selectedLesson && (
            <div className="space-y-4">
              {!showQuiz ? (
                <>
                  <LessonViewer
                    lesson={{
                      title: selectedLesson.title,
                      objective: selectedLesson.objective,
                      sections: selectedLesson.sections,
                    }}
                    defiConcept="identity"
                  />

                  {selectedLesson.practicalExercise && (
                    <div className="rounded-lg border border-yellow-700/50 bg-yellow-900/10 p-4">
                      <h4 className="font-medium text-yellow-400">Practical Exercise</h4>
                      <p className="mt-1 text-sm text-gray-300">
                        {selectedLesson.practicalExercise.description}
                      </p>
                      <p className="mt-2 text-xs text-gray-500">
                        Hint: {selectedLesson.practicalExercise.verificationHint}
                      </p>
                    </div>
                  )}

                  <div className="flex gap-3">
                    {isCurrentLessonCompleted ? (
                      <div className="flex items-center gap-2 rounded-lg bg-green-900/30 px-4 py-2 text-green-400">
                        ✓ Lesson completed
                      </div>
                    ) : (
                      <button
                        onClick={() => setShowQuiz(true)}
                        className="rounded-lg bg-blue-600 px-4 py-2 font-medium text-white transition-colors hover:bg-blue-500"
                      >
                        Take Quiz
                      </button>
                    )}
                  </div>
                </>
              ) : (
                <div className="space-y-4">
                  <button
                    onClick={() => setShowQuiz(false)}
                    className="text-sm text-gray-400 hover:text-gray-200"
                  >
                    ← Back to lesson
                  </button>
                  <QuizCard
                    quiz={selectedLesson.quiz}
                    achievementName={selectedLesson.title}
                    onComplete={(passed) => handleQuizComplete(passed)}
                  />
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Graduation standard */}
      <div className="rounded-lg border border-gray-700 bg-gray-800/30 p-4">
        <h3 className="text-sm font-medium text-gray-300">Graduation Standard</h3>
        <p className="mt-1 text-gray-400">{track.graduationStandard}</p>
        {graduated && (
          <p className="mt-2 text-sm text-green-400">
            ✓ You have achieved this standard
          </p>
        )}
      </div>
    </div>
  );
}

export function TrackProgressSkeleton() {
  return (
    <div className="space-y-6">
      <div className="flex items-center gap-4">
        <div className="h-4 w-12 animate-pulse rounded bg-gray-700" />
        <div className="h-8 w-48 animate-pulse rounded bg-gray-700" />
      </div>
      <div className="h-2 w-full animate-pulse rounded bg-gray-700" />
      <div className="grid gap-6 lg:grid-cols-3">
        <div className="space-y-2">
          {Array.from({ length: 5 }).map((_, i) => (
            <div key={i} className="h-16 animate-pulse rounded bg-gray-700" />
          ))}
        </div>
        <div className="lg:col-span-2">
          <LessonViewerSkeleton />
        </div>
      </div>
    </div>
  );
}
