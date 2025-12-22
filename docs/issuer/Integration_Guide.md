# BTCNFT Protocol Integration Guide

> **Version:** 1.0
> **Status:** Draft
> **Last Updated:** 2025-12-21
> **Related Documents:**
> - [Technical Specification](../protocol/Technical_Specification.md)
> - [Product Specification](../protocol/Product_Specification.md)
> - [Holder Experience](./Holder_Experience.md)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Issuer Registration](#2-issuer-registration)
3. [Entry Strategies](#3-entry-strategies)
4. [Minting Modes](#4-minting-modes)
5. [Badge-Gated Minting](#5-badge-gated-minting)
6. [Redemption Controller](#6-redemption-controller)
7. [Treasure Strategy](#7-treasure-strategy)
8. [Achievement Integration](#8-achievement-integration)
9. [Campaign System](#9-campaign-system)
10. [Gamification](#10-gamification)
11. [Governance Options](#11-governance-options)
12. [Revenue Models](#12-revenue-models)
13. [Capital Flow Architecture](#13-capital-flow-architecture)
14. [Bonding Integration](#14-bonding-integration)
15. [Liquidity Bootstrapping](#15-liquidity-bootstrapping)
16. [Analytics](#16-analytics)

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
| Withdrawal rate | - | 10.5% annually (0.875% monthly) |
| Vesting period | - | 1093 days |
| Collateral matching | - | Pro-rata distribution |
| Dormancy mechanism | - | 1093-day inactivity threshold |
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
1. Issuer calls `createDutchAuction(maxSupply, collateralToken, tier, config)`
2. Price decays from `startPrice` to `floorPrice` based on `decayRate`
3. Users call `purchaseDutch(auctionId)` at any time to purchase at current price
4. Payment becomes collateral for the minted Vault

#### English Auction

Ascending bid auction for slots:

```
Issuer creates auction → Users bid on slots → Highest bids win → Settlement creates Vault NFTs
```

**Flow:**
1. Issuer calls `createEnglishAuction(maxSupply, collateralToken, tier, config)`
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

## 5. Achievement-Based Recognition

### Achievement System Overview

The protocol is **open** - anyone can mint Vaults directly. Achievements are **post-hoc recognition** for on-chain actions, not access gates.

| Property | Value |
|----------|-------|
| Standard | ERC-5192 (Soulbound) |
| Transferable | No |
| Purpose | Recognize and attest wallet actions |
| Claiming | User-initiated, contract verifies state |

### Achievement Types

| Achievement | Criteria | Claiming Function |
|-------------|----------|-------------------|
| MINTER | Owns vault with issuer's Treasure | `claimMinterAchievement(vaultId)` |
| MATURED | MINTER + vault vested + match claimed | `claimMaturedAchievement(vaultId)` |
| HODLER_SUPREME | MINTER + MATURED (composite) | `mintHodlerSupremeVault(...)` |
| FIRST_MONTH | Hold vault 30+ days | `claimDurationAchievement(vaultId, type)` |
| QUARTER_STACK | Hold vault 91+ days | `claimDurationAchievement(vaultId, type)` |
| HALF_YEAR | Hold vault 182+ days | `claimDurationAchievement(vaultId, type)` |
| ANNUAL | Hold vault 365+ days | `claimDurationAchievement(vaultId, type)` |
| DIAMOND_HANDS | Hold vault 730+ days | `claimDurationAchievement(vaultId, type)` |

### Achievement Flow

```
1. User mints Vault on PROTOCOL with issuer's TreasureNFT
   └─ No achievement yet (just protocol action)

2. User calls ISSUER claimMinterAchievement(vaultId)
   ├─ Contract verifies: vault uses issuer's Treasure
   ├─ Contract verifies: caller owns the vault
   └─ Mints "MINTER" soulbound to wallet

3. User holds vault, claims duration achievements as milestones pass
   └─ claimDurationAchievement(vaultId, FIRST_MONTH) after 30 days
   └─ claimDurationAchievement(vaultId, QUARTER_STACK) after 91 days
   └─ ... and so on

4. After vesting (1093 days), user claims MATURED
   ├─ Contract verifies: wallet has MINTER
   ├─ Contract verifies: vault.isVested() && vault.matchClaimed
   └─ Mints "MATURED" soulbound to wallet

5. User calls mintHodlerSupremeVault() for composite reward
   ├─ Contract verifies: has MINTER AND MATURED
   ├─ Mints "HODLER_SUPREME" soulbound + Treasure + Vault
   └─ All atomic in single transaction
```

### Vault Stacking Flywheel

```
┌─────────────────────────────────────────────────────────────────┐
│                    VAULT STACKING FLYWHEEL                      │
│                                                                 │
│  ┌──────────┐   ┌─────────────┐   ┌─────────────┐               │
│  │ Mint     │──▶│ Vault #1    │──▶│ Claim       │               │
│  │ Vault    │   │ + Treasure  │   │ Achievements│               │
│  └──────────┘   └─────────────┘   └──────┬──────┘               │
│       ▲                                  │                      │
│       │                                  ▼                      │
│       │         ┌─────────────────────────────────┐             │
│       └─────────│ mintHodlerSupremeVault()        │             │
│                 │ → Requires MINTER + MATURED     │             │
│                 │ → Mints new Vault atomically    │             │
│                 └─────────────────────────────────┘             │
│                                                                 │
│  Growth Mechanics:                                              │
│  ├─ Each Vault generates achievements over time                │
│  ├─ Achievements unlock composite minting opportunities        │
│  └─ Compounding: more time = more achievements = more Vaults   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 6. Achievement Minter

### Purpose

The AchievementMinter enables achievement claiming and composite vault minting:

```
Verify on-chain state → Mint soulbound achievement
MINTER + MATURED achievements → mintHodlerSupremeVault() → New Vault
```

### Minter Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      AchievementMinter                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Immutable State:                                               │
│  ├─ achievements: IAchievementNFT (soulbound achievements)     │
│  ├─ treasureNFT: ITreasureNFT (issuer's treasure)              │
│  └─ protocol: IVaultState (BTCNFT Protocol)                    │
│                                                                 │
│  Achievement Claiming:                                          │
│  ├─ claimMinterAchievement(vaultId)                            │
│  │   └─ Verify: caller owns vault + vault uses issuer treasure │
│  ├─ claimMaturedAchievement(vaultId)                           │
│  │   └─ Verify: has MINTER + vault vested + match claimed      │
│  ├─ claimDurationAchievement(vaultId, achievementType)         │
│  │   └─ Verify: vault age >= duration threshold                │
│  └─ mintHodlerSupremeVault(collateralToken, amount, tier)      │
│       └─ Verify: has MINTER + MATURED → mint vault atomically  │
│                                                                 │
│  Duration Thresholds:                                           │
│  ├─ FIRST_MONTH: 30 days                                       │
│  ├─ QUARTER_STACK: 91 days                                     │
│  ├─ HALF_YEAR: 182 days                                        │
│  ├─ ANNUAL: 365 days                                           │
│  └─ DIAMOND_HANDS: 730 days                                    │
└─────────────────────────────────────────────────────────────────┘
```

### Minter Interface

```solidity
interface IAchievementMinter {
    // Achievement claiming
    function claimMinterAchievement(uint256 vaultId) external;
    function claimMaturedAchievement(uint256 vaultId) external;
    function claimDurationAchievement(uint256 vaultId, bytes32 achievementType) external;

    // Composite vault minting
    function mintHodlerSupremeVault(
        address collateralToken,
        uint256 collateralAmount,
        uint8 tier
    ) external returns (uint256 vaultId);

    // View functions
    function canClaimMinterAchievement(address wallet, uint256 vaultId)
        external view returns (bool canClaim, string memory reason);
    function canClaimMaturedAchievement(address wallet, uint256 vaultId)
        external view returns (bool canClaim, string memory reason);
    function canClaimDurationAchievement(address wallet, uint256 vaultId, bytes32 achievementType)
        external view returns (bool canClaim, string memory reason);
    function canMintHodlerSupremeVault(address wallet)
        external view returns (bool canMint, string memory reason);

    // Duration helpers
    function isDurationAchievement(bytes32 achievementType) external view returns (bool);
    function getDurationThreshold(bytes32 achievementType) external view returns (uint256);
}
```

---

## 7. Treasure Strategy

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

## 8. Achievement Integration

### Implemented Achievements

The AchievementMinter contract implements these achievement types:

**Core Achievements:**

| Achievement | Requirement | Function |
|-------------|-------------|----------|
| MINTER | Own vault with issuer's Treasure | `claimMinterAchievement(vaultId)` |
| MATURED | MINTER + vault vested + match claimed | `claimMaturedAchievement(vaultId)` |
| HODLER_SUPREME | MINTER + MATURED | `mintHodlerSupremeVault(...)` |

**Duration Achievements:**

| Achievement | Duration | Function |
|-------------|----------|----------|
| FIRST_MONTH | 30 days | `claimDurationAchievement(vaultId, FIRST_MONTH)` |
| QUARTER_STACK | 91 days | `claimDurationAchievement(vaultId, QUARTER_STACK)` |
| HALF_YEAR | 182 days | `claimDurationAchievement(vaultId, HALF_YEAR)` |
| ANNUAL | 365 days | `claimDurationAchievement(vaultId, ANNUAL)` |
| DIAMOND_HANDS | 730 days | `claimDurationAchievement(vaultId, DIAMOND_HANDS)` |

### Future Achievement Types (Not Yet Implemented)

The following are conceptual achievement types that could be added:

**Behavior Achievements (Future):**

| Achievement | Requirement |
|-------------|-------------|
| First Withdrawal | Execute first post-vesting withdrawal |
| Withdrawal Streak | 3/6/12 consecutive monthly withdrawals |
| Compounder | Re-mint new Vault using withdrawal BTC |
| LP Provider | Provide vestedBTC liquidity |
| Match Claimer | Claim collateral matching at vesting |

**Participation Achievements (Future):**

| Achievement | Requirement |
|-------------|-------------|
| Genesis | Mint in first 30 days |
| Pioneer 100 | Among first 100 minters |
| Season Survivor | Hold through a complete season |

> **Note:** The bytes32-based achievement system supports adding new achievement types without contract redeployment. Issuers can extend with custom achievements.

### Soulbound Properties

All achievements are ERC-5192 soulbound (non-transferable):
- Permanently attest wallet actions
- Cannot be sold or transferred
- One per wallet per achievement type
- Verified against on-chain protocol state

### No-Pay-to-Win Principle

Achievements are merit-based:
- No better withdrawal rates
- No increased collateral matching
- No priority access
- All achievements verified against on-chain state

---

## 9. Campaign System

### Milestone Campaigns

| Campaign | Trigger | Reward |
|----------|---------|--------|
| TVL Milestone | Total collateral reaches target | Commemorative badge |
| First Maturity | First Vault completes vesting | "Witness" badge |
| Pool Milestone | Match pool reaches target | "Witness" badge |

### Seasonal Competitions

| Campaign | Metric | Reward |
|----------|--------|--------|
| Referral Race | Referral code usage | "Top Referrer" badge |
| Retention Royale | Lowest % referrals that redeem early | "Quality Connector" badge |
| Compound Championship | % withdrawals re-minted | "Master Compounder" badge |

### Partner Campaigns

```
Example: "DeFi Integration Launch"
├─ Sponsor: Partner Protocol
├─ Action: Use vestedBTC in partner protocol
├─ Reward: Token airdrop + "DeFi Pioneer" badge
└─ Duration: Time-limited

Structure: Partners sponsor rewards, issuer provides audience
```

---

## 10. Gamification

### Season Structure

| Season | Days | Focus |
|--------|------|-------|
| 1 (Genesis) | 0-365 | Early adopter recognition |
| 2 (Conviction) | 366-730 | Retention and community building |
| 3 (Maturity) | 731-1093 | First maturity events |
| 4+ (Perpetual) | 1094+ | Sustainable growth |

### Leaderboards

| Leaderboard | Metric | Type |
|-------------|--------|------|
| Longest Hold | Days held | Merit |
| Achievement Hunter | Total achievements earned | Merit |
| Whale Watch | Total BTC collateral | Vanity (separate) |

**Critical:** Merit and vanity leaderboards must be SEPARATE.

### Vanity Tiers (Dynamic Percentiles)

| Tier | Percentile | Cosmetic |
|------|------------|----------|
| Bronze | 0-50th | Standard frame |
| Silver | 50-75th | Silver frame |
| Gold | 75-90th | Gold frame + title |
| Platinum | 90-99th | Platinum frame + animated |
| Diamond | 99-99.9th | Diamond frame + effects |
| Whale | 99.9th+ | Unique frame + leaderboard |

**Properties:**
- Tiers are relative to all active holders
- **VISUAL ONLY** - no rate/reward advantage

---

## 11. Governance Options

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

## 12. Revenue Models

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

## 13. Capital Flow Architecture

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

## 14. Bonding Integration

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

## 15. Liquidity Bootstrapping

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

## 16. Analytics

### On-Chain Metrics

| Metric | Description | Query Method |
|--------|-------------|--------------|
| Total Collateral | BTC locked across all Vaults | `sum(collateralAmount)` per issuer |
| Vault Count | Total Vaults created | Count of `VaultMinted` events |
| Active Vaults | Vaults not redeemed | Total - redeemed |
| Matured Vaults | Vaults past vesting | Count where `now > mint + 1093 days` |

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
