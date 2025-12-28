# Vault Percentile Distribution Specification

> **Version:** 1.0
> **Status:** Draft
> **Last Updated:** 2025-12-21
> **Related Documents:**
> - [Technical Specification](../protocol/Technical_Specification.md)
> - [Integration Guide](./Integration_Guide.md)
> - [Holder Experience](./Holder_Experience.md)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Data Model](#2-data-model)
3. [Percentile Ranking](#3-percentile-ranking)
4. [Filter Definitions](#4-filter-definitions)
5. [Display Format](#5-display-format)
6. [Query Patterns](#6-query-patterns)
7. [Example Scenarios](#7-example-scenarios)

---

## 1. Overview

### Purpose

Display Vault NFT collections with percentile rankings based on BTC collateral amount. Issuers can view their vault distribution and identify high-value positions relative to the filtered dataset.

### Use Cases

| Use Case | Description |
|----------|-------------|
| **Portfolio Analysis** | Issuer reviews distribution of vault sizes across their ecosystem |
| **Diamond Tier Identification** | Identify top-tier vaults for community recognition or outreach |
| **Health Monitoring** | Track vesting progress and separation rates |
| **Dormancy Detection** | Identify at-risk vaults requiring holder engagement |

### Relationship to Achievement System

Display tiers are **orthogonal** to achievements:

| System | Basis | Persistence | Applied To |
|--------|-------|-------------|------------|
| **Achievements** | Merit (actions, duration) | Permanent (soulbound) | Achievement NFT |
| **Display Tiers** | Wealth (collateral %) | Dynamic (recalculated) | Treasure NFT visuals |

A holder can earn DIAMOND_HANDS achievement (730 days held) while their Treasure displays as "Bronze" tier (low collateral percentile). These are independent systems that serve different purposes:

- **Achievements** recognize commitment and actions (what you've done)
- **Display Tiers** reflect relative position (how you compare to others)

See [Achievements Specification](./Achievements_Specification.md) for the merit-based achievement system.

---

## 2. Data Model

### Vault Fields

| Field | Type | Source | Description |
|-------|------|--------|-------------|
| `tokenId` | uint256 | VaultNFT | Unique vault identifier |
| `owner` | address | VaultNFT.ownerOf() | Current vault holder |
| `treasureContract` | address | Per-token | ERC-721 contract of Treasure |
| `treasureTokenId` | uint256 | Per-token | Token ID of Treasure |
| `collateralToken` | address | Per-token | WBTC or cbBTC address |
| `collateralAmount` | uint256 | Per-token | BTC collateral deposited |
| `mintTimestamp` | uint256 | Per-token | Block timestamp at mint |
| `lastWithdrawal` | uint256 | Per-token | Timestamp of last withdrawal |
| `vestedBTCAmount` | uint256 | Per-token | Amount of vestedBTC minted (0 = combined) |
| `lastActivity` | uint256 | Dormancy | Last activity timestamp |
| `pokeTimestamp` | uint256 | Dormancy | Poke timestamp (0 = not poked) |

### Derived Fields

| Field | Derivation | Description |
|-------|------------|-------------|
| `vestingEndsAt` | `mintTimestamp + 1129 days` | When vesting completes |
| `isVested` | `block.timestamp >= vestingEndsAt` | Vesting complete |
| `isSeparated` | `vestedBTCAmount > 0` | Collateral separated to vestedBTC |
| `dormancyState` | See [Section 4.3](#43-dormancy-status) | Active, Poke Pending, Claimable |
| `vestingDaysRemaining` | `max(0, vestingEndsAt - block.timestamp) / 1 days` | Days until vested |

---

## 3. Percentile Ranking

### Calculation

```
percentile = ((total_vaults - rank) / total_vaults) * 100

Where:
- total_vaults = count of vaults matching current filters
- rank = position when sorted by collateralAmount descending (1 = highest)
```

### Display Tiers

| Tier | Percentile | Frame Color | Visual Enhancement |
|------|------------|-------------|-------------------|
| **Diamond** | 99th+ | `#E8F4FF` | Crystalline frame + leaderboard feature |
| **Platinum** | 90-99th | `#E5E4E2` | Platinum frame + shimmer |
| **Gold** | 75-90th | `#FFD700` | Gold frame |
| **Silver** | 50-75th | `#C0C0C0` | Silver frame |
| **Bronze** | 0-50th | `#CD7F32` | Standard frame |

> **Note:** Display tiers are **VISUAL ONLY** - they provide no rate/reward advantages. Tiers are applied to Treasure NFT artwork based on the vault's collateral percentile.

> Frame SVG templates: [Visual_Assets_Guide.md](./Visual_Assets_Guide.md) Section 3.3

### Ranking Rules

| Rule | Description |
|------|-------------|
| **Scope-Relative** | Percentile calculated within filtered dataset only |
| **Tie-Breaking** | Equal collateral → earlier mintTimestamp ranks higher |
| **Minimum Dataset** | Percentile display requires ≥ 10 vaults in filtered set |
| **Dynamic Recalculation** | Percentile updates when filters change |

### Example

```
Filtered dataset: 1000 vaults
Vault with rank 15 (15th highest collateral):

percentile = ((1000 - 15) / 1000) * 100 = 98.5%
Display: "Top 5%" (≥ 95th percentile tier)
```

---

## 4. Filter Definitions

### 4.1 Vesting Status

| Value | Condition | Description |
|-------|-----------|-------------|
| `vesting` | `block.timestamp < mintTimestamp + 1129 days` | Still in vesting period |
| `vested` | `block.timestamp >= mintTimestamp + 1129 days` | Vesting complete |
| `all` | - | No filter applied |

### 4.2 Separation Status

| Value | Condition | Description |
|-------|-----------|-------------|
| `combined` | `vestedBTCAmount == 0` | Collateral intact in vault |
| `separated` | `vestedBTCAmount > 0` | Collateral separated to vestedBTC |
| `all` | - | No filter applied |

### 4.3 Dormancy Status

| Value | Condition | Description |
|-------|-----------|-------------|
| `active` | `pokeTimestamp == 0` AND not dormant-eligible | Normal state |
| `poke_pending` | `pokeTimestamp > 0` AND within grace period | Grace period active |
| `claimable` | `pokeTimestamp > 0` AND grace period expired | Claimable by vestedBTC holder |
| `all` | - | No filter applied |

**Dormant-Eligible Criteria:**
- Vault is vested (`block.timestamp >= mintTimestamp + 1129 days`)
- Collateral is separated (`vestedBTCAmount > 0`)
- Inactive for threshold period (`block.timestamp >= lastActivity + 1129 days`)

### 4.4 Scope

| Value | Description |
|-------|-------------|
| `all` | All protocol vaults (default) |
| `issuer:<address>` | Vaults minted through windows created by issuer |
| `treasure:<contract>` | Vaults containing Treasures from specific contract |

---

## 5. Display Format

### Table Structure

| Column | Type | Sortable | Description |
|--------|------|----------|-------------|
| Rank | number | - | Position in filtered set |
| Token ID | uint256 | Yes | Vault NFT token ID |
| Collateral | string | Yes | BTC amount (formatted with 8 decimals) |
| Percentile | string | - | Tier badge (e.g., "Top 5%") |
| Status | string | Yes | Vesting + Separation combined status |
| Owner | address | Yes | Wallet address (truncated) |

### Status Display

| Vesting | Separation | Display |
|---------|------------|---------|
| Vesting | Combined | "Vesting (X days)" |
| Vesting | Separated | "Vesting (X days) • Separated" |
| Vested | Combined | "Vested" |
| Vested | Separated | "Vested • Separated" |

### Collateral Formatting

```
Raw: 100000000 (1 BTC in 8 decimal representation)
Display: "1.00000000 BTC"

Raw: 12345678 (0.12345678 BTC)
Display: "0.12345678 BTC"
```

### Pagination

| Parameter | Default | Max |
|-----------|---------|-----|
| Page Size | 25 | 100 |
| Sort Order | Collateral DESC | - |

---

## 6. Query Patterns

### Data Sources

| Source | Method | Data |
|--------|--------|------|
| Vault enumeration | `VaultMinted` events | All token IDs |
| Vault data | `getVaultInfo(tokenId)` | Core vault fields |
| Vesting status | `isVested(tokenId)` | Boolean |
| Dormancy state | `getDormancyState(tokenId)` | ACTIVE, POKE_PENDING, CLAIMABLE |
| Separation status | `btcTokenAmount(tokenId)` | vestedBTC amount (0 = combined) |
| Ownership | `ownerOf(tokenId)` | Current owner address |

### Indexing Strategy

```
1. Index all VaultMinted events
2. For each tokenId, fetch:
   - getVaultInfo(tokenId) → core data
   - ownerOf(tokenId) → owner
3. Apply filters client-side or via indexed query
4. Sort by collateralAmount DESC
5. Calculate rank and percentile
```

> **Metadata Service:** These query patterns feed the Custom API metadata service for dynamic tier frame composition. See [Integration_Guide.md](./Integration_Guide.md) Section 13 for implementation requirements.

### Scope Filtering

**All Protocol:**
```
Query all VaultMinted events
```

**Per-Issuer:**
```
1. Query WindowCreated events WHERE issuer == target
2. Get windowIds from events
3. Query VaultMinted events WHERE windowId IN windowIds
```

**Per-Treasure:**
```
Query VaultMinted events WHERE treasureContract == target
```

---

## 7. Example Scenarios

### Scenario 1: Issuer Portfolio Overview

**Goal:** View all vaults from my minting windows, ranked by collateral.

| Filter | Value |
|--------|-------|
| Scope | `issuer:0x1234...` |
| Vesting Status | `all` |
| Separation Status | `all` |

**Result:** All vaults minted through issuer's windows, sorted by collateral with percentile badges relative to that issuer's ecosystem.

### Scenario 2: Diamond Tier Identification

**Goal:** Find top 1% vaults across the protocol.

| Filter | Value |
|--------|-------|
| Scope | `all` |
| Vesting Status | `vested` |
| Separation Status | `combined` |

**Result:** Only vested, combined vaults. Filter to "Top 1%" tier to identify Diamond tier vaults.

### Scenario 3: At-Risk Vault Detection

**Goal:** Identify vaults at risk of dormancy claims.

| Filter | Value |
|--------|-------|
| Scope | `issuer:0x1234...` |
| Dormancy Status | `poke_pending` |

**Result:** Vaults currently in grace period. Issuer can reach out to holders.

### Scenario 4: Series Analysis

**Goal:** Compare vault distribution across different Treasure collections.

| Filter | Value |
|--------|-------|
| Scope | `treasure:0xABCD...` |
| Vesting Status | `all` |

**Result:** All vaults containing Treasures from specific collection, with percentiles relative to that collection.

---

## Related Documentation

| Document | Purpose |
|----------|---------|
| [Technical Specification](../protocol/Technical_Specification.md) | Vault data model, dormancy mechanics |
| [Integration Guide](./Integration_Guide.md) | Issuer implementation patterns |
| [Holder Experience](./Holder_Experience.md) | End-user vault interactions |

---

## Navigation

← [Issuer Layer](./README.md) | [Documentation Home](../README.md)
