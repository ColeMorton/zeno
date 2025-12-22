import type { Address } from 'viem';

/**
 * Core Vault NFT data structure
 */
export interface Vault {
  /** Unique vault token ID */
  tokenId: bigint;
  /** Current vault owner address */
  owner: Address;
  /** ERC-721 Treasure contract address */
  treasureContract: Address;
  /** Treasure token ID within the contract */
  treasureTokenId: bigint;
  /** Collateral token address (WBTC or cbBTC) */
  collateralToken: Address;
  /** Collateral amount in token's smallest unit (8 decimals for BTC) */
  collateralAmount: bigint;
  /** Block timestamp when vault was minted */
  mintTimestamp: bigint;
  /** Timestamp of last withdrawal (0 if never withdrawn) */
  lastWithdrawal: bigint;
  /** Amount of vestedBTC minted from this vault (0 = combined) */
  vestedBTCAmount: bigint;
  /** Last activity timestamp for dormancy tracking */
  lastActivity: bigint;
  /** Poke timestamp for dormancy (0 = not poked) */
  pokeTimestamp: bigint;
  /** Window ID this vault was minted through (0 for instant mint) */
  windowId: bigint;
  /** Issuer address who created the minting window */
  issuer: Address;
}

/**
 * Raw vault data from subgraph (string types for BigInt fields)
 */
export interface RawVaultData {
  id: string;
  owner: string;
  treasureContract: string;
  treasureTokenId: string;
  collateralToken: string;
  collateralAmount: string;
  mintTimestamp: string;
  lastWithdrawal: string;
  vestedBTCAmount: string;
  lastActivity: string;
  pokeTimestamp: string;
  windowId: string;
  issuer: string;
}
