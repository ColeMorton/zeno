import type { Address, PublicClient } from 'viem';

/**
 * Protocol-level ghost variables from CrossLayerHandler
 */
export interface ProtocolGhostVariables {
  /** Total BTC deposited as collateral */
  totalDeposited: bigint;
  /** Total BTC withdrawn */
  totalWithdrawn: bigint;
  /** Total BTC forfeited to match pool */
  totalForfeited: bigint;
  /** Total match pool rewards claimed */
  totalMatchClaimed: bigint;
}

/**
 * Cross-layer ghost variables from CrossLayerHandler
 */
export interface CrossLayerGhostVariables {
  /** Total achievement NFTs minted */
  achievementsMinted: number;
  /** Total treasure NFTs minted */
  treasuresMinted: number;
  /** Number of vaults with issuer treasure */
  vaultsWithIssuerTreasure: number;
}

/**
 * Call counter ghost variables from CrossLayerHandler
 */
export interface CallCounterVariables {
  /** Number of vault mint calls */
  mintVault: number;
  /** Number of withdrawal calls */
  withdraw: number;
  /** Number of early redemption calls */
  earlyRedeem: number;
  /** Number of match claim calls */
  claimMatch: number;
  /** Number of achievement claim calls */
  claimAchievement: number;
  /** Number of time warp calls */
  warp: number;
}

/**
 * Complete ghost variable state from CrossLayerHandler
 */
export interface GhostVariables {
  /** Protocol-level aggregate values */
  protocol: ProtocolGhostVariables;
  /** Cross-layer aggregate values */
  crossLayer: CrossLayerGhostVariables;
  /** Function call counters */
  callCounters: CallCounterVariables;
}

/**
 * ABI for reading CrossLayerHandler ghost variables
 */
const HANDLER_ABI = [
  // Protocol ghost variables
  {
    inputs: [],
    name: 'ghost_totalDeposited',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'ghost_totalWithdrawn',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'ghost_totalForfeited',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'ghost_totalMatchClaimed',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  // Cross-layer ghost variables
  {
    inputs: [],
    name: 'ghost_achievementsMinted',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'ghost_treasuresMinted',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'ghost_vaultsWithIssuerTreasure',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  // Call counters
  {
    inputs: [],
    name: 'calls_mintVault',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'calls_withdraw',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'calls_earlyRedeem',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'calls_claimMatch',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'calls_claimAchievement',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'calls_warp',
    outputs: [{ type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const;

/**
 * Read ghost variables from a CrossLayerHandler contract
 *
 * @param client - Viem public client
 * @param handlerAddress - CrossLayerHandler contract address
 * @returns Complete ghost variable state
 *
 * @example
 * ```typescript
 * const client = createPublicClient({ chain: anvil, transport: http() });
 * const ghosts = await readGhostVariables(client, '0x...');
 * console.log(`Total deposited: ${ghosts.protocol.totalDeposited}`);
 * console.log(`Mint calls: ${ghosts.callCounters.mintVault}`);
 * ```
 */
export async function readGhostVariables(
  client: PublicClient,
  handlerAddress: Address
): Promise<GhostVariables> {
  // Read all ghost variables in parallel
  const [
    totalDeposited,
    totalWithdrawn,
    totalForfeited,
    totalMatchClaimed,
    achievementsMinted,
    treasuresMinted,
    vaultsWithIssuerTreasure,
    callsMintVault,
    callsWithdraw,
    callsEarlyRedeem,
    callsClaimMatch,
    callsClaimAchievement,
    callsWarp,
  ] = await Promise.all([
    client.readContract({
      address: handlerAddress,
      abi: HANDLER_ABI,
      functionName: 'ghost_totalDeposited',
    }),
    client.readContract({
      address: handlerAddress,
      abi: HANDLER_ABI,
      functionName: 'ghost_totalWithdrawn',
    }),
    client.readContract({
      address: handlerAddress,
      abi: HANDLER_ABI,
      functionName: 'ghost_totalForfeited',
    }),
    client.readContract({
      address: handlerAddress,
      abi: HANDLER_ABI,
      functionName: 'ghost_totalMatchClaimed',
    }),
    client.readContract({
      address: handlerAddress,
      abi: HANDLER_ABI,
      functionName: 'ghost_achievementsMinted',
    }),
    client.readContract({
      address: handlerAddress,
      abi: HANDLER_ABI,
      functionName: 'ghost_treasuresMinted',
    }),
    client.readContract({
      address: handlerAddress,
      abi: HANDLER_ABI,
      functionName: 'ghost_vaultsWithIssuerTreasure',
    }),
    client.readContract({
      address: handlerAddress,
      abi: HANDLER_ABI,
      functionName: 'calls_mintVault',
    }),
    client.readContract({
      address: handlerAddress,
      abi: HANDLER_ABI,
      functionName: 'calls_withdraw',
    }),
    client.readContract({
      address: handlerAddress,
      abi: HANDLER_ABI,
      functionName: 'calls_earlyRedeem',
    }),
    client.readContract({
      address: handlerAddress,
      abi: HANDLER_ABI,
      functionName: 'calls_claimMatch',
    }),
    client.readContract({
      address: handlerAddress,
      abi: HANDLER_ABI,
      functionName: 'calls_claimAchievement',
    }),
    client.readContract({
      address: handlerAddress,
      abi: HANDLER_ABI,
      functionName: 'calls_warp',
    }),
  ]);

  return {
    protocol: {
      totalDeposited: totalDeposited as bigint,
      totalWithdrawn: totalWithdrawn as bigint,
      totalForfeited: totalForfeited as bigint,
      totalMatchClaimed: totalMatchClaimed as bigint,
    },
    crossLayer: {
      achievementsMinted: Number(achievementsMinted),
      treasuresMinted: Number(treasuresMinted),
      vaultsWithIssuerTreasure: Number(vaultsWithIssuerTreasure),
    },
    callCounters: {
      mintVault: Number(callsMintVault),
      withdraw: Number(callsWithdraw),
      earlyRedeem: Number(callsEarlyRedeem),
      claimMatch: Number(callsClaimMatch),
      claimAchievement: Number(callsClaimAchievement),
      warp: Number(callsWarp),
    },
  };
}

/**
 * Format ghost variables for display
 */
export function formatGhostVariables(ghosts: GhostVariables): string {
  const btcDecimals = 8;
  const formatBtc = (value: bigint) => (Number(value) / 10 ** btcDecimals).toFixed(8);

  return `
=== Protocol Ghost Variables ===
Total Deposited:    ${formatBtc(ghosts.protocol.totalDeposited)} BTC
Total Withdrawn:    ${formatBtc(ghosts.protocol.totalWithdrawn)} BTC
Total Forfeited:    ${formatBtc(ghosts.protocol.totalForfeited)} BTC
Total Match Claimed: ${formatBtc(ghosts.protocol.totalMatchClaimed)} BTC

=== Cross-Layer Ghost Variables ===
Achievements Minted:     ${ghosts.crossLayer.achievementsMinted}
Treasures Minted:        ${ghosts.crossLayer.treasuresMinted}
Vaults With Treasure:    ${ghosts.crossLayer.vaultsWithIssuerTreasure}

=== Call Counters ===
Mint Vault:        ${ghosts.callCounters.mintVault}
Withdraw:          ${ghosts.callCounters.withdraw}
Early Redeem:      ${ghosts.callCounters.earlyRedeem}
Claim Match:       ${ghosts.callCounters.claimMatch}
Claim Achievement: ${ghosts.callCounters.claimAchievement}
Time Warp:         ${ghosts.callCounters.warp}
`.trim();
}

/**
 * Calculate protocol conservation from ghost variables
 * Used for invariant verification
 */
export function calculateConservation(ghosts: GhostVariables): {
  conserved: boolean;
  expected: bigint;
  actual: bigint;
} {
  const { totalDeposited, totalWithdrawn, totalForfeited } = ghosts.protocol;

  // Conservation: deposited = withdrawn + forfeited + remaining
  // Match pool: forfeited = matchClaimed + matchPoolBalance (external read needed)
  // For basic check: deposited >= withdrawn + forfeited (accounting for match claimed)
  const expected = totalDeposited;
  const actual = totalWithdrawn + totalForfeited;

  return {
    conserved: actual <= expected,
    expected,
    actual,
  };
}
