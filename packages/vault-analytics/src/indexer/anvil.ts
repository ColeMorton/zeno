import {
  type Address,
  type Hash,
  type Hex,
  type PublicClient,
  type Log,
  createPublicClient,
  http,
  parseAbiItem,
} from 'viem';
import { anvil } from 'viem/chains';
import type {
  IndexedEvent,
  EventType,
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
  WithdrawalDelegateGrantedEvent,
  WithdrawalDelegateRevokedEvent,
  AllWithdrawalDelegatesRevokedEvent,
  DelegatedWithdrawalEvent,
  MinterAchievementClaimedEvent,
  MaturedAchievementClaimedEvent,
  DurationAchievementClaimedEvent,
  HodlerSupremeVaultMintedEvent,
  DutchAuctionCreatedEvent,
  DutchPurchaseEvent,
  EnglishAuctionCreatedEvent,
  BidPlacedEvent,
  BidRefundedEvent,
  SlotSettledEvent,
  AuctionFinalizedEvent,
} from '../events/schema.js';
import { parseDormancyState } from '../events/schema.js';

/**
 * Contract addresses for indexing
 */
export interface ContractAddresses {
  /** VaultNFT protocol contract */
  vaultNFT: Address;
  /** BtcToken (vestedBTC) contract */
  btcToken: Address;
  /** AchievementNFT contract (optional, issuer layer) */
  achievementNFT?: Address;
  /** AchievementMinter contract (optional, issuer layer) */
  achievementMinter?: Address;
  /** AuctionController contract (optional, issuer layer) */
  auctionController?: Address;
}

/**
 * Filter options for querying indexed events
 */
export interface EventFilter {
  /** Filter by event type(s) */
  types?: EventType[];
  /** Filter by block range (inclusive) */
  blockRange?: {
    from?: bigint;
    to?: bigint;
  };
  /** Filter by token ID (for vault events) */
  tokenId?: bigint;
  /** Filter by address (owner, delegate, bidder, etc.) */
  address?: Address;
}

/**
 * Anvil event indexer configuration
 */
export interface AnvilIndexerConfig {
  /** RPC URL (default: http://127.0.0.1:8545) */
  rpcUrl?: string;
  /** Poll interval in ms (default: 1000) */
  pollInterval?: number;
}

// ABI fragments for all events
const VAULT_NFT_EVENTS = [
  parseAbiItem('event VaultMinted(uint256 indexed tokenId, address indexed owner, address treasureContract, uint256 treasureTokenId, uint256 collateral)'),
  parseAbiItem('event Withdrawn(uint256 indexed tokenId, address indexed to, uint256 amount)'),
  parseAbiItem('event EarlyRedemption(uint256 indexed tokenId, address indexed owner, uint256 returned, uint256 forfeited)'),
  parseAbiItem('event BtcTokenMinted(uint256 indexed tokenId, address indexed to, uint256 amount)'),
  parseAbiItem('event BtcTokenReturned(uint256 indexed tokenId, address indexed from, uint256 amount)'),
  parseAbiItem('event MatchClaimed(uint256 indexed tokenId, uint256 amount)'),
  parseAbiItem('event MatchPoolFunded(uint256 amount, uint256 newBalance)'),
  parseAbiItem('event DormantPoked(uint256 indexed tokenId, address indexed owner, address indexed poker, uint256 graceDeadline)'),
  parseAbiItem('event DormancyStateChanged(uint256 indexed tokenId, uint8 newState)'),
  parseAbiItem('event ActivityProven(uint256 indexed tokenId, address indexed owner)'),
  parseAbiItem('event DormantCollateralClaimed(uint256 indexed tokenId, address indexed originalOwner, address indexed claimer, uint256 collateralClaimed)'),
  parseAbiItem('event WithdrawalDelegateGranted(uint256 indexed tokenId, address indexed delegate, uint256 percentageBPS)'),
  parseAbiItem('event WithdrawalDelegateRevoked(uint256 indexed tokenId, address indexed delegate)'),
  parseAbiItem('event AllWithdrawalDelegatesRevoked(uint256 indexed tokenId)'),
  parseAbiItem('event DelegatedWithdrawal(uint256 indexed tokenId, address indexed delegate, uint256 amount)'),
] as const;

const ACHIEVEMENT_MINTER_EVENTS = [
  parseAbiItem('event MinterAchievementClaimed(address indexed wallet, uint256 indexed vaultId)'),
  parseAbiItem('event MaturedAchievementClaimed(address indexed wallet, uint256 indexed vaultId)'),
  parseAbiItem('event DurationAchievementClaimed(address indexed wallet, uint256 indexed vaultId, bytes32 indexed achievementType)'),
  parseAbiItem('event HodlerSupremeVaultMinted(address indexed wallet, uint256 indexed vaultId, uint256 treasureId, uint256 collateralAmount)'),
] as const;

const AUCTION_CONTROLLER_EVENTS = [
  parseAbiItem('event DutchAuctionCreated(uint256 indexed auctionId, uint256 maxSupply, uint256 startPrice, uint256 floorPrice, uint256 startTime, uint256 endTime)'),
  parseAbiItem('event DutchPurchase(uint256 indexed auctionId, address indexed buyer, uint256 price, uint256 vaultId, uint256 treasureId)'),
  parseAbiItem('event EnglishAuctionCreated(uint256 indexed auctionId, uint256 maxSupply, uint256 reservePrice, uint256 startTime, uint256 endTime)'),
  parseAbiItem('event BidPlaced(uint256 indexed auctionId, uint256 indexed slot, address indexed bidder, uint256 amount)'),
  parseAbiItem('event BidRefunded(uint256 indexed auctionId, uint256 indexed slot, address indexed bidder, uint256 amount)'),
  parseAbiItem('event SlotSettled(uint256 indexed auctionId, uint256 indexed slot, address indexed winner, uint256 vaultId, uint256 treasureId, uint256 winningBid)'),
  parseAbiItem('event AuctionFinalized(uint256 indexed auctionId)'),
] as const;

/**
 * Real-time event indexer for Anvil local testnet.
 * Captures protocol and issuer layer events during simulation.
 *
 * @example
 * ```typescript
 * const indexer = createAnvilIndexer('http://127.0.0.1:8545');
 * await indexer.startIndexing({
 *   vaultNFT: '0x...',
 *   btcToken: '0x...',
 * });
 *
 * // Run simulation...
 *
 * const events = indexer.getEvents({ types: ['VaultMinted'] });
 * console.log(indexer.exportToJSON());
 *
 * indexer.stopIndexing();
 * ```
 */
export class AnvilIndexer {
  private events: IndexedEvent[] = [];
  private unwatchers: (() => void)[] = [];
  private isIndexing = false;
  private contracts: ContractAddresses | null = null;

  constructor(private client: PublicClient) {}

  /**
   * Start watching all contract events
   */
  async startIndexing(contracts: ContractAddresses): Promise<void> {
    if (this.isIndexing) {
      throw new Error('Indexer is already running');
    }

    this.contracts = contracts;
    this.isIndexing = true;

    // Watch VaultNFT events
    await this.watchVaultNFTEvents(contracts.vaultNFT);

    // Watch optional issuer contracts
    if (contracts.achievementMinter) {
      await this.watchAchievementMinterEvents(contracts.achievementMinter);
    }

    if (contracts.auctionController) {
      await this.watchAuctionControllerEvents(contracts.auctionController);
    }
  }

  private async watchVaultNFTEvents(address: Address): Promise<void> {
    for (const event of VAULT_NFT_EVENTS) {
      const unwatch = this.client.watchContractEvent({
        address,
        abi: [event],
        onLogs: (logs) => this.handleVaultNFTLogs(logs, event.name),
      });
      this.unwatchers.push(unwatch);
    }
  }

  private async watchAchievementMinterEvents(address: Address): Promise<void> {
    for (const event of ACHIEVEMENT_MINTER_EVENTS) {
      const unwatch = this.client.watchContractEvent({
        address,
        abi: [event],
        onLogs: (logs) => this.handleAchievementMinterLogs(logs, event.name),
      });
      this.unwatchers.push(unwatch);
    }
  }

  private async watchAuctionControllerEvents(address: Address): Promise<void> {
    for (const event of AUCTION_CONTROLLER_EVENTS) {
      const unwatch = this.client.watchContractEvent({
        address,
        abi: [event],
        onLogs: (logs) => this.handleAuctionControllerLogs(logs, event.name),
      });
      this.unwatchers.push(unwatch);
    }
  }

  private async getBlockTimestamp(blockNumber: bigint): Promise<bigint> {
    const block = await this.client.getBlock({ blockNumber });
    return block.timestamp;
  }

  private handleVaultNFTLogs(logs: Log[], eventName: string): void {
    for (const log of logs) {
      const args = (log as unknown as { args: Record<string, unknown> }).args;
      const metadata = {
        blockNumber: log.blockNumber ?? 0n,
        blockTimestamp: 0n, // Will be filled async
        transactionHash: log.transactionHash ?? ('0x' as Hash),
        logIndex: log.logIndex ?? 0,
      };

      // Get block timestamp asynchronously
      if (log.blockNumber) {
        this.getBlockTimestamp(log.blockNumber).then((timestamp) => {
          const event = this.events.find(
            (e) =>
              e.blockNumber === log.blockNumber &&
              e.transactionHash === log.transactionHash &&
              e.logIndex === log.logIndex
          );
          if (event) {
            event.blockTimestamp = timestamp;
          }
        });
      }

      switch (eventName) {
        case 'VaultMinted':
          this.events.push({
            type: 'VaultMinted',
            ...metadata,
            tokenId: args.tokenId as bigint,
            owner: args.owner as Address,
            treasureContract: args.treasureContract as Address,
            treasureTokenId: args.treasureTokenId as bigint,
            collateral: args.collateral as bigint,
          } as VaultMintedEvent);
          break;

        case 'Withdrawn':
          this.events.push({
            type: 'Withdrawn',
            ...metadata,
            tokenId: args.tokenId as bigint,
            to: args.to as Address,
            amount: args.amount as bigint,
          } as WithdrawnEvent);
          break;

        case 'EarlyRedemption':
          this.events.push({
            type: 'EarlyRedemption',
            ...metadata,
            tokenId: args.tokenId as bigint,
            owner: args.owner as Address,
            returned: args.returned as bigint,
            forfeited: args.forfeited as bigint,
          } as EarlyRedemptionEvent);
          break;

        case 'BtcTokenMinted':
          this.events.push({
            type: 'BtcTokenMinted',
            ...metadata,
            tokenId: args.tokenId as bigint,
            to: args.to as Address,
            amount: args.amount as bigint,
          } as BtcTokenMintedEvent);
          break;

        case 'BtcTokenReturned':
          this.events.push({
            type: 'BtcTokenReturned',
            ...metadata,
            tokenId: args.tokenId as bigint,
            from: args.from as Address,
            amount: args.amount as bigint,
          } as BtcTokenReturnedEvent);
          break;

        case 'MatchClaimed':
          this.events.push({
            type: 'MatchClaimed',
            ...metadata,
            tokenId: args.tokenId as bigint,
            amount: args.amount as bigint,
          } as MatchClaimedEvent);
          break;

        case 'MatchPoolFunded':
          this.events.push({
            type: 'MatchPoolFunded',
            ...metadata,
            amount: args.amount as bigint,
            newBalance: args.newBalance as bigint,
          } as MatchPoolFundedEvent);
          break;

        case 'DormantPoked':
          this.events.push({
            type: 'DormantPoked',
            ...metadata,
            tokenId: args.tokenId as bigint,
            owner: args.owner as Address,
            poker: args.poker as Address,
            graceDeadline: args.graceDeadline as bigint,
          } as DormantPokedEvent);
          break;

        case 'DormancyStateChanged':
          this.events.push({
            type: 'DormancyStateChanged',
            ...metadata,
            tokenId: args.tokenId as bigint,
            newState: parseDormancyState(Number(args.newState)),
          } as DormancyStateChangedEvent);
          break;

        case 'ActivityProven':
          this.events.push({
            type: 'ActivityProven',
            ...metadata,
            tokenId: args.tokenId as bigint,
            owner: args.owner as Address,
          } as ActivityProvenEvent);
          break;

        case 'DormantCollateralClaimed':
          this.events.push({
            type: 'DormantCollateralClaimed',
            ...metadata,
            tokenId: args.tokenId as bigint,
            originalOwner: args.originalOwner as Address,
            claimer: args.claimer as Address,
            collateralClaimed: args.collateralClaimed as bigint,
          } as DormantCollateralClaimedEvent);
          break;

        case 'WithdrawalDelegateGranted':
          this.events.push({
            type: 'WithdrawalDelegateGranted',
            ...metadata,
            tokenId: args.tokenId as bigint,
            delegate: args.delegate as Address,
            percentageBPS: args.percentageBPS as bigint,
          } as WithdrawalDelegateGrantedEvent);
          break;

        case 'WithdrawalDelegateRevoked':
          this.events.push({
            type: 'WithdrawalDelegateRevoked',
            ...metadata,
            tokenId: args.tokenId as bigint,
            delegate: args.delegate as Address,
          } as WithdrawalDelegateRevokedEvent);
          break;

        case 'AllWithdrawalDelegatesRevoked':
          this.events.push({
            type: 'AllWithdrawalDelegatesRevoked',
            ...metadata,
            tokenId: args.tokenId as bigint,
          } as AllWithdrawalDelegatesRevokedEvent);
          break;

        case 'DelegatedWithdrawal':
          this.events.push({
            type: 'DelegatedWithdrawal',
            ...metadata,
            tokenId: args.tokenId as bigint,
            delegate: args.delegate as Address,
            amount: args.amount as bigint,
          } as DelegatedWithdrawalEvent);
          break;
      }
    }
  }

  private handleAchievementMinterLogs(logs: Log[], eventName: string): void {
    for (const log of logs) {
      const args = (log as unknown as { args: Record<string, unknown> }).args;
      const metadata = {
        blockNumber: log.blockNumber ?? 0n,
        blockTimestamp: 0n,
        transactionHash: log.transactionHash ?? ('0x' as Hash),
        logIndex: log.logIndex ?? 0,
      };

      if (log.blockNumber) {
        this.getBlockTimestamp(log.blockNumber).then((timestamp) => {
          const event = this.events.find(
            (e) =>
              e.blockNumber === log.blockNumber &&
              e.transactionHash === log.transactionHash &&
              e.logIndex === log.logIndex
          );
          if (event) {
            event.blockTimestamp = timestamp;
          }
        });
      }

      switch (eventName) {
        case 'MinterAchievementClaimed':
          this.events.push({
            type: 'MinterAchievementClaimed',
            ...metadata,
            wallet: args.wallet as Address,
            vaultId: args.vaultId as bigint,
          } as MinterAchievementClaimedEvent);
          break;

        case 'MaturedAchievementClaimed':
          this.events.push({
            type: 'MaturedAchievementClaimed',
            ...metadata,
            wallet: args.wallet as Address,
            vaultId: args.vaultId as bigint,
          } as MaturedAchievementClaimedEvent);
          break;

        case 'DurationAchievementClaimed':
          this.events.push({
            type: 'DurationAchievementClaimed',
            ...metadata,
            wallet: args.wallet as Address,
            vaultId: args.vaultId as bigint,
            achievementType: args.achievementType as Hex,
          } as DurationAchievementClaimedEvent);
          break;

        case 'HodlerSupremeVaultMinted':
          this.events.push({
            type: 'HodlerSupremeVaultMinted',
            ...metadata,
            wallet: args.wallet as Address,
            vaultId: args.vaultId as bigint,
            treasureId: args.treasureId as bigint,
            collateralAmount: args.collateralAmount as bigint,
          } as HodlerSupremeVaultMintedEvent);
          break;
      }
    }
  }

  private handleAuctionControllerLogs(logs: Log[], eventName: string): void {
    for (const log of logs) {
      const args = (log as unknown as { args: Record<string, unknown> }).args;
      const metadata = {
        blockNumber: log.blockNumber ?? 0n,
        blockTimestamp: 0n,
        transactionHash: log.transactionHash ?? ('0x' as Hash),
        logIndex: log.logIndex ?? 0,
      };

      if (log.blockNumber) {
        this.getBlockTimestamp(log.blockNumber).then((timestamp) => {
          const event = this.events.find(
            (e) =>
              e.blockNumber === log.blockNumber &&
              e.transactionHash === log.transactionHash &&
              e.logIndex === log.logIndex
          );
          if (event) {
            event.blockTimestamp = timestamp;
          }
        });
      }

      switch (eventName) {
        case 'DutchAuctionCreated':
          this.events.push({
            type: 'DutchAuctionCreated',
            ...metadata,
            auctionId: args.auctionId as bigint,
            maxSupply: args.maxSupply as bigint,
            startPrice: args.startPrice as bigint,
            floorPrice: args.floorPrice as bigint,
            startTime: args.startTime as bigint,
            endTime: args.endTime as bigint,
          } as DutchAuctionCreatedEvent);
          break;

        case 'DutchPurchase':
          this.events.push({
            type: 'DutchPurchase',
            ...metadata,
            auctionId: args.auctionId as bigint,
            buyer: args.buyer as Address,
            price: args.price as bigint,
            vaultId: args.vaultId as bigint,
            treasureId: args.treasureId as bigint,
          } as DutchPurchaseEvent);
          break;

        case 'EnglishAuctionCreated':
          this.events.push({
            type: 'EnglishAuctionCreated',
            ...metadata,
            auctionId: args.auctionId as bigint,
            maxSupply: args.maxSupply as bigint,
            reservePrice: args.reservePrice as bigint,
            startTime: args.startTime as bigint,
            endTime: args.endTime as bigint,
          } as EnglishAuctionCreatedEvent);
          break;

        case 'BidPlaced':
          this.events.push({
            type: 'BidPlaced',
            ...metadata,
            auctionId: args.auctionId as bigint,
            slot: args.slot as bigint,
            bidder: args.bidder as Address,
            amount: args.amount as bigint,
          } as BidPlacedEvent);
          break;

        case 'BidRefunded':
          this.events.push({
            type: 'BidRefunded',
            ...metadata,
            auctionId: args.auctionId as bigint,
            slot: args.slot as bigint,
            bidder: args.bidder as Address,
            amount: args.amount as bigint,
          } as BidRefundedEvent);
          break;

        case 'SlotSettled':
          this.events.push({
            type: 'SlotSettled',
            ...metadata,
            auctionId: args.auctionId as bigint,
            slot: args.slot as bigint,
            winner: args.winner as Address,
            vaultId: args.vaultId as bigint,
            treasureId: args.treasureId as bigint,
            winningBid: args.winningBid as bigint,
          } as SlotSettledEvent);
          break;

        case 'AuctionFinalized':
          this.events.push({
            type: 'AuctionFinalized',
            ...metadata,
            auctionId: args.auctionId as bigint,
          } as AuctionFinalizedEvent);
          break;
      }
    }
  }

  /**
   * Stop watching and cleanup
   */
  stopIndexing(): void {
    this.unwatchers.forEach((unwatch) => unwatch());
    this.unwatchers = [];
    this.isIndexing = false;
  }

  /**
   * Query indexed events with optional filters
   */
  getEvents(filter?: EventFilter): IndexedEvent[] {
    let result = [...this.events];

    if (filter?.types?.length) {
      result = result.filter((e) => filter.types!.includes(e.type));
    }

    if (filter?.blockRange?.from !== undefined) {
      result = result.filter((e) => e.blockNumber >= filter.blockRange!.from!);
    }

    if (filter?.blockRange?.to !== undefined) {
      result = result.filter((e) => e.blockNumber <= filter.blockRange!.to!);
    }

    if (filter?.tokenId !== undefined) {
      result = result.filter((e) => {
        if ('tokenId' in e) return e.tokenId === filter.tokenId;
        if ('vaultId' in e) return e.vaultId === filter.tokenId;
        return false;
      });
    }

    if (filter?.address !== undefined) {
      const addr = filter.address.toLowerCase();
      result = result.filter((e) => {
        if ('owner' in e && (e as { owner: Address }).owner?.toLowerCase() === addr) return true;
        if ('to' in e && (e as { to: Address }).to?.toLowerCase() === addr) return true;
        if ('from' in e && (e as { from: Address }).from?.toLowerCase() === addr) return true;
        if ('delegate' in e && (e as { delegate: Address }).delegate?.toLowerCase() === addr) return true;
        if ('wallet' in e && (e as { wallet: Address }).wallet?.toLowerCase() === addr) return true;
        if ('bidder' in e && (e as { bidder: Address }).bidder?.toLowerCase() === addr) return true;
        if ('buyer' in e && (e as { buyer: Address }).buyer?.toLowerCase() === addr) return true;
        if ('winner' in e && (e as { winner: Address }).winner?.toLowerCase() === addr) return true;
        if ('claimer' in e && (e as { claimer: Address }).claimer?.toLowerCase() === addr) return true;
        if ('poker' in e && (e as { poker: Address }).poker?.toLowerCase() === addr) return true;
        return false;
      });
    }

    return result.sort((a, b) => {
      if (a.blockNumber !== b.blockNumber) {
        return Number(a.blockNumber - b.blockNumber);
      }
      return a.logIndex - b.logIndex;
    });
  }

  /**
   * Get count of indexed events
   */
  getEventCount(): number {
    return this.events.length;
  }

  /**
   * Check if indexer is running
   */
  isRunning(): boolean {
    return this.isIndexing;
  }

  /**
   * Get the contract addresses being indexed
   */
  getContracts(): ContractAddresses | null {
    return this.contracts;
  }

  /**
   * Export all events to JSON
   */
  exportToJSON(): string {
    return JSON.stringify(
      this.events.map((e) => this.serializeEvent(e)),
      null,
      2
    );
  }

  /**
   * Export all events to CSV
   */
  exportToCSV(): string {
    if (this.events.length === 0) return '';

    const headers = [
      'type',
      'blockNumber',
      'blockTimestamp',
      'transactionHash',
      'logIndex',
      'tokenId',
      'amount',
      'address1',
      'address2',
      'extra',
    ];

    const rows = this.events.map((e) => {
      const serialized = this.serializeEvent(e);
      return [
        serialized.type,
        serialized.blockNumber,
        serialized.blockTimestamp,
        serialized.transactionHash,
        serialized.logIndex,
        this.getTokenId(e),
        this.getAmount(e),
        this.getAddress1(e),
        this.getAddress2(e),
        this.getExtra(e),
      ].join(',');
    });

    return [headers.join(','), ...rows].join('\n');
  }

  private serializeEvent(e: IndexedEvent): Record<string, unknown> {
    const result: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(e)) {
      if (typeof value === 'bigint') {
        result[key] = value.toString();
      } else {
        result[key] = value;
      }
    }
    return result;
  }

  private getTokenId(e: IndexedEvent): string {
    if ('tokenId' in e) return (e as { tokenId: bigint }).tokenId.toString();
    if ('vaultId' in e) return (e as { vaultId: bigint }).vaultId.toString();
    if ('auctionId' in e) return (e as { auctionId: bigint }).auctionId.toString();
    return '';
  }

  private getAmount(e: IndexedEvent): string {
    if ('amount' in e) return (e as { amount: bigint }).amount.toString();
    if ('collateral' in e) return (e as { collateral: bigint }).collateral.toString();
    if ('collateralAmount' in e) return (e as { collateralAmount: bigint }).collateralAmount.toString();
    if ('price' in e) return (e as { price: bigint }).price.toString();
    if ('winningBid' in e) return (e as { winningBid: bigint }).winningBid.toString();
    return '';
  }

  private getAddress1(e: IndexedEvent): string {
    if ('owner' in e) return (e as { owner: Address }).owner;
    if ('to' in e) return (e as { to: Address }).to;
    if ('wallet' in e) return (e as { wallet: Address }).wallet;
    if ('buyer' in e) return (e as { buyer: Address }).buyer;
    if ('bidder' in e) return (e as { bidder: Address }).bidder;
    if ('winner' in e) return (e as { winner: Address }).winner;
    return '';
  }

  private getAddress2(e: IndexedEvent): string {
    if ('delegate' in e) return (e as { delegate: Address }).delegate;
    if ('poker' in e) return (e as { poker: Address }).poker;
    if ('claimer' in e) return (e as { claimer: Address }).claimer;
    if ('from' in e) return (e as { from: Address }).from;
    return '';
  }

  private getExtra(e: IndexedEvent): string {
    if ('newState' in e) return (e as { newState: string }).newState;
    if ('achievementType' in e) return (e as { achievementType: Hex }).achievementType;
    if ('percentageBPS' in e) return (e as { percentageBPS: bigint }).percentageBPS.toString();
    if ('slot' in e) return (e as { slot: bigint }).slot.toString();
    return '';
  }

  /**
   * Clear all stored events
   */
  clear(): void {
    this.events = [];
  }
}

/**
 * Create an Anvil indexer with default configuration
 *
 * @param rpcUrl - RPC URL (default: http://127.0.0.1:8545)
 */
export function createAnvilIndexer(rpcUrl = 'http://127.0.0.1:8545'): AnvilIndexer {
  const client = createPublicClient({
    chain: anvil,
    transport: http(rpcUrl),
  });

  return new AnvilIndexer(client);
}
