'use client';

import { useQuery } from '@tanstack/react-query';
import { useAccount, useChainId } from 'wagmi';
import { ANVIL_CHAIN_ID } from '@/lib/wagmi';
import { bigintStructuralSharing } from '@/lib/queryUtils';

// Anvil contract addresses from deployment
const ANVIL_CONTRACTS = {
  vaultNFT: process.env.NEXT_PUBLIC_VAULT_NFT_ANVIL,
  btcToken: process.env.NEXT_PUBLIC_BTC_TOKEN_ANVIL,
};

// SDK client factory - lazy import to handle SSR
async function getVaultClient(chainId: number) {
  const { createVaultClient } = await import('@btcnft/vault-analytics');
  // Cast to satisfy SDK type (1=mainnet, 8453=base, 11155111=sepolia, 84532=base-sepolia, 31337=anvil)
  return createVaultClient({ chainId: chainId as 1 | 8453 | 11155111 | 84532 | 31337 });
}

// Anvil indexer singleton to avoid re-creating on each query
let anvilIndexerPromise: Promise<any> | null = null;

async function getAnvilIndexer() {
  if (anvilIndexerPromise) return anvilIndexerPromise;

  anvilIndexerPromise = (async () => {
    const { createAnvilIndexer } = await import('@btcnft/vault-analytics');
    const rpcUrl = process.env.NEXT_PUBLIC_ANVIL_RPC ?? 'http://127.0.0.1:8545';
    const indexer = createAnvilIndexer(rpcUrl);

    if (!ANVIL_CONTRACTS.vaultNFT || !ANVIL_CONTRACTS.btcToken) {
      throw new Error(
        'Anvil contract addresses not configured. Set NEXT_PUBLIC_VAULT_NFT_ANVIL and NEXT_PUBLIC_BTC_TOKEN_ANVIL'
      );
    }

    await indexer.startIndexing({
      vaultNFT: ANVIL_CONTRACTS.vaultNFT as `0x${string}`,
      btcToken: ANVIL_CONTRACTS.btcToken as `0x${string}`,
    });

    return indexer;
  })();

  return anvilIndexerPromise;
}

async function getVaultsFromAnvil(address: string) {
  const { AnvilAdapter } = await import('@btcnft/vault-analytics');
  const indexer = await getAnvilIndexer();
  const adapter = new AnvilAdapter({ indexer });
  const vaults = await adapter.getVaults();
  return vaults.filter(
    (v) => v.owner.toLowerCase() === address.toLowerCase()
  );
}

async function getVaultsFromSubgraph(chainId: number, address: string) {
  const client = await getVaultClient(chainId);
  const vaults = await client.getVaults();
  return vaults.filter(
    (v) => v.owner.toLowerCase() === address.toLowerCase()
  );
}

export function useVaults() {
  const { address } = useAccount();
  const chainId = useChainId();
  const isAnvil = chainId === ANVIL_CHAIN_ID;

  return useQuery({
    queryKey: ['vaults', address, chainId, isAnvil ? 'anvil' : 'subgraph'],
    queryFn: async () => {
      if (!address) throw new Error('No address');

      if (isAnvil) {
        return getVaultsFromAnvil(address);
      }
      return getVaultsFromSubgraph(chainId, address);
    },
    enabled: !!address,
    staleTime: isAnvil ? 10 * 1000 : 60 * 1000,
    structuralSharing: bigintStructuralSharing,
  });
}

export function useVault(tokenId: bigint | undefined) {
  const chainId = useChainId();
  const isAnvil = chainId === ANVIL_CHAIN_ID;

  return useQuery({
    queryKey: ['vault', tokenId?.toString(), chainId],
    queryFn: async () => {
      if (!tokenId) throw new Error('No tokenId');

      if (isAnvil) {
        const { AnvilAdapter } = await import('@btcnft/vault-analytics');
        const indexer = await getAnvilIndexer();
        const adapter = new AnvilAdapter({ indexer });
        const vaults = await adapter.getVaults();
        const vault = vaults.find((v) => v.tokenId === tokenId);
        if (!vault) throw new Error(`Vault ${tokenId} not found`);
        return vault;
      }

      const client = await getVaultClient(chainId);
      const vaults = await client.getVaults();
      const vault = vaults.find((v) => v.tokenId === tokenId);
      if (!vault) throw new Error(`Vault ${tokenId} not found`);
      return vault;
    },
    enabled: !!tokenId,
    staleTime: isAnvil ? 10 * 1000 : 60 * 1000,
    structuralSharing: bigintStructuralSharing,
  });
}

export function useVaultRanking(tokenId: bigint | undefined) {
  const chainId = useChainId();
  const isAnvil = chainId === ANVIL_CHAIN_ID;

  return useQuery({
    queryKey: ['vaultRanking', tokenId?.toString(), chainId],
    queryFn: async () => {
      if (!tokenId) throw new Error('No tokenId');
      const { getVaultRanking, AnvilAdapter } = await import('@btcnft/vault-analytics');

      let vaults;
      if (isAnvil) {
        const indexer = await getAnvilIndexer();
        const adapter = new AnvilAdapter({ indexer });
        vaults = await adapter.getVaults();
      } else {
        const client = await getVaultClient(chainId);
        vaults = await client.getVaults();
      }

      return getVaultRanking(vaults, tokenId);
    },
    enabled: !!tokenId,
    staleTime: isAnvil ? 10 * 1000 : 5 * 60 * 1000,
    structuralSharing: bigintStructuralSharing,
  });
}

// Hook to check if connected to Anvil
export function useIsAnvil() {
  const chainId = useChainId();
  return chainId === ANVIL_CHAIN_ID;
}
