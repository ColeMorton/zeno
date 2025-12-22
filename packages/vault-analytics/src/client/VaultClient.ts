import type { VaultClientConfig, SupportedChainId } from '../types/client.js';
import type { Vault } from '../types/vault.js';
import type { VaultQueryOptions } from '../types/filter.js';
import type { RankedVault, AnalyticsResult, RankingOptions } from '../types/percentile.js';
import { getChainConfig } from '../constants/chains.js';
import { SubgraphClient } from './SubgraphClient.js';
import { filterVaults } from '../analytics/filters.js';
import { rankByCollateral } from '../analytics/percentile.js';

/**
 * Main client for vault analytics.
 *
 * Provides methods to fetch vault data from the subgraph, apply filters,
 * and calculate percentile rankings.
 *
 * @example Create and use client
 * ```typescript
 * const client = new VaultClient({ chainId: 1 });
 * const vaults = await client.getVaults({
 *   scope: { type: 'issuer', address: '0x...' }
 * });
 * ```
 */
export class VaultClient {
  private readonly chainId: SupportedChainId;
  private readonly subgraph: SubgraphClient;

  /**
   * Create a new VaultClient instance.
   *
   * @param config - Client configuration
   * @param config.chainId - Chain ID (1 = Ethereum, 8453 = Base, etc.)
   * @param config.subgraphUrl - Optional custom subgraph URL
   * @param config.rpcUrl - Optional custom RPC URL
   * @throws {Error} If chainId is not supported
   */
  constructor(config: VaultClientConfig) {
    this.chainId = config.chainId;

    const chainConfig = getChainConfig(config.chainId);
    const subgraphUrl = config.subgraphUrl ?? chainConfig.subgraphUrl;

    this.subgraph = new SubgraphClient(subgraphUrl);
  }

  /**
   * Get the chain ID this client is configured for.
   *
   * @returns The chain ID passed during initialization
   *
   * @example
   * ```typescript
   * const chainId = client.getChainId(); // 1
   * ```
   */
  getChainId(): SupportedChainId {
    return this.chainId;
  }

  /**
   * Fetch vaults with optional scope filter and pagination.
   *
   * @param options - Query options
   * @param options.scope - Filter by issuer or treasure contract
   * @param options.filters - Status filters (vesting, separation, dormancy)
   * @param options.pagination - Page number and size
   * @param options.sortBy - Sort field ('collateral' | 'mintTimestamp' | 'tokenId')
   * @param options.sortOrder - Sort direction ('asc' | 'desc')
   * @returns Array of vault objects matching the query
   * @throws {Error} If subgraph request fails
   *
   * @example Fetch issuer vaults
   * ```typescript
   * const vaults = await client.getVaults({
   *   scope: { type: 'issuer', address: '0x1234...' },
   *   pagination: { page: 1, pageSize: 25 }
   * });
   * ```
   *
   * @example Fetch with filters
   * ```typescript
   * const vaults = await client.getVaults({
   *   filters: { vestingStatus: 'vested', separationStatus: 'combined' }
   * });
   * ```
   */
  async getVaults(options: VaultQueryOptions = {}): Promise<Vault[]> {
    const { scope, pagination, sortBy, sortOrder, filters } = options;

    // Fetch from subgraph - only pass defined properties
    let vaults = await this.subgraph.getVaults({
      ...(scope && { scope }),
      ...(pagination && { pagination }),
      ...(sortBy && { sortBy }),
      ...(sortOrder && { sortOrder }),
    });

    // Apply client-side filters if provided
    if (filters) {
      vaults = filterVaults(vaults, filters);
    }

    return vaults;
  }

  /**
   * Fetch all vaults matching scope (handles pagination internally).
   *
   * Automatically pages through results from the subgraph, fetching up to
   * 1000 vaults per request until all matching vaults are retrieved.
   *
   * @param options - Query options (pagination is handled internally)
   * @param options.scope - Filter by issuer or treasure contract
   * @param options.filters - Status filters applied after fetching
   * @returns All vaults matching the scope and filters
   * @throws {Error} If subgraph request fails
   *
   * @example Fetch all vaults for an issuer
   * ```typescript
   * const allVaults = await client.getAllVaults({
   *   scope: { type: 'issuer', address: '0x1234...' }
   * });
   * console.log(`Total: ${allVaults.length} vaults`);
   * ```
   *
   * @example Fetch and filter all vested vaults
   * ```typescript
   * const vestedVaults = await client.getAllVaults({
   *   scope: { type: 'issuer', address: '0x1234...' },
   *   filters: { vestingStatus: 'vested' }
   * });
   * ```
   *
   * @remarks
   * Use this method when you need the complete dataset for analytics
   * calculations. For paginated display, use {@link getVaults} instead.
   */
  async getAllVaults(options: Omit<VaultQueryOptions, 'pagination'> = {}): Promise<Vault[]> {
    const { scope, filters } = options;

    let vaults = await this.subgraph.getAllVaults(scope);

    if (filters) {
      vaults = filterVaults(vaults, filters);
    }

    return vaults;
  }

  /**
   * Get total vault count matching scope.
   *
   * Returns the count of vaults without fetching full vault data.
   * Useful for pagination calculations and summary statistics.
   *
   * @param options - Query options
   * @param options.scope - Filter by issuer or treasure contract
   * @returns Total number of vaults matching the scope
   * @throws {Error} If subgraph request fails
   *
   * @example Get issuer vault count
   * ```typescript
   * const count = await client.getVaultCount({
   *   scope: { type: 'issuer', address: '0x1234...' }
   * });
   * console.log(`Issuer has ${count} vaults`);
   * ```
   *
   * @example Calculate pagination
   * ```typescript
   * const total = await client.getVaultCount();
   * const pageSize = 25;
   * const totalPages = Math.ceil(total / pageSize);
   * ```
   */
  async getVaultCount(options: Pick<VaultQueryOptions, 'scope'> = {}): Promise<number> {
    return this.subgraph.getVaultCount(options.scope);
  }

  /**
   * Fetch vaults, apply filters, calculate rankings, and paginate in one call.
   *
   * This is the primary method for building vault leaderboards. It fetches
   * all matching vaults to calculate accurate percentiles, then returns a
   * paginated slice with ranking information.
   *
   * @param options - Query options with ranking configuration
   * @param options.scope - Filter by issuer or treasure contract
   * @param options.filters - Status filters (vesting, separation, dormancy)
   * @param options.pagination - Page number and size (default: page 1, size 25)
   * @param options.sortBy - Sort field: 'collateral' | 'mintTimestamp' | 'tokenId'
   * @param options.sortOrder - Sort direction: 'asc' | 'desc'
   * @param options.rankingOptions - Custom percentile thresholds
   * @returns Analytics result containing:
   *   - `vaults`: Array of {@link RankedVault} for the current page
   *   - `total`: Total vaults matching filters
   *   - `page`: Current page number
   *   - `pageSize`: Items per page
   *   - `totalPages`: Total number of pages
   * @throws {Error} If subgraph request fails
   *
   * @example Build a leaderboard
   * ```typescript
   * const result = await client.getAnalytics({
   *   scope: { type: 'issuer', address: '0x1234...' },
   *   filters: { vestingStatus: 'vested' },
   *   pagination: { page: 1, pageSize: 25 }
   * });
   *
   * result.vaults.forEach(({ vault, rank, percentile, tier }) => {
   *   console.log(`#${rank}: ${vault.tokenId} - ${tier} (${percentile}%)`);
   * });
   * ```
   *
   * @example Sort by mint date
   * ```typescript
   * const result = await client.getAnalytics({
   *   sortBy: 'mintTimestamp',
   *   sortOrder: 'asc'
   * });
   * ```
   *
   * @remarks
   * Percentile calculation requires fetching all matching vaults internally.
   * For large datasets, consider caching results.
   */
  async getAnalytics(
    options: VaultQueryOptions & { rankingOptions?: RankingOptions } = {}
  ): Promise<AnalyticsResult> {
    const {
      scope,
      filters,
      pagination = { page: 1, pageSize: 25 },
      sortBy = 'collateral',
      sortOrder = 'desc',
      rankingOptions,
    } = options;

    // Fetch all vaults for accurate percentile calculation
    let allVaults = await this.subgraph.getAllVaults(scope);

    // Apply filters
    if (filters) {
      allVaults = filterVaults(allVaults, filters);
    }

    const total = allVaults.length;
    const totalPages = Math.ceil(total / pagination.pageSize);

    // Rank all vaults
    const ranked = rankByCollateral(allVaults, rankingOptions);

    // Handle different sort orders
    let sortedRanked = ranked;
    if (sortBy !== 'collateral' || sortOrder !== 'desc') {
      sortedRanked = [...ranked].sort((a, b) => {
        let comparison = 0;

        switch (sortBy) {
          case 'mintTimestamp':
            comparison = Number(a.vault.mintTimestamp - b.vault.mintTimestamp);
            break;
          case 'tokenId':
            comparison = Number(a.vault.tokenId - b.vault.tokenId);
            break;
          case 'collateral':
          default:
            comparison = Number(b.vault.collateralAmount - a.vault.collateralAmount);
            break;
        }

        return sortOrder === 'asc' ? comparison : -comparison;
      });
    }

    // Paginate
    const start = (pagination.page - 1) * pagination.pageSize;
    const end = start + pagination.pageSize;
    const paginatedVaults = sortedRanked.slice(start, end);

    return {
      vaults: paginatedVaults,
      total,
      page: pagination.page,
      pageSize: pagination.pageSize,
      totalPages,
    };
  }

  /**
   * Get ranking for a specific vault within a collection.
   *
   * Fetches all vaults matching the scope, calculates rankings, and returns
   * the ranking data for the specified vault.
   *
   * @param tokenId - Vault token ID to look up
   * @param options - Query options defining the ranking context
   * @param options.scope - Filter by issuer or treasure contract
   * @param options.filters - Status filters applied before ranking
   * @returns Ranked vault data or null if vault not found in collection
   * @throws {Error} If subgraph request fails
   *
   * @example Get vault ranking within issuer collection
   * ```typescript
   * const ranking = await client.getVaultRanking(42n, {
   *   scope: { type: 'issuer', address: '0x1234...' }
   * });
   *
   * if (ranking) {
   *   console.log(`Vault #42 is rank ${ranking.rank}`);
   *   console.log(`Percentile: ${ranking.percentile}%`);
   *   console.log(`Tier: ${ranking.tier}`);
   * } else {
   *   console.log('Vault not found in collection');
   * }
   * ```
   *
   * @example Check if vault is in top tier
   * ```typescript
   * const ranking = await client.getVaultRanking(tokenId, {
   *   scope: { type: 'issuer', address: issuerAddress },
   *   filters: { vestingStatus: 'vested' }
   * });
   * const isWhale = ranking?.tier === 'Whale';
   * ```
   */
  async getVaultRanking(
    tokenId: bigint,
    options: Omit<VaultQueryOptions, 'pagination'> = {}
  ): Promise<RankedVault | null> {
    const allVaults = await this.getAllVaults(options);
    const ranked = rankByCollateral(allVaults);

    return ranked.find((r) => r.vault.tokenId === tokenId) ?? null;
  }
}

/**
 * Create a vault analytics client.
 *
 * Factory function for creating {@link VaultClient} instances.
 *
 * @param config - Client configuration
 * @param config.chainId - Chain ID (1 = Ethereum, 8453 = Base, etc.)
 * @param config.subgraphUrl - Optional custom subgraph URL
 * @param config.rpcUrl - Optional custom RPC URL
 * @returns Configured VaultClient instance
 * @throws {Error} If chainId is not supported
 *
 * @example Create client for Ethereum mainnet
 * ```typescript
 * const client = createVaultClient({ chainId: 1 });
 * ```
 *
 * @example Create client with custom subgraph
 * ```typescript
 * const client = createVaultClient({
 *   chainId: 1,
 *   subgraphUrl: 'https://api.studio.thegraph.com/...'
 * });
 * ```
 *
 * @example Create client for Base
 * ```typescript
 * const client = createVaultClient({ chainId: 8453 });
 * const vaults = await client.getVaults();
 * ```
 */
export function createVaultClient(config: VaultClientConfig): VaultClient {
  return new VaultClient(config);
}
