# BTCNFT Protocol Product Specification

> **Version:** 2.1
> **Status:** Draft
> **Last Updated:** 2025-12-19
> **Related Documents:**
> - [Technical Specification](./Technical_Specification.md)
> - [Quantitative Validation](./Quantitative_Validation.md)
> - [Market Analysis](../issuer/Market_Analysis.md)
> - [Withdrawal Delegation](./Withdrawal_Delegation.md)

---

## Table of Contents

1. [Overview](#1-overview)
   - 1.1 [Purpose](#11-purpose)
   - 1.2 [Mechanism Summary](#12-mechanism-summary)
   - 1.3 [Token Standard](#13-token-standard)
   - 1.4 [Minting Windows](#14-minting-windows)
   - 1.5 [Non-Custodial Guarantee](#15-non-custodial-guarantee)
   - 1.6 [Withdrawal Delegation](#16-withdrawal-delegation)
2. [vestedBTC Product](#2-vestedbtc-product)
   - 2.1 [Product Definition](#21-product-definition)
   - 2.2 [Value Proposition](#22-value-proposition)
3. [Dormant NFT Recovery](#3-dormant-nft-recovery)
   - 3.1 [Problem Statement](#31-problem-statement)
   - 3.2 [Recovery Mechanism](#32-recovery-mechanism)
   - 3.3 [Outcomes](#33-outcomes)
   - 3.4 [Economic Fairness](#34-economic-fairness)
4. [DeFi Composability](#4-defi-composability)
   - 4.1 [vestedBTC Integration Stack](#41-vestedbtc-integration-stack)
   - 4.2 [Withdrawal Stacking Example](#42-withdrawal-stacking-example)
   - 4.3 [DeFi Use Cases](#43-defi-use-cases)
5. [Exit Strategies](#5-exit-strategies)
   - 5.1 [Exit Strategy Matrix](#51-exit-strategy-matrix)
   - 5.2 [Exit Decision Tree](#52-exit-decision-tree)
   - 5.3 [Comparative Analysis](#53-comparative-analysis)
6. [Design Decisions](#6-design-decisions)

---

## 1. Overview

### 1.1 Purpose

BTCNFT Protocol provides perpetual withdrawals through percentage-based collateral access, designed to maintain USD-denominated value stability based on historical Bitcoin performance.

### 1.2 Mechanism Summary

| Phase | Action |
|-------|--------|
| **Mint** | Vault your Treasure NFT + BTC → Receive Vault NFT |
| **Vesting** | 1129-day lock (no withdrawals) |
| **Post-Vesting** | Withdraw 1.0% of remaining BTC per 30-day period (12% annually) |
| **Perpetual** | Percentage-based withdrawal ensures collateral never depletes |

> **Note:** The 12% annual withdrawal rate was selected based on quantitative validation showing 100% historical yearly stability (2017-2025). See [Quantitative Validation](./Quantitative_Validation.md) for analysis.

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

### 1.4 Minting Windows

Issuers can create time-bound minting campaigns for community goals.

**Use Case:**
> "As an NFT issuer, I want to launch a 30-day community goal to mint as many vaults as possible within that time period."

**Minting Modes:**

| Mode | Description | Use Case |
|------|-------------|----------|
| **Instant Mint** | Immediate Vault NFT creation | Standard minting |
| **Window Mint** | Deferred batch minting | Campaign-based releases |

**Window Lifecycle:**

| Phase | Duration | Actions Available |
|-------|----------|-------------------|
| **Created** | Before start | Window awaiting start time |
| **Open** | Start → End | Create pending mints, increase collateral, cancel |
| **Closed** | End → Execution | Finalize collateral, cancel pending mints |
| **Executed** | After execution | All pending mints become Vault NFTs |

**Key Properties:**
- Multiple issuers can operate concurrently on a shared protocol
- Issuers can run parallel windows (multiple community goals)
- Windows define allowed Treasure contracts (on-chain scope enforcement)
- Open participation: any address can join any open window
- Instant minting remains available alongside window-based minting

See [Technical Specification Section 1.3](./Technical_Specification.md#13-dynamic-minting-windows) for implementation details.

### 1.5 Non-Custodial Guarantee

| Property | Value |
|----------|-------|
| Custody Model | Non-custodial (user retains control) |
| Collateral Location | Inside user's Vault NFT (ERC-998 composable) |
| Withdrawal Rights | Owner only (via `msg.sender == ownerOf(vaultTokenId)`) |
| Collateral Access | Direct transfer to owner wallet |
| Issuer Access | **None** (no extraction function exists) |

**Architecture:**
```
┌─────────────────────────────────────┐
│  Vault NFT (ERC-998)                │
│  ┌─────────────┬───────────────────┐│
│  │  Treasure   │  BTC Collateral   ││
│  │  (ERC-721)  │  (ERC-20)         ││
│  │  Child NFT  │  Locked Balance   ││
│  └─────────────┴───────────────────┘│
│  Owner: USER (not issuer, not protocol)
└─────────────────────────────────────┘
```

**Key Guarantees:**
- Only the Vault NFT owner can call `withdraw()`
- No extraction function exists in the contract
- Issuers have zero access to user collateral
- 100% of deposited BTC becomes user collateral

### 1.6 Withdrawal Delegation

**Overview:** Vault holders can grant percentage-based withdrawal permissions to other addresses, enabling flexible treasury management without transferring ownership.

**Key Features:**
- **Non-custodial delegation**: Vault ownership never transfers
- **Percentage allocation**: Grant share of the cumulative 1.0% monthly withdrawal
- **Multiple delegates**: Support for multi-party treasury management
- **Revocable permissions**: Owner maintains full control (single or bulk revoke)
- **Independent periods**: Each delegate has separate 30-day cooldowns
- **Cumulative withdrawals**: The 1.0% monthly limit is shared among all parties

**Use Case Examples:**

| Scenario | Implementation |
|----------|----------------|
| **DAO Treasury** | Treasury committee (60%), Operations (30%), Emergency (10%) |
| **Family Trust** | Children receive equal monthly allowances (33.3% each) |
| **Automated Services** | DCA bot (25%), Bill payments (20%), Investments (55%) |
| **Corporate Treasury** | Hot wallet ops (40%), Cold storage rotation (60%) |

**Delegation Flow:**
```
Vault with 1 BTC: Monthly Withdrawal Pool = 0.01 BTC (1.0%)
├─ Owner retains vault ownership + withdrawal rights
└─ Grants percentage shares of the 0.01 BTC pool:
    ├─ Delegate A: 60% = 0.006 BTC monthly
    ├─ Delegate B: 30% = 0.003 BTC monthly
    └─ Delegate C: 10% = 0.001 BTC monthly

Total: 100% of 0.01 BTC distributed
```

**Benefits:**
- Enables institutional treasury management patterns
- Supports automated withdrawal strategies
- Compatible with multi-signature setups
- Maintains security through owner-controlled permissions

For technical implementation details, see [Withdrawal Delegation Specification](./Withdrawal_Delegation.md).

---

## 2. vestedBTC Product

### 2.1 Product Definition

**vestedBTC** is the branded name for the ERC-20 token derived from Vault NFTs.

| Property | vestedBTC |
|----------|-----------|
| Source | Vault NFT collateral claim token |
| Withdrawal rate | -12% annually (1.0%/mo) |
| Historical BTC appreciation | +63.11% annually (mean, 2017-2025) |
| Net expected return | ~+51% annually |
| Historical stability | **100%** yearly, **100%** 1129-day (2017-2025 data) |

> **Note:** vestedBTC is BTC-denominated (not pegged to USD). "Stability" refers to historical patterns, not a forward-looking guarantee.

### 2.2 Value Proposition

vestedBTC offers a unique position in the market:
- **BTC upside exposure** with USD-denominated stability floor
- **No liquidation risk** (unlike CDP-based stablecoins)
- **No peg maintenance** required (not pegged to $1)
- **Backed by actual BTC** (not algorithmic)
- **DeFi-native** (ERC-20, tradeable on DEXs)
- **Non-custodial** - user retains control via NFT ownership

---

## 3. Dormant NFT Recovery

### 3.1 Problem Statement

When a Vault holder separates their collateral into vestedBTC and later sells or loses access to that vestedBTC, the underlying BTC can become permanently inaccessible:

- **Vault holder**: Cannot redeem (lacks vestedBTC requirement)
- **vestedBTC holder**: Cannot recombine (lacks the Vault)

If the Vault holder becomes inactive, this creates "zombie" positions where valuable BTC collateral is permanently locked.

### 3.2 Recovery Mechanism

The dormant claim mechanism allows vestedBTC holders to recover abandoned positions:

**Dormancy Criteria:**
| Condition | Requirement |
|-----------|-------------|
| vestedBTC separated | vestedBTC must exist for the Vault |
| vestedBTC not at owner | Owner no longer holds sufficient vestedBTC |
| Extended inactivity | No activity for 1129+ days |

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
                    │  Owner proves   │       │  Grace expires  │       │  vestedBTC holder    │
                    │  activity       │       │                 │       │  claims         │
                    │  → Back to      │       │  → Vault        │       │  → Collateral   │
                    │    ACTIVE       │       │    CLAIMABLE    │       │    to claimer   │
                    └─────────────────┘       └─────────────────┘       └─────────────────┘
```

### 3.3 Outcomes

When dormant collateral is claimed:

| Party | Receives | Loses |
|-------|----------|-------|
| **Claimer** | BTC collateral (remaining amount) | vestedBTC (burned) |
| **Original Owner** | N/A | Collateral, Treasure (burned) |
| **Vault NFT** | N/A (burned - empty shell) | N/A |
| **vestedBTC** | N/A (permanently burned) | Supply reduced |

**Note:** Both the Vault NFT and Treasure NFT are burned as a commitment mechanism, treating dormancy similarly to early redemption.

### 3.4 Economic Fairness

The mechanism ensures fair treatment for all parties:

**For Original Owner:**
- Treasure burned (commitment mechanism; disincentivizes dormancy)
- Already received value when selling vestedBTC
- Had 1129+ days of inactivity + 30-day warning to respond

**For Claimer:**
- Burns vestedBTC equal to original minted amount
- Receives BTC collateral directly
- Economically equivalent to normal recombination (vestedBTC → BTC)

**For Protocol:**
- Reduces "zombie" positions
- vestedBTC burn is deflationary (reduces supply)
- Maintains economic integrity of the system

---

## 4. DeFi Composability

### 4.1 vestedBTC Integration Stack

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
│  │  Curve: vestedBTC/WBTC stable-like (PRIMARY)            │   │
│  │  Curve: vestedBTC/cbBTC stable-like                     │   │
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

**Why BTC-Denominated Pairs Only?**

vestedBTC represents a claim on BTC collateral. Pairing exclusively with WBTC/cbBTC creates correlated-asset pools (similar to stETH/ETH) that minimize impermanent loss, enable direct NAV arbitrage without oracle dependency, and keep users within the BTC ecosystem. Users acquire WBTC/cbBTC through existing market infrastructure before interacting with vestedBTC.

### 4.2 Withdrawal Stacking Example

```
Base: Vault NFT
├─ BTC Withdrawals: 12% annually
│
Separation: mintVestedBTC() → vestedBTC
├─ Retain: Withdrawal rights (12%)
├─ vestedBTC → Curve LP → Convex boost
│   └─ LP fees: ~2-5% APY
│   └─ CRV rewards: ~3-8% APY
│   └─ CVX boost: ~2-4% APY
│
Total Stack: 12% + 7-17% = 19-29% APY
```

### 4.3 DeFi Use Cases

| Use Case | Mechanism |
|----------|-----------|
| Liquidity access | Sell vestedBTC on DEX, retain Vault for withdrawal rights |
| DeFi collateral | Deposit vestedBTC in Aave/Compound |
| Partial liquidation | Sell portion of vestedBTC while retaining rest |
| Liquidity provision | Add vestedBTC to DEX liquidity pool |
| Structured products | Create principal-only and withdrawal-rights-only tranches |

---

## 5. Exit Strategies

### 5.1 Exit Strategy Matrix

| Strategy | Mechanism | Time | Cost |
|----------|-----------|------|------|
| **Hold Perpetual** | Withdraw forever (Zeno) | Infinite | Gas only |
| **Early Redemption** | Linear unlock | Any time | Forfeiture penalty |
| **Sell Vault NFT** | Secondary market | Immediate | Market spread |
| **Sell vestedBTC** | DEX trade | Immediate | Slippage + gas |
| **Sell vestedBTC, Keep Withdrawals** | DEX trade | Immediate | Principal only |
| **Delegate Withdrawals** | Grant % to other wallets | Immediate | Gas only |
| **Claim Dormant Collateral** | Burn vestedBTC to claim abandoned BTC | 30+ days | vestedBTC burned |

### 5.2 Exit Decision Tree

```
                    ┌─────────────────────┐
                    │  Exit Goal?         │
                    └─────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ↓                   ↓                   ↓
   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
   │ Full Exit   │    │ Partial     │    │ Keep        │
   │             │    │ Liquidity   │    │ Position    │
   └─────────────┘    └─────────────┘    └─────────────┘
          ↓                   ↓                   ↓
   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
   │Sell Vault or│    │Sell vestedBTC    │    │Hold Perpetual│
   │Early Redeem │    │Keep Vault   │    │Withdraw %  │
   └─────────────┘    └─────────────┘    └─────────────┘
```

### 5.3 Comparative Analysis

| Exit Type | Best For | Trade-off |
|-----------|----------|-----------|
| Hold Perpetual | Long-term income | No principal access |
| Early Redemption | Emergency liquidity | Forfeiture penalty + Treasure loss |
| Sell Vault NFT | Clean exit | Market-dependent price |
| Sell vestedBTC | Principal access | Lose redemption rights |
| Delegate Withdrawals | Distributed management | Retains ownership |
| Claim Dormant | vestedBTC → BTC conversion | Requires dormant position |

---

## 6. Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Token standard | ERC-998 Composable | Enables NFT + ERC-20 bundling |
| Treasure NFT | Required at mint | Provides identity/art to backing |
| Treasure on early redemption | Burned with Vault NFT | Commitment mechanism; disincentivizes early exit |
| BTC collateral | WBTC or cbBTC | Widely available wrapped BTC |
| Withdrawal rate | 12% annually (1.0%/mo) | 100% historical positive windows |
| Vesting period | 1129 days | Full BTC market cycle coverage |
| Dormancy threshold | 1129 days | Matches vesting period; full inactivity cycle |
| Grace period | 30 days | Fair warning; one withdrawal period |
| Treasure on claim | Burned | Commitment mechanism; disincentivizes dormancy |
| Collateral on claim | Transferred to claimer | Claimer receives BTC directly |
| Vault NFT on claim | Burned | Empty shell after extraction - no value |
| vestedBTC on claim | Burned | Economic equivalence with recombination |
