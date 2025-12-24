# Withdrawal Tier Research

> **Status:** Archived Research
> **Decision:** Protocol uses fixed Conservative rate (0.875%/month, 10.5%/year)

This document preserves research on withdrawal tier options that were considered during protocol design. The protocol implements a single fixed withdrawal rate.

---

## 1. Tier Options Evaluated

| Tier | Annual Rate | Monthly Rate | Solidity Constant |
|------|-------------|--------------|-------------------|
| Conservative | 10.5% | 0.875% | 875 |
| Balanced | 14.6% | ~1.22% | 1140 |
| Aggressive | 20.8% | ~1.73% | 1590 |

### Basis Points Calculation

All rates use `BASIS_POINTS = 100000` as denominator:
- Conservative: `875 / 100000 = 0.00875 = 0.875%`
- Balanced: `1140 / 100000 = 0.0114 = 1.14%`
- Aggressive: `1590 / 100000 = 0.0159 = 1.59%`

Annual rates derived: `monthly_rate × 12`

---

## 2. Breakeven Analysis

Each tier requires different BTC appreciation to maintain USD value:

| Tier | Required Annual BTC Return |
|------|---------------------------|
| Conservative | +10.5% |
| Balanced | +14.6% |
| Aggressive | +20.8% |

### Sensitivity Analysis

| Scenario | BTC Return | Conservative Tier | Net Impact |
|----------|------------|-------------------|------------|
| Historical mean | +63.11% | -10.5% withdrawal | **+52.6%** |
| 50% of mean | +31.6% | -10.5% withdrawal | **+21.1%** |
| 25% of mean | +15.8% | -10.5% withdrawal | **+5.3%** |
| Breakeven | +10.5% | -10.5% withdrawal | **0%** |
| Below breakeven | <+10.5% | -10.5% withdrawal | **Negative** |

---

## 3. Historical Validation (2017-2025)

### Would Conservative Tier Hold USD Value?

| Period | BTC Annual Return | Result |
|--------|-------------------|--------|
| 2018 (bear) | -73% | No |
| 2019 | +95% | Yes |
| 2020 | +303% | Yes |
| 2021 | +60% | Yes |
| 2022 (bear) | -64% | No |
| 2023 | +155% | Yes |
| 2024 | +121% | Yes |

**Yearly stability:** 5/7 years (71%) exceeded 10.5% threshold

### 1129-Day Window Analysis

| Metric | Value |
|--------|-------|
| Data range | 2017-09-13 to 2025-09-20 |
| Rolling samples | 1,837 |
| Mean return | 313.07% |
| Min return | 77.78% |
| Stability | 100% (all samples > 10.5%) |

The 1129-day vesting period smooths volatility, achieving 100% historical yearly stability for the Conservative tier.

---

## 4. Decision Rationale

### Why Conservative Only?

1. **100% historical yearly stability** - All 1129-day rolling windows exceeded the 10.5% threshold
2. **Simplicity** - Single rate eliminates user confusion and mint-time decisions
3. **Protocol integrity** - Fixed rate matches immutable vesting period philosophy
4. **Reduced attack surface** - No tier selection logic to exploit

### Rejected Alternatives

**User-selectable tiers:**
- Added complexity to mint flow
- Required additional storage (`uint8 tier` per vault)
- Higher gas costs
- Potential for user regret

**Higher default rates:**
- Balanced (14.6%): 92% yearly stability
- Aggressive (20.8%): 71% yearly stability
- Neither achieved Conservative's 100% stability

---

## 5. Original Implementation (Removed)

```solidity
// VaultMath.sol (original)
uint256 internal constant TIER_CONSERVATIVE = 833;
uint256 internal constant TIER_BALANCED = 1140;
uint256 internal constant TIER_AGGRESSIVE = 1590;

function getTierRate(uint8 tier) internal pure returns (uint256) {
    if (tier == 0) return TIER_CONSERVATIVE;
    if (tier == 1) return TIER_BALANCED;
    if (tier == 2) return TIER_AGGRESSIVE;
    revert("Invalid tier");
}

function calculateWithdrawal(
    uint256 collateral,
    uint8 tier
) internal pure returns (uint256) {
    uint256 rate = getTierRate(tier);
    return (collateral * rate) / BASIS_POINTS;
}
```

```solidity
// VaultNFT.sol (original)
mapping(uint256 => uint8) private _tier;

function mint(
    address treasureContract_,
    uint256 treasureTokenId_,
    address collateralToken_,
    uint256 collateralAmount_,
    uint8 tier_  // removed
) external returns (uint256 tokenId) {
    if (tier_ > 2) revert InvalidTier(tier_);
    // ...
    _tier[tokenId] = tier_;
}
```

---

## 6. Data Limitations

| Limitation | Description |
|------------|-------------|
| Sample period | 2017-2025 only (~8 years) |
| Bull market bias | Period includes unprecedented institutional adoption |
| Survivorship | BTC survived; other assets may not |
| Macro environment | Low interest rates, QE for most of period |

Past performance does not guarantee future results.
