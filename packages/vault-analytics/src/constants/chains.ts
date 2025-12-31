import type { ChainConfig, SupportedChainId } from '../types/client.js';

/**
 * Chain configurations for supported networks.
 *
 * Contains contract addresses and subgraph URLs for each supported chain.
 *
 * **Production chains:** Ethereum (1), Base (8453)
 * **Testnet chains:** Sepolia (11155111), Base Sepolia (84532)
 *
 * @remarks
 * Contract addresses are placeholders until production deployment.
 *
 * @example Access chain config
 * ```typescript
 * import { CHAIN_CONFIGS } from '@btcnft/vault-analytics';
 *
 * const ethConfig = CHAIN_CONFIGS[1];
 * console.log(ethConfig.subgraphUrl);
 * ```
 */
export const CHAIN_CONFIGS: Record<SupportedChainId, ChainConfig> = {
  /**
   * Ethereum Mainnet - Primary production chain
   */
  1: {
    chainId: 1,
    vaultNftAddress: '0x0000000000000000000000000000000000000000',
    vestedBtcAddress: '0x0000000000000000000000000000000000000000',
    subgraphUrl: 'https://api.thegraph.com/subgraphs/name/btcnft/vault-analytics',
  },
  /**
   * Base Mainnet - L2 production chain
   */
  8453: {
    chainId: 8453,
    vaultNftAddress: '0x0000000000000000000000000000000000000000',
    vestedBtcAddress: '0x0000000000000000000000000000000000000000',
    subgraphUrl: 'https://api.thegraph.com/subgraphs/name/btcnft/vault-analytics-base',
  },
  /**
   * Sepolia Testnet - Ethereum L1 testnet
   */
  11155111: {
    chainId: 11155111,
    vaultNftAddress: '0x0000000000000000000000000000000000000000',
    vestedBtcAddress: '0x0000000000000000000000000000000000000000',
    subgraphUrl: 'https://api.thegraph.com/subgraphs/name/btcnft/vault-analytics-sepolia',
  },
  /**
   * Base Sepolia Testnet - Base L2 testnet
   */
  84532: {
    chainId: 84532,
    vaultNftAddress: '0x0000000000000000000000000000000000000000',
    vestedBtcAddress: '0x0000000000000000000000000000000000000000',
    subgraphUrl: 'https://api.thegraph.com/subgraphs/name/btcnft/vault-analytics-base-sepolia',
  },
  /**
   * Local Anvil - Development chain
   *
   * Contract addresses should be set via environment variables or
   * updated after local deployment. Use AnvilAdapter for local testing.
   *
   * @remarks
   * For local development, use the AnvilIndexer and AnvilAdapter instead of
   * the SubgraphClient. The addresses here are defaults from `forge script`.
   */
  31337: {
    chainId: 31337,
    vaultNftAddress: '0x5FbDB2315678afecb367f032d93F642f64180aa3',
    vestedBtcAddress: '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512',
    subgraphUrl: '', // No subgraph for local development
  },
};

/**
 * Get chain configuration by chain ID.
 *
 * @param chainId - Supported chain ID (1, 8453, 11155111, or 84532)
 * @returns Chain configuration with contract addresses and subgraph URL
 * @throws {Error} If chainId is not supported
 *
 * @example Get Ethereum config
 * ```typescript
 * const config = getChainConfig(1);
 * console.log(config.subgraphUrl);
 * ```
 *
 * @example Handle unsupported chain
 * ```typescript
 * try {
 *   const config = getChainConfig(chainId);
 * } catch (e) {
 *   console.error('Chain not supported');
 * }
 * ```
 */
export function getChainConfig(chainId: SupportedChainId): ChainConfig {
  const config = CHAIN_CONFIGS[chainId];
  if (!config) {
    throw new Error(`Unsupported chain ID: ${chainId}`);
  }
  return config;
}
