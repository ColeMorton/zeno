# vestedBTC Derivatives Suite

## Overview

The vestedBTC Derivatives Suite provides comprehensive financial exposure mechanisms for vestedBTC holders. This unified specification consolidates three interconnected products enabling price, volume, and volatility exposure.

**Design Philosophy:**
- Non-profit protocol (zero protocol fees)
- Immutable contracts with no governance
- Fail-fast oracles (no fallbacks)
- Full upfront collateralization (no liquidations where possible)
- Reusable infrastructure (shared TWAP oracle)

---

## Terminology

| Term | Meaning |
|------|---------|
| vBTC | vestedBTC token (fungible ERC-20 from separated Vaults) |
| vBTC discount | `1 - (vBTC_price / wBTC_price)` from Curve pool |
| BTC-equivalent | Any wrapped BTC variant (wBTC, cbBTC, tBTC) |
| wBTC | Reference wrapped BTC for oracle pricing |

**Price References:**
- Oracle: vBTC/wBTC from Curve CryptoSwap V2 pool
- All discount calculations use wBTC as denominator
- Note: vBTC is a subordinated residual claim (not pegged to wBTC)

---

## Product Matrix

| Exposure | Product | Collateral | Leverage | Liquidation |
|----------|---------|------------|----------|-------------|
| Long vBTC Price | Capped Bull Vault | vBTC | 1-5x | No |
| Short vBTC Price | Capped Bear Vault | vBTC | 1-5x | No |
| Long Volume | Yield Vault (yvBTC) | vBTC | 1x | No |
| Long Volatility | VarianceVaultLong | vBTC | 1x | No |
| Short Volatility | VarianceVaultShort | vBTC | 1x | No |

**Single asset. No liquidations. Full feature set.**

---

## Part I: Price Exposure - Capped Leverage Vaults

### Design Rationale

vBTC is a **subordinated residual claim** with time-locked redemption (1% monthly). Capped leverage vaults eliminate liquidation entirely by bounding payoffs—maximum loss equals deposit.

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│              CAPPED LEVERAGE VAULTS (vBTC-Only)                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────┐  ┌─────────────────────────┐  │
│  │ BULL VAULT (Long Price)     │  │ BEAR VAULT (Short Price)│  │
│  │                             │  │                         │  │
│  │ Collateral: vBTC            │  │ Collateral: vBTC        │  │
│  │ Leverage: 1-5x (user)       │  │ Leverage: 1-5x (user)   │  │
│  │ Duration: 30/60/90 days     │  │ Duration: 30/60/90 days │  │
│  │ Liquidation: None           │  │ Liquidation: None       │  │
│  │ Settlement: vBTC            │  │ Settlement: vBTC        │  │
│  └──────────────┬──────────────┘  └────────────┬────────────┘  │
│                 │                              │               │
│                 └──────────────┬───────────────┘               │
│                                │                               │
│                    ┌───────────┴───────────┐                   │
│                    │ BILATERAL SETTLEMENT  │                   │
│                    │ Bulls ↔ Bears         │                   │
│                    │ Zero-sum              │                   │
│                    └───────────────────────┘                   │
└─────────────────────────────────────────────────────────────────┘
```

### Core Principle: Cap Replaces Liquidation

Instead of liquidating when health factor drops, the payoff hits its floor/ceiling. Maximum loss equals deposit.

```
Cap = 100% of deposit = 1/leverage move

At 3x leverage:
├─ Cap triggers at ±33% price move
├─ Max gain: 2x deposit (100% return)
└─ Max loss: ~0 deposit (100% loss)
```

### Position Types

| Position | User Thesis | Mechanism |
|----------|-------------|-----------|
| **Long vBTC** | Discount will narrow | Deposit vBTC to Bull Vault → Profit if vBTC/BTC ratio increases |
| **Short vBTC** | Discount will widen | Deposit vBTC to Bear Vault → Profit if vBTC/BTC ratio decreases |

### Capped Bull Vault (Long vBTC Price)

```
User deposits: 1 vBTC
Leverage: 3x (user-selected, 1-5x)
Strike: Current vBTC/BTC ratio at deposit (e.g., 0.85)
Duration: 30 days (user-selected: 30/60/90)
Cap: 100% of deposit (1/leverage = ±33% move)

Payoff at expiry:
├─ Ratio → 0.935 (+10%): 1 + (3 × 0.10) = 1.30 vBTC (+30%)
├─ Ratio → 0.765 (-10%): 1 - (3 × 0.10) = 0.70 vBTC (-30%)
├─ Ratio → 0.57 (-33%): 0.01 vBTC (floored at ~0)
└─ Ratio → 1.13 (+33%): 1.99 vBTC (capped at ~2x)
```

### Capped Bear Vault (Short vBTC Price)

Mirror of Bull Vault with inverted payoff:

```
User deposits: 1 vBTC
Leverage: 3x
Strike: 0.85

Payoff at expiry:
├─ Ratio → 0.765 (-10%): 1 + (3 × 0.10) = 1.30 vBTC (+30%)
├─ Ratio → 0.935 (+10%): 1 - (3 × 0.10) = 0.70 vBTC (-30%)
├─ Ratio → 1.13 (+33%): 0.01 vBTC (floored at ~0)
└─ Ratio → 0.57 (-33%): 1.99 vBTC (capped at ~2x)
```

### Bilateral Settlement

Bull Vault gains come from Bear Vault losses (and vice versa). Pure zero-sum between directional traders.

```
Example: Bull TVL = 100 vBTC, Bear TVL = 80 vBTC

Matched portion: 80 vBTC each
├─ Full leverage payoff applies
└─ Settlement: losers pay winners

Unmatched portion: 20 vBTC Bulls
├─ Reduced effective leverage
└─ Scaled proportionally: 20 × (80/100) = 16 vBTC effective
```

### Leverage Selection

| Leverage | Cap (Price Move) | Risk Profile |
|----------|------------------|--------------|
| 1x | ±100% | Conservative, no amplification |
| 2x | ±50% | Moderate |
| 3x | ±33% | Standard |
| 5x | ±20% | Aggressive |

### Parameters

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| MIN_LEVERAGE | 1x | Floor |
| MAX_LEVERAGE | 5x | Cap speculation |
| DURATIONS | 30, 60, 90 days | Standard periods |
| MIN_DEPOSIT | 0.01 vBTC | Spam prevention |

---

## Part II: Volume Exposure - Native Volatility Farming (yvBTC)

### Architecture

ERC-4626 yield-bearing vault that deploys vestedBTC to Curve LP, allowing users to earn external Curve trading fees.

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

**yvBTC Vault Yields (accrues to depositors):**

| Source | Estimated APY | Dependency |
|--------|---------------|------------|
| Curve swap fees | 0.5-2% | Trading volume |
| CRV emissions | 3-10% | Gauge approval |
| **yvBTC Total** | **3.5-12%** | Combined |

*Note: Vault owners who separate vBTC and deposit to yvBTC also retain their 12% annual withdrawal rights on the underlying Vault NFT. This is separate from yvBTC yield.*

**Total Yield Stack (Vault Owner Who Deposits to yvBTC):**

| Source | Estimated APY | Who Receives |
|--------|---------------|--------------|
| Vault withdrawals | 12% | Vault NFT owner |
| yvBTC vault yield | 3.5-12% | yvBTC depositor |
| **Combined** | **15.5-24%** | Same person if owner deposits |

The 12% withdrawal is NOT distributed by yvBTC; it flows directly from the Vault NFT to its owner.

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

**Realized Variance (Industry Standard for Variance Swaps):**

```
Step 1: Collect Price Observations
├─ Observation frequency: Daily (86400 seconds)
├─ Price ratio: P(t) = vBTC_price / wBTC_price

Step 2: Calculate Log Returns
├─ r(t) = ln(P(t) / P(t-1))

Step 3: Calculate Realized Variance
├─ Realized Variance = (252 / N) × Σ r(t)²
├─ Annualized using 252 trading days

Step 4: Settlement
├─ PnL = Notional × (Realized_Variance - Strike_Variance)
├─ If PnL > 0: Long receives from Short
├─ If PnL < 0: Short receives from Long
```

**Note:** This formula assumes zero mean return, which is standard convention for variance swaps over short horizons (7-90 days). This differs from statistical sample variance `Σ(r - r̄)² / (N-1)` which centers on observed mean.

The zero-mean convention:
1. Avoids look-ahead bias in mean estimation
2. Simplifies hedging (delta-neutral positions)
3. Matches market standard for variance swap settlement

### Collateral Requirements

Full upfront collateralization eliminates liquidation risk. **Collateral: vBTC only.**

```solidity
MAX_VARIANCE = 1e18  // 100% annualized variance cap

// Long party: max loss = notional × strike (if realized = 0)
longCollateralRequired = notional × strikeVariance

// Short party: max loss = notional × (maxVariance - strike)
shortCollateralRequired = notional × (MAX_VARIANCE - strikeVariance)

// All collateral and settlement in vBTC
collateralToken = vBTC
settlementToken = vBTC
```

### Settlement Examples (30-day, 1 vBTC notional, 4% strike)

| Scenario | Realized Variance | PnL | Winner |
|----------|-------------------|-----|--------|
| High Vol | 8% | +0.04 vBTC | Long |
| Low Vol | 2% | -0.02 vBTC | Short |
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
| Min Price | 0.50 | vBTC cannot trade below 50% of wBTC |
| Max Price | 1.00 | vBTC cannot exceed wBTC price |
| Fallback | None | Fail-fast philosophy |

### Curve CryptoSwap V2 Pool

```
Pool: vBTC/WBTC
├─ A Parameter: 50-100 (non-pegged volatile pair)
├─ gamma: 0.000145 (standard for volatile pairs)
├─ mid_fee: 0.26% (between stable and volatile)
├─ Expected Range: 0.50-0.95 vBTC per WBTC
└─ IL Profile: ~2% at 25% discount (with profit-offset protection)

Note: CryptoSwap V2 selected because vBTC is a subordinated residual
claim with structural decay, NOT a pegged asset. See Curve_Liquidity_Pool.md.
```

---

## Part V: Integration Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│              vBTC-ONLY DERIVATIVES SUITE                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │ PRICE EXPOSURE  │  │ VOLUME EXPOSURE │  │ VOL EXPOSURE    │ │
│  │                 │  │                 │  │                 │ │
│  │ Bull Vault      │  │ yvBTC Vault     │  │ VarianceVaultL  │ │
│  │ Bear Vault      │  │ (Curve LP)      │  │ VarianceVaultS  │ │
│  │                 │  │                 │  │                 │ │
│  │ Leverage: 1-5x  │  │ Leverage: 1x    │  │ Leverage: 1x    │ │
│  │ Collateral: vBTC│  │ Collateral: vBTC│  │ Collateral: vBTC│ │
│  │ Liquidation: No │  │ Liquidation: No │  │ Liquidation: No │ │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘ │
│           │                    │                    │          │
│           └────────────────────┴────────────────────┘          │
│                                │                               │
│                    ┌───────────┴───────────┐                   │
│                    │ ORACLE (Settlement)   │                   │
│                    │ vBTC/WBTC TWAP        │                   │
│                    │ (Curve Pool)          │                   │
│                    └───────────────────────┘                   │
│                                                                │
└─────────────────────────────────────────────────────────────────┘
```

**Single asset. No liquidations. Full feature set.**

### Protocol Layer Boundary

All derivatives products operate at the **issuer layer** without modifying protocol contracts:

| Layer | Contracts | Modifiable |
|-------|-----------|------------|
| Protocol | VaultNFT, BtcToken | No (immutable) |
| Issuer | Bull/Bear Vaults, yvBTC, Variance Vaults | Yes (new deployments) |

---

## Part VI: Risk Matrix

### Capped Vault Risks (Price Exposure)

| Risk | Severity | Mitigation |
|------|----------|------------|
| Counterparty imbalance | MEDIUM | Scaled leverage for unmatched portion |
| Oracle manipulation | MEDIUM | 30-min TWAP; settlement-only (not continuous) |
| Price cap breach | NONE | Bounded by design (cap = 100% deposit) |
| Liquidation | NONE | No liquidations by design |
| Bad debt | NONE | Full upfront collateralization |

### Yield Vault Risks (Volume Exposure)

| Risk | Severity | Mitigation |
|------|----------|------------|
| Smart contract (Curve) | HIGH | 5+ year Lindy, $3B+ TVL |
| Impermanent loss | MEDIUM | CryptoSwap profit-offset rule minimizes (~2% expected at 25% discount) |
| CRV price crash | MEDIUM | Frequent harvesting |
| Low trading volume | LOW | Accept lower yield |

### Variance Swap Risks (Volatility Exposure)

| Risk | Severity | Mitigation |
|------|----------|------------|
| Variance cap breach | HIGH | MAX_VARIANCE = 100% cap |
| Low liquidity (no match) | MEDIUM | Permissionless; cancel if unmatched |
| Oracle manipulation | MEDIUM | 30-min TWAP; multiple observations |
| Counterparty default | NONE | Full upfront collateralization |
| Liquidation | NONE | No liquidations by design |

---

## Part VII: Comparison Summary

| Aspect | Bull/Bear Vault | yvBTC | Variance Swap |
|--------|-----------------|-------|---------------|
| **Exposure** | Price direction | Volume/fees | Price magnitude |
| **Collateral** | vBTC | vBTC | vBTC |
| **Leverage** | 1-5x (capped) | 1x | 1x |
| **Liquidation** | No | No | No |
| **Active Management** | None | None | None |
| **Settlement** | End of period | On withdrawal | End of period |
| **Oracle Dependency** | Settlement only | Low | Medium |

---

## Related Documents

- [Native Volatility Farming Architecture](../research/Native_Volatility_Farming_Architecture.md) - ERC-4626 vault design
- [Curve Liquidity Pool](./Curve_Liquidity_Pool.md) - Base LP design
- [Peapods Finance Analysis](../research/Peapods_Finance_Analysis.md) - External protocol comparison
