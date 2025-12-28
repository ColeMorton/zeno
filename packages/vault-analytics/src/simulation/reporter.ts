import type { Address, PublicClient } from 'viem';
import { createPublicClient, http } from 'viem';
import { anvil } from 'viem/chains';
import { AnvilIndexer, type ContractAddresses } from '../indexer/anvil.js';
import type { IndexedEvent, EventType } from '../events/schema.js';
import { type GhostVariables, readGhostVariables, formatGhostVariables } from './ghosts.js';
import { BTC_DECIMALS } from '../constants/protocol.js';

/**
 * Summary statistics for a simulation run
 */
export interface SimulationSummary {
  /** Total vaults minted */
  vaultsMinted: number;
  /** Total collateral deposited (in satoshis) */
  totalCollateral: bigint;
  /** Total withdrawals executed */
  withdrawalsExecuted: number;
  /** Total withdrawn amount (in satoshis) */
  totalWithdrawn: bigint;
  /** Total early redemptions */
  earlyRedemptions: number;
  /** Total forfeited to match pool (in satoshis) */
  totalForfeited: bigint;
  /** Total achievements claimed */
  achievementsClaimed: number;
  /** Total match claims */
  matchClaims: number;
  /** Total auction purchases */
  auctionPurchases: number;
}

/**
 * Complete simulation report
 */
export interface SimulationReport {
  /** Report generation timestamp */
  generatedAt: Date;
  /** Simulation duration in blocks */
  blockRange: {
    start: bigint;
    end: bigint;
  };
  /** Contract addresses indexed */
  contracts: ContractAddresses;
  /** Summary statistics */
  summary: SimulationSummary;
  /** Ghost variables from handler (if available) */
  ghostVariables?: GhostVariables | undefined;
  /** All indexed events */
  events: IndexedEvent[];
  /** Event counts by type */
  eventCounts: Record<EventType, number>;
}

/**
 * Configuration for simulation reporter
 */
export interface SimulationReporterConfig {
  /** RPC URL (default: http://127.0.0.1:8545) */
  rpcUrl?: string | undefined;
  /** CrossLayerHandler address for ghost variables */
  handlerAddress?: Address | undefined;
}

/**
 * Generates comprehensive reports from simulation runs.
 * Combines event indexing with ghost variable analysis.
 *
 * @example
 * ```typescript
 * const reporter = createSimulationReporter({
 *   rpcUrl: 'http://127.0.0.1:8545',
 *   handlerAddress: '0x...',
 * });
 *
 * await reporter.startCapturing({
 *   vaultNFT: '0x...',
 *   btcToken: '0x...',
 * });
 *
 * // Run simulation...
 *
 * const report = await reporter.generateReport();
 * console.log(report.summary.vaultsMinted);
 *
 * await reporter.exportReport(report, 'json', 'simulation-report.json');
 * ```
 */
export class SimulationReporter {
  private indexer: AnvilIndexer;
  private client: PublicClient;
  private handlerAddress: Address | undefined;
  private startBlock: bigint = 0n;

  constructor(config: SimulationReporterConfig = {}) {
    const rpcUrl = config.rpcUrl ?? 'http://127.0.0.1:8545';
    this.client = createPublicClient({
      chain: anvil,
      transport: http(rpcUrl),
    });
    this.indexer = new AnvilIndexer(this.client);
    this.handlerAddress = config.handlerAddress;
  }

  /**
   * Start capturing events for a simulation run
   */
  async startCapturing(contracts: ContractAddresses): Promise<void> {
    this.startBlock = await this.client.getBlockNumber();
    await this.indexer.startIndexing(contracts);
  }

  /**
   * Stop capturing and generate a report
   */
  async generateReport(): Promise<SimulationReport> {
    const endBlock = await this.client.getBlockNumber();
    const events = this.indexer.getEvents();
    const contracts = this.indexer.getContracts();

    if (!contracts) {
      throw new Error('No contracts configured - call startCapturing first');
    }

    // Calculate summary from events
    const summary = this.calculateSummary(events);

    // Calculate event counts
    const eventCounts = this.calculateEventCounts(events);

    // Read ghost variables if handler configured
    let ghostVariables: GhostVariables | undefined;
    if (this.handlerAddress) {
      try {
        ghostVariables = await readGhostVariables(this.client, this.handlerAddress);
      } catch {
        // Handler may not be deployed - ghost variables optional
      }
    }

    return {
      generatedAt: new Date(),
      blockRange: {
        start: this.startBlock,
        end: endBlock,
      },
      contracts,
      summary,
      ghostVariables,
      events,
      eventCounts,
    };
  }

  /**
   * Stop capturing events
   */
  stopCapturing(): void {
    this.indexer.stopIndexing();
  }

  /**
   * Clear captured events
   */
  clear(): void {
    this.indexer.clear();
  }

  private calculateSummary(events: IndexedEvent[]): SimulationSummary {
    let vaultsMinted = 0;
    let totalCollateral = 0n;
    let withdrawalsExecuted = 0;
    let totalWithdrawn = 0n;
    let earlyRedemptions = 0;
    let totalForfeited = 0n;
    let achievementsClaimed = 0;
    let matchClaims = 0;
    let auctionPurchases = 0;

    for (const event of events) {
      switch (event.type) {
        case 'VaultMinted':
          vaultsMinted++;
          totalCollateral += event.collateral;
          break;
        case 'Withdrawn':
          withdrawalsExecuted++;
          totalWithdrawn += event.amount;
          break;
        case 'DelegatedWithdrawal':
          withdrawalsExecuted++;
          totalWithdrawn += event.amount;
          break;
        case 'EarlyRedemption':
          earlyRedemptions++;
          totalForfeited += event.forfeited;
          break;
        case 'MinterAchievementClaimed':
        case 'MaturedAchievementClaimed':
        case 'DurationAchievementClaimed':
          achievementsClaimed++;
          break;
        case 'MatchClaimed':
          matchClaims++;
          break;
        case 'DutchPurchase':
        case 'SlotSettled':
          auctionPurchases++;
          break;
      }
    }

    return {
      vaultsMinted,
      totalCollateral,
      withdrawalsExecuted,
      totalWithdrawn,
      earlyRedemptions,
      totalForfeited,
      achievementsClaimed,
      matchClaims,
      auctionPurchases,
    };
  }

  private calculateEventCounts(events: IndexedEvent[]): Record<EventType, number> {
    const counts: Record<string, number> = {};
    for (const event of events) {
      counts[event.type] = (counts[event.type] ?? 0) + 1;
    }
    return counts as Record<EventType, number>;
  }

  /**
   * Export report to JSON or CSV format
   */
  exportReport(report: SimulationReport, format: 'json' | 'csv'): string {
    if (format === 'json') {
      return this.exportToJSON(report);
    }
    return this.exportToCSV(report);
  }

  private exportToJSON(report: SimulationReport): string {
    return JSON.stringify(
      {
        generatedAt: report.generatedAt.toISOString(),
        blockRange: {
          start: report.blockRange.start.toString(),
          end: report.blockRange.end.toString(),
        },
        contracts: report.contracts,
        summary: {
          ...report.summary,
          totalCollateral: report.summary.totalCollateral.toString(),
          totalWithdrawn: report.summary.totalWithdrawn.toString(),
          totalForfeited: report.summary.totalForfeited.toString(),
        },
        ghostVariables: report.ghostVariables
          ? this.serializeGhostVariables(report.ghostVariables)
          : undefined,
        eventCounts: report.eventCounts,
        events: report.events.map((e) => this.serializeEvent(e)),
      },
      null,
      2
    );
  }

  private exportToCSV(report: SimulationReport): string {
    const lines: string[] = [];

    // Summary section
    lines.push('=== SIMULATION SUMMARY ===');
    lines.push(`Generated At,${report.generatedAt.toISOString()}`);
    lines.push(`Block Range,${report.blockRange.start}-${report.blockRange.end}`);
    lines.push(`Vaults Minted,${report.summary.vaultsMinted}`);
    lines.push(`Total Collateral (BTC),${this.formatBtc(report.summary.totalCollateral)}`);
    lines.push(`Withdrawals,${report.summary.withdrawalsExecuted}`);
    lines.push(`Total Withdrawn (BTC),${this.formatBtc(report.summary.totalWithdrawn)}`);
    lines.push(`Early Redemptions,${report.summary.earlyRedemptions}`);
    lines.push(`Total Forfeited (BTC),${this.formatBtc(report.summary.totalForfeited)}`);
    lines.push(`Achievements Claimed,${report.summary.achievementsClaimed}`);
    lines.push(`Match Claims,${report.summary.matchClaims}`);
    lines.push(`Auction Purchases,${report.summary.auctionPurchases}`);
    lines.push('');

    // Ghost variables section
    if (report.ghostVariables) {
      lines.push('=== GHOST VARIABLES ===');
      lines.push(formatGhostVariables(report.ghostVariables));
      lines.push('');
    }

    // Event counts section
    lines.push('=== EVENT COUNTS ===');
    lines.push('Event Type,Count');
    for (const [type, count] of Object.entries(report.eventCounts)) {
      lines.push(`${type},${count}`);
    }
    lines.push('');

    // Events section
    lines.push('=== EVENTS ===');
    lines.push(this.indexer.exportToCSV());

    return lines.join('\n');
  }

  private formatBtc(value: bigint): string {
    return (Number(value) / 10 ** Number(BTC_DECIMALS)).toFixed(8);
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

  private serializeGhostVariables(ghosts: GhostVariables): Record<string, unknown> {
    return {
      protocol: {
        totalDeposited: ghosts.protocol.totalDeposited.toString(),
        totalWithdrawn: ghosts.protocol.totalWithdrawn.toString(),
        totalForfeited: ghosts.protocol.totalForfeited.toString(),
        totalMatchClaimed: ghosts.protocol.totalMatchClaimed.toString(),
      },
      crossLayer: ghosts.crossLayer,
      callCounters: ghosts.callCounters,
    };
  }
}

/**
 * Create a simulation reporter with the given configuration
 */
export function createSimulationReporter(
  config: SimulationReporterConfig = {}
): SimulationReporter {
  return new SimulationReporter(config);
}
