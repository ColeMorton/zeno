# BTCNFT Protocol Product Specification

> **Version:** 1.5
> **Status:** Draft
> **Last Updated:** 2025-12-12
> **Related Documents:**
> - [Technical Specification](./Technical_Specification.md)
> - [Quantitative Validation](./Quantitative_Validation.md)
> - [Market Analysis](../issuer/Market_Analysis.md)

---

## Table of Contents

1. [Overview](#1-overview)
   - 1.1 [Purpose](#11-purpose)
   - 1.2 [Mechanism Summary](#12-mechanism-summary)
   - 1.3 [Token Standard](#13-token-standard)
2. [Withdrawal Tiers](#2-withdrawal-tiers)
   - 2.1 [Tier Definitions](#21-tier-definitions)
   - 2.2 [Stability Coverage](#22-stability-coverage)
   - 2.3 [Tier Selection](#23-tier-selection)
3. [vBTC Product](#3-stablebtc-product)
   - 3.1 [Product Definition](#31-product-definition)
   - 3.2 [Value Proposition](#32-value-proposition)
4. [Dormant NFT Recovery](#4-dormant-nft-recovery)
   - 4.1 [Problem Statement](#41-problem-statement)
   - 4.2 [Recovery Mechanism](#42-recovery-mechanism)
   - 4.3 [Outcomes](#43-outcomes)
   - 4.4 [Economic Fairness](#44-economic-fairness)
5. [Design Decisions](#5-design-decisions)

---

## 1. Overview

### 1.1 Purpose

BTCNFT Protocol provides perpetual withdrawals through percentage-based collateral access, designed to maintain USD-denominated value stability based on historical Bitcoin performance.

### 1.2 Mechanism Summary

| Phase | Action |
|-------|--------|
| **Mint** | Vault your Treasure NFT + BTC → Receive Vault NFT |
| **Vesting** | 1093-day lock (no withdrawals) |
| **Post-Vesting** | Withdraw X% of remaining BTC per 30-day period |
| **Perpetual** | Percentage-based withdrawal ensures collateral never depletes |

### 1.3 Token Standard

Implements **ERC-998 Composable Non-Fungible Token** standard:

| Component | Standard | Description |
|-----------|----------|-------------|
| Vault NFT | ERC-998 | Composable token holding stored assets |
| Treasure NFT | ERC-721 | Any compatible NFT (art, PFP, membership, etc.) |
| BTC Collateral | ERC-20 | WBTC or cbBTC |

**Composition Structure:**
```
┌─────────────────────────────────────┐
│  Vault NFT (ERC-998 Composable)     │
│  ┌───────────────┬────────────────┐ │
│  │   Treasure    │  BTC Collateral│ │
│  │   (ERC-721)   │  (ERC-20)      │ │
│  └───────────────┴────────────────┘ │
└─────────────────────────────────────┘
```

---

## 2. Withdrawal Tiers

### 2.1 Tier Definitions

| Tier | Monthly Rate | Annual Rate |
|------|--------------|-------------|
| **Conservative** | 0.833% | 10.5% |
| **Balanced** | 1.14% | 14.6% |
| **Aggressive** | 1.59% | 20.8% |

### 2.2 Historical Stability Coverage

Percentage of historical periods (2017-2025) where USD value would NOT decline:

| Tier | Monthly | Yearly | 1093-Day |
|------|---------|--------|----------|
| **Conservative** | 92% | **100%** | **100%** |
| **Balanced** | 86% | **100%** | **100%** |
| **Aggressive** | 78% | 74% | **100%** |

> **Note:** Past performance does not guarantee future results. These figures are based on historical BTC price data from 2017-2025.

### 2.3 Tier Selection

| Tier | Best Stability Window | Coverage |
|------|----------------------|----------|
| **Conservative** | Yearly | 100% |
| **Balanced** | Yearly | 100% |
| **Aggressive** | 1093-Day | 100% |

---

## 3. vBTC Product

### 3.1 Product Definition

**vBTC** is the branded name for btcToken derived from **Conservative-tier** Parent NFTs.

| Property | vBTC |
|----------|-----------|
| Source | btcToken from Conservative-tier (0.833%/mo) Parent NFT |
| Withdrawal rate | -10.5% annually |
| Historical BTC appreciation | +63.11% annually (mean, 2017-2025) |
| Net expected return | ~+52% annually |
| Historical stability | **100%** yearly, **100%** 1093-day (2017-2025 data) |

> **Note:** vBTC is BTC-denominated (not pegged to USD). "Stability" refers to historical patterns, not a forward-looking guarantee.

### 3.2 Value Proposition

vBTC offers a unique position in the market:
- **BTC upside exposure** with USD-denominated stability floor
- **No liquidation risk** (unlike CDP-based stablecoins)
- **No peg maintenance** required (not pegged to $1)
- **Backed by actual BTC** (not algorithmic)
- **DeFi-native** (ERC-20, tradeable on DEXs)
- **Non-custodial** - user retains control via NFT ownership

---

## 4. Dormant NFT Recovery

### 4.1 Problem Statement

When a Vault holder separates their collateral into vBTC and later sells or loses access to that vBTC, the underlying BTC can become permanently inaccessible:

- **Vault holder**: Cannot redeem (lacks vBTC requirement)
- **vBTC holder**: Cannot recombine (lacks the Vault)

If the Vault holder becomes inactive, this creates "zombie" positions where valuable BTC collateral is permanently locked.

### 4.2 Recovery Mechanism

The dormant claim mechanism allows vBTC holders to recover abandoned positions:

**Dormancy Criteria:**
| Condition | Requirement |
|-----------|-------------|
| vBTC separated | btcToken must exist for the Vault |
| vBTC not at owner | Owner no longer holds sufficient vBTC |
| Extended inactivity | No activity for 1093+ days |

**Recovery Flow:**
```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Vault becomes  │────►│  Anyone can     │────►│  30-day grace   │
│  dormant-       │     │  "poke" the     │     │  period for     │
│  eligible       │     │  Vault          │     │  owner response │
└─────────────────┘     └─────────────────┘     └────────┬────────┘
                                                         │
                              ┌───────────────────────────┼───────────────────────────┐
                              │                           │                           │
                              ▼                           ▼                           ▼
                    ┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
                    │  Owner proves   │       │  Grace expires  │       │  vBTC holder    │
                    │  activity       │       │                 │       │  claims         │
                    │  → Back to      │       │  → Vault        │       │  → Collateral   │
                    │    ACTIVE       │       │    CLAIMABLE    │       │    to claimer   │
                    └─────────────────┘       └─────────────────┘       └─────────────────┘
```

### 4.3 Outcomes

When dormant collateral is claimed:

| Party | Receives | Loses |
|-------|----------|-------|
| **Claimer** | BTC collateral (remaining amount) | vBTC (burned) |
| **Original Owner** | Treasure (returned) | Collateral |
| **Vault NFT** | N/A (burned - empty shell) | N/A |
| **vBTC** | N/A (permanently burned) | Supply reduced |

**Note:** The Vault NFT is burned because after Treasure extraction and collateral transfer, it has no remaining value.

### 4.4 Economic Fairness

The mechanism ensures fair treatment for all parties:

**For Original Owner:**
- Receives Treasure back (original property, unrelated to BTC collateral)
- Already received value when selling vBTC
- Had 1093+ days of inactivity + 30-day warning to respond

**For Claimer:**
- Burns vBTC equal to original minted amount
- Receives BTC collateral directly
- Economically equivalent to normal recombination (vBTC → BTC)

**For Protocol:**
- Reduces "zombie" positions
- vBTC burn is deflationary (reduces supply)
- Maintains economic integrity of the system

---

## 5. Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Token standard | ERC-998 Composable | Enables NFT + ERC-20 bundling |
| Treasure NFT | Required at mint | Provides identity/art to backing |
| Treasure on early redemption | Burned with Vault NFT | Commitment mechanism; disincentivizes early exit |
| BTC collateral | WBTC or cbBTC | Widely available wrapped BTC |
| Withdrawal rate | Fixed at mint | Predictability for holder |
| Vesting period | 1093 days | Full BTC market cycle coverage |
| vBTC branding | Conservative-tier btcToken | Clear market positioning vs. STRC/SATA |
| Dormancy threshold | 1093 days | Matches vesting period; full inactivity cycle |
| Grace period | 30 days | Fair warning; one withdrawal period |
| Treasure on claim | Returned to original owner | Preserves original property rights |
| Collateral on claim | Transferred to claimer | Claimer receives BTC directly |
| Vault NFT on claim | Burned | Empty shell after extraction - no value |
| vBTC on claim | Burned | Economic equivalence with recombination |
