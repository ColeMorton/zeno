# @btcnft/vault-analytics

Framework-agnostic TypeScript SDK for BTCNFT Protocol vault analytics. Provides utilities for fetching, filtering, and ranking Vault NFTs by collateral percentile.

## Installation

```bash
npm install @btcnft/vault-analytics viem
# or
pnpm add @btcnft/vault-analytics viem
# or
yarn add @btcnft/vault-analytics viem
```

## Quick Start

```typescript
import { createVaultClient, filterVaults, rankByCollateral } from '@btcnft/vault-analytics';

// Initialize client
const client = createVaultClient({ chainId: 1 });

// Fetch vaults for an issuer
const vaults = await client.getVaults({
  scope: { type: 'issuer', address: '0x1234...' }
});

// Filter to vested vaults only
const vestedVaults = filterVaults(vaults, { vestingStatus: 'vested' });

// Rank by collateral and get percentile tiers
const ranked = rankByCollateral(vestedVaults);

console.log(ranked[0]);
// { vault: {...}, rank: 1, percentile: 99, tier: 'Diamond' }
```

## API Reference

### Client

#### `createVaultClient(config)`

Create a vault analytics client.

```typescript
const client = createVaultClient({
  chainId: 1,                    // Required: Chain ID
  subgraphUrl: 'https://...',    // Optional: Custom subgraph URL
  rpcUrl: 'https://...',         // Optional: Custom RPC URL
});
```

#### `client.getVaults(options)`

Fetch vaults with optional filters and pagination.

```typescript
const vaults = await client.getVaults({
  scope: { type: 'issuer', address: '0x...' },
  filters: { vestingStatus: 'vested' },
  pagination: { page: 1, pageSize: 25 },
  sortBy: 'collateral',
  sortOrder: 'desc',
});
```

#### `client.getAnalytics(options)`

Fetch, filter, and rank vaults in one call.

```typescript
const result = await client.getAnalytics({
  scope: { type: 'issuer', address: '0x...' },
  filters: { vestingStatus: 'vested' },
  pagination: { page: 1, pageSize: 25 },
});

// result.vaults: RankedVault[]
// result.total: number
// result.page: number
// result.totalPages: number
```

### Analytics Functions

#### `filterVaults(vaults, filter)`

Filter vaults by status.

```typescript
const filtered = filterVaults(vaults, {
  vestingStatus: 'vested',      // 'vesting' | 'vested' | 'all'
  separationStatus: 'combined', // 'combined' | 'separated' | 'all'
  dormancyStatus: 'active',     // 'active' | 'poke_pending' | 'claimable' | 'all'
});
```

#### `rankByCollateral(vaults, options)`

Rank vaults by collateral and calculate percentiles.

```typescript
const ranked = rankByCollateral(vaults);
// Returns: { vault, rank, percentile, tier }[]
```

#### `getPercentileTier(percentile)`

Get tier name for a percentile value.

```typescript
getPercentileTier(99);  // 'Diamond'
getPercentileTier(95);  // 'Platinum'
getPercentileTier(90);  // 'Gold'
getPercentileTier(75);  // 'Silver'
getPercentileTier(50);  // 'Bronze'
getPercentileTier(49);  // null
```

#### `deriveVaultStatus(vault)`

Get complete derived status for a vault.

```typescript
const status = deriveVaultStatus(vault);
// {
//   isVested: boolean,
//   isSeparated: boolean,
//   dormancyStatus: 'active' | 'poke_pending' | 'claimable',
//   vestingDaysRemaining: number,
//   vestingEndsAt: bigint
// }
```

### Utility Functions

```typescript
import {
  isVested,              // Check if vault is vested
  isSeparated,           // Check if collateral is separated
  getDormancyStatus,     // Get dormancy state
  getVestingDaysRemaining, // Days until vesting completes
} from '@btcnft/vault-analytics';
```

## Types

```typescript
import type {
  Vault,
  RankedVault,
  VaultFilter,
  ScopeFilter,
  PercentileTier,
  AnalyticsResult,
} from '@btcnft/vault-analytics';
```

## Constants

```typescript
import {
  VESTING_PERIOD,        // 1129 days in seconds
  WITHDRAWAL_RATE,       // 1000 (1.0%)
  DORMANCY_THRESHOLD,    // 1129 days in seconds
  GRACE_PERIOD,          // 30 days in seconds
  BTC_DECIMALS,          // 8
} from '@btcnft/vault-analytics';
```

## Percentile Tiers

| Tier | Percentile |
|------|------------|
| Diamond | ≥ 99% |
| Platinum | ≥ 95% |
| Gold | ≥ 90% |
| Silver | ≥ 75% |
| Bronze | ≥ 50% |

## Framework Integration Examples

### React (with TanStack Query)

```typescript
import { useQuery } from '@tanstack/react-query';
import { createVaultClient, rankByCollateral } from '@btcnft/vault-analytics';

const client = createVaultClient({ chainId: 1 });

function useVaultAnalytics(issuerAddress: string) {
  return useQuery({
    queryKey: ['vaults', issuerAddress],
    queryFn: async () => {
      const vaults = await client.getVaults({
        scope: { type: 'issuer', address: issuerAddress }
      });
      return rankByCollateral(vaults);
    }
  });
}
```

### Vue (with Composition API)

```typescript
import { ref, onMounted } from 'vue';
import { createVaultClient, rankByCollateral } from '@btcnft/vault-analytics';

const client = createVaultClient({ chainId: 1 });

export function useVaultAnalytics(issuerAddress: string) {
  const vaults = ref([]);
  const loading = ref(true);

  onMounted(async () => {
    const data = await client.getVaults({
      scope: { type: 'issuer', address: issuerAddress }
    });
    vaults.value = rankByCollateral(data);
    loading.value = false;
  });

  return { vaults, loading };
}
```

### Node.js

```typescript
import { createVaultClient, filterVaults, rankByCollateral } from '@btcnft/vault-analytics';

async function analyzeIssuerVaults(issuerAddress: string) {
  const client = createVaultClient({ chainId: 1 });

  const vaults = await client.getAllVaults({
    scope: { type: 'issuer', address: issuerAddress }
  });

  const vested = filterVaults(vaults, { vestingStatus: 'vested' });
  const ranked = rankByCollateral(vested);

  console.log(`Total vaults: ${vaults.length}`);
  console.log(`Vested vaults: ${vested.length}`);
  console.log(`Top vault: ${ranked[0]?.tier}`);
}
```

## License

MIT
