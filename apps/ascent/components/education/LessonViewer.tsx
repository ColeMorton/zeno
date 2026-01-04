'use client';

import { type Lesson, type LessonSection, CONCEPT_COLORS } from '@/lib/education';

interface LessonViewerProps {
  lesson: Lesson;
  defiConcept: string;
  onComplete?: () => void;
}

function TextSection({ content }: { content: string }) {
  return (
    <p className="text-gray-300 leading-relaxed">
      {content}
    </p>
  );
}

function KeyPointsSection({ points }: { points: string[] }) {
  return (
    <ul className="space-y-2">
      {points.map((point, i) => (
        <li key={i} className="flex items-start gap-3">
          <span className="text-green-400 mt-1">&#10003;</span>
          <span className="text-gray-300">{point}</span>
        </li>
      ))}
    </ul>
  );
}

function InfographicSection({ path }: { path: string }) {
  return (
    <div className="rounded-lg overflow-hidden bg-gray-800/50 p-4">
      <div className="text-center text-gray-500 text-sm">
        [Infographic: {path}]
      </div>
    </div>
  );
}

function VideoSection({ path }: { path: string }) {
  return (
    <div className="rounded-lg overflow-hidden bg-gray-800/50 aspect-video flex items-center justify-center">
      <div className="text-center text-gray-500 text-sm">
        [Video: {path}]
      </div>
    </div>
  );
}

function SectionRenderer({ section }: { section: LessonSection }) {
  switch (section.type) {
    case 'text':
      return <TextSection content={section.content as string} />;
    case 'keyPoints':
      return <KeyPointsSection points={section.content as string[]} />;
    case 'infographic':
      return <InfographicSection path={section.path ?? ''} />;
    case 'video':
      return <VideoSection path={section.path ?? ''} />;
    default:
      return null;
  }
}

export function LessonViewer({ lesson, defiConcept, onComplete }: LessonViewerProps) {
  const conceptColor = CONCEPT_COLORS[defiConcept] ?? '#4A90A4';

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="border-l-4 pl-4" style={{ borderColor: conceptColor }}>
        <h2 className="text-xl font-bold text-white mb-1">{lesson.title}</h2>
        <p className="text-sm text-gray-400">{lesson.objective}</p>
      </div>

      {/* Sections */}
      <div className="space-y-4">
        {lesson.sections.map((section, i) => (
          <div key={i} className="py-2">
            <SectionRenderer section={section} />
          </div>
        ))}
      </div>

      {/* Complete button */}
      {onComplete && (
        <button
          onClick={onComplete}
          className="w-full py-3 rounded-lg bg-green-600 hover:bg-green-500 text-white font-semibold transition-colors"
        >
          I&apos;ve read this lesson
        </button>
      )}
    </div>
  );
}

export function LessonViewerSkeleton() {
  return (
    <div className="space-y-6 animate-pulse">
      <div className="border-l-4 border-gray-700 pl-4">
        <div className="h-6 w-48 bg-gray-700 rounded mb-2" />
        <div className="h-4 w-64 bg-gray-700 rounded" />
      </div>
      <div className="space-y-4">
        <div className="h-20 bg-gray-700 rounded" />
        <div className="h-20 bg-gray-700 rounded" />
        <div className="h-16 bg-gray-700 rounded" />
      </div>
    </div>
  );
}
