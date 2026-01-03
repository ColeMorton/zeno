// Education Content Types and Utilities

// ============================================================================
// Core Types (shared between achievements and tracks)
// ============================================================================

export interface LessonSection {
  type: 'text' | 'keyPoints' | 'infographic' | 'video';
  content: string | string[];
  path?: string;
}

export interface QuizQuestion {
  question: string;
  options: string[];
  correct: number;
}

export interface Quiz {
  questions: QuizQuestion[];
  passingScore: number;
}

export interface Lesson {
  title: string;
  objective: string;
  sections: LessonSection[];
}

export interface AchievementContent {
  achievementId: string;
  week: number;
  category: string;
  defiConcept: string;
  lesson: Lesson;
  quiz: Quiz;
  unlockHint: string;
  nextSteps: string[];
  verificationNote?: string;
  celebration?: {
    title: string;
    message: string;
  };
}

// Map achievement names to content file paths
const ACHIEVEMENT_CONTENT_MAP: Record<string, string> = {
  TRAILHEAD: 'trailhead',
  FIRST_STEPS: 'first_steps',
  WALLET_WARMED: 'wallet_warmed',
  IDENTIFIED: 'identified',
  STEADY_PACE: 'steady_pace',
  EXPLORER: 'explorer',
  GUIDE: 'guide',
  PREPARED: 'prepared',
  REGULAR: 'regular',
  COMMITTED: 'committed',
  RESOLUTE: 'resolute',
  STUDENT: 'student',
  CHAPTER_COMPLETE: 'chapter_complete',
};

// Load achievement content
export async function getAchievementContent(
  achievementName: string,
  chapterNumber: number = 1
): Promise<AchievementContent | null> {
  const fileName = ACHIEVEMENT_CONTENT_MAP[achievementName];
  if (!fileName) return null;

  try {
    const content = await import(
      `@/content/chapters/ch${chapterNumber}/achievements/${fileName}.json`
    );
    return content.default as AchievementContent;
  } catch {
    return null;
  }
}

// Calculate quiz score
export function calculateQuizScore(
  answers: number[],
  questions: QuizQuestion[]
): { score: number; passed: boolean; passingScore: number } {
  if (answers.length !== questions.length) {
    return { score: 0, passed: false, passingScore: 100 };
  }

  const correct = answers.filter((answer, i) => answer === questions[i].correct).length;
  const score = Math.round((correct / questions.length) * 100);
  const passingScore = 100; // All questions must be correct

  return {
    score,
    passed: score >= passingScore,
    passingScore,
  };
}

// Category icons for display
export const CATEGORY_ICONS: Record<string, string> = {
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

// DeFi concept colors for visual coding
export const CONCEPT_COLORS: Record<string, string> = {
  identity: '#4A90A4',
  commitment: '#7BA4C7',
  transactions: '#8B7355',
  socialRecovery: '#4A7C59',
  yieldMechanics: '#C4A35A',
  protocolDiversity: '#6B7C8A',
  networkEffects: '#5A6B7C',
  tokenApprovals: '#553C3C',
  consistency: '#6B5B4A',
  vesting: '#7C6B5D',
  attestations: '#5B6B8A',
  metaLearning: '#4A5568',
  mastery: '#C4A35A',
};

// ============================================================================
// Track System Types (Layer 2: Self-Paced Knowledge Building)
// ============================================================================

export interface PracticalExercise {
  type: 'onchain' | 'explorer' | 'calculation';
  description: string;
  verificationHint: string;
  verification?: {
    eventSignature?: string;
    contractRead?: {
      method: string;
      expectedResult: string;
    };
  };
}

export interface TrackLesson {
  id: string;
  title: string;
  objective: string;
  sections: LessonSection[];
  quiz: Quiz;
  practicalExercise?: PracticalExercise;
}

export interface Track {
  id: string;
  name: string;
  description: string;
  graduationStandard: string;
  lessons: TrackLesson[];
}

export interface TrackProgress {
  trackId: string;
  completedLessons: string[];
  graduated: boolean;
}

export interface VerificationResult {
  verified: boolean;
  txHash?: string;
  timestamp?: number;
  errorReason?: string;
}

// Track IDs
export const TRACK_IDS = {
  BITCOIN_FUNDAMENTALS: 'bitcoin-fundamentals',
  PROTOCOL_MECHANICS: 'protocol-mechanics',
  DEFI_FOUNDATIONS: 'defi-foundations',
  ADVANCED_PROTOCOL: 'advanced-protocol',
  SECURITY_RISK: 'security-risk',
  EXPLORER_OPERATIONS: 'explorer-operations',
} as const;

export type TrackId = (typeof TRACK_IDS)[keyof typeof TRACK_IDS];

// Track metadata for display
export const TRACK_METADATA: Record<
  TrackId,
  { name: string; description: string; icon: string; lessonsCount: number }
> = {
  [TRACK_IDS.BITCOIN_FUNDAMENTALS]: {
    name: 'Bitcoin Fundamentals',
    description: 'Understand the thesis behind 1129-day SMA',
    icon: '₿',
    lessonsCount: 6,
  },
  [TRACK_IDS.PROTOCOL_MECHANICS]: {
    name: 'Protocol Mechanics',
    description: 'Core protocol operations and Zeno\'s paradox',
    icon: '⚙️',
    lessonsCount: 7,
  },
  [TRACK_IDS.DEFI_FOUNDATIONS]: {
    name: 'DeFi Foundations',
    description: 'General DeFi literacy for broader utility',
    icon: '🏛️',
    lessonsCount: 7,
  },
  [TRACK_IDS.ADVANCED_PROTOCOL]: {
    name: 'Advanced Protocol',
    description: 'Full feature mastery including vestedBTC',
    icon: '🔬',
    lessonsCount: 6,
  },
  [TRACK_IDS.SECURITY_RISK]: {
    name: 'Security & Risk',
    description: 'Due diligence and risk assessment',
    icon: '🛡️',
    lessonsCount: 5,
  },
  [TRACK_IDS.EXPLORER_OPERATIONS]: {
    name: 'Explorer Operations',
    description: 'Direct contract interaction without UI',
    icon: '🔍',
    lessonsCount: 5,
  },
};

// Load track content
export async function getTrackContent(trackId: TrackId): Promise<Track | null> {
  try {
    const content = await import(`@/content/tracks/${trackId}.json`);
    return content.default as Track;
  } catch {
    return null;
  }
}

// Load all tracks
export async function getAllTracks(): Promise<Track[]> {
  const trackIds = Object.values(TRACK_IDS);
  const tracks = await Promise.all(trackIds.map((id) => getTrackContent(id)));
  return tracks.filter((track): track is Track => track !== null);
}

// Check if track is graduated (all lessons completed)
export function isTrackGraduated(
  track: Track,
  completedLessons: string[]
): boolean {
  return track.lessons.every((lesson) => completedLessons.includes(lesson.id));
}

// Calculate track progress percentage
export function calculateTrackProgress(
  track: Track,
  completedLessons: string[]
): number {
  if (track.lessons.length === 0) return 0;
  const completed = track.lessons.filter((lesson) =>
    completedLessons.includes(lesson.id)
  ).length;
  return Math.round((completed / track.lessons.length) * 100);
}
