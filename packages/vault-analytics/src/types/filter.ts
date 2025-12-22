import type { Address } from 'viem';

/**
 * Vesting status filter values
 */
export type VestingStatus = 'vesting' | 'vested' | 'all';

/**
 * Separation status filter values
 */
export type SeparationStatus = 'combined' | 'separated' | 'all';

/**
 * Dormancy status filter values
 */
export type DormancyStatus = 'active' | 'poke_pending' | 'claimable' | 'all';

/**
 * Vault filter options
 */
export interface VaultFilter {
  /** Filter by vesting completion status */
  vestingStatus?: VestingStatus;
  /** Filter by collateral separation status */
  separationStatus?: SeparationStatus;
  /** Filter by dormancy state */
  dormancyStatus?: DormancyStatus;
}

/**
 * Scope filter for vault queries
 */
export type ScopeFilter =
  | { type: 'all' }
  | { type: 'issuer'; address: Address }
  | { type: 'treasure'; contract: Address };

/**
 * Sort field options
 */
export type SortField = 'collateral' | 'mintTimestamp' | 'tokenId';

/**
 * Sort order options
 */
export type SortOrder = 'asc' | 'desc';

/**
 * Pagination options
 */
export interface PaginationOptions {
  /** Page number (1-indexed) */
  page: number;
  /** Items per page */
  pageSize: number;
}

/**
 * Complete query options for vault fetching
 */
export interface VaultQueryOptions {
  /** Scope filter (issuer, treasure, or all) */
  scope?: ScopeFilter;
  /** Status filters */
  filters?: VaultFilter;
  /** Pagination settings */
  pagination?: PaginationOptions;
  /** Sort field */
  sortBy?: SortField;
  /** Sort order */
  sortOrder?: SortOrder;
}
