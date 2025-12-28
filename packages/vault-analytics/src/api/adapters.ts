import type { Address } from 'viem';
import type { Vault } from '../types/vault.js';
import type { IndexedEvent, EventType } from '../events/schema.js';
import type { VaultQueryOptions } from '../types/filter.js';
import type { AnvilIndexer, EventFilter } from '../indexer/anvil.js';
import type { SubgraphClient } from '../client/SubgraphClient.js';

/**
 * Supported data sources
 */
export type DataSource = 'anvil' | 'subgraph';

/**
 * Event filter for adapter queries
 */
export interface AdapterEventFilter {
  /** Filter by event types */
  types?: EventType[] | undefined;
  /** Filter by block range */
  fromBlock?: bigint | undefined;
  toBlock?: bigint | undefined;
  /** Filter by token ID */
  tokenId?: bigint | undefined;
  /** Filter by wallet address */
  wallet?: Address | undefined;
}

/**
 * Base adapter interface for data sources
 */
export interface DataSourceAdapter {
  /** Data source identifier */
  readonly source: DataSource;
  /** Get vaults with optional filtering */
  getVaults(filter?: VaultQueryOptions): Promise<Vault[]>;
  /** Get indexed events with optional filtering */
  getEvents(filter?: AdapterEventFilter): Promise<IndexedEvent[]>;
  /** Check if adapter is connected and ready */
  isReady(): boolean;
}

/**
 * Anvil adapter configuration
 */
export interface AnvilAdapterConfig {
  indexer: AnvilIndexer;
}

/**
 * Subgraph adapter configuration
 */
export interface SubgraphAdapterConfig {
  client: SubgraphClient;
}

/**
 * Anvil data source adapter
 *
 * Uses local AnvilIndexer for real-time event capture during simulation.
 */
export class AnvilAdapter implements DataSourceAdapter {
  readonly source: DataSource = 'anvil';
  private indexer: AnvilIndexer;

  constructor(config: AnvilAdapterConfig) {
    this.indexer = config.indexer;
  }

  async getVaults(_filter?: VaultQueryOptions): Promise<Vault[]> {
    // Anvil indexer captures events, not vault states
    // Build vault state from VaultMinted events
    const events = this.indexer.getEvents({ types: ['VaultMinted'] });

    const vaults: Vault[] = [];
    for (const event of events) {
      if (event.type === 'VaultMinted') {
        vaults.push({
          tokenId: event.tokenId,
          owner: event.owner,
          treasureContract: event.treasureContract,
          treasureTokenId: event.treasureTokenId,
          collateralToken: '0x0000000000000000000000000000000000000000' as Address,
          collateralAmount: event.collateral,
          mintTimestamp: event.blockTimestamp,
          lastWithdrawal: 0n,
          vestedBTCAmount: 0n,
          lastActivity: event.blockTimestamp,
          pokeTimestamp: 0n,
          windowId: 0n,
          issuer: event.treasureContract,
        });
      }
    }

    return vaults;
  }

  async getEvents(filter?: AdapterEventFilter): Promise<IndexedEvent[]> {
    const eventFilter: EventFilter = {};

    if (filter?.types !== undefined) {
      eventFilter.types = filter.types;
    }

    if (filter?.tokenId !== undefined) {
      eventFilter.tokenId = filter.tokenId;
    }

    if (filter?.fromBlock !== undefined || filter?.toBlock !== undefined) {
      const blockRange: { from?: bigint; to?: bigint } = {};
      if (filter?.fromBlock !== undefined) {
        blockRange.from = filter.fromBlock;
      }
      if (filter?.toBlock !== undefined) {
        blockRange.to = filter.toBlock;
      }
      eventFilter.blockRange = blockRange;
    }

    return this.indexer.getEvents(eventFilter);
  }

  isReady(): boolean {
    return this.indexer.getContracts() !== null;
  }

  /**
   * Get the underlying indexer for direct access
   */
  getIndexer(): AnvilIndexer {
    return this.indexer;
  }
}

/**
 * Subgraph data source adapter
 *
 * Uses SubgraphClient for production data from The Graph.
 */
export class SubgraphAdapter implements DataSourceAdapter {
  readonly source: DataSource = 'subgraph';
  private client: SubgraphClient;

  constructor(config: SubgraphAdapterConfig) {
    this.client = config.client;
  }

  async getVaults(filter?: VaultQueryOptions): Promise<Vault[]> {
    return this.client.getVaults(filter);
  }

  async getEvents(_filter?: AdapterEventFilter): Promise<IndexedEvent[]> {
    // Subgraph client doesn't support event queries directly
    // Return empty array - events come from Anvil during simulation
    return [];
  }

  isReady(): boolean {
    return true;
  }

  /**
   * Get the underlying client for direct access
   */
  getClient(): SubgraphClient {
    return this.client;
  }
}

/**
 * Create an Anvil adapter from an indexer
 */
export function createAnvilAdapter(indexer: AnvilIndexer): AnvilAdapter {
  return new AnvilAdapter({ indexer });
}

/**
 * Create a Subgraph adapter from a client
 */
export function createSubgraphAdapter(client: SubgraphClient): SubgraphAdapter {
  return new SubgraphAdapter({ client });
}
