import type { Address, Hash, Hex } from 'viem';

/**
 * Base event metadata common to all indexed events
 */
export interface EventMetadata {
  /** Block number when event was emitted */
  blockNumber: bigint;
  /** Block timestamp (Unix seconds) */
  blockTimestamp: bigint;
  /** Transaction hash containing this event */
  transactionHash: Hash;
  /** Log index within the block */
  logIndex: number;
}

// ============================================================================
// Protocol Layer Events (VaultNFT.sol)
// ============================================================================

/**
 * Emitted when a new vault is minted
 */
export interface VaultMintedEvent extends EventMetadata {
  type: 'VaultMinted';
  tokenId: bigint;
  owner: Address;
  treasureContract: Address;
  treasureTokenId: bigint;
  collateral: bigint;
}

/**
 * Emitted when collateral is withdrawn from a vault
 */
export interface WithdrawnEvent extends EventMetadata {
  type: 'Withdrawn';
  tokenId: bigint;
  to: Address;
  amount: bigint;
}

/**
 * Emitted when a vault is redeemed early (before vesting complete)
 */
export interface EarlyRedemptionEvent extends EventMetadata {
  type: 'EarlyRedemption';
  tokenId: bigint;
  owner: Address;
  returned: bigint;
  forfeited: bigint;
}

/**
 * Emitted when vestedBTC is minted from a vested vault
 */
export interface BtcTokenMintedEvent extends EventMetadata {
  type: 'BtcTokenMinted';
  tokenId: bigint;
  to: Address;
  amount: bigint;
}

/**
 * Emitted when vestedBTC is returned to recombine with vault
 */
export interface BtcTokenReturnedEvent extends EventMetadata {
  type: 'BtcTokenReturned';
  tokenId: bigint;
  from: Address;
  amount: bigint;
}

/**
 * Emitted when match pool bonus is claimed
 */
export interface MatchClaimedEvent extends EventMetadata {
  type: 'MatchClaimed';
  tokenId: bigint;
  amount: bigint;
}

/**
 * Emitted when funds are added to the match pool
 */
export interface MatchPoolFundedEvent extends EventMetadata {
  type: 'MatchPoolFunded';
  amount: bigint;
  newBalance: bigint;
}

/**
 * Emitted when a dormant vault is poked
 */
export interface DormantPokedEvent extends EventMetadata {
  type: 'DormantPoked';
  tokenId: bigint;
  owner: Address;
  poker: Address;
  graceDeadline: bigint;
}

/**
 * Dormancy state enum matching contract
 */
export type DormancyState = 'ACTIVE' | 'POKE_PENDING' | 'CLAIMABLE';

/**
 * Emitted when dormancy state changes
 */
export interface DormancyStateChangedEvent extends EventMetadata {
  type: 'DormancyStateChanged';
  tokenId: bigint;
  newState: DormancyState;
}

/**
 * Emitted when owner proves activity to reset dormancy
 */
export interface ActivityProvenEvent extends EventMetadata {
  type: 'ActivityProven';
  tokenId: bigint;
  owner: Address;
}

/**
 * Emitted when dormant collateral is claimed
 */
export interface DormantCollateralClaimedEvent extends EventMetadata {
  type: 'DormantCollateralClaimed';
  tokenId: bigint;
  originalOwner: Address;
  claimer: Address;
  collateralClaimed: bigint;
}

// ============================================================================
// Protocol Layer - Delegation Events
// ============================================================================

/**
 * Emitted when withdrawal delegation is granted
 */
export interface WithdrawalDelegateGrantedEvent extends EventMetadata {
  type: 'WithdrawalDelegateGranted';
  tokenId: bigint;
  delegate: Address;
  percentageBPS: bigint;
}

/**
 * Emitted when withdrawal delegation is revoked
 */
export interface WithdrawalDelegateRevokedEvent extends EventMetadata {
  type: 'WithdrawalDelegateRevoked';
  tokenId: bigint;
  delegate: Address;
}

/**
 * Emitted when all withdrawal delegates are revoked
 */
export interface AllWithdrawalDelegatesRevokedEvent extends EventMetadata {
  type: 'AllWithdrawalDelegatesRevoked';
  tokenId: bigint;
}

/**
 * Emitted when delegate executes a withdrawal
 */
export interface DelegatedWithdrawalEvent extends EventMetadata {
  type: 'DelegatedWithdrawal';
  tokenId: bigint;
  delegate: Address;
  amount: bigint;
}

// ============================================================================
// Issuer Layer - Achievement Events (AchievementMinter.sol)
// ============================================================================

/**
 * Emitted when MINTER achievement is claimed
 */
export interface MinterAchievementClaimedEvent extends EventMetadata {
  type: 'MinterAchievementClaimed';
  wallet: Address;
  vaultId: bigint;
}

/**
 * Emitted when MATURED achievement is claimed
 */
export interface MaturedAchievementClaimedEvent extends EventMetadata {
  type: 'MaturedAchievementClaimed';
  wallet: Address;
  vaultId: bigint;
}

/**
 * Emitted when duration achievement is claimed
 */
export interface DurationAchievementClaimedEvent extends EventMetadata {
  type: 'DurationAchievementClaimed';
  wallet: Address;
  vaultId: bigint;
  achievementType: Hex;
}

/**
 * Emitted when HODLER_SUPREME mints a vault
 */
export interface HodlerSupremeVaultMintedEvent extends EventMetadata {
  type: 'HodlerSupremeVaultMinted';
  wallet: Address;
  vaultId: bigint;
  treasureId: bigint;
  collateralAmount: bigint;
}

// ============================================================================
// Issuer Layer - Auction Events (AuctionController.sol)
// ============================================================================

/**
 * Emitted when a Dutch auction is created
 */
export interface DutchAuctionCreatedEvent extends EventMetadata {
  type: 'DutchAuctionCreated';
  auctionId: bigint;
  maxSupply: bigint;
  startPrice: bigint;
  floorPrice: bigint;
  startTime: bigint;
  endTime: bigint;
}

/**
 * Emitted when a purchase is made in a Dutch auction
 */
export interface DutchPurchaseEvent extends EventMetadata {
  type: 'DutchPurchase';
  auctionId: bigint;
  buyer: Address;
  price: bigint;
  vaultId: bigint;
  treasureId: bigint;
}

/**
 * Emitted when an English auction is created
 */
export interface EnglishAuctionCreatedEvent extends EventMetadata {
  type: 'EnglishAuctionCreated';
  auctionId: bigint;
  maxSupply: bigint;
  reservePrice: bigint;
  startTime: bigint;
  endTime: bigint;
}

/**
 * Emitted when a bid is placed in an English auction
 */
export interface BidPlacedEvent extends EventMetadata {
  type: 'BidPlaced';
  auctionId: bigint;
  slot: bigint;
  bidder: Address;
  amount: bigint;
}

/**
 * Emitted when a bid is refunded (outbid)
 */
export interface BidRefundedEvent extends EventMetadata {
  type: 'BidRefunded';
  auctionId: bigint;
  slot: bigint;
  bidder: Address;
  amount: bigint;
}

/**
 * Emitted when an English auction slot is settled
 */
export interface SlotSettledEvent extends EventMetadata {
  type: 'SlotSettled';
  auctionId: bigint;
  slot: bigint;
  winner: Address;
  vaultId: bigint;
  treasureId: bigint;
  winningBid: bigint;
}

/**
 * Emitted when an auction is finalized
 */
export interface AuctionFinalizedEvent extends EventMetadata {
  type: 'AuctionFinalized';
  auctionId: bigint;
}

// ============================================================================
// Union Types
// ============================================================================

/**
 * All protocol layer events
 */
export type ProtocolEvent =
  | VaultMintedEvent
  | WithdrawnEvent
  | EarlyRedemptionEvent
  | BtcTokenMintedEvent
  | BtcTokenReturnedEvent
  | MatchClaimedEvent
  | MatchPoolFundedEvent
  | DormantPokedEvent
  | DormancyStateChangedEvent
  | ActivityProvenEvent
  | DormantCollateralClaimedEvent
  | WithdrawalDelegateGrantedEvent
  | WithdrawalDelegateRevokedEvent
  | AllWithdrawalDelegatesRevokedEvent
  | DelegatedWithdrawalEvent;

/**
 * All achievement-related events
 */
export type AchievementEvent =
  | MinterAchievementClaimedEvent
  | MaturedAchievementClaimedEvent
  | DurationAchievementClaimedEvent
  | HodlerSupremeVaultMintedEvent;

/**
 * All auction-related events
 */
export type AuctionEvent =
  | DutchAuctionCreatedEvent
  | DutchPurchaseEvent
  | EnglishAuctionCreatedEvent
  | BidPlacedEvent
  | BidRefundedEvent
  | SlotSettledEvent
  | AuctionFinalizedEvent;

/**
 * All indexed events
 */
export type IndexedEvent = ProtocolEvent | AchievementEvent | AuctionEvent;

/**
 * Event type discriminator
 */
export type EventType = IndexedEvent['type'];

/**
 * All event type strings
 */
export const EVENT_TYPES = [
  // Protocol
  'VaultMinted',
  'Withdrawn',
  'EarlyRedemption',
  'BtcTokenMinted',
  'BtcTokenReturned',
  'MatchClaimed',
  'MatchPoolFunded',
  'DormantPoked',
  'DormancyStateChanged',
  'ActivityProven',
  'DormantCollateralClaimed',
  'WithdrawalDelegateGranted',
  'WithdrawalDelegateRevoked',
  'AllWithdrawalDelegatesRevoked',
  'DelegatedWithdrawal',
  // Achievement
  'MinterAchievementClaimed',
  'MaturedAchievementClaimed',
  'DurationAchievementClaimed',
  'HodlerSupremeVaultMinted',
  // Auction
  'DutchAuctionCreated',
  'DutchPurchase',
  'EnglishAuctionCreated',
  'BidPlaced',
  'BidRefunded',
  'SlotSettled',
  'AuctionFinalized',
] as const;

/**
 * Map dormancy state number to string
 */
export function parseDormancyState(state: number): DormancyState {
  switch (state) {
    case 0:
      return 'ACTIVE';
    case 1:
      return 'POKE_PENDING';
    case 2:
      return 'CLAIMABLE';
    default:
      throw new Error(`Unknown dormancy state: ${state}`);
  }
}
