# SDK Documentation

> **Status:** Available
> **Last Updated:** 2025-12-30

Developer tools and integration libraries for the BTCNFT Protocol.

---

## Packages

### @btcnft/vault-analytics

Framework-agnostic TypeScript SDK for vault analytics. Fetch, filter, and rank Vault NFTs by collateral percentile.

**Installation:**

```bash
npm install @btcnft/vault-analytics viem
```

**Quick Start:**

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
// { vault: {...}, rank: 1, percentile: 99, tier: 'Diamond' }
```

**Features:**
- Subgraph-based vault fetching with pagination
- Filter by vesting status, separation status, dormancy state
- Collateral-based percentile ranking with tier labels
- Framework-agnostic (React, Vue, Node.js examples included)

**Full API Reference:** [packages/vault-analytics/README.md](../../packages/vault-analytics/README.md)

---

## Additional Features

Beyond the core vault fetching and ranking, the SDK includes:

### Unified Analytics API

The `AnalyticsAPI` class provides a consistent interface across data sources:

```typescript
import { createAnalyticsAPI } from '@btcnft/vault-analytics';

const api = createAnalyticsAPI({
  source: 'subgraph',
  chainId: 1
});

// Portfolio analytics
const stats = await api.getPortfolioStats();
const tiers = await api.getTierDistribution();

// Health monitoring
const health = await api.getEcosystemHealth();
const risks = await api.getDormancyRisks();

// Leaderboards
const topVaults = await api.getCollateralLeaderboard({ limit: 10 });
const topAchievers = await api.getAchievementLeaderboard({ limit: 10 });
```

### Event Indexing

Index protocol events from local Anvil nodes for testing:

```typescript
import { createAnvilIndexer } from '@btcnft/vault-analytics';

const indexer = createAnvilIndexer({
  rpcUrl: 'http://localhost:8545',
  addresses: { vaultNft: '0x...', btcToken: '0x...' }
});

const events = await indexer.getEvents({ fromBlock: 0n });
```

### Simulation & Testing

Generate simulation reports for protocol testing:

```typescript
import { createSimulationReporter, readGhostVariables } from '@btcnft/vault-analytics';

const reporter = createSimulationReporter({ outputDir: './reports' });
const ghost = await readGhostVariables(client, addresses);
await reporter.generateReport(events, ghost);
```

### Data Export

Export analytics data in multiple formats:

```typescript
import { exportVaults, exportEcosystemHealth } from '@btcnft/vault-analytics';

// Export as CSV or JSON
const csv = exportVaults(vaults, { format: 'csv' });
const json = exportEcosystemHealth(health, { format: 'json' });
```

### Achievement Analytics

Track and analyze achievement distributions:

```typescript
import {
  calculateAchievementDistribution,
  calculateAchievementFunnel,
  buildWalletProfiles
} from '@btcnft/vault-analytics';

const distribution = calculateAchievementDistribution(events);
const funnel = calculateAchievementFunnel(events);
const profiles = buildWalletProfiles(events);
```

### Subgraph Queries

For custom GraphQL queries, see the query definitions in [`SubgraphClient.ts`](../../packages/vault-analytics/src/client/SubgraphClient.ts).

### Delegation Tracking

For institutional custody audit trails, see [Delegation Subgraph Schema](./Delegation_Subgraph_Schema.md) for GraphQL entities and queries to track:

- Withdrawal delegation grants/revocations
- Delegated withdrawal events
- Compliance reporting queries

---

## Roadmap

Future SDK enhancements:

| Component | Status | Notes |
|-----------|--------|-------|
| **React Hooks** | Examples available | See [package README](../../packages/vault-analytics/README.md) for React/Vue/Node.js examples |
| **Issuer Client** | Planned | Contract interaction wrappers for issuers |
| **Auction SDK** | Planned | TypeScript utilities for auction management |

---

## Direct Contract Integration

For operations not covered by the SDK, integrate directly with smart contracts:

```solidity
interface IVaultNFT {
    function instantMint(address treasure, uint256 tokenId, uint256 collateral) external;
    function withdraw(uint256 vaultId) external;
    function mintBtcToken(uint256 vaultId) external;
    function returnBtcToken(uint256 vaultId) external;
}
```

See [Technical Specification](../protocol/Technical_Specification.md) for complete contract mechanics.

---

## Related Documentation

| Layer | Documents |
|-------|-----------|
| **Protocol** | [protocol/](../protocol/) |
| **Issuer** | [issuer/](../issuer/) |
| **Glossary** | [GLOSSARY.md](../GLOSSARY.md) |

---

## Navigation

← [Documentation Home](../README.md)
