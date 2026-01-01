// Chapter System Configuration
// 12 chapters spanning the 1129-day vesting period
// Each chapter runs for one calendar quarter with unique achievements per version

export interface ChapterConfig {
  number: number;
  minDaysHeld: number;
  maxDaysHeld: number;
  theme: string;
  description: string;
}

// Static chapter definitions (day ranges are fixed)
export const CHAPTERS: ChapterConfig[] = [
  { number: 1, minDaysHeld: 0, maxDaysHeld: 90, theme: 'Frozen Tundra', description: 'Begin the journey across frozen wastes' },
  { number: 2, minDaysHeld: 91, maxDaysHeld: 181, theme: 'Ice Caves', description: 'Navigate treacherous underground passages' },
  { number: 3, minDaysHeld: 182, maxDaysHeld: 272, theme: 'Glacier Fields', description: 'Cross the ancient ice fields' },
  { number: 4, minDaysHeld: 273, maxDaysHeld: 363, theme: 'Mountain Base', description: 'Establish your foundation' },
  { number: 5, minDaysHeld: 364, maxDaysHeld: 454, theme: 'Forest Trail', description: 'Trek through alpine forests' },
  { number: 6, minDaysHeld: 455, maxDaysHeld: 545, theme: 'Rocky Ascent', description: 'Scale the rocky outcrops' },
  { number: 7, minDaysHeld: 546, maxDaysHeld: 636, theme: 'Ridge Line', description: 'Walk the knife-edge ridge' },
  { number: 8, minDaysHeld: 637, maxDaysHeld: 727, theme: 'High Camp', description: 'Prepare for the final push' },
  { number: 9, minDaysHeld: 728, maxDaysHeld: 818, theme: 'Storm Zone', description: 'Weather the mountain storms' },
  { number: 10, minDaysHeld: 819, maxDaysHeld: 909, theme: 'Death Zone', description: 'Enter the thin air' },
  { number: 11, minDaysHeld: 910, maxDaysHeld: 1000, theme: 'Final Ascent', description: 'The summit beckons' },
  { number: 12, minDaysHeld: 1001, maxDaysHeld: 1129, theme: 'Summit', description: 'Claim your place at the peak' },
];

export type ChapterStatus = 'locked' | 'active' | 'completed' | 'missed';

export interface ChapterState {
  chapter: ChapterConfig;
  status: ChapterStatus;
  versionId: string | null; // e.g., "CH1_2025Q1" if active/available
  windowStart: number | null;
  windowEnd: number | null;
  achievementCount: number;
  claimedCount: number;
}

// Get the current calendar quarter
export function getCurrentQuarter(): { year: number; quarter: number } {
  const now = new Date();
  const year = now.getFullYear();
  const quarter = Math.floor(now.getMonth() / 3) + 1;
  return { year, quarter };
}

// Generate chapter version ID
export function getChapterVersionId(chapterNumber: number, year: number, quarter: number): string {
  return `CH${chapterNumber}_${year}Q${quarter}`;
}

// Get quarter start timestamp
export function getQuarterStart(year: number, quarter: number): number {
  const month = (quarter - 1) * 3;
  return Math.floor(new Date(year, month, 1).getTime() / 1000);
}

// Get quarter end timestamp
export function getQuarterEnd(year: number, quarter: number): number {
  const month = quarter * 3;
  return Math.floor(new Date(year, month, 1).getTime() / 1000) - 1;
}

// Determine which chapter a holder is eligible for based on days held
export function getEligibleChapter(daysHeld: number): ChapterConfig | null {
  return CHAPTERS.find(
    ch => daysHeld >= ch.minDaysHeld && daysHeld <= ch.maxDaysHeld
  ) ?? null;
}

// Format remaining time as human-readable string
export function formatTimeRemaining(seconds: number): string {
  if (seconds <= 0) return 'Ended';

  const days = Math.floor(seconds / 86400);
  const hours = Math.floor((seconds % 86400) / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);

  if (days > 0) {
    return `${days}d ${hours}h`;
  }
  if (hours > 0) {
    return `${hours}h ${minutes}m`;
  }
  return `${minutes}m`;
}

// Check if currently within a quarter's time window
export function isWithinWindow(windowStart: number, windowEnd: number, currentTime?: number): boolean {
  const now = currentTime ?? Math.floor(Date.now() / 1000);
  return now >= windowStart && now <= windowEnd;
}

// Calculate progress percentage through a chapter's day range
export function getChapterProgress(daysHeld: number, chapter: ChapterConfig): number {
  if (daysHeld < chapter.minDaysHeld) return 0;
  if (daysHeld > chapter.maxDaysHeld) return 100;

  const range = chapter.maxDaysHeld - chapter.minDaysHeld;
  const progress = daysHeld - chapter.minDaysHeld;
  return Math.round((progress / range) * 100);
}

// Chapter 1 Achievement Definitions
export interface Chapter1Achievement {
  name: string;
  description: string;
  week: number;
  category: string;
}

export const CHAPTER_1_ACHIEVEMENTS: Chapter1Achievement[] = [
  { name: 'TRAILHEAD', description: 'Create your on-chain profile', week: 1, category: 'Registration' },
  { name: 'FIRST_STEPS', description: '15 days since registration', week: 2, category: 'Milestone' },
  { name: 'WALLET_WARMED', description: 'First protocol interaction', week: 3, category: 'Activity' },
  { name: 'IDENTIFIED', description: 'Link ENS or Farcaster identity', week: 4, category: 'Identity' },
  { name: 'STEADY_PACE', description: '30 days since registration', week: 5, category: 'Milestone' },
  { name: 'EXPLORER', description: '3 protocol interactions', week: 6, category: 'Activity' },
  { name: 'GUIDE', description: 'Refer another user', week: 7, category: 'Referral' },
  { name: 'PREPARED', description: 'Approve tokens for minting', week: 8, category: 'Preparation' },
  { name: 'REGULAR', description: '3 interactions across 3 days', week: 9, category: 'Consistency' },
  { name: 'COMMITTED', description: '60 days since registration', week: 10, category: 'Milestone' },
  { name: 'RESOLUTE', description: 'Sign commitment attestation', week: 11, category: 'Commitment' },
  { name: 'STUDENT', description: 'Earn any prior achievement', week: 12, category: 'Learning' },
  { name: 'CHAPTER_COMPLETE', description: 'Earn 10 chapter achievements', week: 13, category: 'Completion' },
];

// Chapter theme colors (used for visual styling)
export const CHAPTER_COLORS: Record<number, { primary: string; secondary: string; bg: string }> = {
  1: { primary: '#4A90A4', secondary: '#E8F4F8', bg: 'from-sky-900/30' },
  2: { primary: '#5B6B8A', secondary: '#D8E0F0', bg: 'from-slate-900/30' },
  3: { primary: '#7BA4C7', secondary: '#E0EEF8', bg: 'from-cyan-900/30' },
  4: { primary: '#8B7355', secondary: '#F0E8DC', bg: 'from-amber-900/30' },
  5: { primary: '#4A7C59', secondary: '#E0F0E8', bg: 'from-emerald-900/30' },
  6: { primary: '#7C6B5D', secondary: '#EDE8E0', bg: 'from-stone-900/30' },
  7: { primary: '#6B7C8A', secondary: '#E8EEF0', bg: 'from-gray-800/30' },
  8: { primary: '#5A6B7C', secondary: '#E0E8F0', bg: 'from-blue-900/30' },
  9: { primary: '#4A5568', secondary: '#E2E8F0', bg: 'from-slate-800/30' },
  10: { primary: '#553C3C', secondary: '#F0E0E0', bg: 'from-red-900/30' },
  11: { primary: '#6B5B4A', secondary: '#F0EBE0', bg: 'from-orange-900/30' },
  12: { primary: '#C4A35A', secondary: '#FDF8E8', bg: 'from-yellow-800/30' },
};
