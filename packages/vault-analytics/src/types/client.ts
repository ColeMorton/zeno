import type { Chain } from 'viem';

/**
 * Supported chain IDs
 *
 * - 1: Ethereum Mainnet
 * - 8453: Base Mainnet
 * - 11155111: Sepolia Testnet
 * - 84532: Base Sepolia Testnet
 * - 31337: Local Anvil (development)
 */
export type SupportedChainId = 1 | 8453 | 11155111 | 84532 | 31337;

/**
 * Chain configuration
 */
export interface ChainConfig {
  /** Chain ID */
  chainId: SupportedChainId;
  /** VaultNFT contract address */
  vaultNftAddress: `0x${string}`;
  /** vestedBTC contract address */
  vestedBtcAddress: `0x${string}`;
  /** Default subgraph URL */
  subgraphUrl: string;
}

/**
 * Client configuration options
 */
export interface VaultClientConfig {
  /** Chain ID to connect to */
  chainId: SupportedChainId;
  /** Custom subgraph URL (overrides default) */
  subgraphUrl?: string;
  /** Custom RPC URL (overrides default) */
  rpcUrl?: string;
  /** Custom viem chain configuration */
  chain?: Chain;
}

/**
 * Subgraph query response
 */
export interface SubgraphResponse<T> {
  data: T;
  errors?: Array<{ message: string }>;
}
