/**
 * Protocol constants (immutable on-chain values)
 */

/** Vesting period in seconds (1129 days) */
export const VESTING_PERIOD = 1129n * 24n * 60n * 60n;

/** Vesting period in days */
export const VESTING_PERIOD_DAYS = 1129n;

/** Withdrawal period in seconds (30 days) */
export const WITHDRAWAL_PERIOD = 30n * 24n * 60n * 60n;

/** Withdrawal rate in basis points × 100 (0.875% = 875/100000) */
export const WITHDRAWAL_RATE = 875n;

/** Withdrawal rate denominator */
export const WITHDRAWAL_RATE_DENOMINATOR = 100000n;

/** Dormancy threshold in seconds (1129 days) */
export const DORMANCY_THRESHOLD = 1129n * 24n * 60n * 60n;

/** Grace period in seconds (30 days) */
export const GRACE_PERIOD = 30n * 24n * 60n * 60n;

/** BTC token decimals */
export const BTC_DECIMALS = 8;

/**
 * Default percentile tier thresholds
 */
export const DEFAULT_PERCENTILE_THRESHOLDS = {
  whale: 99,
  diamond: 95,
  gold: 90,
  silver: 75,
  bronze: 50,
} as const;

/**
 * Minimum vaults required for percentile display
 */
export const MIN_VAULTS_FOR_PERCENTILE = 10;
