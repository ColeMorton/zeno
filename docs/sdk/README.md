# SDK Documentation

> **Status:** Available
> **Last Updated:** 2025-12-21

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

## Roadmap

Future SDK components:

1. **React Hooks** - Frontend integration helpers
2. **Subgraph Schema** - GraphQL indexing documentation
3. **Examples** - Reference implementations

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
