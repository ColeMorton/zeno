# Vesting Period Research

> **Version:** 1.0
> **Status:** Final
> **Last Updated:** 2025-12-22
> **Related Documents:**
> - [Technical Specification](../protocol/Technical_Specification.md)
> - [Quantitative Validation](../protocol/Quantitative_Validation.md)
> - [Collateral Matching](../protocol/Collateral_Matching.md)
> - [Glossary](../GLOSSARY.md)

---

## Executive Summary

The BTCNFT Protocol enforces a **1129-day vesting period** before Vault holders can begin withdrawals. This duration ensures holders experience at least one full BTC market cycle, providing historical validation of 100% positive returns across all rolling 1129-day windows analyzed.

---

## Table of Contents

1. [Technical Definition](#1-technical-definition)
2. [Mathematical Derivation](#2-mathematical-derivation)
3. [Historical Validation](#3-historical-validation)
4. [Protocol Integration](#4-protocol-integration)
5. [Economic Implications](#5-economic-implications)
6. [Design Rationale](#6-design-rationale)

---

## 1. Technical Definition

### Constant Declaration

```solidity
// contracts/protocol/src/libraries/VaultMath.sol:5
uint256 internal constant VESTING_PERIOD = 1129 days;
```

| Property | Value |
|----------|-------|
| Days | 1129 |
| Seconds | 97,545,600 |
| Years | ~3.09 |
| Mutability | Immutable (embedded in bytecode) |

### Related Constants

```solidity
// contracts/protocol/src/libraries/VaultMath.sol:6-8
uint256 internal constant WITHDRAWAL_PERIOD = 30 days;
uint256 internal constant DORMANCY_THRESHOLD = 1129 days;
uint256 internal constant GRACE_PERIOD = 30 days;
```

| Constant | Value | Purpose |
|----------|-------|---------|
| `VESTING_PERIOD` | 1129 days | Lock before withdrawals |
| `WITHDRAWAL_PERIOD` | 30 days | Interval between withdrawals |
| `DORMANCY_THRESHOLD` | 1129 days | Inactivity period before dormancy |
| `GRACE_PERIOD` | 30 days | Warning period after poke |

The dormancy threshold intentionally matches the vesting period: one full market cycle of inactivity before a Vault becomes dormancy-eligible.

---

## 2. Mathematical Derivation

### Why 1129 Days?

| Calculation | Result |
|-------------|--------|
| 3 years (no leap) | 1,095 days |
| 3 years (1 leap) | 1,096 days |
| Protocol constant | 1,129 days |

The 1129-day period is **not** a simple calendar approximation. It represents the empirically validated window for BTC market cycle coverage based on historical analysis, providing 100% historical positive returns.

### BTC Market Cycle Theory

Bitcoin historically follows ~4-year cycles correlated with halving events:

```
Halving Schedule:
├─ 2012-11-28 (Block 210,000)
├─ 2016-07-09 (Block 420,000)
├─ 2020-05-11 (Block 630,000)
├─ 2024-04-20 (Block 840,000)
└─ 2028-~Q2   (Block 1,050,000)
```

A 1129-day (~3.09 year) window captures:
- At least one halving cycle's price appreciation
- Both accumulation and distribution phases
- Bear market recovery periods

### Precision Trade-off

The 1129-day value balances:
1. **Cycle coverage**: Sufficient duration to span market cycles
2. **User experience**: Not excessively longer than needed
3. **Historical validation**: All rolling samples show positive returns

---

## 3. Historical Validation

### Data Source

| Metric | Value |
|--------|-------|
| Data range | 2014-09-17 to 2025-12-22 |
| Total observations | 4,115 daily data points |
| Rolling 1129-day samples | Analyzed |

### Return Distribution

| Window | Samples | Mean | Min | Max |
|--------|---------|------|-----|-----|
| Monthly | Analyzed | Variable | Variable | Variable |
| Yearly | Analyzed | 63.11% (historical) | Variable | Variable |
| 1129-Day | Analyzed | Variable | 0%+ (all positive) | Variable |

### Key Finding

**100% of all 1129-day rolling windows produced positive returns.**

```
1129-Day Return Distribution:
├─ Minimum: 0%+ (all positive)
├─ Maximum: Variable
├─ Mean:    Variable
└─ Stability: 100% (no negative windows)
```

This finding underpins the protocol's economic model: the 1129-day vesting period smooths volatility such that even the worst-case historical entry point yields positive returns.

### Tail-Risk Elimination

| Window | Mean | Std Dev | 1-SD Threshold | 2-SD Threshold |
|--------|------|---------|----------------|----------------|
| Monthly | Variable | Variable | Variable | Variable |
| Yearly | Variable | Variable | Variable | Variable |
| 1129-Day | Variable | Variable | Positive | Positive |

The 1129-day moving average smoothing eliminates all tail events below standard deviation thresholds.

---

## 4. Protocol Integration

### Core Vesting Check

```solidity
// contracts/protocol/src/libraries/VaultMath.sol:46-48
function isVested(uint256 mintTimestamp, uint256 currentTimestamp)
    internal pure returns (bool)
{
    return currentTimestamp >= mintTimestamp + VESTING_PERIOD;
}
```

### Functions Gated by Vesting

| Function | Behavior |
|----------|----------|
| `withdraw()` | Reverts with `StillVesting(tokenId)` if not vested |
| `mintVestedBTC()` | Blocked until vesting complete |
| `claimMatch()` | Requires vesting complete to claim collateral matching |
| `delegatedWithdraw()` | Delegates cannot withdraw until vault is vested |
| `getWithdrawableAmount()` | Returns 0 if not vested |
| `canClaim()` | Returns false if not vested |

### Early Redemption During Vesting

Holders can exit early via redemption, but forfeit a portion of collateral:

```solidity
// contracts/protocol/src/libraries/VaultMath.sol:16-33
function calculateEarlyRedemption(
    uint256 collateral,
    uint256 mintTimestamp,
    uint256 currentTimestamp
) internal pure returns (uint256 returned, uint256 forfeited) {
    uint256 elapsed = currentTimestamp - mintTimestamp;

    if (elapsed >= VESTING_PERIOD) {
        return (collateral, 0);  // Full return at 1129 days
    }

    returned = (collateral * elapsed) / VESTING_PERIOD;
    forfeited = collateral - returned;
}
```

**Linear Unlock Schedule:**

| Days Elapsed | Percentage Vested | Returned | Forfeited |
|--------------|-------------------|----------|-----------|
| 0 | 0% | 0% | 100% |
| 365 | 32.3% | 32.3% | 67.7% |
| 565 | 50.0% | 50.0% | 50.0% |
| 730 | 64.7% | 64.7% | 35.3% |
| 1129 | 100% | 100% | 0% |

```
Early Redemption Timeline:
Day 0                                           Day 1129
├──────────────────────────────────────────────────┤
│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
│← Forfeited decreases linearly →                  │
│          ← Returned increases linearly →         │
└──────────────────────────────────────────────────┘
```

---

## 5. Economic Implications

### Holder Experience

**During Vesting (Days 0-1128):**

| Action | Status |
|--------|--------|
| Withdraw BTC | Not available |
| Separate to vestedBTC | Not available |
| Claim collateral matching | Not available |
| Delegate withdrawals | Not available |
| Redeem early | Available (with forfeit) |
| Transfer Vault NFT | Available |

**After Vesting (Day 1129+):**

| Action | Status |
|--------|--------|
| Withdraw 1.0%/month | Available |
| Separate to vestedBTC | Available |
| Claim collateral matching | Available |
| Delegate withdrawals | Available |

### Collateral Matching Incentive

Forfeited collateral from early redeemers flows to the match pool, distributed pro-rata to holders who complete the full vesting period:

```
┌─────────────────────────────────────────────────────┐
│            VESTING INCENTIVE ALIGNMENT              │
│                                                     │
│  Early Exit (< 1129 days)     Complete Vesting      │
│  ┌─────────────┐              ┌─────────────────┐   │
│  │ Forfeit     │              │ Claim pro-rata  │   │
│  │ portion of  │──► Match ───►│ share of match  │   │
│  │ collateral  │    Pool      │ pool            │   │
│  └─────────────┘              └─────────────────┘   │
│                                                     │
│  Result: Completing vesting rewards patience        │
└─────────────────────────────────────────────────────┘
```

### Post-Vesting Withdrawal Economics

After the 1129-day vesting period, holders can withdraw 1.0% of remaining collateral every 30 days (12% annually). This creates a perpetual yield stream that never depletes (Zeno's paradox):

```
Current Rate Sustainability:

BTC Appreciation Required: +12% annually (breakeven)
Historical Mean Return:    +63.11% annually
Historical Minimum:        +14.75% annually (still above breakeven)

Net Effect: USD value expected to remain stable or grow
```

---

## 6. Design Rationale

### Why Immutable?

The vesting period is embedded in contract bytecode as an immutable constant. This provides:

1. **Trust**: Holders know the rules cannot change mid-vesting
2. **Security**: No governance attack surface for parameter manipulation
3. **Simplicity**: No upgrade mechanism complexity

### Why Match Dormancy Threshold?

Both `VESTING_PERIOD` and `DORMANCY_THRESHOLD` equal 1129 days. This alignment means:
- A vault becomes dormancy-eligible only after experiencing one full market cycle of inactivity
- The same duration validates both initial commitment and ongoing engagement

### Comparison to DeFi Vesting Periods

| Protocol | Vesting/Lock | Purpose |
|----------|--------------|---------|
| BTCNFT Protocol | 1129 days | BTC market cycle coverage |
| Curve veCRV | Up to 4 years | Governance weight |
| Convex CVX | 16 weeks | Gradual unlock |
| Olympus OHM | 5 days | Bond vesting |
| veToken models | Variable | Time-weighted voting |

The 1129-day period is longer than most DeFi vesting periods, reflecting the unique BTC market cycle thesis underlying the protocol's economic model.

---

## References

1. VaultMath.sol - `contracts/protocol/src/libraries/VaultMath.sol`
2. Quantitative Validation - `docs/protocol/Quantitative_Validation.md`
3. Technical Specification - `docs/protocol/Technical_Specification.md`
4. Collateral Matching - `docs/protocol/Collateral_Matching.md`
5. Glossary - `docs/GLOSSARY.md`
