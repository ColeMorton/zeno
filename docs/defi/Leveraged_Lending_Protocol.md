# Leveraged vestedBTC Lending Protocol Architecture

## Overview

Design a standalone lending protocol enabling leveraged long and short vestedBTC (vBTC) positions using wBTC, cbBTC, and tBTC as collateral via over-collateralized CDP mechanics.

**Scope**: Design & Architecture Only
**Integration**: Standalone Protocol (immutable, no governance)
**Collateral**: All three variants (wBTC, cbBTC, tBTC)
**Oracle**: DEX TWAP Only (fail-fast)

---

## 1. Economic Model

### vBTC Discount Dynamics

vestedBTC trades at a **structural discount** to BTC due to:
- 1129-day vesting lock (time value of money)
- 1% monthly withdrawal rate (illiquidity premium)
- Discount narrows as vesting approaches completion

**Expected discount range**: 5-25% depending on market conditions and time to vest.

### Synthetic Positions via CDP

| Position | Thesis | Mechanism |
|----------|--------|-----------|
| **Long vBTC** | Discount is too steep / will narrow | Deposit wBTC → Borrow stablecoins → Buy vBTC |
| **Short vBTC** | Discount will widen | Deposit wBTC → Borrow vBTC → Sell vBTC |

### Inverse Perpetual Analogy

- Using wBTC collateral to trade vBTC mirrors BTC-margined inverse perps
- Interest rates on borrowed assets = funding rate equivalent
- Liquidation LTV = maintenance margin equivalent

---

## 2. Pool Architecture: Isolated Markets

Following BTCNFT Protocol's 1:1 deployment per collateral type for **risk isolation**.

```
┌─────────────────────────────────────────────────────────────────┐
│                 ISOLATED LENDING MARKETS                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │ vWBTC Market    │  │ vCBBTC Market   │  │ vTBTC Market    │ │
│  │                 │  │                 │  │                 │ │
│  │ Collateral: wBTC│  │ Collateral:cbBTC│  │ Collateral: tBTC│ │
│  │ Borrow: vWBTC   │  │ Borrow: vCBBTC  │  │ Borrow: vTBTC   │ │
│  │ Oracle: TWAP    │  │ Oracle: TWAP    │  │ Oracle: TWAP    │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │ Stablecoin Pool │  │ Stablecoin Pool │  │ Stablecoin Pool │ │
│  │                 │  │                 │  │                 │ │
│  │ Collateral:vWBTC│  │ Collateral:vCBBTC│ │ Collateral:vTBTC│ │
│  │ Borrow: USDC    │  │ Borrow: USDC    │  │ Borrow: USDC    │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

**Rationale**: Risk contagion is eliminated - a vWBTC crisis does not affect vTBTC markets.

---

## 3. Contract Structure

```
contracts/lending/
├── src/
│   ├── VBTCLendingPool.sol           # Core lending per market
│   ├── VBTCOracleUniswapV3.sol       # TWAP from Uniswap V3
│   ├── VBTCOracleCurve.sol           # TWAP from Curve pool
│   ├── KinkInterestRateModel.sol     # Utilization-based rates
│   ├── LiquidationEngine.sol         # DEX-first liquidation
│   ├── PositionManager.sol           # Leveraged position tracking
│   └── interfaces/
│       ├── IVBTCLendingPool.sol
│       ├── IVBTCOracle.sol
│       └── IInterestRateModel.sol
└── test/
```

### Core Interfaces

```solidity
interface IVBTCLendingPool {
    struct Position {
        uint256 collateralAmount;
        uint256 borrowedAmount;
        uint256 borrowIndex;
        uint256 lastUpdateTimestamp;
    }

    // Supply liquidity (lenders)
    function supply(uint256 amount) external returns (uint256 shares);
    function withdraw(uint256 shares) external returns (uint256 amount);

    // Borrow against collateral (borrowers)
    function depositCollateral(uint256 amount) external;
    function withdrawCollateral(uint256 amount) external;
    function borrow(uint256 amount) external;
    function repay(uint256 amount) external;

    // Liquidation
    function liquidate(address borrower, uint256 repayAmount)
        external returns (uint256 collateralSeized);

    // View functions
    function getPosition(address user) external view returns (Position memory);
    function getHealthFactor(address user) external view returns (uint256);
}

interface IVBTCOracle {
    function getPrice() external view returns (uint256 price);  // 18 decimals
    function getTWAP(uint32 period) external view returns (uint256 price);
}
```

---

## 4. Oracle Design: DEX TWAP

### Architecture

```solidity
contract VBTCOracleUniswapV3 is IVBTCOracle {
    IUniswapV3Pool public immutable pool;
    uint32 public immutable twapPeriod;  // 30 minutes

    uint256 constant MIN_PRICE = 0.5e18;   // 50% floor
    uint256 constant MAX_PRICE = 1.0e18;   // 100% ceiling
    uint256 constant MAX_STALENESS = 1 hours;

    function getPrice() external view returns (uint256 price) {
        price = getTWAP(twapPeriod);

        // Fail-fast on out-of-bounds price
        if (price < MIN_PRICE || price > MAX_PRICE) {
            revert PriceOutOfBounds(price);
        }
    }

    function getTWAP(uint32 period) public view returns (uint256) {
        // Check staleness - fail fast if stale
        (,, uint16 observationIndex,,,) = pool.slot0();
        (uint32 blockTimestamp,,,) = pool.observations(observationIndex);
        if (block.timestamp - blockTimestamp > MAX_STALENESS) {
            revert OracleStale(blockTimestamp);
        }

        // Calculate TWAP from tick cumulatives
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = period;
        secondsAgos[1] = 0;

        (int56[] memory tickCumulatives,) = pool.observe(secondsAgos);
        int24 arithmeticMeanTick = int24(
            (tickCumulatives[1] - tickCumulatives[0]) / int56(uint56(period))
        );

        return TickMath.getSqrtRatioAtTick(arithmeticMeanTick).toPrice();
    }
}
```

### Parameters

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| TWAP Period | 30 min | Balance manipulation resistance vs responsiveness |
| Max Staleness | 1 hour | Fail-fast on illiquid conditions |
| Min Price | 0.50 | vBTC cannot trade below 50% of BTC |
| Max Price | 1.00 | vBTC cannot exceed BTC price |

---

## 5. Interest Rate Model

### Kink-Based Model

```solidity
contract KinkInterestRateModel {
    uint256 public immutable baseRate = 2e16;      // 2% APR
    uint256 public immutable slope1 = 4e16;        // 4% per 100% util
    uint256 public immutable slope2 = 100e16;      // 100% per 100% util above kink
    uint256 public immutable kink = 80e16;         // 80% utilization

    function getBorrowRate(uint256 totalSupply, uint256 totalBorrow)
        external view returns (uint256)
    {
        if (totalSupply == 0) return baseRate;

        uint256 utilization = (totalBorrow * 1e18) / totalSupply;

        if (utilization <= kink) {
            return baseRate + (utilization * slope1) / 1e18;
        } else {
            uint256 normalRate = baseRate + (kink * slope1) / 1e18;
            uint256 excessUtil = utilization - kink;
            return normalRate + (excessUtil * slope2) / 1e18;
        }
    }
}
```

### Rate Curve

| Utilization | Borrow APR |
|-------------|------------|
| 0% | 2.0% |
| 50% | 4.0% |
| 80% (kink) | 5.2% |
| 90% | 15.2% |
| 100% | 25.2% |

---

## 6. Collateral Factors & LTV

### Risk Parameters

| Market | Max LTV | Liq LTV | Liq Bonus |
|--------|---------|---------|-----------|
| wBTC → vBTC borrow | 85% | 90% | 5% |
| vBTC → USDC borrow | 70% | 80% | 8% |
| vBTC → wBTC borrow | 80% | 85% | 6% |

### Rationale

- **wBTC as collateral (shorting vBTC)**: High LTV because wBTC is stable reference; vBTC discount provides additional buffer
- **vBTC as collateral (longing vBTC)**: Lower LTV due to dual volatility (BTC price + discount volatility)

### Health Factor

```solidity
function getHealthFactor(address user) public view returns (uint256) {
    Position memory pos = positions[user];
    if (pos.borrowedAmount == 0) return type(uint256).max;

    uint256 collateralValue = getCollateralValue(pos.collateralAmount);
    uint256 borrowValue = getBorrowValue(pos.borrowedAmount);

    // HF = (Collateral × LLTV) / Borrow
    // HF > 1 = healthy, HF < 1 = liquidatable
    return (collateralValue * lltv) / borrowValue;
}
```

---

## 7. Liquidation Mechanism

### Hybrid: DEX-First with Dutch Auction Fallback

```
Health Factor < 1.0
        │
        ▼
┌─────────────────┐
│ Check DEX       │
│ Liquidity       │
└────────┬────────┘
         │
   ┌─────┴─────┐
   │           │
   ▼           ▼
Sufficient   Insufficient
(>95%)       (<95%)
   │           │
   ▼           ▼
┌──────────┐ ┌──────────────┐
│ Instant  │ │ Dutch        │
│ DEX Swap │ │ Auction      │
│ 5% bonus │ │ 0% → 15%     │
└──────────┘ │ over 30 min  │
             └──────────────┘
```

### Implementation

```solidity
function liquidate(address borrower, uint256 repayAmount) external {
    uint256 healthFactor = getHealthFactor(borrower);
    if (healthFactor >= 1e18) revert PositionHealthy();

    uint256 dexLiquidity = checkDEXLiquidity(repayAmount);

    if (dexLiquidity >= repayAmount * 95 / 100) {
        // Instant liquidation via DEX
        uint256 bonus = liquidationBonus;  // 5%
        uint256 collateralSeized = (repayAmount * (100 + bonus)) / 100;

        executeSwap(borrower, repayAmount, collateralSeized);
    } else {
        // Start Dutch auction
        startAuction(borrower, repayAmount);
    }
}
```

---

## 8. Position Data Flows

### Synthetic Long vBTC (Profit if discount narrows)

```
Step 1: Deposit wBTC as collateral
        User (1 wBTC) → Stablecoin Market → depositCollateral()

Step 2: Borrow USDC at 70% LTV
        User ← 50,000 USDC ← Stablecoin Market

Step 3: Buy vBTC on DEX
        User (50k USDC) → Curve/Uniswap → 0.84 vWBTC (at 15% discount)

Result:
- Collateral: 1 wBTC ($70,000)
- Debt: 50,000 USDC
- Acquired: ~0.84 vWBTC
- Effective Exposure: ~1.84x long vBTC
```

### Synthetic Short vBTC (Profit if discount widens)

```
Step 1: Deposit wBTC as collateral
        User (1 wBTC) → vBTC Lending Market → depositCollateral()

Step 2: Borrow vBTC at 85% LTV
        User ← 0.8 vWBTC ← vBTC Lending Market

Step 3: Sell vBTC on DEX
        User (0.8 vWBTC) → Curve/Uniswap → 0.68 wBTC (at 15% discount)

Result:
- Collateral: 1 wBTC
- Debt: 0.8 vWBTC
- Received: ~0.68 wBTC
- Net Position: Short 0.8 vBTC
```

---

## 9. Risk Matrix

| Risk | Description | Mitigation |
|------|-------------|------------|
| **Discount Volatility** | vBTC/BTC can swing 5-15% | Lower LTV than standard |
| **Liquidity Spiral** | Forced selling widens discount | Circuit breaker: max 10% liquidation/hour |
| **Oracle Manipulation** | DEX liquidity may be thin | 30-min TWAP, staleness check |
| **Underlying BTC Risk** | Wrapped BTC custody failure | Isolated markets per collateral |
| **Bad Debt** | Position insolvent before liquidation | Reserve fund from 10% of interest |

### Circuit Breakers

```solidity
uint256 public constant MAX_HOURLY_LIQUIDATION = 10;  // 10% of pool
uint256 public hourlyLiquidated;
uint256 public lastHourReset;

modifier liquidationThrottle(uint256 amount) {
    if (block.timestamp > lastHourReset + 1 hours) {
        hourlyLiquidated = 0;
        lastHourReset = block.timestamp;
    }

    uint256 poolSize = totalCollateral;
    if (hourlyLiquidated + amount > poolSize * MAX_HOURLY_LIQUIDATION / 100) {
        revert LiquidationThrottled();
    }

    hourlyLiquidated += amount;
    _;
}
```

---

## 10. Immutability Alignment

Following BTCNFT Protocol philosophy:

| Aspect | Design Choice |
|--------|---------------|
| Admin functions | None |
| Parameter changes | Impossible after deployment |
| Upgradability | None - new deployment required |
| Governance token | None |
| Oracle fallback | None - fail-fast only |

All parameters are `immutable` constants set at deployment time.

---

## 11. Critical Files Reference

| File | Relevance |
|------|-----------|
| `contracts/protocol/src/BtcToken.sol` | vBTC token interface for borrowing |
| `contracts/protocol/src/VaultNFT.sol` | vBTC minting mechanics |
| `contracts/protocol/src/libraries/VaultMath.sol` | Withdrawal rate constants |
| `docs/protocol/Technical_Specification.md` | Layer 3 DeFi vision |

---

## Summary

This architecture enables leveraged vBTC positions via isolated CDP lending markets. The design:

1. **Mirrors inverse perpetual mechanics** using CDP over-collateralization
2. **Maintains risk isolation** per collateral type (wBTC, cbBTC, tBTC)
3. **Uses fail-fast DEX TWAP oracles** with no fallbacks
4. **Aligns with immutability principles** of the core BTCNFT Protocol
5. **Enables synthetic longs** (profit if discount narrows) and **shorts** (profit if discount widens)

Interest rates act as funding rate equivalents, liquidation LTV maps to maintenance margin, and the 30-minute TWAP provides manipulation resistance comparable to perp mark prices.
