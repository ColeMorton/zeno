# BTCNFT Protocol Integration Guide

> **Version:** 1.0
> **Status:** Draft
> **Last Updated:** 2025-12-21
> **Related Documents:**
> - [Achievements Specification](./Achievements_Specification.md)
> - [Technical Specification](../protocol/Technical_Specification.md)
> - [Product Specification](../protocol/Product_Specification.md)
> - [Holder Experience](./Holder_Experience.md)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Issuer Registration](#2-issuer-registration)
3. [Entry Strategies](#3-entry-strategies)
4. [Minting Modes](#4-minting-modes)
5. [Achievement System](#5-achievement-system)
6. [Treasure Strategy](#6-treasure-strategy)
7. [Campaigns & Gamification](#7-campaigns--gamification)
8. [Governance Options](#8-governance-options)
9. [Revenue Models](#9-revenue-models)
10. [Capital Flow Architecture](#10-capital-flow-architecture)
11. [Bonding Integration](#11-bonding-integration)
12. [Liquidity Bootstrapping](#12-liquidity-bootstrapping)
13. [Display Tier Integration](#13-display-tier-integration)
14. [Analytics](#14-analytics)

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
| **Personal Brand** | Individual-driven with unique series | Content creators, influencers |
| **DAO** | Community-governed with token/NFT voting | DeFi protocols, NFT communities |
| **Corporation** | Enterprise-managed with formal governance | Companies, institutions |
| **Artist Collective** | Creator-focused with art-centric Treasures | Artists, galleries |
| **Community** | Group-managed with shared objectives | Discord communities, clubs |

### Protocol-Issuer Architecture

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
│  └─ Auction Controller (Dutch & English auctions)              │
│                                                                 │
│  Relationship:                                                  │
│  ├─ Protocol accepts any ERC-721 as Treasure                   │
│  ├─ Issuers control access via auction configuration           │
│  ├─ Issuers cannot modify core protocol parameters             │
│  └─ Multiple issuers operate concurrently                      │
└─────────────────────────────────────────────────────────────────┘
```

### Issuer Control vs Protocol Control

| Aspect | Issuer Control | Protocol Control (Immutable) |
|--------|----------------|------------------------------|
| Entry requirements | Open vs badge-gated | - |
| Treasure design | Art, metadata, editions | - |
| Minting windows | Timing, campaigns | - |
| Achievement extensions | Custom achievements | - |
| Gamification | Leaderboards, tiers | - |
| Governance | Multisig, DAO, centralized | - |
| Withdrawal rate | - | 12% annually (1.0% monthly) |
| Vesting period | - | 1129 days |
| Collateral matching | - | Pro-rata distribution |
| Dormancy mechanism | - | 1129-day inactivity threshold |
| vestedBTC mechanics | - | ERC-20, 1:1 with collateral |

**Key Insight:** No admin, no DAO, no governance mechanism can alter protocol parameters. The functions to modify them do not exist in the contract.

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
| Create auctions | Define Dutch or English auctions for vault minting |
| Configure auction parameters | Set prices, durations, and supplies |
| Specify Treasures | Associate TreasureNFT contracts with auctions |

### Issuer Constraints (Code-Enforced)

These constraints are **technically impossible to circumvent**—they are enforced by the absence of functions in the smart contract.

| Constraint | Enforcement |
|------------|-------------|
| Cannot modify core protocol | **No function exists** in contract |
| Cannot access user collateral | **No function exists** in contract |
| Cannot cancel executed windows | **State cannot transition** from terminal |
| Cannot modify active auctions | **State transition** rules in contract |

---

## 3. Entry Strategies

### Open Minting

Anyone can mint with any eligible Treasure:

```
User → Treasure + BTC → Protocol.instantMint() → Vault NFT
```

**Best for:**
- Maximum accessibility
- Permissionless growth
- Protocol-level participation

### Badge-Gated Minting

Require credentials for access:

```
Earn Badge → Badge + BTC → Controller → Vault NFT
```

**Best for:**
- Quality filtering
- Community building
- Engagement-driven growth

### Hybrid Approach

Combine open minting with badge benefits:

| Access Level | Requirement | Benefit |
|--------------|-------------|---------|
| Basic | Any Treasure | Standard Vault |
| Premium | Entry Badge | Unique Treasure art |
| Exclusive | Rare Badge | Limited edition series |

---

## 4. Minting Modes

### Direct Mint

Permissionless Vault NFT creation through the protocol:

```
User → Treasure + BTC → Protocol.mint() → Vault NFT
```

**Use cases:**
- Open permissionless minting
- Direct protocol interaction
- Immediate Vault creation

### Auction Mint (Issuer Layer)

Issuers use the AuctionController to create structured minting campaigns:

#### Dutch Auction

Descending price auction where price decays over time:

```
Issuer creates auction → Price starts high → Decays linearly → User purchases at current price → Vault NFT
```

**Flow:**
1. Issuer calls `createDutchAuction(maxSupply, collateralToken, config)`
2. Price decays from `startPrice` to `floorPrice` based on `decayRate`
3. Users call `purchaseDutch(auctionId)` at any time to purchase at current price
4. Payment becomes collateral for the minted Vault

#### English Auction

Ascending bid auction for slots:

```
Issuer creates auction → Users bid on slots → Highest bids win → Settlement creates Vault NFTs
```

**Flow:**
1. Issuer calls `createEnglishAuction(maxSupply, collateralToken, config)`
2. Users call `placeBid(auctionId, slot, amount)` to bid on specific slots
3. Higher bids refund previous bidders automatically
4. After auction ends, anyone calls `settleSlot(auctionId, slot)` to mint Vault for winner
5. Winning bid becomes collateral

### Comparison

| Aspect | Direct Mint | Dutch Auction | English Auction |
|--------|-------------|---------------|-----------------|
| Timing | Immediate | Purchase anytime during auction | Bid during auction, settle after |
| Price | User-defined | Issuer-defined, decays | Market-discovered |
| Quantity | Unlimited | Issuer-defined maxSupply | Issuer-defined slots |
| Best for | Open access | Fair distribution | Price discovery |

---

## 5. Achievement System

The protocol includes a comprehensive achievement system for recognizing holder milestones.

### Overview

| Property | Value |
|----------|-------|
| Standard | ERC-5192 (Soulbound) |
| Transferable | No |
| Purpose | Recognize and attest wallet actions |
| Principle | Merit-based, cosmetic-only |

### Integration Points

Issuers interact with achievements through:
- **AchievementMinter**: Claim logic and verification
- **AchievementNFT**: Soulbound token storage

For complete achievement types, claiming mechanics, dependency graphs, and gamification, see [Achievements Specification](./Achievements_Specification.md).

### Issuer Customization

Issuers can extend achievements using the bytes32-based system:
- Deploy custom AchievementMinter with additional types
- Define issuer-specific verification logic
- Maintain compatibility with protocol achievements

```solidity
// Example: Define custom achievement
bytes32 constant CUSTOM_ACHIEVEMENT = keccak256("CUSTOM_ACHIEVEMENT");

// Add verification logic in custom minter
function claimCustomAchievement(uint256 vaultId) external {
    require(customConditionMet(vaultId), "Condition not met");
    achievements.mint(msg.sender, CUSTOM_ACHIEVEMENT);
}
```

---

## 6. Treasure Strategy

### Collection Types

| Collection | Pricing | Use Case |
|------------|---------|----------|
| Genesis | Auction | Scarcity via limited supply |
| Seasonal | Auction/Fixed | Edition-based releases |
| Achievement | Free (merit) | Earned through behavior |
| Partner | Partner-defined | Revenue share collaborations |

### Edition Releases

| Release Type | Mechanism | Best For |
|--------------|-----------|----------|
| Fixed Price | Set BTC price | Predictable, accessible |
| Ascending Auction | Rising bids | Price discovery for rare editions |
| Dutch Auction | Descending price | Fair distribution, demand-based |

**Auction Properties:**
- Winning bid = collateral deposit (100% to user's position)
- Limited supply creates natural scarcity
- Edition numbers track provenance
- Burned editions reduce total supply permanently

### Deflationary Mechanics

Early redemptions permanently destroy Treasures:
- Natural supply reduction over time
- Increased scarcity of remaining editions
- Stronger penalty for early exit
- Long-term value accrual for holders

---

## 7. Campaigns & Gamification

### Campaign Integration

Issuers can create time-limited campaigns with achievement rewards:

| Campaign Type | Description |
|---------------|-------------|
| Milestone | TVL targets, first maturity |
| Seasonal | Referral, retention, compounding |
| Partner | Sponsored DeFi integration rewards |

### Leaderboard Configuration

| Leaderboard | Type | Purpose |
|-------------|------|---------|
| Merit-based | Longest Hold, Achievement Hunter | Engagement recognition |
| Vanity | Diamond Watch | Collateral display (separate) |

**Critical:** Merit and vanity leaderboards must be SEPARATE. Vanity tiers are VISUAL ONLY with no rate/reward advantage.

For campaign structure, season alignment, and complete gamification mechanics, see [Achievements Specification](./Achievements_Specification.md#5-gamification).

---

## 8. Governance Options

### Multisig Council

| Aspect | Design |
|--------|--------|
| Structure | 3-of-5 or 5-of-7 signers |
| Responsibilities | Campaigns, Treasure releases, partners, treasury |
| Constraints | Cannot modify core protocol (no functions exist) |

### DAO Governance

| Aspect | Options |
|--------|---------|
| Voting power | NFT-weighted, 1-per-wallet, quadratic |
| Proposal threshold | Minimum holdings to propose |
| Quorum | Minimum participation required |
| Timelock | Delay between approval and execution |

### Centralized (Personal Brand)

| Aspect | Design |
|--------|--------|
| Decision-making | Sole authority |
| Accountability | Personal reputation |
| Speed | Fast iteration |
| Trust | Brand-dependent |

---

## 9. Revenue Models

### Collateral Integrity Principle

**100% of deposited BTC becomes user collateral.**

Issuers receive no revenue from primary mints. This ensures:
- Maximum collateral backing
- User trust through alignment
- No extraction from deposits

### Revenue Sources

| Source | Description |
|--------|-------------|
| **Services** | Premium features paid in vestedBTC |
| **Memberships** | Subscription-based access tiers |
| **Partner integrations** | Revenue share with DeFi protocols |
| **LP fees** | Protocol-owned liquidity trading fees |
| **Treasury appreciation** | vestedBTC holdings growth |

### Access Philosophy

| Aspect | Design |
|--------|--------|
| Core functionality | Free and unrestricted |
| Paywall footprint | Minimal |
| Upgrade paths | Transparent and non-intrusive |
| Gatekeeping | None on protocol features |

---

## 10. Capital Flow Architecture

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

---

## 11. Bonding Integration

> **Note**: Bonding is NOT part of the core protocol. This is an optional issuer-layer extension.

### Overview

Bonding enables protocol-owned liquidity (POL) accumulation by allowing users to exchange LP tokens for discounted Vault NFTs.

### Mechanism

```
Step 1: User Provides Liquidity
└─ vBTC + WBTC → Curve → LP Tokens

Step 2: User Bonds LP
└─ Call bond(lpTokenAmount)
└─ Issuer quotes: 5-15% discount, 5-7 day vesting

Step 3: Issuer Receives LP
└─ LP tokens → Issuer Treasury
└─ Issuer earns all trading fees
└─ Liquidity is permanent (no mercenary flight)

Step 4: User Receives Discounted Position
└─ After vesting: Claim Vault NFT (pre-funded with BTC)
└─ Effective entry: 5-15% below market
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

## 12. Liquidity Bootstrapping

### The Cold Start Problem

```
No liquidity → High slippage → Users won't mint vBTC
     ↑                                    │
     └────── No vBTC supply ←─────────────┘
```

Issuers must bootstrap Issuer-Owned Liquidity (IOL) to break this cycle.

### Strategy Options

| Strategy | Capital Required | Stickiness | Best For |
|----------|-----------------|------------|----------|
| Genesis Program | None | Very High | Community building |
| Single-Sided | High | Medium | Fast bootstrap |
| Time-Locked | None | Very High | Long-term depth |
| LBP | Medium | Low | Price discovery |

### Recommended Phased Approach

**Phase 1: Genesis (Launch)**
- Genesis Vault Program for first 100-500 participants
- 6-month minimum LP commitment required
- Exclusive benefits for early supporters

**Phase 2: Growth (Months 1-6)**
- Single-sided deposits to accelerate liquidity
- Time-locked multipliers for new entrants
- Bonding integration (if implemented)

**Phase 3: Maturity (6+ months)**
- Remove special incentives gradually
- Natural LP economics (trading fees) sustain liquidity
- Focus shifts to volume growth

---

## 13. Display Tier Integration

### Overview

When rendering Treasure NFTs, issuers apply visual enhancements based on the vault's collateral percentile rank. This is distinct from the achievement system.

| System | Basis | Purpose |
|--------|-------|---------|
| **Achievements** | Merit (actions) | Recognize holder actions (soulbound) |
| **Display Tiers** | Wealth (collateral %) | Visual ranking of Treasure NFTs |

### Tier Calculation

Display tiers are calculated **OFF-CHAIN** based on collateral percentile:

```
1. Query vault collateral: vaultNFT.collateralAmount(tokenId)
2. Calculate percentile against protocol/issuer TVL
3. Apply tier-appropriate visual enhancements
```

### Tier Mapping

| Tier | Percentile | Frame Color | Visual Enhancement |
|------|------------|-------------|-------------------|
| **Diamond** | 99th+ | `#E8F4FF` | Crystalline frame + leaderboard feature |
| **Platinum** | 90-99th | `#E5E4E2` | Platinum frame + shimmer |
| **Gold** | 75-90th | `#FFD700` | Gold frame |
| **Silver** | 50-75th | `#C0C0C0` | Silver frame |
| **Bronze** | 0-50th | `#CD7F32` | Standard frame |

> Frame SVG templates and color specifications: [Visual_Assets_Guide.md](./Visual_Assets_Guide.md) Section 3

### Implementation Notes

- **Dynamic**: Percentiles recalculate as protocol TVL changes
- **Scope-relative**: Can calculate against all vaults or per-issuer subset
- **Visual-only**: No protocol rate/reward advantages
- **Off-chain**: Protocol does not store tier assignments

### Rendering Flow

```
┌────────────────────────────────────────────────────────────┐
│  1. Fetch vault collateral amount                          │
│     └─ vaultNFT.collateralAmount(tokenId)                 │
│                                                            │
│  2. Query total collateral distribution                    │
│     └─ Index VaultMinted events or query all vaults       │
│                                                            │
│  3. Calculate percentile rank                              │
│     └─ percentile = ((total - rank) / total) × 100        │
│                                                            │
│  4. Map percentile to tier                                 │
│     └─ 99+ = Diamond, 90-99 = Platinum, etc.              │
│                                                            │
│  5. Apply visual enhancement to Treasure artwork           │
│     └─ Compose tier frame SVG around IPFS image           │
│     └─ See Visual_Assets_Guide.md Section 3.3             │
└────────────────────────────────────────────────────────────┘
```

For detailed percentile specification, see [Vault Percentile Specification](./Vault_Percentile_Specification.md).

### Metadata Service Requirements

The Custom API metadata service implements the rendering flow above:

| Responsibility | Implementation |
|----------------|----------------|
| **Indexing** | Subscribe to `VaultMinted` events, cache collateral amounts |
| **Percentile Calculation** | Rank vaults by collateral, compute percentile |
| **Frame Composition** | Apply tier frame SVG around Treasure image (IPFS) |
| **JSON Generation** | Return OpenSea-compatible metadata |

**API Response Pattern:**

```json
{
  "name": "Treasure #1234",
  "image": "[COMPOSED_IMAGE_URI]",
  "attributes": [
    { "trait_type": "Display Tier", "value": "Gold" },
    { "trait_type": "Percentile", "display_type": "number", "value": 82 }
  ]
}
```

> Full metadata schemas: [Visual_Assets_Guide.md](./Visual_Assets_Guide.md) Section 5

---

## 14. Analytics

### On-Chain Metrics

| Metric | Description | Query Method |
|--------|-------------|--------------|
| Total Collateral | BTC locked across all Vaults | `sum(collateralAmount)` per issuer |
| Vault Count | Total Vaults created | Count of `VaultMinted` events |
| Active Vaults | Vaults not redeemed | Total - redeemed |
| Matured Vaults | Vaults past vesting | Count where `now > mint + 1129 days` |

### Badge-Gated Metrics

| Metric | Description | Use Case |
|--------|-------------|----------|
| Collateral per badge type | BTC locked by entry badge | Identify high-value badges |
| Redemption rate | % badges redeemed | Assess badge utility |
| Vaults per participant | Stacking rate | Measure engagement depth |
| Achievement velocity | Achievement → Vault conversion | Track stacking behavior |

### Health Indicators

| Indicator | Healthy | Warning |
|-----------|---------|---------|
| Early redemption rate | < 10% | > 20% |
| Maturity completion rate | > 80% | < 60% |
| vestedBTC/BTC ratio | > 0.95 | < 0.90 |
| Active participation | Growing | Declining |

### Events for Indexing

```solidity
// Issuer-level events
event IssuerRegistered(address indexed issuer, uint256 timestamp);
event WindowCreated(uint256 indexed windowId, address indexed issuer, ...);
event WindowExecuted(uint256 indexed windowId, uint32 totalMinted);

// Badge redemption events
event BadgeRedeemed(
    address indexed redeemer,
    uint256 indexed badgeTokenId,
    uint256 indexed vaultTokenId,
    uint256 btcAmount,
    uint256 treasureTokenId
);
```

---

## Summary

| Aspect | Recommendation |
|--------|----------------|
| Entry | Start open, add badge-gating for premium |
| Revenue | Service-based, not extraction-based |
| Treasures | Limited editions with auction discovery |
| Achievements | Leverage protocol defaults, extend sparingly |
| Campaigns | Partner-sponsored for sustainable rewards |
| Gamification | Merit-first, vanity separate |
| Governance | Match to organizational structure |
| Analytics | Track health indicators, optimize |
| Bonding | Optional; deploy for POL accumulation if needed |
| IOL Bootstrap | Genesis program → Single-sided → Time-locked multipliers |

---

## Navigation

← [Issuer Layer](./README.md) | [Documentation Home](../README.md)
