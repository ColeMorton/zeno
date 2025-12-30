# vestedBTC/WBTC Curve Liquidity Pool

> **Version:** 1.0
> **Status:** Draft
> **Last Updated:** 2025-12-30
> **Related Documents:**
> - [Leveraged Lending Protocol](./Leveraged_Lending_Protocol.md)
> - [Technical Specification](../protocol/Technical_Specification.md)
> - [Product Specification](../protocol/Product_Specification.md)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Pool Parameters](#2-pool-parameters)
3. [Price Dynamics](#3-price-dynamics)
4. [Liquidity Bootstrapping](#4-liquidity-bootstrapping)
5. [Risk Analysis](#5-risk-analysis)
6. [Deployment Checklist](#6-deployment-checklist)
7. [Multi-Collateral Strategy](#7-multi-collateral-strategy)

---

## 1. Overview

### Problem

vestedBTC holders currently have no secondary market for entry/exit. The early redemption penalty (0-100% linear over 1129 days) creates friction for holders needing liquidity before vesting completes.

### Solution

Deploy a Curve StableSwap pool (vWBTC/WBTC) enabling market-determined exit pricing. Arbitrageurs maintain price equilibrium between DEX pricing and the early redemption formula.

### Integration Layer

| Aspect | Value |
|--------|-------|
| Layer | Off-chain DeFi integration |
| Protocol Changes | None required |
| Pool Type | Curve StableSwap (correlated assets) |
| Pair | vWBTC/WBTC (single collateral type) |

### Lindy Score

| Component | Age | Score |
|-----------|-----|-------|
| Curve Protocol | 5+ years | HIGH |
| StableSwap Invariant | 5+ years | HIGH |
| ERC-20 Standard | 8+ years | HIGH |
| Factory Pool Pattern | 3+ years | MEDIUM-HIGH |

---

## 2. Pool Parameters

### Recommended Configuration

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Invariant | StableSwap | Correlated assets (vBTC trades at discount to BTC) |
| A Parameter | 100-200 | Balance capital efficiency vs. slippage tolerance |
| Swap Fee | 0.04% | Matches stETH/ETH pool (similar correlated pair) |
| Admin Fee | 50% | Standard Curve admin fee share |

### A Parameter Selection

The amplification parameter (A) controls how "flat" the bonding curve is around the peg:

| A Value | Behavior | Use Case |
|---------|----------|----------|
| 10-50 | More curved, tolerates large depegs | Volatile pairs |
| 100-200 | Balanced | **vestedBTC (recommended)** |
| 500+ | Very flat, assumes tight peg | True stablecoins |

**Recommendation:** Start with A=100, monitor price dynamics, adjust via Curve governance if needed.

### Why StableSwap (Not Uniswap V3)

| Feature | StableSwap | Uniswap V3 |
|---------|------------|------------|
| Capital efficiency | High for correlated assets | Requires active management |
| LP complexity | Passive | Requires range management |
| Slippage at 10% deviation | Low | Moderate |
| Depeg tolerance | Built into invariant | Position becomes out-of-range |

vestedBTC is expected to trade at 0.70-0.95 of WBTC, making StableSwap's correlated-asset invariant ideal.

---

## 3. Price Dynamics

### Expected Price Range

| Metric | Value | Derivation |
|--------|-------|------------|
| Price Floor | ~0.00 | Early redemption at day 0 = 100% penalty |
| Practical Floor | ~0.70 | Arbitrage profitable above this level |
| Price Ceiling | ~0.95 | Near-vested vaults, minimal discount |
| Equilibrium | 0.75-0.90 | Market-discovered, cohort-dependent |

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

## 4. Liquidity Bootstrapping

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

## 5. Risk Analysis

### Risk Matrix

| Risk | Severity | Probability | Mitigation |
|------|----------|-------------|------------|
| Impermanent Loss | MEDIUM | MEDIUM | Correlated assets minimize IL; StableSwap curve reduces further |
| Low Initial Liquidity | HIGH | HIGH | Issuer seeding; conservative A parameter |
| Depeg Event | LOW | MEDIUM | A=100-200 tolerates 10-30% deviation; pool continues functioning |
| Smart Contract (Curve) | HIGH | LOW | 5+ years Lindy; no custom code deployed |
| Smart Contract (vWBTC) | HIGH | LOW | Protocol audited; minimal ERC-20 |

### Impermanent Loss Analysis

For correlated assets trading within 0.70-0.95 range:

| Price Ratio (vWBTC/WBTC) | IL (Uniswap V2) | IL (StableSwap A=100) |
|--------------------------|-----------------|----------------------|
| 0.95 | ~0.3% | ~0.05% |
| 0.85 | ~2.8% | ~0.5% |
| 0.75 | ~6.2% | ~1.5% |

**Conclusion:** StableSwap significantly reduces IL for expected price range.

### Depeg Scenario

If vWBTC drops below 0.50 (severe discount):
- StableSwap invariant remains functional
- Slippage increases but trading continues
- Arbitrage remains profitable (buy cheap vWBTC → recombine → redeem)
- Pool does not "break" like concentrated liquidity positions

---

## 6. Deployment Checklist

### Pre-Deployment

- [ ] Verify vWBTC contract address on target network
- [ ] Confirm WBTC contract address
- [ ] Prepare initial liquidity (vWBTC + WBTC)
- [ ] Document expected initial price

### Deployment

- [ ] Deploy Curve Factory pool via Curve UI
- [ ] Set A parameter (100-200)
- [ ] Set swap fee (0.04%)
- [ ] Seed initial liquidity
- [ ] Verify pool appears on Curve UI

### Post-Deployment

- [ ] Add pool to BTCNFT Protocol documentation
- [ ] Announce pool to community
- [ ] Monitor initial trading activity
- [ ] Track arbitrage efficiency

### Governance (Optional)

- [ ] Submit Curve gauge proposal for CRV rewards
- [ ] Coordinate vote timing with Curve governance

---

## 7. Multi-Collateral Strategy

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
