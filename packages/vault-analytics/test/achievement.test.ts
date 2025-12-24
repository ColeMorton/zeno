import { describe, it, expect } from 'vitest';
import { keccak256, toBytes } from 'viem';
import {
  ACHIEVEMENT_TYPE_HASHES,
  HASH_TO_ACHIEVEMENT_TYPE,
  DURATION_THRESHOLDS,
  DURATION_THRESHOLDS_DAYS,
  ACHIEVEMENT_CATEGORIES,
  ALL_ACHIEVEMENT_TYPES,
  DURATION_ACHIEVEMENT_TYPES,
  isDurationAchievement,
  getDurationThreshold,
} from '../src/constants/achievements.js';

describe('ACHIEVEMENT_TYPE_HASHES', () => {
  it('contains all 8 achievement types', () => {
    expect(Object.keys(ACHIEVEMENT_TYPE_HASHES)).toHaveLength(8);
  });

  it('matches contract keccak256 hashes', () => {
    expect(ACHIEVEMENT_TYPE_HASHES.MINTER).toBe(keccak256(toBytes('MINTER')));
    expect(ACHIEVEMENT_TYPE_HASHES.MATURED).toBe(keccak256(toBytes('MATURED')));
    expect(ACHIEVEMENT_TYPE_HASHES.HODLER_SUPREME).toBe(keccak256(toBytes('HODLER_SUPREME')));
    expect(ACHIEVEMENT_TYPE_HASHES.FIRST_MONTH).toBe(keccak256(toBytes('FIRST_MONTH')));
    expect(ACHIEVEMENT_TYPE_HASHES.QUARTER_STACK).toBe(keccak256(toBytes('QUARTER_STACK')));
    expect(ACHIEVEMENT_TYPE_HASHES.HALF_YEAR).toBe(keccak256(toBytes('HALF_YEAR')));
    expect(ACHIEVEMENT_TYPE_HASHES.ANNUAL).toBe(keccak256(toBytes('ANNUAL')));
    expect(ACHIEVEMENT_TYPE_HASHES.DIAMOND_HANDS).toBe(keccak256(toBytes('DIAMOND_HANDS')));
  });
});

describe('HASH_TO_ACHIEVEMENT_TYPE', () => {
  it('is inverse mapping of ACHIEVEMENT_TYPE_HASHES', () => {
    for (const [type, hash] of Object.entries(ACHIEVEMENT_TYPE_HASHES)) {
      expect(HASH_TO_ACHIEVEMENT_TYPE[hash]).toBe(type);
    }
  });
});

describe('DURATION_THRESHOLDS', () => {
  it('contains correct durations in seconds', () => {
    expect(DURATION_THRESHOLDS.FIRST_MONTH).toBe(30n * 24n * 60n * 60n);
    expect(DURATION_THRESHOLDS.QUARTER_STACK).toBe(91n * 24n * 60n * 60n);
    expect(DURATION_THRESHOLDS.HALF_YEAR).toBe(182n * 24n * 60n * 60n);
    expect(DURATION_THRESHOLDS.ANNUAL).toBe(365n * 24n * 60n * 60n);
    expect(DURATION_THRESHOLDS.DIAMOND_HANDS).toBe(730n * 24n * 60n * 60n);
  });

  it('does not contain non-duration achievements', () => {
    expect(DURATION_THRESHOLDS.MINTER).toBeUndefined();
    expect(DURATION_THRESHOLDS.MATURED).toBeUndefined();
    expect(DURATION_THRESHOLDS.HODLER_SUPREME).toBeUndefined();
  });
});

describe('DURATION_THRESHOLDS_DAYS', () => {
  it('contains correct durations in days', () => {
    expect(DURATION_THRESHOLDS_DAYS.FIRST_MONTH).toBe(30);
    expect(DURATION_THRESHOLDS_DAYS.QUARTER_STACK).toBe(91);
    expect(DURATION_THRESHOLDS_DAYS.HALF_YEAR).toBe(182);
    expect(DURATION_THRESHOLDS_DAYS.ANNUAL).toBe(365);
    expect(DURATION_THRESHOLDS_DAYS.DIAMOND_HANDS).toBe(730);
  });
});

describe('ACHIEVEMENT_CATEGORIES', () => {
  it('categorizes lifecycle achievements correctly', () => {
    expect(ACHIEVEMENT_CATEGORIES.MINTER).toBe('lifecycle');
    expect(ACHIEVEMENT_CATEGORIES.MATURED).toBe('lifecycle');
  });

  it('categorizes duration achievements correctly', () => {
    expect(ACHIEVEMENT_CATEGORIES.FIRST_MONTH).toBe('duration');
    expect(ACHIEVEMENT_CATEGORIES.QUARTER_STACK).toBe('duration');
    expect(ACHIEVEMENT_CATEGORIES.HALF_YEAR).toBe('duration');
    expect(ACHIEVEMENT_CATEGORIES.ANNUAL).toBe('duration');
    expect(ACHIEVEMENT_CATEGORIES.DIAMOND_HANDS).toBe('duration');
  });

  it('categorizes composite achievements correctly', () => {
    expect(ACHIEVEMENT_CATEGORIES.HODLER_SUPREME).toBe('composite');
  });
});

describe('ALL_ACHIEVEMENT_TYPES', () => {
  it('contains all 8 types', () => {
    expect(ALL_ACHIEVEMENT_TYPES).toHaveLength(8);
  });

  it('includes all expected types', () => {
    expect(ALL_ACHIEVEMENT_TYPES).toContain('MINTER');
    expect(ALL_ACHIEVEMENT_TYPES).toContain('MATURED');
    expect(ALL_ACHIEVEMENT_TYPES).toContain('HODLER_SUPREME');
    expect(ALL_ACHIEVEMENT_TYPES).toContain('FIRST_MONTH');
    expect(ALL_ACHIEVEMENT_TYPES).toContain('QUARTER_STACK');
    expect(ALL_ACHIEVEMENT_TYPES).toContain('HALF_YEAR');
    expect(ALL_ACHIEVEMENT_TYPES).toContain('ANNUAL');
    expect(ALL_ACHIEVEMENT_TYPES).toContain('DIAMOND_HANDS');
  });
});

describe('DURATION_ACHIEVEMENT_TYPES', () => {
  it('contains only duration achievements', () => {
    expect(DURATION_ACHIEVEMENT_TYPES).toHaveLength(5);
    expect(DURATION_ACHIEVEMENT_TYPES).toContain('FIRST_MONTH');
    expect(DURATION_ACHIEVEMENT_TYPES).toContain('QUARTER_STACK');
    expect(DURATION_ACHIEVEMENT_TYPES).toContain('HALF_YEAR');
    expect(DURATION_ACHIEVEMENT_TYPES).toContain('ANNUAL');
    expect(DURATION_ACHIEVEMENT_TYPES).toContain('DIAMOND_HANDS');
  });

  it('does not contain non-duration achievements', () => {
    expect(DURATION_ACHIEVEMENT_TYPES).not.toContain('MINTER');
    expect(DURATION_ACHIEVEMENT_TYPES).not.toContain('MATURED');
    expect(DURATION_ACHIEVEMENT_TYPES).not.toContain('HODLER_SUPREME');
  });
});

describe('isDurationAchievement', () => {
  it('returns true for duration achievements', () => {
    expect(isDurationAchievement('FIRST_MONTH')).toBe(true);
    expect(isDurationAchievement('QUARTER_STACK')).toBe(true);
    expect(isDurationAchievement('HALF_YEAR')).toBe(true);
    expect(isDurationAchievement('ANNUAL')).toBe(true);
    expect(isDurationAchievement('DIAMOND_HANDS')).toBe(true);
  });

  it('returns false for non-duration achievements', () => {
    expect(isDurationAchievement('MINTER')).toBe(false);
    expect(isDurationAchievement('MATURED')).toBe(false);
    expect(isDurationAchievement('HODLER_SUPREME')).toBe(false);
  });
});

describe('getDurationThreshold', () => {
  it('returns correct threshold for duration achievements', () => {
    expect(getDurationThreshold('FIRST_MONTH')).toBe(30n * 24n * 60n * 60n);
    expect(getDurationThreshold('DIAMOND_HANDS')).toBe(730n * 24n * 60n * 60n);
  });

  it('throws for non-duration achievements', () => {
    expect(() => getDurationThreshold('MINTER')).toThrow('MINTER is not a duration achievement');
    expect(() => getDurationThreshold('MATURED')).toThrow('MATURED is not a duration achievement');
  });
});
