# Minting Economics: The 0.005 WBTC Reference Unit

> **Version:** 1.0
> **Status:** Research
> **Last Updated:** 2026-03-22
> **Related Documents:**
> - [vBTC Pricing Model](./vBTC_Pricing_Model.md)
> - [Long Duration Capital Strategies](./Long_Duration_Capital_Strategies.md)
> - [Quantitative Validation](./Quantitative_Validation.md)
> - [Competitive Positioning](./Competitive_Positioning.md)
> - [Withdrawal Rate Stability](./Withdrawal_Rate_Stability.md)
> - [Bootstrap Minting Behavior](./Bootstrap_Minting_Behavior.md)
> - [Collateral Architecture](./Collateral_Architecture.md)

---

## Executive Summary

This document establishes **0.005 WBTC as the expected average mint quantity** for vault creation. The rationale: at current BTC prices (~$86K), 0.005 WBTC equals ~$430 -- comparable to purchasing a single share of a US stock or ETF. This familiar price point lowers cognitive friction for retail participants. The protocol enforces no minimum beyond `collateralAmount > 0`, making fractional minting permissionless.

The multi-vault assumption is central: minters are expected to create **multiple 0.005 WBTC vaults** rather than one large vault, gaining granular optionality over early redemption, staggered vesting, and partial exits. All percentage-based protocol mechanics (withdrawal rate, decay, roll-forward multiplication) are **scale-invariant** -- the economics at 0.005 WBTC are identical to 1 BTC in proportional terms.

Gas cost analysis confirms 0.005 WBTC is comfortably above the L1 significance threshold (~1.5% of first withdrawal) and trivially efficient on L2.

---

## Table of Contents

1. [USD Equivalence Across BTC Price Points](#1-usd-equivalence-across-btc-price-points)
2. [Retail Entry Point Comparison](#2-retail-entry-point-comparison)
3. [Withdrawal Economics at 0.005 WBTC](#3-withdrawal-economics-at-0005-wbtc)
4. [Gas Cost Significance Threshold](#4-gas-cost-significance-threshold)
5. [Multi-Vault Strategy](#5-multi-vault-strategy)
6. [Perpetual Roll-Forward at 0.005 Scale](#6-perpetual-roll-forward-at-0005-scale)

---

## 1. USD Equivalence Across BTC Price Points

0.005 WBTC maps to a familiar retail price band across a wide range of BTC valuations:

| BTC Price | 0.005 WBTC (USD) | Comparable Asset |
|-----------|-------------------|------------------|
| $50,000 | $250 | ~1 MSFT share |
| $86,000 | $430 | ~1 SPY share |
| $100,000 | $500 | ~1 BRK.B share |
| $150,000 | $750 | ~2 SPY shares |
| $250,000 | $1,250 | ~1 MSTR share |
| $500,000 | $2,500 | Accessible retail |

The $250-$2,500 range spans the "single stock purchase" mental model across even extreme BTC price scenarios. This is the price range where retail investors make individual purchase decisions without significant deliberation.

On-chain representation: 0.005 WBTC = 500,000 units (8 decimals), well above any dust or rounding concern.

---

## 2. Retail Entry Point Comparison

Compared to existing Bitcoin-exposure products (see [Competitive Positioning](./Competitive_Positioning.md) for full analysis):

| Product | Entry Cost | Mechanism | Counterparty Risk |
|---------|-----------|-----------|-------------------|
| **BTCNFT Vault (0.005 WBTC)** | ~$430 | Permissionless mint | Smart contract only |
| Strategy STRF (preferred) | ~$85/share | Brokerage purchase | Corporate solvency |
| Strive SATA (preferred) | ~$80/share | Brokerage purchase | Corporate solvency |
| IBIT (BTC ETF) | ~$55/share | Brokerage purchase | Custodial (BlackRock) |
| Direct BTC (exchange) | Any amount | Exchange purchase | Exchange custody |

Key distinctions at 0.005 WBTC:
- **Higher absolute entry** than single ETF/preferred shares, but comparable to a meaningful stock position (5-10 shares)
- **Zero counterparty risk** beyond smart contract -- no corporate solvency, no custodial intermediary
- **Zero ongoing fees** -- no management fees, no expense ratios, only gas costs
- **Composable** -- vault is an ERC-998 NFT, not a brokerage entry

---

## 3. Withdrawal Economics at 0.005 WBTC

Monthly withdrawal = 1% of remaining collateral (`WITHDRAWAL_RATE=1000 / BASIS_POINTS=100000` per `VaultMath.sol`).

Collateral decay follows `C(t) = C₀ × 0.99^t` where t = months elapsed since first withdrawal:

| Month | Collateral (WBTC) | Withdrawal (WBTC) | USD @ $86K | USD @ $150K |
|-------|-------------------|--------------------|-----------:|------------:|
| 1 | 0.005000 | 0.000050 | $4.30 | $7.50 |
| 6 | 0.004706 | 0.000047 | $4.05 | $7.06 |
| 12 | 0.004432 | 0.000044 | $3.81 | $6.65 |
| 24 | 0.003926 | 0.000039 | $3.38 | $5.89 |
| 60 | 0.002726 | 0.000027 | $2.35 | $4.09 |
| 120 | 0.001486 | 0.000015 | $1.28 | $2.23 |

Cumulative withdrawals over time:

| Period | Cumulative Withdrawn | % of Original |
|--------|---------------------|---------------|
| Year 1 | 0.000568 WBTC | 11.36% |
| Year 3 | 0.001537 WBTC | 30.74% |
| Year 5 | 0.002274 WBTC | 45.48% |
| Year 10 | 0.003514 WBTC | 70.28% |

Withdrawals are small in absolute terms but **identical in proportional terms** to any vault size. The Zeno's paradox property (collateral never reaches zero) holds regardless of scale.

---

## 4. Gas Cost Significance Threshold

At what vault size do gas costs materially erode withdrawal value?

Assumptions: L1 withdrawal gas ~$0.05-0.08 per transaction; L2 (Base/Arbitrum) ~90% cheaper.

| Vault Size (WBTC) | First Withdrawal (USD @ $86K) | L1 Gas Cost | Gas % (L1) | Gas % (L2) |
|--------------------|------------------------------:|------------:|-----------:|-----------:|
| 1.0 | $860.00 | $0.05-0.08 | <0.01% | Negligible |
| 0.1 | $86.00 | $0.05-0.08 | ~0.08% | Negligible |
| 0.01 | $8.60 | $0.05-0.08 | ~0.8% | Negligible |
| **0.005** | **$4.30** | **$0.05-0.08** | **~1.5%** | **Negligible** |
| 0.001 | $0.86 | $0.05-0.08 | ~7% | ~0.1% |
| 0.0001 | $0.086 | $0.05-0.08 | ~80% | ~1% |

**Finding:** 0.005 WBTC is comfortably above the L1 gas significance threshold. At ~1.5% gas-to-withdrawal ratio, gas costs are a minor friction, not an economic barrier. On L2, even 0.001 WBTC vaults remain viable.

Below 0.001 WBTC on L1, gas costs begin to dominate withdrawal economics. This represents the practical floor for L1 minting.

---

## 5. Multi-Vault Strategy

### Mathematical Equivalence

Withdrawal rate is percentage-based: N vaults of size X produce **identical aggregate withdrawals** to 1 vault of size N×X when minted simultaneously.

Proof: `sum(0.01 × X × 0.99^t, N times) = N × 0.01 × X × 0.99^t = 0.01 × (N×X) × 0.99^t`

### The Optionality Advantage

The reason to mint multiple small vaults is not withdrawal economics but **optionality**:

| Metric | 1 Vault (0.05 WBTC) | 10 Vaults (0.005 each) |
|--------|---------------------:|-----------------------:|
| Total collateral | 0.05 WBTC | 0.05 WBTC |
| Monthly withdrawal (total) | 0.0005 WBTC | 0.0005 WBTC |
| Gas cost (total/year) | ~$0.60-0.90 | ~$6.00-9.00 |
| Early redeem flexibility | All or nothing | Granular (per vault) |
| Mint gas cost | 1× | 10× |
| Staggered vesting | No | Yes (if minted over time) |
| Partial position exit | No | Yes (burn individual vaults) |
| Strategy diversification | Single path | Per-vault (separate, hold, redeem) |

### Early Redemption Optionality

During the 1129-day vesting period, early redemption returns collateral proportional to elapsed time (`returned = collateral × elapsed / VESTING_PERIOD` per `VaultMath.sol`).

With 10 vaults at 0.005 WBTC each, a minter needing partial liquidity can redeem 1-2 vaults while keeping 8-9 vaults progressing toward full vesting. This avoids the all-or-nothing choice of a single large vault.

### Gas Overhead

The 10× gas overhead for minting and withdrawals (~$6-9/year vs ~$0.60-0.90/year) remains trivially small relative to collateral value (0.05 WBTC = ~$4,300 at $86K BTC). On L2, this overhead drops to ~$0.60-0.90/year for 10 vaults.

---

## 6. Perpetual Roll-Forward at 0.005 Scale

The perpetual roll-forward strategy from [Long Duration Capital Strategies](./Long_Duration_Capital_Strategies.md) applies identically at 0.005 WBTC scale. The 6.55× net BTC multiplication factor is **scale-invariant** because it derives from percentage-based mechanics.

Scaled from the 1 BTC reference model (assuming 15% vBTC market discount, D=0.85):

| Year | Active Vaults | Total Locked (WBTC) | Total Withdrawn (WBTC) | New Vault Size (WBTC) |
|------|:-------------:|--------------------:|-----------------------:|----------------------:|
| 0 | 1 | 0.005000 | 0 | 0.005000 |
| 3.09 | 2 | 0.009250 | 0 | 0.004250 |
| 6.18 | 3 | 0.011510 | 0.001510 | 0.003613 |
| 15.45 | 6 | 0.015000 | 0.009125 | 0.002200 |
| 30.90 | 11 | 0.016445 | 0.026295 | 0.001000 |
| 50.00 | 16 | 0.016645 | 0.049455 | 0.000500 |

**50-year net alpha:** 0.005 × 6.55 = **0.03275 WBTC** from a single 0.005 WBTC initial mint.

At $86K BTC: $430 initial deposit produces ~$2,817 in cumulative withdrawals over 50 years (BTC-denominated; USD value depends on future BTC price).

A minter starting with 10 vaults (0.05 WBTC total) would generate ~0.3275 WBTC net alpha over 50 years through the same roll-forward mechanics.

---

## References

### Internal
- `contracts/protocol/src/libraries/VaultMath.sol` -- Authoritative constants: WITHDRAWAL_RATE=1000, BASIS_POINTS=100000, VESTING_PERIOD=1129 days
- `contracts/protocol/src/VaultNFT.sol` -- Mint function: only constraint is `collateralAmount > 0`
- [Long Duration Capital Strategies](./Long_Duration_Capital_Strategies.md) -- Perpetual roll-forward model (1 BTC reference)
- [Competitive Positioning](./Competitive_Positioning.md) -- Retail entry point comparisons
- [Withdrawal Rate Stability](./Withdrawal_Rate_Stability.md) -- 12% rate calibration and decay schedule
- [vBTC Pricing Model](./vBTC_Pricing_Model.md) -- Collateral decay formula and market discount modeling
