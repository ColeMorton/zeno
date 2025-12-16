# BTCNFT Protocol Issuer Guide

> **Version:** 1.0
> **Status:** Draft
> **Last Updated:** 2025-12-16
> **Related Documents:**
> - [Issuer Integration](../protocol/Issuer_Integration.md)
> - [Technical Specification](../protocol/Technical_Specification.md)
> - [Holder Experience](./Holder_Experience.md)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Entry Strategies](#2-entry-strategies)
3. [Revenue Models](#3-revenue-models)
4. [Treasure Strategy](#4-treasure-strategy)
5. [Achievement Integration](#5-achievement-integration)
6. [Campaign System](#6-campaign-system)
7. [Gamification](#7-gamification)
8. [Governance Options](#8-governance-options)
9. [Analytics](#9-analytics)

---

## 1. Overview

### What Issuers Control

Issuers customize the participant experience without modifying core protocol parameters:

| Aspect | Issuer Control |
|--------|----------------|
| Entry requirements | Open vs badge-gated |
| Treasure design | Art, metadata, editions |
| Minting windows | Timing, campaigns |
| Achievement extensions | Custom achievements beyond protocol defaults |
| Gamification | Leaderboards, vanity tiers, profiles |
| Governance | Multisig, DAO, or centralized |

### What Protocol Controls

| Aspect | Protocol Control |
|--------|------------------|
| Withdrawal rate | Fixed at 10.5% annually (0.875% monthly) |
| Vesting period | Fixed at 1093 days |
| Collateral matching | Pro-rata distribution from early exits |
| Dormancy mechanism | 1093-day inactivity threshold |
| vestedBTC mechanics | ERC-20, 1:1 with collateral |

---

## 2. Entry Strategies

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

### Badge Types

| Badge Type | Purpose | Transferable |
|------------|---------|--------------|
| Entry Badge | Gates initial Vault | No (soulbound) |
| Achievement | Enables Vault stacking | Yes (most) |
| Participation | Historical recognition | No (soulbound) |
| Campaign | Time-limited rewards | Varies |

---

## 3. Revenue Models

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

### Service Examples

| Category | Examples |
|----------|----------|
| Digital | Analytics dashboards, priority access, enhanced gamification |
| Support | Technical support, dedicated account management |
| Education | Training, workshops, content |
| Concierge | White-glove experience, personalized onboarding |

### Access Philosophy

**Principle:** Maximize access to core features.

| Aspect | Design |
|--------|--------|
| Core functionality | Free and unrestricted |
| Paywall footprint | Minimal |
| Upgrade paths | Transparent and non-intrusive |
| Gatekeeping | None on protocol features |

---

## 4. Treasure Strategy

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

## 5. Achievement Integration

### Protocol Achievements

The protocol provides standard achievement types:

**Duration Achievements (Merit):**

| Achievement | Requirement |
|-------------|-------------|
| First Month | Hold for 30 days |
| Quarter Stack | Hold for 91 days |
| Half Year | Hold for 182 days |
| Annual | Hold for 365 days |
| Diamond Hands | Hold for 730 days |
| Hodler Supreme | Hold for 1093 days |

**Behavior Achievements (Merit):**

| Achievement | Requirement |
|-------------|-------------|
| First Withdrawal | Execute first post-vesting withdrawal |
| Withdrawal Streak | 3/6/12 consecutive monthly withdrawals |
| Compounder | Re-mint new Vault using withdrawal BTC |
| LP Provider | Provide vestedBTC liquidity |
| Match Claimer | Claim collateral matching at vesting |

**Participation Achievements (Soulbound):**

| Achievement | Requirement |
|-------------|-------------|
| Genesis | Mint in first 30 days |
| Pioneer 100 | Among first 100 minters |
| Season Survivor | Hold through a complete season |

### Achievement as Treasure

Achievements serve dual purpose:
1. **Badge:** Visual proof of accomplishment
2. **Treasure:** Usable when minting new Vaults

```
Achievement NFT → Use as Treasure → New Vault NFT
                  (Achievement locked for 1093 days)
```

### Transferability Design

| Type | Transferable | Rationale |
|------|--------------|-----------|
| Duration | Yes | Earned merit, tradeable |
| Behavior | Yes | Action-based, tradeable |
| Participation | No (Soulbound) | Address-specific history |
| Campaign | Varies | Partner-defined rules |

**No-Pay-to-Win Principle:**

Purchased achievements provide cosmetic value only:
- No better withdrawal rates
- No increased collateral matching
- No priority access
- Transparent on-chain provenance (`originalEarner ≠ currentHolder`)

---

## 6. Campaign System

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
┌─────────────────────────────────────────────────────────────────┐
│                    PARTNER CAMPAIGNS                            │
│                                                                 │
│  Example: "DeFi Integration Launch"                            │
│  ├─ Sponsor: Partner Protocol                                  │
│  ├─ Action: Use vestedBTC in partner protocol                  │
│  ├─ Reward: Token airdrop + "DeFi Pioneer" badge               │
│  └─ Duration: Time-limited                                     │
│                                                                 │
│  Structure: Partners sponsor rewards, issuer provides audience │
└─────────────────────────────────────────────────────────────────┘
```

---

## 7. Gamification

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
- Position updates as collateral distribution changes
- **VISUAL ONLY** - no rate/reward advantage

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
└─────────────────────────────────────────────────────────────────┘
```

---

## 8. Governance Options

### Multisig Council

```
┌─────────────────────────────────────────────────────────────────┐
│                    MULTISIG GOVERNANCE                          │
│                                                                 │
│  Structure: 3-of-5 or 5-of-7 signers                           │
│                                                                 │
│  Responsibilities:                                              │
│  ├─ Campaign launches and parameters                           │
│  ├─ Treasure collection releases                               │
│  ├─ Partner integrations                                       │
│  ├─ Treasury management                                        │
│  └─ Gamification updates                                       │
│                                                                 │
│  Constraints (Immutable):                                       │
│  ├─ Cannot modify core protocol contract                       │
│  ├─ Cannot access user collateral                              │
│  ├─ Cannot change withdrawal rates                             │
│  └─ Cannot create fungible governance tokens                   │
└─────────────────────────────────────────────────────────────────┘
```

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

## 9. Analytics

### On-Chain Metrics

| Metric | Description | Query Method |
|--------|-------------|--------------|
| Total Collateral | BTC locked across all Vaults | Sum of `collateralAmount` |
| Vault Count | Total Vaults created | Count of mint events |
| Active Vaults | Vaults not redeemed | Total - redeemed |
| Matured Vaults | Vaults past vesting | Count where `now > mint + 1093 days` |
| Average Collateral | BTC per Vault | Total / Vault count |

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
