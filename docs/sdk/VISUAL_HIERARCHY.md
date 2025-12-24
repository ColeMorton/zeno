# Visual Hierarchy SDK Reference

> **Version:** 1.0
> **Status:** Draft
> **Last Updated:** 2025-12-23
> **Package:** `@btcnft/vault-analytics`

---

## Overview

The Visual Hierarchy module provides types and utilities for composing vault visual identity from two orthogonal systems:

| System | Basis | Token Type | Persistence |
|--------|-------|------------|-------------|
| **Achievements** | Merit (actions, duration) | ERC-5192 Soulbound | Permanent |
| **Display Tiers** | Wealth (collateral percentile) | Applied to Treasure NFT | Dynamic |

### Key Concept: Orthogonality

A wallet can earn DIAMOND_HANDS (730-day hold achievement) while their vault displays as "Bronze" tier (low collateral percentile). These systems are independent:

- **Achievements** = Tier 0 base blueprint (what you've done)
- **Display Tiers** = Materialized visual (how you compare to others)

---

## Installation

```bash
npm install @btcnft/vault-analytics
```

---

## Types

### Achievement Types

```typescript
import type {
  AchievementType,
  AchievementCategory,
  Achievement,
  AchievementStatus,
  AchievementEligibility,
} from '@btcnft/vault-analytics';
```

#### `AchievementType`

```typescript
type AchievementType =
  | 'MINTER'           // Lifecycle: First mint
  | 'MATURED'          // Lifecycle: Vault fully vested
  | 'HODLER_SUPREME'   // Composite: MINTER + MATURED
  | 'FIRST_MONTH'      // Duration: 30 days
  | 'QUARTER_STACK'    // Duration: 91 days
  | 'HALF_YEAR'        // Duration: 182 days
  | 'ANNUAL'           // Duration: 365 days
  | 'DIAMOND_HANDS';   // Duration: 730 days
```

#### `AchievementStatus`

Aggregated achievement state for a wallet:

```typescript
interface AchievementStatus {
  wallet: Address;
  achievements: Achievement[];
  hasMinter: boolean;
  hasMatured: boolean;
  hasHodlerSupreme: boolean;
  durationAchievements: AchievementType[];
}
```

### Visual Types

```typescript
import type {
  DisplayTier,
  TierVisualConfig,
  AchievementVisual,
  VaultVisualHierarchy,
} from '@btcnft/vault-analytics';
```

#### `DisplayTier`

```typescript
type DisplayTier = 'Whale' | 'Diamond' | 'Gold' | 'Silver' | 'Bronze' | null;
```

#### `TierVisualConfig`

Complete rendering configuration for a tier:

```typescript
interface TierVisualConfig {
  tier: DisplayTier;
  percentile: number;
  frame: {
    style: 'standard' | 'metallic' | 'animated' | 'unique';
    color: string;  // hex
    glow: boolean;
    animation?: 'pulse' | 'shimmer' | 'sparkle';
  };
  badge: {
    icon: string;
    label: string;
  };
  leaderboard: boolean;  // Whale only
}
```

#### `VaultVisualHierarchy`

Combined visual hierarchy for a vault:

```typescript
interface VaultVisualHierarchy {
  vaultId: bigint;
  treasureContract: Address;
  treasureTokenId: bigint;
  displayTier: TierVisualConfig;
  achievements: AchievementVisual[];
  highestAchievement: AchievementVisual | null;
  isVeteran: boolean;  // MATURED + HODLER_SUPREME
}
```

---

## AchievementClient

Direct contract queries for achievement state.

### Configuration

```typescript
import { createAchievementClient } from '@btcnft/vault-analytics';
import { createPublicClient, http } from 'viem';
import { mainnet } from 'viem/chains';

const publicClient = createPublicClient({
  chain: mainnet,
  transport: http(),
});

const achievementClient = createAchievementClient({
  achievementNFT: '0x...',
  achievementMinter: '0x...',
  publicClient,
});
```

### Methods

#### `hasAchievement(wallet, type)`

Check if a wallet has a specific achievement.

```typescript
const hasMinter = await achievementClient.hasAchievement(walletAddress, 'MINTER');
```

#### `getAchievements(wallet)`

Get aggregated achievement status for a wallet.

```typescript
const status = await achievementClient.getAchievements(walletAddress);
console.log(status.hasMinter);  // true/false
console.log(status.durationAchievements);  // ['FIRST_MONTH', 'ANNUAL']
```

#### `canClaimMinter(wallet, vaultId)`

Check eligibility for MINTER achievement.

```typescript
const eligibility = await achievementClient.canClaimMinter(wallet, vaultId);
if (eligibility.eligible) {
  // Can claim MINTER
} else {
  console.log(eligibility.reason);  // "Already has MINTER achievement"
}
```

#### `getEligibleAchievements(wallet, vaultId)`

Get all claimable achievements for a wallet/vault pair.

```typescript
const eligible = await achievementClient.getEligibleAchievements(wallet, vaultId);
const claimable = eligible.filter(e => e.eligible);
```

---

## Visual Hierarchy Composition

### `composeVisualHierarchy(rankedVault, achievements)`

Combine vault ranking with achievements into a complete visual hierarchy.

```typescript
import {
  createVaultClient,
  createAchievementClient,
  composeVisualHierarchy,
} from '@btcnft/vault-analytics';

// Fetch vault with ranking
const vaultClient = createVaultClient({ chainId: 1 });
const result = await vaultClient.getAnalytics({
  scope: { type: 'issuer', address: issuerAddress },
});

// Fetch achievements for vault owner
const rankedVault = result.vaults[0];
const achievements = await achievementClient.getAchievements(rankedVault.vault.owner);

// Compose visual hierarchy
const hierarchy = composeVisualHierarchy(rankedVault, achievements);

console.log(hierarchy.displayTier.tier);  // 'Diamond'
console.log(hierarchy.achievements);       // [AchievementVisual, ...]
console.log(hierarchy.isVeteran);          // false
```

### `getTierVisualConfig(percentile, tier)`

Get visual configuration for a specific tier.

```typescript
import { getTierVisualConfig } from '@btcnft/vault-analytics';

const config = getTierVisualConfig(98.5, 'Diamond');
console.log(config.frame.color);     // '#B9F2FF'
console.log(config.frame.animation); // 'shimmer'
```

---

## MetadataBuilder

Generate OpenSea-compatible NFT metadata.

### Configuration

```typescript
import { createMetadataBuilder } from '@btcnft/vault-analytics';

const builder = createMetadataBuilder({
  externalUrlBase: 'https://btcnft.io/vault',
  protocolName: 'BTCNFT Protocol',  // optional
});
```

### Building Metadata

```typescript
const metadata = builder.buildTreasureMetadata(
  rankedVault,
  achievements,
  'https://ipfs.io/ipfs/QmTreasureImage'
);

// Result structure:
{
  name: 'Vault #42',
  description: 'BTCNFT Protocol Vault #42 containing 1.00000000 BTC. Diamond tier. 3 achievements earned.',
  image: 'https://ipfs.io/ipfs/QmTreasureImage',
  external_url: 'https://btcnft.io/vault/42',
  attributes: [
    { trait_type: 'Token ID', value: 42 },
    { trait_type: 'Collateral (BTC)', value: 1.0 },
    { trait_type: 'Rank', value: 5 },
    { trait_type: 'Percentile', value: 95 },
    { trait_type: 'Display Tier', value: 'Diamond' },
    { trait_type: 'Minter', value: 'Yes' },
    // ...
  ],
  tier_data: { display_tier: 'Diamond', percentile: 95, rank: 5 },
  achievement_data: { earned: ['MINTER', 'ANNUAL'], highest: 'ANNUAL' }
}
```

---

## Constants

### Achievement Hashes

```typescript
import { ACHIEVEMENT_TYPE_HASHES } from '@btcnft/vault-analytics';

// bytes32 values matching contract constants
ACHIEVEMENT_TYPE_HASHES.MINTER  // keccak256("MINTER")
```

### Duration Thresholds

```typescript
import {
  DURATION_THRESHOLDS,
  DURATION_THRESHOLDS_DAYS,
  isDurationAchievement,
  getDurationThreshold,
} from '@btcnft/vault-analytics';

DURATION_THRESHOLDS.FIRST_MONTH  // 30n * 24n * 60n * 60n (seconds)
DURATION_THRESHOLDS_DAYS.FIRST_MONTH  // 30

isDurationAchievement('FIRST_MONTH')  // true
isDurationAchievement('MINTER')       // false

getDurationThreshold('DIAMOND_HANDS')  // 730 days in seconds
```

### Tier Visuals

```typescript
import { TIER_VISUALS, ACHIEVEMENT_VISUALS, RARITY_ORDER } from '@btcnft/vault-analytics';

TIER_VISUALS.Whale.frame.color  // '#00D4FF'
TIER_VISUALS.Whale.leaderboard  // true

ACHIEVEMENT_VISUALS.MINTER.rarity      // 'common'
ACHIEVEMENT_VISUALS.HODLER_SUPREME.rarity  // 'legendary'

RARITY_ORDER.legendary  // 3 (highest)
RARITY_ORDER.common     // 0 (lowest)
```

---

## Integration Patterns

### React Hook Example

```typescript
function useVaultVisualHierarchy(vaultId: bigint) {
  const [hierarchy, setHierarchy] = useState<VaultVisualHierarchy | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetch() {
      setLoading(true);
      const ranking = await vaultClient.getVaultRanking(vaultId, {
        scope: { type: 'all' }
      });
      if (ranking) {
        const achievements = await achievementClient.getAchievements(ranking.vault.owner);
        setHierarchy(composeVisualHierarchy(ranking, achievements));
      }
      setLoading(false);
    }
    fetch();
  }, [vaultId]);

  return { hierarchy, loading };
}
```

### Batch Processing

```typescript
async function getVisualHierarchies(vaults: RankedVault[]): Promise<VaultVisualHierarchy[]> {
  const hierarchies = await Promise.all(
    vaults.map(async (rankedVault) => {
      const achievements = await achievementClient.getAchievements(rankedVault.vault.owner);
      return composeVisualHierarchy(rankedVault, achievements);
    })
  );
  return hierarchies;
}
```

---

## Related Documentation

| Document | Purpose |
|----------|---------|
| [SDK README](./README.md) | Package overview |
| [Achievements Specification](../issuer/Achievements_Specification.md) | Contract mechanics |
| [Vault Percentile Specification](../issuer/Vault_Percentile_Specification.md) | Tier calculation |
| [Holder Experience](../issuer/Holder_Experience.md) | User journey |
