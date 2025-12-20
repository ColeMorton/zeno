# BTCNFT Protocol Issuer Integration

> **Version:** 1.0
> **Status:** Draft
> **Last Updated:** 2025-12-16
> **Related Documents:**
> - [Technical Specification](./Technical_Specification.md)
> - [Product Specification](./Product_Specification.md)
> - [Collateral Matching](./Collateral_Matching.md)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Issuer Registration](#2-issuer-registration)
3. [Minting Modes](#3-minting-modes)
4. [Badge-Gated Minting](#4-badge-gated-minting)
5. [Badge Redemption Controller](#5-badge-redemption-controller)
6. [Capital Flow Architecture](#6-capital-flow-architecture)
7. [Bonding Mechanism](#7-bonding-mechanism)
8. [Issuer Analytics](#8-issuer-analytics)

---

## 1. Overview

### What is an Issuer?

An issuer is any entity that creates minting opportunities for BTCNFT Protocol. Issuers control:
- Which Treasure NFTs can be vaulted
- Minting windows and campaigns
- Entry requirements (open vs badge-gated)

### Issuer Types

| Type | Description | Examples |
|------|-------------|----------|
| **Open** | Anyone can mint with any eligible Treasure | Permissionless protocol access |
| **Curated** | Specific Treasure collections allowed | Artist drops, brand partnerships |
| **Gated** | Badge or credential required | Community-only, KYC-gated |

### Protocol-Issuer Relationship

```
┌─────────────────────────────────────────────────────────────────┐
│                    PROTOCOL-ISSUER ARCHITECTURE                 │
│                                                                 │
│  Protocol Layer (Immutable):                                    │
│  ├─ Core BTCNFT Contract (Vault NFT, withdrawals, vesting)     │
│  ├─ Collateral Matching Pool                                   │
│  └─ vestedBTC Contract (ERC-20)                                │
│                                                                 │
│  Issuer Layer (Per-Issuer):                                    │
│  ├─ Badge Contracts (optional, ERC-721/ERC-5192)               │
│  ├─ Treasure Contracts (ERC-721)                               │
│  ├─ Redemption Controllers (optional)                          │
│  └─ Minting Windows                                            │
│                                                                 │
│  Relationship:                                                  │
│  ├─ Protocol accepts any ERC-721 as Treasure                   │
│  ├─ Issuers control which Treasures via window configuration   │
│  ├─ Issuers cannot modify core protocol parameters             │
│  └─ Multiple issuers operate concurrently                      │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Issuer Registration

### Permissionless Registration

Any address can register as an issuer:

```solidity
function registerIssuer() external {
    if (registeredIssuers[msg.sender]) revert AlreadyRegistered(msg.sender);
    registeredIssuers[msg.sender] = true;
    emit IssuerRegistered(msg.sender, block.timestamp);
}
```

### Issuer Capabilities

| Capability | Description |
|------------|-------------|
| Create windows | Define time-bound minting campaigns |
| Specify allowed Treasures | Whitelist ERC-721 contracts per window |
| Cancel pending mints | Remove pending mints from their windows |
| Cancel empty windows | Cancel windows with no pending mints |

### Issuer Constraints (Code-Enforced)

These constraints are **technically impossible to circumvent**—they are enforced by the absence of functions in the smart contract, not by policy.

| Constraint | Reason | Enforcement |
|------------|--------|-------------|
| Cannot modify core protocol | Immutable withdrawal rates, vesting periods | **No function exists** in contract |
| Cannot access user collateral | Non-custodial design | **No function exists** in contract |
| Cannot cancel executed windows | Terminal state protection | **State cannot transition** from terminal |
| Cannot cancel with pending mints | User asset protection | **Revert condition** in contract |

**Key Insight:** Issuers are constrained by immutable code, not by trust or policy. The functions that would enable these actions simply do not exist in the deployed contract.

---

## 3. Minting Modes

### Instant Mint

Direct Vault NFT creation without window coordination:

```
User → Treasure + BTC → Protocol.instantMint() → Vault NFT
```

**Use cases:**
- Standard permissionless minting
- No campaign coordination required
- Immediate Vault creation

### Window Mint

Deferred batch minting for coordinated campaigns:

```
User → Treasure + BTC → Protocol.pendingMint() → [Window Period] → executeMints() → Vault NFT
```

**Use cases:**
- Community goals (e.g., "Mint 100 Vaults this month")
- Synchronized vesting starts
- Series releases

### Comparison

| Aspect | Instant Mint | Window Mint |
|--------|--------------|-------------|
| Timing | Immediate | Deferred to execution |
| Vesting start | Mint timestamp | Execution timestamp |
| Campaign support | No | Yes |
| Treasure restriction | Protocol-wide | Per-window |
| Collateral adjustment | No | Yes (increase only) |

---

## 4. Badge-Gated Minting

### Architecture

Badge-gated minting creates quality filters where credentials gate Vault access:

```
┌─────────────────────────────────────────────────────────────────┐
│                    BADGE-GATED ARCHITECTURE                     │
│                                                                 │
│  Open Mint:                                                     │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Anyone → Treasure + BTC → Vault NFT                    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Badge-Gated Mint:                                              │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Earn Badge → Badge + BTC → Controller → Vault NFT      │   │
│  │  (Treasure minted by controller, unique per badge type) │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### Two-Tier Badge System

| Tier | Badge Type | Purpose | Transferable |
|------|------------|---------|--------------|
| 1 | Entry Badge | Gates initial Vault access | No (soulbound) |
| 2 | Achievement | Enables Vault stacking | Yes (most) |

### Tier 1: Entry Badges

Soulbound badges (ERC-5192) granted by issuer to participants BEFORE any Vault:

| Property | Value |
|----------|-------|
| Standard | ERC-5192 (Soulbound) |
| Transferable | No |
| Redeemable | Once |
| Purpose | Gate first Vault mint |

**Entry Badge Flow:**
```
Issuer → Grant Entry Badge → User
                              ↓
              User → Badge + BTC → Controller → Vault NFT
                              ↓
              Badge marked as "redeemed" (stays at wallet)
```

### Tier 2: Protocol Achievements

Protocol achievements earned from holding/using Vaults can be redeemed for NEW Vaults:

| Type | Examples | Redeemable |
|------|----------|------------|
| Duration | First Month, Diamond Hands, Hodler Supreme | Yes |
| Behavior | First Withdrawal, Compounder, LP Provider | Yes |
| Participation | Genesis, Pioneer, Season Survivor | Yes |

### Vault Stacking Flywheel

```
┌─────────────────────────────────────────────────────────────────┐
│                    VAULT STACKING FLYWHEEL                      │
│                                                                 │
│                    ┌─────────────────────────────────┐          │
│                    │                                 │          │
│                    ▼                                 │          │
│  ┌──────────┐   ┌─────────┐   ┌─────────────┐   ┌─────────────┐│
│  │ Engage   │──▶│ Entry   │──▶│ Vault #1    │──▶│ Achievements││
│  │ w/ Issuer│   │ Badge   │   │ + BTC       │   │ Earned      ││
│  └──────────┘   └─────────┘   └─────────────┘   └──────┬──────┘│
│                                                        │        │
│                                                        ▼        │
│                    ┌─────────────────────────────────┐          │
│                    │ Redeem Achievement for Vault #2 │──────────┘
│                    │ → Earns more achievements       │
│                    │ → Redeem for Vault #3...        │
│                    └─────────────────────────────────┘
│                                                                 │
│  Growth Mechanics:                                              │
│  ├─ Each Vault generates achievements over time                │
│  ├─ Each achievement can become a Treasure for new Vault       │
│  └─ Compounding: more time = more achievements = more Vaults   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 5. Badge Redemption Controller

### Purpose

A BadgeRedemptionController enables atomic badge-to-Vault transactions:

```
Badge + BTC → Controller → Vault NFT (with unique Treasure)
```

### Controller Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   BadgeRedemptionController                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  State:                                                         │
│  ├─ entryBadgeContract: address (soulbound badges)             │
│  ├─ achievementContract: address (protocol achievements)       │
│  ├─ treasureContract: address (Treasure NFT minter)            │
│  ├─ protocolContract: address (BTCNFT Protocol)                │
│  └─ redeemed: mapping(uint256 => bool)                         │
│                                                                 │
│  Function: redeemBadge(badgeTokenId, btcAmount)                 │
│  ├─ 1. Verify caller owns badge (entry OR achievement)         │
│  ├─ 2. Verify badge not previously redeemed                    │
│  ├─ 3. transferFrom(caller, this, btcAmount)                   │
│  ├─ 4. treasureContract.mint(caller, badgeType) → treasureId   │
│  ├─ 5. approve(protocolContract, treasureId, btcAmount)        │
│  ├─ 6. protocolContract.mintVault(treasureId, btcAmount, tier) │
│  ├─ 7. vaultNFT.transferFrom(this, caller, vaultId)            │
│  ├─ 8. redeemed[badgeTokenId] = true                           │
│  └─ 9. emit RedemptionEvent(caller, badgeType, btcAmount)      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Controller Interface

```solidity
interface IBadgeRedemptionController {
    /// @notice Redeem a badge for a Vault NFT
    /// @param badgeTokenId The badge to redeem (entry or achievement)
    /// @param btcAmount BTC collateral to deposit
    /// @return vaultTokenId The minted Vault NFT token ID
    function redeemBadge(
        uint256 badgeTokenId,
        uint256 btcAmount
    ) external returns (uint256 vaultTokenId);

    /// @notice Check if a badge has been redeemed
    function isRedeemed(uint256 badgeTokenId) external view returns (bool);

    /// @notice Get the Treasure design for a badge type
    function getTreasureDesign(uint256 badgeType) external view returns (bytes32);
}
```

### Events

```solidity
event BadgeRedeemed(
    address indexed redeemer,
    uint256 indexed badgeTokenId,
    uint256 indexed vaultTokenId,
    uint256 btcAmount,
    uint256 treasureTokenId
);
```

---

## 6. Capital Flow Architecture

### Protocol Capital Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    BTCNFT PROTOCOL CAPITAL FLOW                 │
│                                                                 │
│  User BTC                                                       │
│       ↓                                                         │
│  mint() or redeemBadge()                                       │
│       ↓                                                         │
│  Smart Contract (100% to collateral)                           │
│       ↓                                                         │
│  Post-Vesting: withdraw() every 30 days                        │
│       ↓                                                         │
│  BTC directly to wallet                                        │
└─────────────────────────────────────────────────────────────────┘

Key Property: 100% of deposited BTC becomes user collateral.
No issuer extraction from deposits.
```

### vestedBTC Secondary Market Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                 vestedBTC SECONDARY MARKET                      │
│                                                                 │
│  Vault Holder                                                   │
│       │                                                         │
│       ├──► mintVestedBTC() ──► vestedBTC (ERC-20)              │
│       │                              │                          │
│       │    (Withdrawal rights        │                          │
│       │     retained)                ↓                          │
│       │                    ┌─────────────────────┐              │
│       │                    │  DEX (Curve/Uniswap)│              │
│       │                    │  vestedBTC/WBTC LP  │              │
│       │                    └─────────────────────┘              │
│       │                              │                          │
│       │                    ┌─────────┴─────────┐                │
│       │                    ↓                   ↓                │
│       │           ┌──────────────┐    ┌──────────────┐          │
│       │           │  Trade for   │    │  Use as      │          │
│       │           │  WBTC/cbBTC  │    │  Collateral  │          │
│       │           └──────────────┘    │  (Aave)      │          │
│       │                               └──────────────┘          │
│       │                                                         │
│       └──► withdraw() ──► BTC withdrawal (perpetual)           │
└─────────────────────────────────────────────────────────────────┘
```

### DeFi Composability Stack

```
┌─────────────────────────────────────────────────────────────────┐
│                    DeFi COMPOSABILITY                           │
│                                                                 │
│  Layer 1: Base Asset                                           │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  vestedBTC (ERC-20)                                     │   │
│  │  Properties: BTC-denominated, historical yearly         │   │
│  │              stability (not a USD peg)                  │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          ↓                                      │
│  Layer 2: Liquidity (BTC-Denominated Only)                     │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Curve: vestedBTC/WBTC stable-like (minimal IL)         │   │
│  │  Curve: vestedBTC/cbBTC stable-like (multi-BTC)         │   │
│  │  Uniswap V3: vestedBTC/WBTC [0.80-1.00] concentrated    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          ↓                                      │
│  Layer 3: Lending                                              │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Aave: vestedBTC as collateral (borrow WBTC/ETH)        │   │
│  │  Compound: vestedBTC market                             │   │
│  │  Morpho: Optimized vestedBTC lending                    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          ↓                                      │
│  Layer 4: Yield Strategies                                     │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Yearn: vestedBTC vault auto-compound                   │   │
│  │  Convex: Boosted Curve vestedBTC LP                     │   │
│  │  Pendle: vestedBTC yield tokenization                   │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 7. Bonding Mechanism

### Protocol-Owned Liquidity (POL)

Bonding enables protocol-owned liquidity accumulation:

```
┌─────────────────────────────────────────────────────────────────┐
│                    vestedBTC BONDING                            │
│                                                                 │
│  Step 1: User Provides Liquidity                               │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  vestedBTC + WBTC → Curve → LP Tokens                   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          ↓                                      │
│  Step 2: User Bonds LP                                         │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Call bond(lpTokenAmount)                               │   │
│  │  Protocol quotes: 5-15% discount, 5-7 day vesting       │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          ↓                                      │
│  Step 3: Protocol Receives LP                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  LP tokens → Protocol Treasury                          │   │
│  │  Protocol earns all trading fees                        │   │
│  │  Liquidity is permanent (no mercenary flight)           │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          ↓                                      │
│  Step 4: User Receives Discounted Position                     │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  After vesting: Claim Vault NFT (pre-funded with BTC)   │   │
│  │  Effective entry: 5-15% below market                    │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### Bond Pricing

| Parameter | Value |
|-----------|-------|
| Discount Range | 5-15% below market |
| Vesting Period | 5-7 days |
| Capacity | Limited by treasury BTC reserves |
| Price Discovery | Market-driven (no oracle) |

### Robustness vs OHM

| Factor | OHM (Vulnerable) | vestedBTC (Robust) |
|--------|------------------|-------------------|
| Backing | Reflexive (OHM backs OHM) | Non-reflexive (actual BTC) |
| Intrinsic Value | Protocol-dependent | BTC market price |
| Death Spiral Risk | High (circular) | Low (BTC floor) |
| Withdrawal Source | Emissions (dilutive) | Own collateral (non-dilutive) |

---

## 8. Issuer Analytics

### On-Chain Metrics

Issuers can track metrics via on-chain events and state:

| Metric | Description | Query Method |
|--------|-------------|--------------|
| Total Collateral | BTC locked across all Vaults | `sum(collateralAmount)` per issuer |
| Vault Count | Total Vaults created | Count of `VaultMinted` events |
| Window Participation | Pending mints per window | `window.pendingMintCount` |
| Execution Rate | % of pending mints executed | `executedMintCount / pendingMintCount` |

### Badge-Gated Metrics

| Metric | Description | Use Case |
|--------|-------------|----------|
| `totalCollateral[badgeType]` | BTC locked per badge type | Identify high-value badges |
| `vaultCount[badgeType]` | Vaults created per badge type | Measure badge popularity |
| `redemptionRate[badgeType]` | % of badges redeemed | Assess badge utility |
| `avgVaultsPerParticipant` | Vault stacking rate | Measure engagement depth |
| `achievementVelocity` | Achievement → Vault conversion rate | Track stacking behavior |

### Events for Indexing

```solidity
// Issuer-level events
event IssuerRegistered(address indexed issuer, uint256 timestamp);
event WindowCreated(uint256 indexed windowId, address indexed issuer, ...);
event WindowExecuted(uint256 indexed windowId, uint32 totalMinted);

// Badge redemption events (from controller)
event BadgeRedeemed(
    address indexed redeemer,
    uint256 indexed badgeTokenId,
    uint256 indexed vaultTokenId,
    uint256 btcAmount,
    uint256 treasureTokenId
);

// Achievement events
event AchievementMinted(address indexed earner, bytes32 indexed achievementId, uint256 tokenId);
event AchievementUsedAsTreasure(uint256 indexed achievementTokenId, uint256 indexed vaultTokenId);
```

---

## Summary

| Integration Pattern | Description |
|--------------------|-------------|
| **Issuer Registration** | Permissionless; any address can become an issuer |
| **Instant Mint** | Direct Vault creation without coordination |
| **Window Mint** | Deferred batch minting for campaigns |
| **Badge-Gated** | Credential-based access control |
| **Two-Tier Badges** | Entry badges (gate) + Achievements (stack) |
| **Redemption Controller** | Atomic badge-to-Vault transactions |
| **Bonding** | Protocol-owned liquidity accumulation |
| **Analytics** | On-chain metrics for issuer tracking |
