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
10. [Bonding Integration (Optional)](#10-bonding-integration-optional)
11. [Liquidity Bootstrapping (IOL)](#11-liquidity-bootstrapping-iol)

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

### What Protocol Controls (Immutable - Code-Enforced)

These parameters are **technically impossible to change** after deployment. They are stored in contract bytecode, not modifiable storage.

| Aspect | Protocol Control | Modifiability |
|--------|------------------|---------------|
| Withdrawal rate | 10.5% annually (0.875% monthly) | **Immutable** (bytecode constant) |
| Vesting period | 1093 days | **Immutable** (bytecode constant) |
| Collateral matching | Pro-rata distribution from early exits | **Immutable** (no governance params) |
| Dormancy mechanism | 1093-day inactivity threshold | **Immutable** (bytecode constant) |
| vestedBTC mechanics | ERC-20, 1:1 with collateral | **Immutable** (contract logic) |

**Key Insight:** No admin, no DAO, no governance mechanism can alter these parameters. The functions to modify them do not exist in the contract.

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
│  Constraints (Code-Enforced - No Functions Exist):             │
│  ├─ Cannot modify core protocol (no setParameter functions)    │
│  ├─ Cannot access user collateral (no extraction function)     │
│  ├─ Cannot change withdrawal rates (immutable in bytecode)     │
│  └─ Cannot create fungible governance tokens (scope limited)   │
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

## 10. Bonding Integration (Optional)

> **Note**: Bonding is NOT part of the core protocol. This is an optional issuer-layer extension that requires deploying additional smart contracts.

### Overview

Bonding enables protocol-owned liquidity (POL) accumulation by allowing users to exchange LP tokens for discounted Vault NFTs.

### Mechanism

```
┌─────────────────────────────────────────────────────────────┐
│                      vBTC BONDING                           │
│                                                             │
│  Step 1: User Provides Liquidity                            │
│  └─ vBTC + WBTC → Curve → LP Tokens                        │
│                                                             │
│  Step 2: User Bonds LP                                      │
│  └─ Call bond(lpTokenAmount)                               │
│  └─ Issuer quotes: 5-15% discount, 5-7 day vesting         │
│                                                             │
│  Step 3: Issuer Receives LP                                 │
│  └─ LP tokens → Issuer Treasury                            │
│  └─ Issuer earns all trading fees                          │
│  └─ Liquidity is permanent (no mercenary flight)           │
│                                                             │
│  Step 4: User Receives Discounted Position                  │
│  └─ After vesting: Claim Vault NFT (pre-funded with BTC)   │
│  └─ Effective entry: 5-15% below market                    │
└─────────────────────────────────────────────────────────────┘
```

### Bond Pricing Parameters

| Parameter | Recommended Value | Rationale |
|-----------|-------------------|-----------|
| Discount Floor | 5% | Covers gas + vesting opportunity cost (~4% breakeven) |
| Discount Ceiling | 15% | Prevents dilutive acquisition; creates arbitrage ceiling |
| Vesting Period | 5-7 days | Prevents flash loan attacks; allows price discovery |
| Capacity | Treasury-limited | Prevents over-commitment |

### Oracle-Free Pricing Approaches

Bonding can operate without external price oracles using these approaches:

#### Option 1: Fixed Rate (Simplest)

```
1 LP token → Fixed BTC amount in Vault
```

| Pros | Cons |
|------|------|
| No price feed required | Doesn't adapt to market conditions |
| Simple implementation | Can become exploitable if market moves |
| Predictable for users | Requires manual rate updates |

#### Option 2: Capacity-Based Dynamic Pricing

```
discount = base_rate × (1 - utilization_ratio)

Where:
- base_rate = 15% (max discount)
- utilization_ratio = bonds_outstanding / max_capacity
```

| Utilization | Discount | Behavior |
|-------------|----------|----------|
| 0% (empty) | 15% | Attract bonders aggressively |
| 50% | 10% | Balanced pricing |
| 100% (full) | 5% | Ration access, preserve treasury |

**Tradeoff**: Pricing reflects demand, not market discount. If vBTC trades at 20% discount on DEX, capacity-based pricing won't capture this.

#### Option 3: Dutch Auction

```
discount starts at 15%
decreases by 0.5% per hour toward 5%
resets to 15% after each bond purchase
```

| Pros | Cons |
|------|------|
| Market finds equilibrium naturally | Inefficient; users may delay |
| No oracle dependency | Discount oscillates unpredictably |
| Self-correcting | Gaming possible (wait for reset) |

#### Option 4: DEX TWAP (Recommended for Market-Responsive Pricing)

TWAP (Time-Weighted Average Price) queries on-chain DEX data without external oracles.

**How It Works:**

```
┌─────────────────────────────────────────────────────────────┐
│                    TWAP PRICE ORACLE                        │
│                                                             │
│  Uniswap V3 / Curve Pool: vBTC/WBTC                        │
│                                                             │
│  1. Pool accumulates price observations over time           │
│  2. Bonding contract queries:                               │
│     - observe(secondsAgo: [3600, 0])  // 1-hour window     │
│  3. Calculate TWAP:                                         │
│     - TWAP = (cumulative[now] - cumulative[1hr]) / 3600    │
│  4. Derive discount:                                        │
│     - If TWAP shows vBTC at 0.92 WBTC (8% discount)        │
│     - Bond discount = min(TWAP_discount + 2%, 15%)         │
└─────────────────────────────────────────────────────────────┘
```

**Implementation (Uniswap V3):**

```solidity
// Query TWAP from Uniswap V3 pool
function getVBtcDiscount(address pool, uint32 twapWindow) external view returns (uint256) {
    uint32[] memory secondsAgos = new uint32[](2);
    secondsAgos[0] = twapWindow;  // e.g., 3600 (1 hour)
    secondsAgos[1] = 0;           // now

    (int56[] memory tickCumulatives, ) = IUniswapV3Pool(pool).observe(secondsAgos);

    int24 avgTick = int24((tickCumulatives[1] - tickCumulatives[0]) / int56(uint56(twapWindow)));
    uint256 price = getQuoteAtTick(avgTick, 1e8, vBTC, WBTC);

    // price < 1e8 means vBTC trades at discount
    // e.g., price = 0.92e8 → 8% discount
    return price < 1e8 ? ((1e8 - price) * 100) / 1e8 : 0;
}
```

**TWAP Window Considerations:**

| Window | Pros | Cons |
|--------|------|------|
| 5 min | Responsive to market | Vulnerable to manipulation |
| 1 hour | Balanced | Standard choice |
| 24 hours | Manipulation-resistant | Slow to react |

**Security: Manipulation Resistance**

| Attack Vector | Mitigation |
|---------------|------------|
| Flash loan price manipulation | TWAP averages across time; single-block manipulation ineffective |
| Multi-block manipulation | Longer windows (1hr+) make sustained manipulation expensive |
| Low liquidity exploitation | Require minimum pool liquidity before using TWAP |

**Discount Formula with TWAP:**

```
market_discount = TWAP query result (e.g., 8%)
bond_discount = min(market_discount + premium, 15%)

Where:
- premium = 2-5% (incentive to bond vs DEX purchase)
- ceiling = 15% (treasury protection)
```

| Market Discount | Premium | Bond Discount |
|-----------------|---------|---------------|
| 3% | +2% | 5% |
| 8% | +2% | 10% |
| 12% | +2% | 14% |
| 18% | +2% | 15% (capped) |

**Recommendation**: Use 1-hour TWAP with 2% premium. Require minimum 50 BTC equivalent pool liquidity.

#### Other Price Feed Options

| Approach | Use Case |
|----------|----------|
| **Chainlink** | If pricing against USD or external assets |
| **Custom oracle** | Aggregate multiple DEX prices |
| **Hybrid** | TWAP primary, Chainlink fallback |

### Implementation Requirements

Issuers must deploy:
1. **Bonding Contract** - Accepts LP tokens, manages vesting, distributes Vaults
2. **Treasury Contract** - Holds LP tokens, receives trading fees
3. **Price Oracle** (optional) - Dynamic discount based on capacity utilization

### Economic Considerations

| Factor | Consideration |
|--------|---------------|
| **Acquisition cost** | At 15% discount, paying 85 cents per $1 of permanent liquidity |
| **Fee generation** | LP trading fees accrue to treasury perpetually |
| **Liquidity depth** | Deeper pools reduce slippage for all participants |
| **Death spiral risk** | Bounded discounts prevent OHM-style reflexive selling |

### When to Implement Bonding

| Scenario | Recommendation |
|----------|----------------|
| Early stage, low liquidity | High priority - build POL foundation |
| Established liquidity | Lower priority - market makers sufficient |
| High vBTC discount (>10%) | Bonding attracts arbitrage, compresses discount |
| Treasury has excess BTC | Bonding converts BTC to permanent LP |

---

## 11. Liquidity Bootstrapping (IOL)

### The Cold Start Problem

vBTC utility depends on liquidity. Without it:

```
No liquidity → High slippage → Users won't mint vBTC
     ↑                                    │
     └────── No vBTC supply ←─────────────┘
```

Issuers must bootstrap Issuer-Owned Liquidity (IOL) to break this cycle.

### Strategy Options

#### Option 1: Genesis Vault Program

Limited "Genesis" status for early participants who commit to LP:

```
Genesis Vaults (first 100-500):
├─ Unique on-chain badge (soulbound)
├─ Enhanced benefits (issuer-defined)
├─ Requires: LP commitment for 6+ months
└─ Creates: Urgency, exclusivity, aligned behavior
```

| Pros | Cons |
|------|------|
| Creates FOMO/urgency | Limited to early participants |
| Strong narrative ("Genesis holder") | May create two-tier perception |
| No capital required from issuer | Complex eligibility tracking |

#### Option 2: Single-Sided Liquidity

Users deposit only vBTC; issuer provides WBTC side:

```
User deposits:   100% vBTC
Issuer deposits: 100% WBTC (from treasury)
Pool:            Balancer 80/20 or Curve V2
```

| Pros | Cons |
|------|------|
| Zero WBTC required from users | Issuer bears IL on WBTC side |
| Lowest barrier to entry | Requires significant treasury |
| Familiar to yield farmers | Weighted pools have higher slippage |

#### Option 3: Time-Locked LP Multipliers

Reward longer LP commitments with enhanced benefits:

```
LP Lock Duration → Benefit Multiplier
├─ No lock:    1.0x (baseline)
├─ 6 months:   1.5x
├─ 12 months:  2.0x
└─ 24 months:  3.0x

Benefits can include:
- Fee share boost
- Governance weight
- Priority access to future features
```

| Pros | Cons |
|------|------|
| Creates sticky, long-term liquidity | Locks reduce user flexibility |
| Predictable liquidity depth | Unlock cliffs can cause volatility |
| No issuer capital required | Complex contract logic |

#### Option 4: Liquidity Bootstrapping Pool (LBP)

Balancer-style weight-shifting pool for price discovery:

```
Day 0: 95% vBTC / 5% WBTC  → High vBTC price
Day 3: 50% vBTC / 50% WBTC → Fair market price

Weights shift continuously; market discovers fair value
```

| Pros | Cons |
|------|------|
| Built-in price discovery | Temporary (not permanent liquidity) |
| No need to guess initial price | Requires active management |
| Early participants get discount | Users may wait for "bottom" |

### Strategy Comparison

| Strategy | Capital Required | Complexity | Stickiness | Best For |
|----------|-----------------|------------|------------|----------|
| Genesis Program | None | Low | Very High | Community building |
| Single-Sided | High | Low | Medium | Fast bootstrap |
| Time-Locked | None | Medium | Very High | Long-term depth |
| LBP | Medium | Medium | Low | Price discovery |

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
