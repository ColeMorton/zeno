# SDK Integration Guide

> **Version:** 1.0
> **Status:** Active
> **Last Updated:** 2026-01-04

Deep integration patterns for `@btcnft/vault-analytics`.

---

## Installation

```bash
npm install @btcnft/vault-analytics viem
```

---

## VaultClient Usage

The `VaultClient` provides methods to fetch, filter, and rank vaults.

### Initialization

```typescript
import { createVaultClient } from '@btcnft/vault-analytics';

// Ethereum mainnet
const client = createVaultClient({ chainId: 1 });

// Base mainnet
const baseClient = createVaultClient({ chainId: 8453 });

// Custom subgraph
const customClient = createVaultClient({
  chainId: 1,
  subgraphUrl: 'https://api.studio.thegraph.com/...'
});
```

### Fetching Vaults

```typescript
// Fetch with pagination
const vaults = await client.getVaults({
  scope: { type: 'issuer', address: '0x1234...' },
  pagination: { page: 1, pageSize: 25 }
});

// Fetch all vaults (handles pagination internally)
const allVaults = await client.getAllVaults({
  scope: { type: 'issuer', address: '0x1234...' }
});

// Get vault count
const count = await client.getVaultCount();
```

### Filtering

```typescript
// Filter by vesting status
const vestedOnly = await client.getVaults({
  filters: { vestingStatus: 'vested' }
});

// Combine filters
const target = await client.getVaults({
  filters: {
    vestingStatus: 'vested',
    separationStatus: 'combined',
    dormancyStatus: 'active'
  }
});
```

Filter options:
- `vestingStatus`: `'vesting'` | `'vested'` | `'all'`
- `separationStatus`: `'combined'` | `'separated'` | `'all'`
- `dormancyStatus`: `'active'` | `'poke_pending'` | `'claimable'` | `'all'`

### Analytics (Ranking + Pagination)

```typescript
const result = await client.getAnalytics({
  scope: { type: 'issuer', address: '0x1234...' },
  filters: { vestingStatus: 'vested' },
  pagination: { page: 1, pageSize: 25 },
  sortBy: 'collateral',  // 'collateral' | 'mintTimestamp' | 'tokenId'
  sortOrder: 'desc'
});

// Result structure
result.vaults.forEach(({ vault, rank, percentile, tier }) => {
  console.log(`#${rank}: ${vault.tokenId} - ${tier} (${percentile}%)`);
});

console.log(`Page ${result.page}/${result.totalPages}`);
console.log(`Total: ${result.total} vaults`);
```

### Single Vault Ranking

```typescript
const ranking = await client.getVaultRanking(42n, {
  scope: { type: 'issuer', address: '0x1234...' }
});

if (ranking) {
  console.log(`Rank: ${ranking.rank}`);
  console.log(`Percentile: ${ranking.percentile}%`);
  console.log(`Tier: ${ranking.tier}`);  // 'Diamond' | 'Platinum' | 'Gold' | 'Silver' | 'Bronze'
}
```

---

## AchievementClient Usage

Queries achievement state directly from contracts using viem.

### Initialization

```typescript
import { createAchievementClient } from '@btcnft/vault-analytics';
import { createPublicClient, http } from 'viem';
import { mainnet } from 'viem/chains';

const publicClient = createPublicClient({
  chain: mainnet,
  transport: http()
});

const achievementClient = createAchievementClient({
  achievementNFT: '0x...',
  achievementMinter: '0x...',
  publicClient
});
```

### Query Achievement Status

```typescript
// Check specific achievement
const hasMinter = await achievementClient.hasAchievement(walletAddress, 'MINTER');

// Get all achievements for wallet
const status = await achievementClient.getAchievements(walletAddress);
console.log('Has MINTER:', status.hasMinter);
console.log('Has MATURED:', status.hasMatured);
console.log('Has HODLER_SUPREME:', status.hasHodlerSupreme);
console.log('Duration achievements:', status.durationAchievements);
```

### Check Eligibility

```typescript
// Check if can claim MINTER
const minterEligibility = await achievementClient.canClaimMinter(wallet, vaultId);
if (minterEligibility.eligible) {
  console.log('Can claim MINTER achievement');
} else {
  console.log('Cannot claim:', minterEligibility.reason);
}

// Check all eligible achievements for a vault
const allEligible = await achievementClient.getEligibleAchievements(wallet, vaultId);
const claimable = allEligible.filter(e => e.eligible);
```

Achievement types:
- `MINTER` - Minted a vault
- `MATURED` - Vault reached vesting
- `FIRST_MONTH`, `QUARTER_STACK`, `HALF_YEAR`, `ANNUAL`, `DIAMOND_HANDS` - Duration milestones
- `HODLER_SUPREME` - 1129 days held

---

## Analytics Modules

### Percentile Ranking

```typescript
import { rankByCollateral, getPercentileTier, calculatePercentile } from '@btcnft/vault-analytics';

// Rank all vaults by collateral
const ranked = rankByCollateral(vaults);
// Returns: [{ vault, rank, percentile, tier }, ...]

// Custom thresholds
const customRanked = rankByCollateral(vaults, {
  thresholds: {
    diamond: 98,   // Top 2%
    platinum: 90,  // Top 10%
    gold: 80,
    silver: 60,
    bronze: 40
  }
});

// Get tier for specific percentile
const tier = getPercentileTier(99.5);  // 'Diamond'
```

Default tier thresholds:
- Diamond: 99+
- Platinum: 95+
- Gold: 90+
- Silver: 75+
- Bronze: 50+

### Vault Filtering

```typescript
import {
  filterVaults,
  isVested,
  isSeparated,
  getDormancyStatus,
  deriveVaultStatus
} from '@btcnft/vault-analytics';

// Individual status checks
const vested = isVested(vault);
const separated = isSeparated(vault);
const dormancy = getDormancyStatus(vault);  // 'active' | 'poke_pending' | 'claimable'

// Complete status derivation
const status = deriveVaultStatus(vault);
console.log(`Vested: ${status.isVested}`);
console.log(`Days remaining: ${status.vestingDaysRemaining}`);
console.log(`Vesting ends: ${new Date(Number(status.vestingEndsAt) * 1000)}`);

// Batch filtering
const vestedCombined = filterVaults(vaults, {
  vestingStatus: 'vested',
  separationStatus: 'combined'
});
```

### Dormancy Risk Analysis

```typescript
import {
  calculateDormancyRisk,
  analyzeDormancyRisks,
  groupByRiskLevel,
  calculateCollateralAtRisk
} from '@btcnft/vault-analytics';

// Single vault risk
const risk = calculateDormancyRisk(vault, BigInt(Date.now() / 1000));
console.log(`Days inactive: ${risk.daysInactive}`);
console.log(`Risk level: ${risk.riskLevel}`);  // 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL'

// Analyze multiple vaults (filter by minimum risk)
const risks = analyzeDormancyRisks(vaults, currentTimestamp, 'MEDIUM');

// Group by risk level
const grouped = groupByRiskLevel(risks);
console.log(`Critical vaults: ${grouped.CRITICAL.length}`);
console.log(`High risk vaults: ${grouped.HIGH.length}`);

// Calculate collateral at each risk level
const collateralRisk = calculateCollateralAtRisk(risks);
console.log(`Collateral at CRITICAL risk: ${collateralRisk.CRITICAL}`);
```

Risk thresholds (days inactive):
- CRITICAL: 1099+ days (30 days before dormancy)
- HIGH: 1000+ days
- MEDIUM: 730+ days (2 years)
- LOW: <730 days

### Ecosystem Health

```typescript
import { calculateEcosystemHealth, formatEcosystemHealth } from '@btcnft/vault-analytics';

const health = calculateEcosystemHealth(events, vaults);

console.log(`Total vaults: ${health.totalVaults}`);
console.log(`Match pool: ${health.matchPoolBalance}`);
console.log(`Early redemption rate: ${health.earlyRedemptionRate}%`);
console.log(`Dormancy risk score: ${health.dormancyRiskScore}`);

// Formatted output
console.log(formatEcosystemHealth(health));
```

Health metrics:
- `matchPoolBalance` - Current match pool balance (satoshis)
- `matchPoolUtilization` - Claimed / forfeited ratio
- `earlyRedemptionRate` - Redemptions / total mints
- `vestedBTCSeparationRate` - Separations / vested vaults
- `dormancyRiskScore` - Weighted risk score (0-100)
- `achievementAdoptionRate` - Wallets with achievements / holders

---

## React Integration Patterns

### Custom Hook Example

```typescript
import { useState, useEffect } from 'react';
import { createVaultClient, type RankedVault } from '@btcnft/vault-analytics';

const client = createVaultClient({ chainId: 8453 });

export function useVaultLeaderboard(issuerAddress: string) {
  const [data, setData] = useState<{
    vaults: RankedVault[];
    total: number;
    loading: boolean;
    error: Error | null;
  }>({ vaults: [], total: 0, loading: true, error: null });

  useEffect(() => {
    let cancelled = false;

    async function fetch() {
      try {
        const result = await client.getAnalytics({
          scope: { type: 'issuer', address: issuerAddress },
          filters: { vestingStatus: 'vested' },
          pagination: { page: 1, pageSize: 25 }
        });

        if (!cancelled) {
          setData({
            vaults: result.vaults,
            total: result.total,
            loading: false,
            error: null
          });
        }
      } catch (error) {
        if (!cancelled) {
          setData(prev => ({ ...prev, loading: false, error: error as Error }));
        }
      }
    }

    fetch();
    return () => { cancelled = true; };
  }, [issuerAddress]);

  return data;
}
```

### With TanStack Query

```typescript
import { useQuery } from '@tanstack/react-query';
import { createVaultClient } from '@btcnft/vault-analytics';

const client = createVaultClient({ chainId: 8453 });

export function useVaultRanking(tokenId: bigint, issuerAddress: string) {
  return useQuery({
    queryKey: ['vault-ranking', tokenId.toString(), issuerAddress],
    queryFn: () => client.getVaultRanking(tokenId, {
      scope: { type: 'issuer', address: issuerAddress }
    }),
    staleTime: 60_000  // 1 minute
  });
}
```

---

## Node.js Examples

### Batch Analytics Export

```typescript
import { createVaultClient, exportVaults } from '@btcnft/vault-analytics';
import { writeFileSync } from 'fs';

const client = createVaultClient({ chainId: 1 });

async function exportIssuerData(issuerAddress: string) {
  const vaults = await client.getAllVaults({
    scope: { type: 'issuer', address: issuerAddress }
  });

  const csv = exportVaults(vaults, { format: 'csv' });
  writeFileSync(`vaults-${issuerAddress.slice(0, 8)}.csv`, csv);

  console.log(`Exported ${vaults.length} vaults`);
}
```

### Scheduled Health Monitoring

```typescript
import { createVaultClient, analyzeDormancyRisks } from '@btcnft/vault-analytics';

async function checkDormancyRisks() {
  const client = createVaultClient({ chainId: 8453 });
  const vaults = await client.getAllVaults();

  const criticalRisks = analyzeDormancyRisks(
    vaults,
    BigInt(Math.floor(Date.now() / 1000)),
    'CRITICAL'
  );

  if (criticalRisks.length > 0) {
    console.log(`ALERT: ${criticalRisks.length} vaults at critical dormancy risk`);
    for (const risk of criticalRisks) {
      console.log(`  Vault #${risk.tokenId}: ${risk.daysUntilDormant} days until dormant`);
    }
  }
}
```

---

## Type Reference

### Vault

```typescript
interface Vault {
  tokenId: bigint;
  owner: string;
  treasureContract: string;
  treasureTokenId: bigint;
  collateralToken: string;
  collateralAmount: bigint;
  mintTimestamp: bigint;
  lastWithdrawalTimestamp: bigint;
  lastActivity: bigint;
  vestedBTCAmount: bigint;
  pokeTimestamp: bigint;
}
```

### RankedVault

```typescript
interface RankedVault {
  vault: Vault;
  rank: number;
  percentile: number;
  tier: 'Diamond' | 'Platinum' | 'Gold' | 'Silver' | 'Bronze' | null;
}
```

### VaultFilter

```typescript
interface VaultFilter {
  vestingStatus?: 'vesting' | 'vested' | 'all';
  separationStatus?: 'combined' | 'separated' | 'all';
  dormancyStatus?: 'active' | 'poke_pending' | 'claimable' | 'all';
}
```

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [SDK README](./README.md) | Quick start and overview |
| [Delegation Subgraph Schema](./Delegation_Subgraph_Schema.md) | GraphQL entities |
| [Technical Specification](../protocol/Technical_Specification.md) | Contract mechanics |
| [GLOSSARY](../GLOSSARY.md) | Terminology |

---

## Navigation

[SDK Overview](./README.md) | [Documentation Home](../README.md)
