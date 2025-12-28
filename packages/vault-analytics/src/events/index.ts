/**
 * Event schema definitions for protocol and issuer layer events.
 * These types mirror the Solidity event definitions for type-safe indexing.
 *
 * @module events
 */

export type {
  // Base types
  EventMetadata,
  DormancyState,
  EventType,
  IndexedEvent,

  // Protocol events
  ProtocolEvent,
  VaultMintedEvent,
  WithdrawnEvent,
  EarlyRedemptionEvent,
  BtcTokenMintedEvent,
  BtcTokenReturnedEvent,
  MatchClaimedEvent,
  MatchPoolFundedEvent,
  DormantPokedEvent,
  DormancyStateChangedEvent,
  ActivityProvenEvent,
  DormantCollateralClaimedEvent,

  // Delegation events
  WithdrawalDelegateGrantedEvent,
  WithdrawalDelegateRevokedEvent,
  AllWithdrawalDelegatesRevokedEvent,
  DelegatedWithdrawalEvent,

  // Achievement events
  AchievementEvent,
  MinterAchievementClaimedEvent,
  MaturedAchievementClaimedEvent,
  DurationAchievementClaimedEvent,
  HodlerSupremeVaultMintedEvent,

  // Auction events
  AuctionEvent,
  DutchAuctionCreatedEvent,
  DutchPurchaseEvent,
  EnglishAuctionCreatedEvent,
  BidPlacedEvent,
  BidRefundedEvent,
  SlotSettledEvent,
  AuctionFinalizedEvent,
} from './schema.js';

export { EVENT_TYPES, parseDormancyState } from './schema.js';
