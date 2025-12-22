import type { Address } from 'viem';
import type { Vault, RawVaultData } from '../types/vault.js';
import type { ScopeFilter, PaginationOptions, SortField, SortOrder } from '../types/filter.js';
import type { SubgraphResponse } from '../types/client.js';

/**
 * GraphQL query for fetching vaults
 */
const VAULTS_QUERY = `
  query GetVaults(
    $first: Int!
    $skip: Int!
    $orderBy: String!
    $orderDirection: String!
    $where: Vault_filter
  ) {
    vaults(
      first: $first
      skip: $skip
      orderBy: $orderBy
      orderDirection: $orderDirection
      where: $where
    ) {
      id
      owner
      treasureContract
      treasureTokenId
      collateralToken
      collateralAmount
      mintTimestamp
      lastWithdrawal
      vestedBTCAmount
      lastActivity
      pokeTimestamp
      windowId
      issuer
    }
  }
`;

/**
 * GraphQL query for counting vaults
 */
const VAULT_COUNT_QUERY = `
  query GetVaultCount($where: Vault_filter) {
    vaults(where: $where) {
      id
    }
  }
`;

/**
 * Query options for subgraph
 */
export interface SubgraphQueryOptions {
  scope?: ScopeFilter;
  pagination?: PaginationOptions;
  sortBy?: SortField;
  sortOrder?: SortOrder;
}

/**
 * Low-level client for querying the BTCNFT subgraph.
 *
 * Handles GraphQL queries, response parsing, and pagination for vault data.
 * Use {@link VaultClient} for higher-level analytics operations.
 *
 * @example Direct subgraph access
 * ```typescript
 * const subgraph = new SubgraphClient('https://api.studio.thegraph.com/...');
 * const vaults = await subgraph.getVaults({
 *   scope: { type: 'issuer', address: '0x1234...' },
 *   pagination: { page: 1, pageSize: 100 }
 * });
 * ```
 */
export class SubgraphClient {
  private readonly url: string;

  constructor(url: string) {
    this.url = url;
  }

  /**
   * Execute a GraphQL query
   */
  private async query<T>(
    queryString: string,
    variables: Record<string, unknown> = {}
  ): Promise<T> {
    const response = await fetch(this.url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        query: queryString,
        variables,
      }),
    });

    if (!response.ok) {
      throw new Error(`Subgraph request failed: ${response.status} ${response.statusText}`);
    }

    const result = (await response.json()) as SubgraphResponse<T>;

    if (result.errors?.length) {
      throw new Error(`Subgraph query error: ${result.errors[0]?.message}`);
    }

    return result.data;
  }

  /**
   * Build where clause for scope filter
   */
  private buildWhereClause(scope?: ScopeFilter): Record<string, string> | undefined {
    if (!scope || scope.type === 'all') {
      return undefined;
    }

    if (scope.type === 'issuer') {
      return { issuer: scope.address.toLowerCase() };
    }

    if (scope.type === 'treasure') {
      return { treasureContract: scope.contract.toLowerCase() };
    }

    return undefined;
  }

  /**
   * Map sort field to subgraph field name
   */
  private mapSortField(field: SortField): string {
    switch (field) {
      case 'collateral':
        return 'collateralAmount';
      case 'mintTimestamp':
        return 'mintTimestamp';
      case 'tokenId':
        return 'id';
      default:
        return 'collateralAmount';
    }
  }

  /**
   * Parse raw vault data from subgraph
   */
  private parseVault(raw: RawVaultData): Vault {
    return {
      tokenId: BigInt(raw.id),
      owner: raw.owner as Address,
      treasureContract: raw.treasureContract as Address,
      treasureTokenId: BigInt(raw.treasureTokenId),
      collateralToken: raw.collateralToken as Address,
      collateralAmount: BigInt(raw.collateralAmount),
      mintTimestamp: BigInt(raw.mintTimestamp),
      lastWithdrawal: BigInt(raw.lastWithdrawal),
      vestedBTCAmount: BigInt(raw.vestedBTCAmount),
      lastActivity: BigInt(raw.lastActivity),
      pokeTimestamp: BigInt(raw.pokeTimestamp),
      windowId: BigInt(raw.windowId),
      issuer: raw.issuer as Address,
    };
  }

  /**
   * Fetch vaults from subgraph with pagination and sorting.
   *
   * @param options - Query options
   * @param options.scope - Filter by issuer or treasure contract
   * @param options.pagination - Page number and size (default: page 1, size 100)
   * @param options.sortBy - Sort field (default: 'collateral')
   * @param options.sortOrder - Sort direction (default: 'desc')
   * @returns Array of parsed vault objects
   * @throws {Error} If HTTP request fails (network error, non-2xx status)
   * @throws {Error} If GraphQL query returns errors
   *
   * @example Fetch first page of vaults
   * ```typescript
   * const vaults = await subgraph.getVaults({
   *   pagination: { page: 1, pageSize: 100 }
   * });
   * ```
   */
  async getVaults(options: SubgraphQueryOptions = {}): Promise<Vault[]> {
    const {
      scope,
      pagination = { page: 1, pageSize: 100 },
      sortBy = 'collateral',
      sortOrder = 'desc',
    } = options;

    const skip = (pagination.page - 1) * pagination.pageSize;

    const result = await this.query<{ vaults: RawVaultData[] }>(VAULTS_QUERY, {
      first: pagination.pageSize,
      skip,
      orderBy: this.mapSortField(sortBy),
      orderDirection: sortOrder,
      where: this.buildWhereClause(scope),
    });

    return result.vaults.map((raw) => this.parseVault(raw));
  }

  /**
   * Get total vault count matching scope.
   *
   * @param scope - Optional scope filter
   * @returns Total number of vaults
   * @throws {Error} If HTTP request fails
   * @throws {Error} If GraphQL query returns errors
   */
  async getVaultCount(scope?: ScopeFilter): Promise<number> {
    const result = await this.query<{ vaults: { id: string }[] }>(VAULT_COUNT_QUERY, {
      where: this.buildWhereClause(scope),
    });

    return result.vaults.length;
  }

  /**
   * Fetch all vaults matching scope (handles pagination internally).
   *
   * Iterates through pages of 1000 vaults until all matching vaults are retrieved.
   *
   * @param scope - Optional scope filter
   * @returns All vaults matching the scope
   * @throws {Error} If any HTTP request fails
   * @throws {Error} If any GraphQL query returns errors
   *
   * @example Fetch all vaults for an issuer
   * ```typescript
   * const allVaults = await subgraph.getAllVaults({
   *   type: 'issuer',
   *   address: '0x1234...'
   * });
   * ```
   */
  async getAllVaults(scope?: ScopeFilter): Promise<Vault[]> {
    const allVaults: Vault[] = [];
    let page = 1;
    const pageSize = 1000;

    while (true) {
      const vaults = await this.getVaults({
        ...(scope && { scope }),
        pagination: { page, pageSize },
        sortBy: 'collateral',
        sortOrder: 'desc',
      });

      allVaults.push(...vaults);

      if (vaults.length < pageSize) {
        break;
      }

      page++;
    }

    return allVaults;
  }
}
