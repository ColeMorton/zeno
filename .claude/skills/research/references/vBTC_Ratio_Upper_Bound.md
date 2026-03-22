# vBTC Ratio Upper Bound Analysis

> **Version:** 1.0
> **Status:** Research
> **Last Updated:** 2026-03-22
> **Related Documents:**
> - [vBTC Pricing Model](./vBTC_Pricing_Model.md)
> - [Minting Economics](./Minting_Economics.md)
> - [Native Volatility Farming Architecture](./Native_Volatility_Farming_Architecture.md)

---

## Executive Summary

The vBTC/WBTC exchange ratio (vbtcRatio) is structurally bounded below 1.0. Three independent mechanisms enforce this ceiling: (1) arbitrage via separate-and-sell, (2) perpetual 1% monthly collateral decay, and (3) vBTC's smaller addressable market relative to WBTC. Simulation data showing vbtcRatio > 1 is an artifact of the closed-system AMM lacking external arbitrageurs. This document formalizes the upper bound argument and identifies the simulation gap.

---

## Table of Contents

1. [Definition](#1-definition)
2. [The Arbitrage Ceiling](#2-the-arbitrage-ceiling)
3. [Decay Mechanics](#3-decay-mechanics)
4. [Market Structure Argument](#4-market-structure-argument)
5. [Simulation Analysis](#5-simulation-analysis)
6. [Transient Edge Cases](#6-transient-edge-cases)
7. [Implications](#7-implications)

---

## 1. Definition

In the Curve AMM pool:

$$\text{vbtcRatio} = \frac{\text{WBTC}_{reserve}}{\text{vBTC}_{reserve}}$$

This is the spot exchange rate — how much WBTC 1 vBTC buys. Stored as an 18-decimal integer where `1e18 = 1.0`.

The protocol's TWAP oracle explicitly bounds accepted values to `[0.50, 1.00]` (`SwarmOrchestrator.sol:267`), encoding the design assumption that vbtcRatio > 1 is invalid market state.

---

## 2. The Arbitrage Ceiling

### 2.1 The Separate-and-Sell Loop

If vbtcRatio > 1 in the AMM, a risk-free arbitrage exists:

1. **Separate** a vault containing 1 WBTC of collateral → receive vBTC tokens
2. **Sell** vBTC on AMM at ratio > 1 → receive > 1 WBTC
3. **Net profit** = (WBTC received) - (1 WBTC collateral) > 0

This is a pure arbitrage — no market view required, no risk exposure. Any rational actor with a vault would execute it, pushing vBTC supply into the pool and WBTC out, driving the ratio back below 1.

### 2.2 Why the Ceiling is Strict

The arbitrage requires only:
- A vault with collateral (abundant by protocol design)
- Gas for separation + swap (~2 transactions)
- The AMM spot price exceeding 1.0

No capital lockup, no timing risk, no counterparty risk. The barrier to execution is near-zero, making vbtcRatio > 1 unsustainable for even a single block in a liquid market.

### 2.3 The Effective Ceiling is Below 1.0

The true ceiling is slightly below 1.0, accounting for:
- AMM swap fees (0.3% in SimCurvePool)
- Gas costs for separation + swap
- Slippage on the sell

Effective ceiling ≈ `1.0 - swap_fee - gas_cost/trade_size` ≈ **0.993–0.997** for reasonably sized trades.

---

## 3. Decay Mechanics

From [vBTC Pricing Model](./vBTC_Pricing_Model.md), the collateral claim decays as:

$$C(t) = V_0 \times (1 - w)^t = V_0 \times 0.99^t$$

Where `w = 0.01` (1% monthly) and `t` = months since separation.

At any time `t > 0`, the intrinsic value of 1 vBTC < 1 WBTC:

| Time Since Separation | Collateral Claim | Discount |
|----------------------|-----------------|----------|
| 0 months | 1.000 WBTC | 0% |
| 6 months | 0.941 WBTC | 5.9% |
| 12 months | 0.886 WBTC | 11.4% |
| 24 months | 0.786 WBTC | 21.4% |
| 60 months | 0.547 WBTC | 45.3% |

**The fundamental value of vBTC is always at a discount to WBTC.** For the market price to exceed 1.0, the speculative premium would need to exceed the decay discount — an economically irrational state given the arbitrage ceiling.

---

## 4. Market Structure Argument

### 4.1 Demand Asymmetry

vBTC demand is structurally limited relative to WBTC:

- **WBTC**: Widely used DeFi collateral, lending asset, and trading pair across Aave, Compound, Maker, Uniswap, and hundreds of protocols
- **vBTC**: Niche instrument used within the BTCNFT Protocol ecosystem — LP provision, volatility farming, and speculative trading

No demand scenario justifies vBTC trading at a premium to the undecayed asset it derives from.

### 4.2 Supply Elasticity

vBTC supply is elastic on the upside — any vault holder can create more vBTC by separating. This elastic supply creates a natural price ceiling, similar to how commodity producers increase supply when prices rise above production cost.

---

## 5. Simulation Analysis

### 5.1 Observed Data (320-week, seed 42, 100 agents)

| Metric | Value |
|--------|-------|
| Active ticks (vbtcRatio > 0) | 157 of 320 |
| Ticks with ratio > 1.0 | 64 (41% of active) |
| Ticks with ratio < 1.0 | 93 (59% of active) |
| Maximum ratio | ~3.97 |
| Minimum ratio (non-zero) | ~0.42 |
| Final ratio | ~1.58 |
| Mean ratio | ~1.09 |

### 5.2 Root Cause: Missing Arbitrage

The SimCurvePool is a closed-system constant-product AMM. When agents disproportionately swap vBTC→WBTC (removing vBTC from the pool), the ratio mechanically rises with no corrective force. The simulation lacks:

1. **External arbitrageurs** — No agents perform the separate-and-sell loop when ratio > 1
2. **Fundamental value awareness** — Agent swap decisions are archetype-driven (Yield Farmer, Diamond Hands), not price-rational
3. **External liquidity** — No inflows from outside the 100-agent system to rebalance the pool

### 5.3 Impact on Simulation Validity

The vbtcRatio exceedance does not invalidate the simulation's primary purpose (testing protocol invariants, conservation laws, and agent net worth tracking). However, it means:

- vBTC-denominated net worth calculations are inflated when ratio > 1
- Swap profitability for agents selling vBTC is overstated
- The Curve pool dynamics do not reflect realistic market conditions post-ratio-1

---

## 6. Transient Edge Cases

While sustained vbtcRatio > 1 is impossible, brief transient exceedance is theoretically possible:

| Scenario | Likelihood | Duration | Magnitude |
|----------|-----------|----------|-----------|
| Thin pool + large buy order | Medium (early days) | Seconds–minutes | 1.01–1.05 |
| Flash loan manipulation | Low (no profit motive) | 1 block | Any |
| Coordinated speculative mania | Very low | Hours–days | 1.01–1.10 |

All scenarios self-correct via arbitrage within blocks to minutes.

---

## 7. Implications

### 7.1 For Protocol Design

The vbtcRatio upper bound of ~1.0 is a structural invariant that can be relied upon for:
- TWAP oracle bounds validation (already implemented at `[0.50, 1.00]`)
- Net worth calculations
- Risk parameter calibration

### 7.2 For Simulation Improvement

Two options to address the artifact:

| Approach | Pros | Cons |
|----------|------|------|
| Add arbitrageur agent archetype | Realistic; tests arbitrage dynamics | More complexity; slower simulation |
| Clamp AMM ratio to [0, 1] | Simple; removes artifact | Hides information; masks pool imbalance |

The arbitrageur agent approach is preferred as it produces more realistic market dynamics without hiding information.

---

## References

### Internal
- [vBTC Pricing Model](./vBTC_Pricing_Model.md) — Decay formula, break-even analysis, optimal stopping
- [Minting Economics](./Minting_Economics.md) — Separation cost basis for arbitrage calculation
- [Native Volatility Farming Architecture](./Native_Volatility_Farming_Architecture.md) — Curve pool design and LP dynamics
- `contracts/simulation/src/mocks/SimCurvePool.sol` — AMM implementation (`spotPrice()`)
- `contracts/simulation/src/SwarmOrchestrator.sol:267` — TWAP oracle bounds `[0.50, 1.00]`
