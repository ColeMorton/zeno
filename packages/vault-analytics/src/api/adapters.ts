import {
  type Address,
  type PublicClient,
  createPublicClient,
  http,
} from 'viem';
import { anvil } from 'viem/chains';
import type { Vault } from '../types/vault.js';
import type { IndexedEvent, EventType } from '../events/schema.js';
import type { VaultQueryOptions } from '../types/filter.js';
import type { AnvilIndexer, EventFilter } from '../indexer/anvil.js';
import type { SubgraphClient } from '../client/SubgraphClient.js';

/**
 * Minimal VaultNFT ABI for direct contract queries
 */
const VAULT_NFT_ABI = [
  {
    name: 'ownerOf',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'tokenId', type: 'uint256' }],
    outputs: [{ type: 'address' }],
  },
  {
    name: 'getVaultInfo',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'tokenId', type: 'uint256' }],
    outputs: [
      { name: 'treasureContract', type: 'address' },
      { name: 'treasureTokenId', type: 'uint256' },
      { name: 'collateralToken', type: 'address' },
      { name: 'collateralAmount', type: 'uint256' },
      { name: 'mintTimestamp', type: 'uint256' },
      { name: 'lastWithdrawal', type: 'uint256' },
      { name: 'lastActivity', type: 'uint256' },
      { name: 'btcTokenAmount', type: 'uint256' },
      { name: 'originalMintedAmount', type: 'uint256' },
    ],
  },
] as const;

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
  /** RPC URL for direct contract queries (default: http://127.0.0.1:8545) */
  rpcUrl?: string;
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
 * Queries VaultNFT contract directly for current on-chain state.
 * Uses the indexer for contract addresses and event queries.
 */
export class AnvilAdapter implements DataSourceAdapter {
  readonly source: DataSource = 'anvil';
  private indexer: AnvilIndexer;
  private client: PublicClient;

  constructor(config: AnvilAdapterConfig) {
    this.indexer = config.indexer;
    this.client = createPublicClient({
      chain: anvil,
      transport: http(config.rpcUrl ?? 'http://127.0.0.1:8545'),
    });
  }

  async getVaults(_filter?: VaultQueryOptions): Promise<Vault[]> {
    const contracts = this.indexer.getContracts();
    if (!contracts) {
      throw new Error('Indexer not started - contract addresses unknown');
    }

    const vaults: Vault[] = [];
    let tokenId = 0n;

    // Iterate through token IDs until we hit a non-existent token
    while (true) {
      try {
        const owner = await this.client.readContract({
          address: contracts.vaultNFT,
          abi: VAULT_NFT_ABI,
          functionName: 'ownerOf',
          args: [tokenId],
        });

        const info = await this.client.readContract({
          address: contracts.vaultNFT,
          abi: VAULT_NFT_ABI,
          functionName: 'getVaultInfo',
          args: [tokenId],
        });

        vaults.push({
          tokenId,
          owner: owner as Address,
          treasureContract: info[0] as Address,
          treasureTokenId: info[1] as bigint,
          collateralToken: info[2] as Address,
          collateralAmount: info[3] as bigint,
          mintTimestamp: info[4] as bigint,
          lastWithdrawal: info[5] as bigint,
          vestedBTCAmount: info[7] as bigint,
          lastActivity: info[6] as bigint,
          pokeTimestamp: 0n,
          windowId: 0n,
          issuer: info[0] as Address,
        });

        tokenId++;
      } catch {
        // Token doesn't exist - we've enumerated all vaults
        break;
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
