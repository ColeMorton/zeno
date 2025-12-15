# BTCNFT Protocol DAO Design

> **Version:** 1.0
> **Status:** Draft
> **Last Updated:** 2025-12-12
> **Related Documents:**
> - [Product Specification](../protocol/Product_Specification.md)
> - [Technical Specification](../protocol/Technical_Specification.md)
> - [Collateral Matching](../protocol/Collateral_Matching.md)
> - [E2E Competitive Flow](./E2E_Competitive_Flow.md)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Core Philosophy](#2-core-philosophy)
3. [DAO Structure](#3-dao-structure)
4. [Bootstrapping Period](#4-bootstrapping-period)
5. [Achievement System](#5-achievement-system)
6. [Campaign System](#6-campaign-system)
7. [Child NFT Strategy](#7-child-nft-strategy)
8. [Gamification](#8-gamification)
9. [Contract Architecture](#9-contract-architecture)
10. [vBTC Economy](#10-stablebtc-economy)

---

## 1. Overview

### Problem

BTCNFT Protocol has passive incentives (collateral matching from early redemptions), but lacks **active demand drivers** for holding until maturity.

### Solution

A Protocol-Owned Liquidity (POL) DAO as the issuer that engineers utility through campaigns, achievements, and gamification - without pay-to-win mechanics.

```
┌─────────────────────────────────────────────────────────────────┐
│                       DAO VALUE LOOP                            │
│                                                                 │
│  vBTC Services ───► Treasury ───► LP Accumulation         │
│        │                   │                  │                 │
│        │                   │                  ↓                 │
│        │                   │         vBTC/USDC LP         │
│        │                   │                  │                 │
│        │                   ↓                  ↓                 │
│        │            Achievement         LP Fee Revenue         │
│        │              Rewards                 │                 │
│        │                   │                  │                 │
│        ↓                   ↓                  ↓                 │
│  User Engagement ◄──── Holder Retention ◄──── Deep Liquidity   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Core Philosophy

### Financial Expression vs Merit

| Principle | Implementation |
|-----------|----------------|
| **No pay-to-win** | Financial commitment = vanity display, not advantage |
| **Merit-based rewards** | Achievements tied to behavior/duration, not deposit size |
| **Equal opportunity** | 0.01 BTC holder has same achievement paths as 10 BTC holder |
| **Vanity as expression** | Larger deposits unlock cosmetics/titles, not better rates |

### No Fungible Token

| Decision | Rationale |
|----------|-----------|
| No governance token | Prevents governance attacks, value extraction |
| No withdrawal token | Avoids SEC securities classification |
| NFTs only | Utility-focused, non-speculative |

---

## 3. DAO Structure

### Revenue Sources (vBTC Economy)

```
┌─────────────────────────────────────────────────────────────────┐
│                       DAO TREASURY                               │
│                                                                 │
│  Revenue Sources (No Fungible Token):                           │
│  ├─ Premium Features (vBTC payments)                       │
│  ├─ Membership Tiers (vBTC subscriptions)                  │
│  ├─ Partner Integration Revenue (vBTC)                     │
│  ├─ vBTC/USDC LP Fees (protocol-owned)                     │
│  └─ Treasury vBTC Appreciation                             │
│                                                                 │
│  Revenue Uses:                                                  │
│  ├─ LP accumulation (gradual POL growth)                        │
│  ├─ Achievement rewards (non-financial)                         │
│  ├─ Campaign prizes (partner-sponsored)                         │
│  └─ Protocol development                                        │
└─────────────────────────────────────────────────────────────────┘
```

### Collateral Integrity

When Vault NFTs are minted:
- 100% of deposited BTC becomes user collateral
- DAO receives zero revenue from primary mints
- Auction proceeds (for limited editions) = user collateral

This ensures:
- No DAO extraction from user deposits
- Maximum collateral backing for vBTC
- Trust through alignment of incentives

### Early Redemption Forfeitures

Early redemption forfeitures flow **exclusively** to the collateral matching pool, not the DAO treasury. This ensures:
- Vested holders receive maximum match rewards
- DAO doesn't profit from user early exits
- Aligned incentives for long-term holding

### Governance: Multisig Council

```
┌─────────────────────────────────────────────────────────────────┐
│                    MULTISIG GOVERNANCE                          │
│                                                                 │
│  Structure: 3-of-5 or 5-of-7 signers                           │
│                                                                 │
│  Responsibilities:                                              │
│  ├─ Campaign launches and parameters                           │
│  ├─ Child NFT collection releases                              │
│  ├─ Bonding discount rates                                     │
│  ├─ Partner integrations                                       │
│  └─ Treasury management                                        │
│                                                                 │
│  Constraints (Immutable):                                       │
│  ├─ Cannot modify core BTCNFT Protocol contract                │
│  ├─ Cannot access user collateral                              │
│  ├─ Cannot change withdrawal rates                             │
│  └─ Cannot create fungible tokens                              │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. Bootstrapping Period

### The Chasm Problem

```
┌─────────────────────────────────────────────────────────────────┐
│                    BOOTSTRAPPING CHASM                          │
│                                                                 │
│  Day 0               Day 365            Day 730           Day 1093
│  │                   │                  │                 │
│  ▼                   ▼                  ▼                 ▼
│  ┌───────────────────────────────────────────────────────┐
│  │  NO MATURITIES = NO MATCH POOL = NO PROVEN PRODUCT    │
│  └───────────────────────────────────────────────────────┘
│                                                                 │
│  Challenge: Build confidence before anyone has vested           │
│  Solution: Multi-season engagement with on-chain achievements   │
└─────────────────────────────────────────────────────────────────┘
```

### Season Structure

| Season | Days | Name | Focus |
|--------|------|------|-------|
| 1 | 0-365 | "Genesis" | Early adopter recognition |
| 2 | 366-730 | "Conviction" | Retention and community building |
| 3 | 731-1093 | "Maturity" | Final stretch, first maturity event |
| 4+ | 1094+ | "Perpetual" | Sustainable growth, vBTC liquidity |

---

## 5. Achievement System

### Achievement NFTs as Treasures

**Key Insight:** Achievement NFTs serve dual purpose:
1. **Badge:** Visual proof of accomplishment
2. **Treasure:** Usable component when minting new Vault NFTs

```
┌─────────────────────────────────────────────────────────────────┐
│                ACHIEVEMENT → TREASURE COMPOSABILITY             │
│                                                                 │
│  Step 1: Earn Achievement                                       │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Complete "Diamond Hands" (730 days held)               │   │
│  │  → Mint Achievement NFT (ERC-721)                       │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          ↓                                      │
│  Step 2: Use as Treasure (Optional)                            │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  New mint: Achievement NFT + BTC → Vault NFT            │   │
│  │  Achievement becomes "soul" of new position             │   │
│  │  Visual: Vault NFT displays achievement art             │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Properties:                                                    │
│  ├─ Achievement NFTs are TRANSFERABLE (can be sold/gifted)    │
│  ├─ Once stored as Treasure, locked for 1093 days             │
│  ├─ Creates "provenance" - new position carries history       │
│  └─ Some achievements may be "soulbound" (non-transferable)   │
└─────────────────────────────────────────────────────────────────┘
```

### Achievement Classification

| Type | Transferable | Usable as Treasure | Rationale |
|------|--------------|-------------------|-----------|
| **Duration** (Diamond Hands, etc.) | Yes | Yes | Earned, tradeable merit |
| **Participation** (Genesis, Pioneer) | No (Soulbound) | No | Address-specific history |
| **Behavior** (Compounder, etc.) | Yes | Yes | Action-based, tradeable |
| **Campaign** (Partner rewards) | Varies | Varies | Partner-defined rules |

### Transferability and No-Pay-to-Win

**Design Trade-off:** Transferable achievements create a secondary market where users can purchase merit badges without earning them. This is an intentional design choice:

| Concern | Resolution |
|---------|------------|
| **Purchased achievements** | Achievements provide cosmetic value only - no rate/reward advantage |
| **Merit signal dilution** | On-chain provenance shows `originalEarner` vs current holder |
| **Treasure usage** | Using purchased achievement as Treasure is cosmetic expression, not advantage |

**Key Principle:** Achievements unlock **visual display** and **provenance**, not financial benefits. A purchased "Diamond Hands" badge:
- Does NOT provide better withdrawal rates
- Does NOT increase collateral matching allocation
- Does NOT grant priority access to features
- DOES display on profile (cosmetic)
- DOES show as `originalEarner ≠ currentHolder` (transparent)

**Why Allow Transferability?**
1. **Liquidity** - Earned achievements have value; markets enable price discovery
2. **Flexibility** - Users can exit achievement positions
3. **Composability** - Achievements as Child NFTs create interesting provenance chains
4. **Transparency** - All purchases visible on-chain via `originalEarner` field

**Soulbound Alternative:** Participation achievements (Genesis, Pioneer, Season Survivor) remain soulbound to preserve address-specific historical claims.

### Duration Achievements (Merit)

| Achievement | Requirement |
|-------------|-------------|
| "First Month" | Hold for 30 days |
| "Quarter Stack" | Hold for 91 days |
| "Half Year" | Hold for 182 days |
| "Annual" | Hold for 365 days |
| "Diamond Hands" | Hold for 730 days |
| "Hodler Supreme" | Hold for 1093 days (full vesting) |

### Behavior Achievements (Merit)

| Achievement | Requirement |
|-------------|-------------|
| "First Withdrawal" | Execute first post-vesting withdrawal |
| "Withdrawal Streak" | 3/6/12 consecutive monthly withdrawals |
| "Compounder" | Re-mint new NFT using withdrawal BTC |
| "LP Provider" | Provide vBTC/USDC liquidity |
| "Bonder" | Bond LP tokens to protocol |
| "Match Claimer" | Claim collateral matching at vesting |

### Participation Achievements (Soulbound)

| Achievement | Requirement |
|-------------|-------------|
| "Genesis" | Mint in first 30 days |
| "Pioneer 100" | Among first 100 minters |
| "Season X Survivor" | Hold through Season X |
| "Campaign Victor" | Complete a seasonal campaign |

### Vanity Tiers (Dynamic Percentiles)

| Tier | Percentile | Cosmetic |
|------|------------|----------|
| Bronze | 0-50th | Standard frame |
| Silver | 50-75th | Silver frame |
| Gold | 75-90th | Gold frame + title |
| Platinum | 90-99th | Platinum frame + animated |
| Diamond | 99-99.9th | Diamond frame + custom effects |
| Whale | 99.9th+ | Unique frame + leaderboard |

**Properties:**
- Tiers are relative to all active holders
- Position updates as collateral distribution changes
- Creates dynamic leaderboard competition
- **VISUAL ONLY** - no rate/reward advantage

---

## 6. Campaign System

### Milestone Campaigns

| Campaign | Trigger | Reward |
|----------|---------|--------|
| "100 BTC Locked" | totalActiveCollateral reaches 100 BTC | "Century Club" badge |
| "First Maturity" | First NFT completes 1093-day vesting | "Witness" badge |
| "Millionaire Pool" | matchPool reaches $1M USD equivalent | "Millionaire Witness" badge |

### Seasonal Competitions

| Campaign | Metric | Reward |
|----------|--------|--------|
| "Referral Race" (S1) | Referral code usage | "Top Referrer S1" badge |
| "Retention Royale" (S2) | Lowest % referrals that redeem early | "Quality Connector" badge |
| "Compound Championship" (S4+) | % withdrawals re-minted | "Master Compounder" badge |

### Partner Campaigns

```
┌─────────────────────────────────────────────────────────────────┐
│                    PARTNER CAMPAIGNS                            │
│                                                                 │
│  Example: "Aave Integration Launch"                            │
│  ├─ Sponsor: Aave DAO                                          │
│  ├─ Action: Deposit vBTC as collateral on Aave            │
│  ├─ Reward: AAVE token airdrop + "DeFi Pioneer" badge          │
│  └─ Duration: 30 days                                          │
│                                                                 │
│  Note: Partners sponsor rewards, DAO provides audience         │
└─────────────────────────────────────────────────────────────────┘
```

---

## 7. Treasure Strategy

### DAO as Treasure Issuer

| Collection | Price | Transferable | Rationale |
|------------|-------|--------------|-----------|
| Genesis | Auction → Collateral | Yes | Scarcity via limited supply |
| Seasonal | Auction/Fixed → Collateral | Yes | Edition-based scarcity |
| Achievement | Free (merit) | See classification | Earned through behavior |
| Partner | Partner-defined | Yes | Revenue share with DAO |

### Edition Releases

NFT collections can be released as limited editions:

| Release Type | Mechanism | Use Case |
|--------------|-----------|----------|
| Fixed Price | Set BTC price | Predictable, accessible |
| Auction | Ascending bid | Price discovery for rare editions |
| Dutch Auction | Descending price | Fair distribution, demand-based |

**Auction Properties:**
- Winning bid = collateral deposit (100% to user's position)
- Limited supply creates natural scarcity
- Edition numbers track provenance
- Burned editions reduce total supply permanently

### Early Redemption

When a Vault is redeemed early:
1. Linear unlock: `redeemable = collateral × (days_held / 1093)`
2. Forfeited collateral → Match Pool (exclusively)
3. **Treasure is permanently burned** (supply reduction)
4. Vault NFT is burned

**WARNING:** Early redemption destroys both the Vault NFT AND the stored Treasure permanently.

### Deflationary Mechanics

Early redemptions permanently destroy Treasures, creating:
- Natural supply reduction over time
- Increased scarcity of remaining editions
- Stronger penalty for early exit
- Long-term value accrual for holders

---

## 8. Gamification

### Leaderboards

| Leaderboard | Metric | Type |
|-------------|--------|------|
| "Longest Hold" | Days held | Merit |
| "Achievement Hunter" | Total achievements earned | Merit |
| "Whale Watch" | Total BTC collateral | Vanity (separate) |

**CRITICAL:** Merit and vanity leaderboards are SEPARATE.

### Profile System

```
┌─────────────────────────────────────────────────────────────────┐
│                    ON-CHAIN PROFILE                             │
│                                                                 │
│  Profile Data:                                                  │
│  ├─ Achievement badges (ERC-721 or Soulbound)                  │
│  ├─ Season participation history                               │
│  ├─ Total days held across all Vaults                          │
│  ├─ Vanity tier (cosmetic frame)                               │
│  └─ Campaign completions                                       │
│                                                                 │
│  Display:                                                       │
│  ├─ NFT art (Treasure)                                         │
│  ├─ Frame (Vanity tier)                                        │
│  ├─ Badges (earned achievements)                               │
│  └─ Title (selected from earned titles)                        │
│                                                                 │
│  Example: "Diamond Hands Pioneer" with Gold Frame              │
│  └─ Merit title + Vanity display (separate systems)            │
└─────────────────────────────────────────────────────────────────┘
```

---

## 9. Contract Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    CONTRACT ARCHITECTURE                        │
│                                                                 │
│  Core (Immutable):                                              │
│  ├─ BTCNFT Protocol Contract (Vault NFT, ERC-998)              │
│  │   └─ Accepts any ERC-721 as Treasure                        │
│  └─ Collateral Matching (matchPool, pro-rata claims)           │
│                                                                 │
│  DAO Contracts (Upgradeable via Multisig):                     │
│  ├─ Achievement NFT Contract (ERC-721)                         │
│  │   └─ Transferable achievements                              │
│  │   └─ Compatible as Treasure in core contract                │
│  ├─ Soulbound Badge Contract (ERC-5192)                        │
│  │   └─ Non-transferable participation badges                  │
│  ├─ Season Registry                                            │
│  │   └─ Campaign definitions, milestone tracking               │
│  ├─ Referral Registry                                          │
│  │   └─ Code → address mapping, referral counts                │
│  └─ Treasure Collections (per-season)                          │
│      └─ DAO-issued art NFTs for sale                           │
└─────────────────────────────────────────────────────────────────┘
```

### Achievement NFT Contract

```solidity
contract AchievementNFT is ERC721 {
    enum AchievementType { DURATION, BEHAVIOR, CAMPAIGN }

    struct Achievement {
        bytes32 achievementId;
        AchievementType aType;
        uint256 earnedTimestamp;
        address originalEarner;
    }

    mapping(uint256 => Achievement) public achievements;
    mapping(address => mapping(bytes32 => bool)) public hasEarned;

    function mint(address earner, bytes32 achievementId, AchievementType aType) external;
    function isChildCompatible(uint256 tokenId) external view returns (bool);
}
```

### Soulbound Badge Contract

```solidity
contract SoulboundBadge is ERC721, IERC5192 {
    function locked(uint256 tokenId) external view returns (bool) {
        return true;
    }
}
```

### Events

```solidity
event AchievementMinted(address indexed earner, bytes32 indexed achievementId, uint256 tokenId);
event AchievementUsedAsTreasure(uint256 indexed achievementTokenId, uint256 indexed vaultTokenId);
event SeasonStarted(uint256 indexed seasonId, uint256 startDay);
event MilestoneAchieved(bytes32 indexed milestoneId, uint256 timestamp);
event CampaignCompleted(address indexed user, bytes32 indexed campaignId);
event ReferralUsed(bytes32 indexed code, address indexed newMinter, address indexed referrer);
```

---

## 10. vBTC Economy

### Currency & Unit of Account

vBTC serves as the DAO's native currency:

| Function | Description |
|----------|-------------|
| Unit of Account | All DAO services priced in vBTC |
| Medium of Exchange | Payments within DAO ecosystem |
| Partner Currency | Accepted by integrated protocols |

### Demand Drivers

| Source | Description |
|--------|-------------|
| Premium Features | Digital and non-digital services (see below) |
| Membership Tiers | Subscription-based access levels |
| Partner Integrations | Third-party services accessed via vBTC |
| LP Trading Fees | vBTC/USDC pair transaction fees |

### Premium Features

Premium features include both digital and non-digital services:

| Category | Examples |
|----------|----------|
| **Digital** | Advanced analytics, priority access, enhanced gamification |
| **Support** | Technical support, dedicated account management |
| **Education** | Training, workshops, educational content |
| **Concierge** | White-glove experience, personalized onboarding |
| **Physical** | Non-digital services and products |

### Access Philosophy

**Principle:** Maximize access to features and products.

| Aspect | Design |
|--------|--------|
| Core functionality | **Free and unrestricted** |
| Paywall footprint | Minimal, barely noticeable |
| Discovery | Self-advertises through clear utility-expansion pathway |
| Gatekeeping | **None** on core protocol features |

The paywall exists to fund DAO operations while ensuring:
- All users can fully participate in the protocol
- Premium features provide genuine value expansion
- Upgrade paths are transparent and non-intrusive
- No artificial limitations on core functionality

### LP Bootstrapping

Liquidity builds gradually from vBTC service revenue:

```
┌─────────────────────────────────────────────────────────────────┐
│                    LP GROWTH PHASES                             │
│                                                                 │
│  Phase 1 (Early): Minimal LP, organic growth                   │
│        │          - Service revenue begins accumulating         │
│        │          - Low volume, price discovery                 │
│        ↓                                                        │
│  Phase 2 (Growth): Service revenue → LP accumulation           │
│        │          - Premium features drive vBTC demand     │
│        │          - Memberships create recurring revenue        │
│        ↓                                                        │
│  Phase 3 (Mature): Deep protocol-owned liquidity               │
│                   - Retained earnings fund LP                   │
│                   - Self-sustaining fee revenue                 │
└─────────────────────────────────────────────────────────────────┘
```

### Treasury Holdings

The DAO treasury accumulates vBTC, which:
- Represents claims on underlying BTC collateral
- Appreciates with BTC price movements
- Can be used for protocol operations
- Provides liquidity for vBTC markets

---

## Summary

| Aspect | Design |
|--------|--------|
| Token | **No fungible token** |
| Governance | Multisig council (3-of-5 or 5-of-7) |
| Revenue | vBTC services, LP fees (no NFT sales revenue) |
| Collateral | 100% of mints → user collateral |
| Forfeitures | Match Pool only (not treasury) |
| Merit | Time + behavior achievements (ERC-721) |
| Vanity | Percentile-based cosmetics (dynamic) |
| Pay-to-win | **Prohibited** |
| Achievements | Dual-purpose: Badge OR Treasure for new positions |
| Soulbound | Participation-only badges (non-transferable) |
| Early Redemption | Destroys both Vault NFT and Treasure |
| Editions | Auctions/Dutch auctions with limited supply |
| Bootstrapping | 3-season structure (Day 0-1093) |
| Post-bootstrap | POL for vBTC/USDC liquidity |
