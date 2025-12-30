# vestedBTC Derivatives Suite

## Overview

The vestedBTC Derivatives Suite provides comprehensive financial exposure mechanisms for vestedBTC holders. This unified specification consolidates three interconnected products enabling price, volume, and volatility exposure.

**Design Philosophy:**
- Immutable contracts with no governance
- Fail-fast oracles (no fallbacks)
- Full upfront collateralization (no liquidations where possible)
- Reusable infrastructure (shared TWAP oracle)

---

## Product Matrix

| Exposure | Product | Mechanism | Liquidation Risk |
|----------|---------|-----------|------------------|
| Long vBTC Price | CDP Lending | Borrow USDC → Buy vBTC | Yes |
| Short vBTC Price | CDP Lending | Borrow vBTC → Sell vBTC | Yes |
| Long Volume | Yield Vault (yvBTC) | Curve LP fees + CRV | No |
| Long Volatility | VarianceVaultLong | Pay strike, receive realized | No |
| Short Volatility | VarianceVaultShort | Receive strike, pay realized | No |

---

## Part I: Price Exposure - Leveraged Lending Protocol

### Architecture

CDP-based lending with isolated markets per collateral type (wBTC, cbBTC, tBTC).

```
┌─────────────────────────────────────────────────────────────────┐
│                 ISOLATED LENDING MARKETS                        │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │ vWBTC Market    │  │ vCBBTC Market   │  │ vTBTC Market    │ │
│  │ Collateral: wBTC│  │ Collateral:cbBTC│  │ Collateral: tBTC│ │
│  │ Borrow: vWBTC   │  │ Borrow: vCBBTC  │  │ Borrow: vTBTC   │ │
│  │ Oracle: TWAP    │  │ Oracle: TWAP    │  │ Oracle: TWAP    │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │ Stablecoin Pool │  │ Stablecoin Pool │  │ Stablecoin Pool │ │
│  │ Collateral:vWBTC│  │ Collateral:vCBBTC│ │ Collateral:vTBTC│ │
│  │ Borrow: USDC    │  │ Borrow: USDC    │  │ Borrow: USDC    │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### Position Types

| Position | User Thesis | Execution Flow |
|----------|-------------|----------------|
| **Long vBTC** | Discount will narrow | Deposit wBTC → Borrow USDC → Buy vBTC on Curve |
| **Short vBTC** | Discount will widen | Deposit wBTC → Borrow vBTC → Sell vBTC on Curve |

### Interest Rate Model

vBTC has structural negative carry due to 1% monthly (12% annual) withdrawal rate. The base rate must exceed this to prevent arbitrage.

```solidity
baseRate = 14%      // 12% carry + 2% margin
slope1 = 6%         // Per 100% utilization (0-80%)
slope2 = 200%       // Per 100% utilization above kink
kink = 80%
```

| Utilization | Borrow APR |
|-------------|------------|
| 0% | 14.0% |
| 50% | 17.0% |
| 80% (kink) | 18.8% |
| 100% | 58.8% |

### Dynamic LTV

LTV adjusts based on current vBTC/BTC discount to provide additional buffer during stress.

```solidity
baseLTV = 85%           // At 0% discount
sensitivity = 2.0x      // 2x sensitivity
minLTV = 30%

Max LTV = baseLTV - (currentDiscount × sensitivity)
```

| Discount | vBTC/BTC Price | Max LTV | Liq LTV |
|----------|----------------|---------|---------|
| 5% | 0.95 | 75% | 82% |
| 10% | 0.90 | 65% | 72% |
| 15% | 0.85 | 55% | 62% |
| 25% | 0.75 | 35% | 42% |

### Liquidation: Dutch Auction

Gradual bonus escalation replaces circuit breakers for smoother liquidations.

```
Health Factor < 1.0 triggers auction:
├─ Time 0m:   Bonus = 0%
├─ Time 15m:  Bonus = 3.75%
├─ Time 30m:  Bonus = 7.5%
├─ Time 45m:  Bonus = 11.25%
└─ Time 60m:  Bonus = 15% (max)
```

### Flash Loan Leverage

Atomic leverage via Balancer flash loans (zero fee).

```
openLeveragedLong(1 wBTC, 2.5x leverage):
Step 1: Flash loan 1.5 wBTC → Total 2.5 wBTC
Step 2: Deposit as collateral
Step 3: Borrow USDC at 65% LTV = $97,500
Step 4: Swap USDC → wBTC = 1.625 wBTC
Step 5: Repay flash loan (1.5 wBTC + fee)
Step 6: Deposit remaining as additional collateral
Result: ~2.625x effective leverage in single transaction
```

---

## Part II: Volume Exposure - Native Volatility Farming (yvBTC)

### Architecture

ERC-4626 yield-bearing vault that deploys vestedBTC to Curve LP for fee capture.

```
┌─────────────────────────────────────────────────────────────────┐
│                    NATIVE YIELD VAULT (yvBTC)                    │
├─────────────────────────────────────────────────────────────────┤
│  User: deposit(vBTC) → receive yvBTC shares                     │
│                                                                  │
│  ┌──────────────┐         ┌──────────────┐         ┌──────────┐ │
│  │    USER      │         │  YIELD VAULT │         │ STRATEGY │ │
│  │ deposit(vBTC)├────────►│   (yvBTC)    │────────►│ Curve LP │ │
│  │◄────────────┤         │  ERC-4626    │◄────────┤ + gauge  │ │
│  │receive yvBTC│         │              │         │          │ │
│  └──────────────┘         └──────────────┘         └──────────┘ │
│                                  │                              │
│                         harvest() → CRV → swap to vBTC          │
│                                  │     → compound               │
└─────────────────────────────────────────────────────────────────┘
```

### Yield Sources

| Source | Estimated APY | Dependency |
|--------|---------------|------------|
| Curve swap fees | 0.5-2% | Trading volume |
| CRV emissions | 3-10% | Gauge approval |
| Arbitrage (implicit) | Variable | Market volatility |
| **Base withdrawal** | **12%** | **Retained by Vault holder** |
| **Total** | **17-22%** | Combined |

### Exchange Rate Mechanics

```
Exchange Rate = totalAssets / totalSupply

On deposit:
- User deposits 100 vBTC
- totalAssets = 1000, totalSupply = 1000
- User gets 100 shares

After yield accrual (10 vBTC harvested):
- totalAssets = 1010, totalSupply = 1000
- Exchange rate = 1.01 vBTC per share
- User's 100 shares now worth 101 vBTC
```

### Key Parameters

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Performance Fee | 10% | Industry standard (Yearn uses 10-20%) |
| Management Fee | 0% | KISS principle |
| Strategy | Single immutable | No governance attack surface |
| Harvesting | Permissionless | Anyone can call, MEV bots incentivized |

### Yield Stacking

The Vault holder **retains withdrawal rights** on the underlying Vault NFT:

```
User's Vault NFT (1 BTC collateral)
├─ Withdrawal rights: 12% annually (USER KEEPS THIS)
│
└─ Separation: mintBtcToken() → 1 vestedBTC
    │
    └─ Deposit to YieldVault → yvBTC shares
        │
        └─ Captures: LP fees + CRV rewards (ADDITIONAL YIELD)
```

---

## Part III: Volatility Exposure - Variance Swap

### Concept

A variance swap is a derivative where one party pays fixed (strike variance) and receives floating (realized variance), while the counterparty takes the opposite position.

```
Settlement = Notional × (Realized_Variance - Strike_Variance)

Long Volatility: Profits when Realized > Strike (price movement)
Short Volatility: Profits when Realized < Strike (price stability)
```

### Architecture

```
contracts/issuer/src/volatility/
├── VarianceSwap.sol              # Core variance swap mechanics
├── VarianceOracle.sol            # Realized variance calculator
├── VarianceVaultLong.sol         # ERC-4626 vault for long vol exposure
├── VarianceVaultShort.sol        # ERC-4626 vault for short vol exposure
├── VarianceSwapRouter.sol        # Auto-matching for vault deposits
└── interfaces/
    ├── IVarianceSwap.sol
    ├── IVarianceOracle.sol
    └── IVarianceVault.sol
```

### Standard Observation Periods

| Period | Use Case | Observations |
|--------|----------|--------------|
| 7 days | Short-term vol trading | 7 daily |
| 30 days | Standard vol exposure | 30 daily |
| 90 days | Quarterly hedging | 90 daily |

### Variance Calculation

```
Step 1: Collect Price Observations
├─ Observation frequency: Daily (86400 seconds)
├─ Price ratio: P(t) = vBTC_price / BTC_price

Step 2: Calculate Log Returns
├─ r(t) = ln(P(t) / P(t-1))

Step 3: Calculate Realized Variance
├─ Variance = (252 / N) × Σ r(t)²
├─ Annualized using 252 trading days

Step 4: Settlement
├─ PnL = Notional × (Realized_Variance - Strike_Variance)
├─ If PnL > 0: Long receives from Short
├─ If PnL < 0: Short receives from Long
```

### Collateral Requirements

Full upfront collateralization eliminates liquidation risk:

```solidity
MAX_VARIANCE = 1e18  // 100% annualized variance cap

// Long party: max loss = notional × strike (if realized = 0)
longCollateralRequired = notional × strikeVariance

// Short party: max loss = notional × (maxVariance - strike)
shortCollateralRequired = notional × (MAX_VARIANCE - strikeVariance)
```

### Settlement Examples (30-day, 1 wBTC notional, 4% strike)

| Scenario | Realized Variance | PnL | Winner |
|----------|-------------------|-----|--------|
| High Vol | 8% | +0.04 wBTC | Long |
| Low Vol | 2% | -0.02 wBTC | Short |
| At Strike | 4% | 0 | Even |

### ERC-4626 Vault Wrapper Flow

```
User deposits to VarianceVaultLong:
├─ Vault accumulates deposits
├─ Router matches with VarianceVaultShort deposits
├─ Creates underlying VarianceSwap positions
├─ User receives vault shares
│
On settlement:
├─ Swap settles based on realized variance
├─ Profits/losses flow to respective vaults
├─ Exchange rate adjusts accordingly
└─ Users can withdraw at any time after settlement
```

### Immutable Parameters

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| MAX_VARIANCE | 1e18 (100%) | Caps maximum settlement |
| MIN_OBSERVATION_PERIOD | 7 days | Minimum meaningful period |
| MAX_OBSERVATION_PERIOD | 365 days | Practical limit |
| MIN_OBSERVATION_FREQUENCY | 1 hour | Prevents spam |
| TWAP_PERIOD | 30 minutes | Manipulation resistance |
| ANNUALIZATION_FACTOR | 252 | Standard trading days |

---

## Part IV: Shared Infrastructure

### DEX TWAP Oracle

All products share a common TWAP oracle reading from the Curve vBTC/WBTC pool.

```solidity
interface IVBTCOracle {
    function getPrice() external view returns (uint256 price);  // 18 decimals
    function getTWAP(uint32 period) external view returns (uint256 price);
    function getCurrentDiscount() external view returns (uint256);  // 18 decimals
}
```

**Oracle Parameters:**

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| TWAP Period | 30 min | Manipulation resistance |
| Max Staleness | 1 hour | Fail-fast on illiquid conditions |
| Min Price | 0.50 | vBTC cannot trade below 50% of BTC |
| Max Price | 1.00 | vBTC cannot exceed BTC price |
| Fallback | None | Fail-fast philosophy |

### Curve StableSwap Pool

```
Pool: vBTC/WBTC
├─ A Parameter: 100-200 (balance capital efficiency vs depeg tolerance)
├─ Swap Fee: 0.04% (matches stETH/ETH precedent)
├─ Expected Range: 0.70-0.95 vBTC per WBTC
└─ IL Profile: ~1.5% at 25% discount (vs 6.2% Uniswap V2)
```

---

## Part V: Integration Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                  vestedBTC DERIVATIVES STACK                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────┐  ┌──────────────────┐  ┌────────────────┐ │
│  │ LENDING PROTOCOL │  │ YIELD VAULT      │  │ VARIANCE SWAP  │ │
│  │ (CDP)            │  │ (yvBTC)          │  │                │ │
│  ├──────────────────┤  ├──────────────────┤  ├────────────────┤ │
│  │ Long Price       │  │ Long Volume      │  │ Long Vol       │ │
│  │ Short Price      │  │ (LP fees)        │  │ Short Vol      │ │
│  └────────┬─────────┘  └────────┬─────────┘  └───────┬────────┘ │
│           │                     │                     │          │
│           └─────────────────────┴─────────────────────┘          │
│                                 │                                │
│                    ┌────────────┴────────────┐                   │
│                    │ DEX TWAP ORACLE          │                   │
│                    │ (Curve vBTC/WBTC)        │                   │
│                    └────────────┬────────────┘                   │
│                                 │                                │
│                    ┌────────────┴────────────┐                   │
│                    │ CURVE STABLESWAP POOL   │                   │
│                    │ vBTC/WBTC (A=100-200)   │                   │
│                    └─────────────────────────┘                   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Protocol Layer Boundary

All derivatives products operate at the **issuer layer** without modifying protocol contracts:

| Layer | Contracts | Modifiable |
|-------|-----------|------------|
| Protocol | VaultNFT, BtcToken | No (immutable) |
| Issuer | Lending, Yield Vault, Variance Swap | Yes (new deployments) |

---

## Part VI: Risk Matrix

### Lending Protocol Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Liquidation cascade | HIGH | Dynamic LTV, Dutch auction |
| Oracle manipulation | MEDIUM | 30-min TWAP, staleness check |
| Negative carry arbitrage | HIGH | 14% base rate floor |
| Bad debt | MEDIUM | 10% reserve fund |

### Yield Vault Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Smart contract (Curve) | HIGH | 5+ year Lindy, $3B+ TVL |
| Impermanent loss | MEDIUM | StableSwap minimizes (0.5-1.5% expected) |
| CRV price crash | MEDIUM | Frequent harvesting |
| Low trading volume | LOW | Accept lower yield |

### Variance Swap Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Variance cap breach | HIGH | MAX_VARIANCE = 100% cap |
| Low liquidity (no match) | MEDIUM | Permissionless; cancel if unmatched |
| Oracle manipulation | MEDIUM | 30-min TWAP; multiple observations |
| Counterparty default | NONE | Full upfront collateralization |
| Liquidation | NONE | No liquidations by design |

---

## Part VII: Comparison Summary

| Aspect | Lending | Yield Vault | Variance Swap |
|--------|---------|-------------|---------------|
| **Exposure** | Price direction | Volume/fees | Price magnitude |
| **Leverage** | 1-3x via flash loans | None | None |
| **Liquidation** | Yes (Dutch auction) | No | No |
| **Active Management** | Required | None | None |
| **Collateral** | Over-collateralized | Full deposit | Full upfront |
| **Settlement** | Continuous | On withdrawal | End of period |
| **Oracle Dependency** | High | Low | Medium |

---

## Related Documents

- [Leveraged Lending Protocol](./Leveraged_Lending_Protocol.md) - Detailed CDP mechanics
- [Native Volatility Farming Architecture](../research/Native_Volatility_Farming_Architecture.md) - ERC-4626 vault design
- [Curve Liquidity Pool](./Curve_Liquidity_Pool.md) - Base LP design
- [Peapods Finance Analysis](../research/Peapods_Finance_Analysis.md) - External protocol comparison
