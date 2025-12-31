'use client';

import { useQuery } from '@tanstack/react-query';
import { useChainId, usePublicClient } from 'wagmi';
import { ANVIL_CHAIN_ID } from '@/lib/wagmi';

export type LeaderboardTier = 'DIAMOND' | 'PLATINUM' | 'GOLD' | 'SILVER' | 'BRONZE';

export interface LeaderboardEntry {
  rank: number;
  address: string;
  fullAddress: string;
  daysHeld: number;
  collateral: string;
  tier: LeaderboardTier;
}

function getTierFromPercentile(percentile: number): LeaderboardTier {
  if (percentile >= 99) return 'DIAMOND';
  if (percentile >= 90) return 'PLATINUM';
  if (percentile >= 75) return 'GOLD';
  if (percentile >= 50) return 'SILVER';
  return 'BRONZE';
}

function formatAddress(address: string): string {
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

export function useLeaderboard() {
  const chainId = useChainId();
  const publicClient = usePublicClient();
  const isAnvil = chainId === ANVIL_CHAIN_ID;

  return useQuery({
    queryKey: ['leaderboard', chainId],
    queryFn: async (): Promise<LeaderboardEntry[]> => {
      if (!publicClient) {
        throw new Error('Public client not available');
      }

      const { AnvilAdapter, createAnvilIndexer } = await import('@btcnft/vault-analytics');
      const rpcUrl = process.env.NEXT_PUBLIC_ANVIL_RPC ?? 'http://127.0.0.1:8545';
      const indexer = createAnvilIndexer(rpcUrl);

      const vaultNFT = process.env.NEXT_PUBLIC_VAULT_NFT_ANVIL;
      const btcToken = process.env.NEXT_PUBLIC_BTC_TOKEN_ANVIL;

      if (!vaultNFT || !btcToken) {
        throw new Error('Contract addresses not configured');
      }

      await indexer.startIndexing({
        vaultNFT: vaultNFT as `0x${string}`,
        btcToken: btcToken as `0x${string}`,
      });

      const adapter = new AnvilAdapter({ indexer });
      const vaults = await adapter.getVaults();

      if (vaults.length === 0) {
        return [];
      }

      // Get blockchain timestamp (not system clock)
      const block = await publicClient.getBlock({ blockTag: 'latest' });
      const now = Number(block.timestamp);

      // Group by owner, find longest held vault and total collateral per owner
      const ownerStats = new Map<string, { maxDaysHeld: number; totalCollateral: bigint }>();

      for (const vault of vaults) {
        const daysHeld = Math.floor((now - Number(vault.mintTimestamp)) / 86400);
        const current = ownerStats.get(vault.owner) ?? { maxDaysHeld: 0, totalCollateral: 0n };

        ownerStats.set(vault.owner, {
          maxDaysHeld: Math.max(current.maxDaysHeld, daysHeld),
          totalCollateral: current.totalCollateral + vault.collateralAmount,
        });
      }

      // Sort by max days held (descending)
      const sorted = Array.from(ownerStats.entries())
        .map(([address, stats]) => ({ address, ...stats }))
        .sort((a, b) => b.maxDaysHeld - a.maxDaysHeld);

      // Calculate percentiles and build leaderboard
      const total = sorted.length;
      return sorted.map((entry, index): LeaderboardEntry => {
        const percentile = total > 1 ? ((total - 1 - index) / (total - 1)) * 100 : 100;
        return {
          rank: index + 1,
          address: formatAddress(entry.address),
          fullAddress: entry.address,
          daysHeld: entry.maxDaysHeld,
          collateral: (Number(entry.totalCollateral) / 1e8).toFixed(4),
          tier: getTierFromPercentile(percentile),
        };
      });
    },
    enabled: isAnvil && !!publicClient,
    staleTime: 60 * 1000,
  });
}
