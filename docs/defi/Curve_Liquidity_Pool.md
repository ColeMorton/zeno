# vestedBTC/WBTC Curve Liquidity Pool

> **Version:** 2.0
> **Status:** Draft
> **Last Updated:** 2026-01-10
> **Related Documents:**
> - [Leveraged Lending Protocol](./Leveraged_Lending_Protocol.md)
> - [Time-Preference Primer](../research/Time_Preference_Primer.md)
> - [Technical Specification](../protocol/Technical_Specification.md)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Pool Type: CryptoSwap V2](#2-pool-type-cryptoswap-v2)
3. [Pool Parameters](#3-pool-parameters)
4. [Price Dynamics](#4-price-dynamics)
5. [Liquidity Bootstrapping](#5-liquidity-bootstrapping)
6. [Risk Analysis](#6-risk-analysis)
7. [Deployment Checklist](#7-deployment-checklist)
8. [Multi-Collateral Strategy](#8-multi-collateral-strategy)

---

## 1. Overview

### Problem

vestedBTC holders currently have no secondary market for entry/exit. The early redemption penalty (0-100% linear over 1129 days) creates friction for holders needing liquidity before vesting completes.

### Solution

Deploy a **Curve CryptoSwap V2 pool** (vWBTC/WBTC) enabling market-determined exit pricing. Arbitrageurs maintain price equilibrium between DEX pricing and the early redemption formula.

### Integration Layer

| Aspect | Value |
|--------|-------|
| Layer | Off-chain DeFi integration |
| Protocol Changes | None required |
| Pool Type | **Curve CryptoSwap V2** (non-pegged volatile pairs) |
| Pair | vWBTC/WBTC (single collateral type) |

### Lindy Score

| Component | Age | Score |
|-----------|-----|-------|
| Curve Protocol | 5+ years | HIGH |
| CryptoSwap V2 Invariant | 3+ years | MEDIUM-HIGH |
| ERC-20 Standard | 8+ years | HIGH |
| Factory Pool Pattern | 3+ years | MEDIUM-HIGH |

---

## 2. Pool Type: CryptoSwap V2

### Why CryptoSwap (Not StableSwap)

vBTC is a **subordinated residual claim**, NOT a stable/pegged asset. This is a critical distinction that determines the appropriate AMM design.

**vBTC Characteristics:**
- **Structural decay:** 1% monthly withdrawal to senior claimant (vault owner)
- **Variable discount:** 5-50%+ depending on market conditions
- **No peg mechanism:** No convergence guarantee to 1:1
- **Fair value changes over time:** Unlike liquid staking derivatives

**Why StableSwap is Wrong:**
- StableSwap assumes deviations from 1:1 are **temporary inefficiencies** that arbitrage corrects
- vBTC's discount is **structural reality** — the underlying claim genuinely depletes
- StableSwap pools fail catastrophically at 30-50% discounts (which vBTC can reach)

**Why CryptoSwap is Correct:**
- Designed for **non-pegged volatile pairs**
- **EMA oracle** tracks evolving fair value without assuming a peg
- **Profit-offset rule** protects LPs (rebalance only when fees > 50% of cost)
- Capital efficiency maintained across **50-95% price range**

### Comparison: CryptoSwap vs StableSwap for vBTC

| Factor | StableSwap | CryptoSwap V2 |
|--------|------------|---------------|
| **Design assumption** | Pegged assets (95-105% range) | Non-pegged volatile pairs |
| **vBTC range** | 50-95% (incompatible) | 50-95% (designed for this) |
| **At 30% discount** | 8-12% IL, poor efficiency | 3-5% IL (fee-buffered) |
| **At 50% discount** | Catastrophic failure | Manageable |
| **Structural decay** | Assumes fixed peg (wrong) | EMA oracle tracks changes |
| **LP protection** | None | Profit-offset rule |

### Reference: Time-Preference Primer

For detailed explanation of why vBTC is structurally different from pegged assets, see [Time-Preference Primer](../research/Time_Preference_Primer.md), particularly:
- Part VII: "vBTC: A Subordinated Residual Claim"
- Part VIII: "Mathematical Framework"

---

## 3. Pool Parameters

### Recommended Configuration

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Invariant | **CryptoSwap V2** | Non-pegged volatile pairs |
| A (amplification) | 50-100 | More volatile than stables, less than ETH/BTC |
| gamma (curvature) | 0.000145 | Standard for volatile pairs |
| adjustment_step | 0.00146 | 1% min price move to trigger rebalancing |
| mid_fee | 0.26% | Between stable (0.04%) and volatile (0.4%) |
| out_fee | 0.45% | Higher fee at curve edges |
| EMA half-life | 10 min | Smooth discount tracking |
| Admin Fee | 50% | Standard Curve admin fee share |

### A Parameter Selection (CryptoSwap)

The amplification parameter (A) in CryptoSwap controls liquidity concentration around the EMA price:

| A Value | Behavior | Use Case |
|---------|----------|----------|
| 10-30 | Wide distribution, high slippage tolerance | Highly volatile pairs |
| 50-100 | **Balanced** | **vestedBTC (recommended)** |
| 200+ | Tight concentration | More stable pairs |

**Recommendation:** Start with A=75, monitor rebalancing frequency, adjust based on:
- If rebalancing > daily: Increase adjustment_step or decrease A
- If slippage too high: Increase A

### Gamma Parameter

Gamma controls the curvature shape:

| gamma Value | Effect |
|-------------|--------|
| 0.0001 | Sharper curve, more concentrated |
| 0.000145 | **Standard (recommended)** |
| 0.0002 | Flatter curve, more distributed |

### Why NOT StableSwap

| Feature | StableSwap | CryptoSwap V2 | vBTC Fit |
|---------|------------|---------------|----------|
| Capital efficiency | High near 1:1 only | High across EMA range | CryptoSwap wins |
| LP complexity | Passive | Sophisticated passive | Acceptable |
| IL at 30% deviation | 8-12% | 3-5% (fee-buffered) | CryptoSwap wins |
| Depeg handling | Catastrophic | Dynamic rebalancing | CryptoSwap wins |

---

## 4. Price Dynamics

### Expected Price Range

| Metric | Value | Derivation |
|--------|-------|------------|
| Price Floor | ~0.00 | Early redemption at day 0 = 100% penalty |
| Practical Floor | ~0.50 | Extreme stress scenario |
| Expected Range | 0.70-0.95 | Normal market conditions |
| Price Ceiling | ~0.95 | Near-vested vaults, minimal discount |

**Important:** These are expected ranges, NOT pegs. vBTC's price can and will move within this range based on:
- Time to vesting completion
- Market demand for time-compression
- Protocol TVL and liquidity depth
- General crypto market conditions

### EMA Oracle Behavior

CryptoSwap V2 uses an **exponential moving average (EMA)** to track price:

```
EMA Price Update:
├─ Triggered by trades
├─ Smoothed over configured half-life (10 min recommended)
├─ Used for rebalancing decisions
└─ No assumption of convergence to any fixed value
```

**Key Insight:** The EMA oracle naturally tracks vBTC's evolving fair value without assuming it should return to 1:1.

### Price Discovery Mechanism

```
DEX Price vs. Early Redemption Value

┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  If DEX Price < Redemption Value:                           │
│  └─ Arbitrageur buys vWBTC on DEX                          │
│  └─ Returns vWBTC to Vault (recombination)                 │
│  └─ Redeems Vault for BTC                                  │
│  └─ Profit = Redemption Value - DEX Price                  │
│                                                             │
│  If DEX Price > Redemption Value:                           │
│  └─ Arbitrageur mints new Vault (Treasure + BTC)           │
│  └─ Separates collateral → vWBTC                           │
│  └─ Sells vWBTC on DEX                                     │
│  └─ Profit = DEX Price - Cost to Mint                      │
│                                                             │
│  Result: Market-efficient pricing bounded by redemption     │
└─────────────────────────────────────────────────────────────┘
```

### Redemption Value Formula

From the protocol's early redemption specification:

```
redeemable(d) = collateral × (d / 1129)

Where:
  d = days since mint (0 to 1129)
  collateral = original BTC deposited
```

| Days Elapsed | Redemption Value | vWBTC Fair Price |
|--------------|------------------|------------------|
| 0 | 0% | ~0.00 |
| 282 | 25% | ~0.25 |
| 565 | 50% | ~0.50 |
| 847 | 75% | ~0.75 |
| 1129 | 100% | ~1.00 |

**Note:** DEX price typically trades at a premium to redemption value due to:
- Transaction costs of redemption
- Treasure NFT value (burned on redemption)
- Time value of immediate liquidity

---

## 5. Liquidity Bootstrapping

### Phase 1: Issuer Seeding

| Requirement | Value |
|-------------|-------|
| Initial Seed | 10-50 WBTC equivalent per side |
| Source | Issuers separate vault collateral |
| Purpose | Establish initial price discovery |

**Process:**
1. Issuer mints Vault NFTs (Treasure + BTC)
2. Issuer calls `mintBtcToken()` to separate collateral
3. Issuer receives vWBTC
4. Issuer deposits vWBTC + matching WBTC into Curve pool
5. Issuer receives LP tokens

### Phase 2: LP Incentives (Optional)

| Mechanism | Description |
|-----------|-------------|
| Curve Gauge | Submit governance proposal for CRV rewards |
| Protocol Incentives | Issuer-funded rewards to attract LPs |
| vestedBTC Rewards | Distribute vWBTC to LPs |

**Note:** Incentives accelerate liquidity growth but are not required for pool functionality.

### Phase 3: Organic Growth

| Driver | Mechanism |
|--------|-----------|
| Arbitrage | Profit-seeking maintains price efficiency |
| LP Yield | Swap fees attract passive liquidity |
| Holder Liquidity | vestedBTC holders add LP for yield stacking |

### Yield Stacking for LPs

Vault holders can stack yields:

```
Base: Vault NFT Withdrawal Rights (retained)
├─ BTC Withdrawals: 12% annually
│
Separation: mintBtcToken() → vWBTC
├─ Retain: Withdrawal rights (12%)
├─ vWBTC → Curve LP
│   └─ Swap fees: 0.5-2% APY (volume dependent)
│   └─ CRV rewards: Variable (if gauge approved)
│
Total: 12% + LP Yield
```

---

## 6. Risk Analysis

### LP Risk Disclosure

**Important:** LPs must understand vBTC's structural characteristics:

| Risk Factor | Impact |
|-------------|--------|
| **Structural decay** | vBTC's underlying depletes 1% monthly; creates ~12% annual headwind |
| **IL during rebalancing** | CryptoSwap realizes IL during rebalancing events |
| **No convergence** | Do not expect vBTC to "repeg" to wBTC |
| **Profitability requirement** | LP fees must exceed structural decay for positive returns |

### Risk Matrix

| Risk | Severity | Probability | Mitigation |
|------|----------|-------------|------------|
| Impermanent Loss | MEDIUM | MEDIUM | CryptoSwap's profit-offset rule buffers IL; rebalancing only when economical |
| Low Initial Liquidity | HIGH | HIGH | Issuer seeding; conservative A parameter |
| Wide Discount Event | MEDIUM | MEDIUM | CryptoSwap handles 30-50% discounts; EMA tracks new equilibrium |
| Smart Contract (Curve) | HIGH | LOW | 5+ years Lindy; CryptoSwap V2 battle-tested |
| Smart Contract (vWBTC) | HIGH | LOW | Protocol audited; minimal ERC-20 |

### Impermanent Loss Analysis (CryptoSwap)

CryptoSwap's IL profile differs from StableSwap:

| Price Ratio (vWBTC/WBTC) | IL (Uniswap V2) | IL (StableSwap) | IL (CryptoSwap) |
|--------------------------|-----------------|-----------------|-----------------|
| 0.95 | ~0.3% | ~0.05% | ~0.1% |
| 0.85 | ~2.8% | ~0.5% | ~0.8% |
| 0.75 | ~6.2% | ~1.5% | ~2.0% |
| 0.50 | ~25% | **FAILURE** | ~8% |

**Key Insight:** CryptoSwap handles the full vBTC range (0.50-0.95) without catastrophic failure. StableSwap fails at wide discounts.

### Wide Discount Scenario

If vWBTC drops below 0.50 (severe discount):

**StableSwap behavior:**
- Curve becomes essentially constant-product
- Capital efficiency collapses
- LPs experience massive IL with no protection

**CryptoSwap V2 behavior:**
- EMA oracle tracks new equilibrium
- Rebalancing occurs only when fees offset cost
- Pool continues functioning efficiently
- Arbitrage remains profitable

---

## 7. Deployment Checklist

### Pre-Deployment

- [ ] Verify vWBTC contract address on target network
- [ ] Confirm WBTC contract address
- [ ] Prepare initial liquidity (vWBTC + WBTC)
- [ ] Document expected initial price
- [ ] Select CryptoSwap V2 parameters (A=75, gamma=0.000145)

### Deployment

- [ ] Deploy Curve CryptoSwap V2 pool via Curve Factory
- [ ] Set A parameter (50-100)
- [ ] Set gamma parameter (0.000145)
- [ ] Set fee parameters (mid_fee=0.26%, out_fee=0.45%)
- [ ] Seed initial liquidity
- [ ] Verify pool appears on Curve UI

### Post-Deployment

- [ ] Add pool to BTCNFT Protocol documentation
- [ ] Announce pool to community
- [ ] Monitor initial trading activity
- [ ] Track EMA oracle behavior
- [ ] Monitor rebalancing frequency

### Governance (Optional)

- [ ] Submit Curve gauge proposal for CRV rewards
- [ ] Coordinate vote timing with Curve governance

---

## 8. Multi-Collateral Strategy

### Pool Per Collateral Type

Each vestedBTC variant requires its own pool to maintain risk isolation:

| Pool | Assets | Risk Profile | Status |
|------|--------|--------------|--------|
| vWBTC/WBTC | vestedBTC-wBTC / Wrapped Bitcoin | BitGo custodial | **PRIMARY** |
| vCBBTC/cbBTC | vestedBTC-cbBTC / Coinbase Bitcoin | Coinbase custodial | Future |
| vTBTC/tBTC | vestedBTC-tBTC / Threshold Bitcoin | Decentralized | Future |

### Rationale

- **Risk Isolation:** A custody failure in one wrapped BTC variant does not affect other pools
- **Independent Pricing:** Each variant can price according to its underlying's risk
- **Clear Token Identity:** LPs know exactly which custody model backs their liquidity

### Cross-Pool Considerations

| Topic | Approach |
|-------|----------|
| Arbitrage | Separate pools; no cross-pool arbitrage needed |
| Liquidity Fragmentation | Accept fragmentation for risk isolation benefit |
| UI Integration | Display all pools with clear variant labeling |

---

## Navigation

← [DeFi Documentation](./README.md) | [Leveraged Lending Protocol](./Leveraged_Lending_Protocol.md)
