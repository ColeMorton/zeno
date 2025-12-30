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
    function getCurrentDiscount() external view returns (uint256);  // 18 decimals
}
```

### Position Manager with Flash Loan Looping

Recursive borrowing (looping) is a first-class feature via flash loans for atomic execution.

```solidity
interface IPositionManager {
    struct LeveragedPosition {
        uint256 positionId;
        address owner;
        uint256 initialCollateral;
        uint256 totalCollateral;
        uint256 totalDebt;
        uint256 leverage;           // 18 decimals (2e18 = 2x)
        uint256 openTimestamp;
    }

    /// @notice Open leveraged long position in single transaction
    /// @param collateralAmount Initial wBTC to deposit
    /// @param targetLeverage Desired leverage (1e18 = 1x, 2.5e18 = 2.5x)
    /// @param maxSlippage Maximum acceptable slippage (1e16 = 1%)
    /// @return positionId Unique identifier for the position
    function openLeveragedLong(
        uint256 collateralAmount,
        uint256 targetLeverage,
        uint256 maxSlippage
    ) external returns (uint256 positionId);

    /// @notice Close leveraged position atomically
    /// @param positionId Position to close
    /// @param minCollateralOut Minimum collateral to receive after repaying debt
    /// @return collateralReturned Amount of collateral returned to user
    function closeLeveragedPosition(
        uint256 positionId,
        uint256 minCollateralOut
    ) external returns (uint256 collateralReturned);

    /// @notice Add collateral to reduce leverage
    function addCollateral(uint256 positionId, uint256 amount) external;

    /// @notice Remove excess collateral (maintains health factor > 1.2)
    function removeCollateral(uint256 positionId, uint256 amount) external;

    /// @notice Get position details
    function getPosition(uint256 positionId) external view returns (LeveragedPosition memory);
}
```

### Flash Loan Flow: Leveraged Long

```
User calls: openLeveragedLong(1 wBTC, 2.5e18, 1e16)

┌─────────────────────────────────────────────────────────────┐
│ Step 1: Flash loan 1.5 wBTC from Balancer (zero fee)        │
│         Total: 1 wBTC (user) + 1.5 wBTC (flash) = 2.5 wBTC  │
├─────────────────────────────────────────────────────────────┤
│ Step 2: Deposit 2.5 wBTC as collateral                      │
│         → Lending Pool collateral = 2.5 wBTC                │
├─────────────────────────────────────────────────────────────┤
│ Step 3: Borrow USDC at dynamic LTV                          │
│         At 10% discount: LTV = 65%                          │
│         Borrow: 2.5 × 0.65 × $60,000 = $97,500 USDC         │
├─────────────────────────────────────────────────────────────┤
│ Step 4: Swap USDC → wBTC on Curve/Uniswap                   │
│         $97,500 / $60,000 = 1.625 wBTC                      │
├─────────────────────────────────────────────────────────────┤
│ Step 5: Repay flash loan                                    │
│         Return: 1.5 wBTC + fee                              │
│         Remaining: 1.625 - 1.5 = 0.125 wBTC profit          │
├─────────────────────────────────────────────────────────────┤
│ Step 6: Deposit remaining wBTC as additional collateral     │
│         Final collateral: 2.5 + 0.125 = 2.625 wBTC          │
└─────────────────────────────────────────────────────────────┘

Result:
- Initial deposit: 1 wBTC
- Final collateral: 2.625 wBTC
- Debt: $97,500 USDC
- Effective leverage: ~2.625x
- Single transaction, no MEV exposure
```

### Flash Loan Provider Integration

```solidity
// Balancer V2 Flash Loan (zero-fee)
interface IBalancerVault {
    function flashLoan(
        IFlashLoanRecipient recipient,
        IERC20[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external;
}

contract PositionManager is IFlashLoanRecipient {
    IBalancerVault public immutable balancerVault;

    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external override {
        if (msg.sender != address(balancerVault)) revert UnauthorizedCaller();

        (OperationType opType, bytes memory params) = abi.decode(
            userData,
            (OperationType, bytes)
        );

        if (opType == OperationType.OPEN_LONG) {
            _executeLeveragedLong(tokens, amounts, feeAmounts, params);
        } else if (opType == OperationType.CLOSE_POSITION) {
            _executeClosePosition(tokens, amounts, feeAmounts, params);
        }

        // Repay flash loan
        for (uint256 i = 0; i < tokens.length; i++) {
            tokens[i].safeTransfer(address(balancerVault), amounts[i] + feeAmounts[i]);
        }
    }
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

### Economic Rationale: 12% Floor Requirement

vBTC has a **structural negative carry** due to the 1% monthly (12% annual) withdrawal rate:

```
vBTC Backing Shrinkage: -1.0%/month = -12%/year

If borrow rate < 12%:
├─ Arbitrage: Borrow vBTC at 5% → hold → backing shrinks 12%
├─ Borrower profits from dilution
└─ Protocol bleeds value to borrowers
```

**The base rate must exceed the withdrawal rate** to prevent this arbitrage:

```
minimum_base_rate > annual_withdrawal_rate + risk_premium
minimum_base_rate > 12% + 2% = 14%
```

### Kink-Based Model (vBTC-Adjusted)

```solidity
contract KinkInterestRateModel {
    uint256 public immutable baseRate = 14e16;     // 14% APR (12% carry + 2% margin)
    uint256 public immutable slope1 = 6e16;        // 6% per 100% util
    uint256 public immutable slope2 = 200e16;      // 200% per 100% util above kink
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

| Utilization | Borrow APR | Rationale |
|-------------|------------|-----------|
| 0% | 14.0% | Floor exceeds 12% withdrawal rate |
| 50% | 17.0% | Moderate demand |
| 80% (kink) | 18.8% | Optimal utilization |
| 90% | 38.8% | Scarcity premium |
| 100% | 58.8% | Emergency rate |

### Comparison: Standard vs vBTC-Adjusted

| Utilization | Standard Model | vBTC-Adjusted | Delta |
|-------------|----------------|---------------|-------|
| 0% | 2.0% | 14.0% | +12% |
| 80% | 5.2% | 18.8% | +13.6% |
| 100% | 25.2% | 58.8% | +33.6% |

The elevated rates compensate lenders for the structural dilution of vBTC backing.

---

## 6. Collateral Factors & LTV

### Dynamic LTV Based on Discount

Static LTV is dangerous because vBTC discount volatility compounds with BTC price volatility. When discounts widen during stress, static LTV provides insufficient buffer.

**Solution**: LTV adjusts dynamically based on current vBTC/wBTC discount.

```solidity
contract DynamicLTVCalculator {
    uint256 public immutable baseLTV = 85e16;        // 85% at 0% discount
    uint256 public immutable sensitivity = 2e18;     // 2x sensitivity factor
    uint256 public immutable minLTV = 30e16;         // 30% floor

    function getMaxLTV(uint256 currentDiscount) public pure returns (uint256) {
        // currentDiscount in 18 decimals (e.g., 15e16 = 15%)
        uint256 adjustment = (currentDiscount * sensitivity) / 1e18;

        if (adjustment >= baseLTV - minLTV) {
            return minLTV;
        }
        return baseLTV - adjustment;
    }

    function getLiquidationLTV(uint256 currentDiscount) public pure returns (uint256) {
        // Liquidation LTV = Max LTV + 7% buffer
        return getMaxLTV(currentDiscount) + 7e16;
    }
}
```

### Dynamic LTV Table

| Current Discount | vBTC/wBTC Price | Max LTV | Liq LTV | Liq Bonus |
|------------------|-----------------|---------|---------|-----------|
| 5% | 0.95 | 75% | 82% | 5% |
| 10% | 0.90 | 65% | 72% | 6% |
| 15% | 0.85 | 55% | 62% | 7% |
| 20% | 0.80 | 45% | 52% | 8% |
| 25% | 0.75 | 35% | 42% | 10% |
| 30%+ | ≤0.70 | 30% | 37% | 12% |

### Market-Specific Base Parameters

| Market | Base LTV | Sensitivity | Rationale |
|--------|----------|-------------|-----------|
| wBTC → vBTC borrow | 85% | 2.0x | wBTC stable reference |
| vBTC → USDC borrow | 70% | 2.5x | Dual volatility exposure |
| vBTC → wBTC borrow | 75% | 2.0x | Correlated assets |

### Health Factor

```solidity
function getHealthFactor(address user) public view returns (uint256) {
    Position memory pos = positions[user];
    if (pos.borrowedAmount == 0) return type(uint256).max;

    uint256 collateralValue = getCollateralValue(pos.collateralAmount);
    uint256 borrowValue = getBorrowValue(pos.borrowedAmount);

    // Dynamic LLTV based on current discount
    uint256 currentDiscount = oracle.getCurrentDiscount();
    uint256 dynamicLLTV = getLiquidationLTV(currentDiscount);

    // HF = (Collateral × Dynamic LLTV) / Borrow
    // HF > 1 = healthy, HF < 1 = liquidatable
    return (collateralValue * dynamicLLTV) / borrowValue;
}
```

### Rationale

- **Wider discount = Lower LTV**: More buffer when volatility is high
- **Tighter discount = Higher LTV**: Capital efficiency when stable
- **Continuous adjustment**: No discrete jumps that could cause cascade liquidations

---

## 7. Liquidation Mechanism

### Dutch Auction Liquidation

Circuit breakers (hourly caps) are replaced with gradual Dutch auctions to prevent bad debt accumulation during liquidation queues.

**Why Dutch Auction over Circuit Breaker**:

| Approach | Problem |
|----------|---------|
| Circuit breaker (10%/hr cap) | Liquidations queue up → price continues falling → bad debt |
| Dutch auction (no cap) | Market-driven clearing → patient liquidators → less slippage |

### Auction Flow

```
Health Factor < 1.0
        │
        ▼
┌─────────────────────────────────────────┐
│           DUTCH AUCTION STARTS          │
│                                         │
│  Time 0:    Bonus = 0%                  │
│  Time 15m:  Bonus = 3.75%               │
│  Time 30m:  Bonus = 7.5%                │
│  Time 45m:  Bonus = 11.25%              │
│  Time 60m:  Bonus = 15% (max)           │
│                                         │
│  Liquidator claims when bonus > gas     │
└─────────────────────────────────────────┘
```

### Implementation

```solidity
struct DutchAuction {
    uint256 startTime;
    uint256 startBonus;         // 0%
    uint256 endBonus;           // 15%
    uint256 duration;           // 60 minutes
    uint256 debtToRepay;
    uint256 collateralAvailable;
    bool active;
}

mapping(address => DutchAuction) public auctions;

function getCurrentBonus(address borrower) public view returns (uint256) {
    DutchAuction memory auction = auctions[borrower];
    if (!auction.active) return 0;

    uint256 elapsed = block.timestamp - auction.startTime;
    if (elapsed >= auction.duration) {
        return auction.endBonus;
    }

    // Linear interpolation: 0% → 15% over 60 minutes
    return (auction.endBonus * elapsed) / auction.duration;
}

function startAuction(address borrower) external {
    uint256 healthFactor = getHealthFactor(borrower);
    if (healthFactor >= 1e18) revert PositionHealthy();
    if (auctions[borrower].active) revert AuctionAlreadyActive();

    Position memory pos = positions[borrower];

    auctions[borrower] = DutchAuction({
        startTime: block.timestamp,
        startBonus: 0,
        endBonus: 15e16,        // 15%
        duration: 60 minutes,
        debtToRepay: pos.borrowedAmount,
        collateralAvailable: pos.collateralAmount,
        active: true
    });

    emit AuctionStarted(borrower, pos.borrowedAmount, pos.collateralAmount);
}

function liquidateAuction(address borrower, uint256 repayAmount) external {
    DutchAuction storage auction = auctions[borrower];
    if (!auction.active) revert NoActiveAuction();

    uint256 bonus = getCurrentBonus(borrower);
    uint256 collateralSeized = (repayAmount * (1e18 + bonus)) / 1e18;

    if (collateralSeized > auction.collateralAvailable) {
        revert InsufficientCollateral();
    }

    // Transfer debt token from liquidator
    debtToken.safeTransferFrom(msg.sender, address(this), repayAmount);

    // Transfer collateral to liquidator
    collateralToken.safeTransfer(msg.sender, collateralSeized);

    // Update auction state
    auction.debtToRepay -= repayAmount;
    auction.collateralAvailable -= collateralSeized;

    // Update position
    positions[borrower].borrowedAmount -= repayAmount;
    positions[borrower].collateralAmount -= collateralSeized;

    // Close auction if fully liquidated
    if (auction.debtToRepay == 0) {
        auction.active = false;
    }

    emit AuctionLiquidation(borrower, msg.sender, repayAmount, collateralSeized, bonus);
}
```

### Auction Parameters

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Start Bonus | 0% | No premium at start |
| End Bonus | 15% | Max incentive after 60 min |
| Duration | 60 min | Allows price discovery |
| Partial Liquidation | Yes | Multiple liquidators can participate |

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
| **Discount Volatility** | vBTC/BTC can swing 5-15% | Dynamic LTV based on current discount |
| **Liquidity Spiral** | Forced selling widens discount | Dutch auction: gradual bonus incentivizes patient liquidators |
| **Oracle Manipulation** | DEX liquidity may be thin | 30-min TWAP, staleness check, fail-fast bounds |
| **Underlying BTC Risk** | Wrapped BTC custody failure | Isolated markets per collateral type |
| **Bad Debt** | Position insolvent before liquidation | Reserve fund from 10% of interest |
| **Negative Carry** | vBTC shrinks 12%/year | 14%+ base interest rate floor |

### Reserve Fund Mechanism

```solidity
uint256 public constant RESERVE_FACTOR = 10e16;  // 10% of interest

function accrueInterest() internal {
    uint256 interestAccrued = calculateInterest();
    uint256 reserveAmount = (interestAccrued * RESERVE_FACTOR) / 1e18;

    reserveFund += reserveAmount;
    totalSupply += interestAccrued - reserveAmount;
}

function coverBadDebt(address borrower) external {
    Position memory pos = positions[borrower];
    if (pos.collateralAmount > 0) revert HasCollateral();

    uint256 badDebt = pos.borrowedAmount;
    if (badDebt > reserveFund) revert InsufficientReserves();

    reserveFund -= badDebt;
    positions[borrower].borrowedAmount = 0;

    emit BadDebtCovered(borrower, badDebt);
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
| `contracts/protocol/src/interfaces/IVaultNFT.sol` | Withdrawal event definitions |
| `docs/protocol/Technical_Specification.md` | Layer 3 DeFi vision |

---

## 12. Protocol Event Integration

### Withdrawal Event Subscription

The lending protocol monitors VaultNFT withdrawal events to track collateral changes for vBTC-backed positions. This is critical because vBTC backing shrinks with each withdrawal.

**Events Subscribed (from IVaultNFT)**:

```solidity
// Emitted when Vault owner withdraws collateral
event Withdrawn(
    uint256 indexed tokenId,
    address indexed to,
    uint256 amount
);

// Emitted when delegate withdraws on behalf of owner
event DelegatedWithdrawal(
    uint256 indexed tokenId,
    address indexed delegate,
    address indexed owner,
    uint256 amount
);
```

### Indexer Integration Flow

```
VaultNFT.withdraw() or withdrawAsDelegate()
        │
        ├─ Emits Withdrawn/DelegatedWithdrawal event
        │
        ▼
Lending Protocol Indexer (off-chain)
        │
        ├─ Maps vaultTokenId → vBTC amount
        ├─ Calculates new collateral ratio
        │
        ▼
┌───────────────────────────────────────┐
│ If significant withdrawal detected:   │
│                                       │
│ 1. Update collateral valuations       │
│ 2. Recalculate health factors         │
│ 3. Trigger liquidation if HF < 1.0    │
│ 4. Adjust interest rate model inputs  │
└───────────────────────────────────────┘
```

### On-Chain Oracle Update

```solidity
interface IVBTCCollateralOracle {
    /// @notice Update collateral amount for a specific Vault
    /// @dev Called by authorized indexer after detecting withdrawal event
    function updateCollateralValue(
        uint256 vaultTokenId,
        uint256 newCollateralAmount
    ) external;

    /// @notice Get current backing ratio for vBTC from a specific Vault
    function getBackingRatio(uint256 vaultTokenId) external view returns (uint256);
}
```

### Cross-Reference

See [Technical Specification - Post-Vesting Withdrawals](../protocol/Technical_Specification.md) for Vault withdrawal mechanics and event definitions.

---

## Summary

This architecture enables leveraged vBTC positions via isolated CDP lending markets. The design:

1. **Mirrors inverse perpetual mechanics** using CDP over-collateralization
2. **Maintains risk isolation** per collateral type (wBTC, cbBTC, tBTC)
3. **Uses fail-fast DEX TWAP oracles** with no fallbacks
4. **Aligns with immutability principles** of the core BTCNFT Protocol
5. **Enables synthetic longs** (profit if discount narrows) and **shorts** (profit if discount widens)
6. **Accounts for negative carry** via 14%+ base interest rate floor
7. **Adapts to market conditions** via dynamic LTV based on discount
8. **Provides atomic leverage** via flash loan-powered PositionManager
9. **Uses market-driven liquidations** via Dutch auctions instead of circuit breakers

Interest rates exceed the 12% annual withdrawal rate to prevent arbitrage. Dynamic LTV adjusts with discount levels. Dutch auctions replace circuit breakers for smoother liquidations. The 30-minute TWAP provides manipulation resistance comparable to perp mark prices.
