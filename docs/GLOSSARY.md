# BTCNFT Protocol Glossary

> **Version:** 1.0
> **Last Updated:** 2025-12-21

Standardized terminology for BTCNFT Protocol documentation.

---

## Core Concepts

### Vault NFT

| Attribute | Value |
|-----------|-------|
| Standard | ERC-998 (Composable) |
| Contains | Treasure NFT + BTC collateral |
| Rights | Withdrawals, redemption, collateral matching |

The primary asset of the protocol. A composable NFT that holds both a Treasure NFT and BTC collateral, granting perpetual withdrawal rights after vesting.

### Treasure NFT

| Attribute | Value |
|-----------|-------|
| Standard | ERC-721 |
| Purpose | Wrapped within Vault NFT |
| Ownership | Vault holder |

Any ERC-721 NFT that can be deposited into a Vault. Issuers define which Treasure contracts are eligible for their minting windows.

### vestedBTC (vBTC)

| Attribute | Value |
|-----------|-------|
| Standard | ERC-20 (Fungible) |
| Symbol | vBTC |
| Decimals | 8 (matches WBTC) |
| Backing | 1:1 with Vault collateral at mint |

**Also known as:** btcToken (internal contract name)

Fungible token representing a claim on BTC collateral. Created by separating collateral from a Vault NFT. Enables DeFi composability (DEX trading, lending, liquidity pools).

---

## Protocol Parameters

### Vesting Period

| Value | Description |
|-------|-------------|
| 1129 days | ~3.09 years |

Time before Vault holders can begin withdrawals. Immutable.

### Withdrawal Rate

| Value | Description |
|-------|-------------|
| 0.875%/month | 10.5%/year |

Maximum BTC that can be withdrawn each period. Immutable.

### Withdrawal Period

| Value | Description |
|-------|-------------|
| 30 days | Monthly cycle |

Interval between withdrawal opportunities.

### Dormancy Threshold

| Value | Description |
|-------|-------------|
| 1129 days | Inactivity period |

Time without activity before a separated Vault becomes dormant-eligible.

---

## Actors

### Issuer

Entity that creates minting opportunities. Controls entry requirements, Treasure design, and campaigns. Cannot modify core protocol parameters.

**Types:**
- Personal Brand
- DAO
- Corporation
- Artist Collective
- Community

### Holder

Owner of a Vault NFT. Has withdrawal rights, Treasure ownership, and (unless separated) redemption rights.

### vestedBTC Holder

Owner of vestedBTC tokens. Has collateral claim but no withdrawal rights or Treasure ownership.

---

## Operations

### Minting

Creating a new Vault NFT by depositing Treasure NFT + BTC collateral.

**Modes:**
- **Instant Mint**: Immediate permissionless minting
- **Window Mint**: Campaign-based coordinated releases

### Separation

Converting Vault collateral into fungible vestedBTC tokens via `mintBtcToken()`.

**Effect:** Vault retains withdrawal rights; vestedBTC represents collateral claim.

### Recombination

Returning vestedBTC to restore full Vault rights via `returnBtcToken()`.

**Requirement:** All-or-nothing (full original amount required).

### Collateral Matching

Pro-rata distribution of forfeited collateral from early redeemers to remaining Vault holders.

### Dormancy Claim

Process by which vestedBTC holders claim collateral from abandoned (dormant) Vaults.

---

## Token Standards

| Token | Standard | Fungibility |
|-------|----------|-------------|
| Vault NFT | ERC-998 | Non-fungible |
| Treasure NFT | ERC-721 | Non-fungible |
| vestedBTC | ERC-20 | Fungible |
| WBTC (collateral) | ERC-20 | Fungible |

---

## Naming Conventions

### In Code vs Documentation

| Code | Documentation | Description |
|------|---------------|-------------|
| `BtcToken` | vestedBTC | Separated collateral token |
| `btcToken` | vestedBTC | Contract instance |
| `mintBtcToken()` | Separation | Function to create vestedBTC |
| `returnBtcToken()` | Recombination | Function to restore Vault rights |
| `vBTC` | vestedBTC | Token symbol |

---

## Visual & Tier System

### Display Tier

Wealth-based visual tier (Bronze/Silver/Gold/Diamond/Whale) dynamically computed from collateral percentile. Unlike achievements which are merit-based, display tiers reflect relative collateral position within the protocol.

| Tier | Percentile Range |
|------|-----------------|
| Bronze | 0–50th |
| Silver | 50–75th |
| Gold | 75–90th |
| Diamond | 90–99th |
| Whale | 99th+ |

**Note:** Thresholds are keeper-updated based on current collateral distribution.

### Keeper

Authorized address that periodically updates on-chain tier thresholds based on current collateral distribution. Ensures Display Tiers remain calibrated to actual protocol TVL.

### ERC-4906

Metadata update extension (EIP-4906). Defines `MetadataUpdate` and `BatchMetadataUpdate` events for signaling NFT metadata changes to marketplaces and indexers.

**Usage:** Emitted when tier thresholds change, triggering marketplace cache invalidation.
