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
| Long Volatility | VolatilityPool (Long) | vBTC | 1x | No |
| Short Volatility | VolatilityPool (Short) | vBTC | 1x | No |

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

## Part III: Volatility Exposure - Perpetual Volatility Pool

### Concept

The Volatility Pool provides perpetual exposure to vBTC price variance through a socialized pool model. Instead of bilateral matching, users deposit to long or short volatility pools, and variance P&L continuously transfers between pools based on realized variance vs strike.

```
Long Volatility: Profits when Realized Variance > Strike (price movement)
Short Volatility: Profits when Realized Variance < Strike (price stability)
```

### Architecture

```
contracts/issuer/src/volatility/
├── VolatilityPool.sol            # Unified pool for long/short vol
├── VarianceOracle.sol            # Price observations & variance calculation
└── interfaces/
    ├── IVolatilityPool.sol
    └── IVarianceOracle.sol
```

### Design Principles

| Traditional Variance Swap | Volatility Pool |
|--------------------------|-----------------|
| Epoch-based (7/30/90 days) | Perpetual (enter/exit anytime) |
| Bilateral matching required | Socialized pools (no matching) |
| Complex collateral requirements | Symmetric deposits |
| 5+ contracts | 2 contracts |

### Pool Mechanics

```
┌─────────────────────────────────────────────────────────────────┐
│                    VOLATILITY POOL                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────┐        ┌─────────────────────┐        │
│  │   LONG VOL POOL     │        │   SHORT VOL POOL    │        │
│  │                     │        │                     │        │
│  │ Deposits → Shares   │  P&L   │ Deposits → Shares   │        │
│  │ Users: Alice, Bob   │◄──────►│ Users: Charlie      │        │
│  │                     │        │                     │        │
│  └──────────┬──────────┘        └──────────┬──────────┘        │
│             │                              │                    │
│             └──────────────┬───────────────┘                    │
│                            │                                    │
│               ┌────────────┴────────────┐                       │
│               │      SETTLEMENT         │                       │
│               │ variance > strike: L→S  │                       │
│               │ variance < strike: S→L  │                       │
│               │ (daily permissionless)  │                       │
│               └─────────────────────────┘                       │
└─────────────────────────────────────────────────────────────────┘
```

### Settlement Logic

Settlement transfers value between pools based on variance:

```solidity
function settle() external {
    // 1. Get rolling realized variance from oracle
    uint256 realizedVariance = oracle.getRollingVariance(7 days);

    // 2. Calculate variance delta from strike
    int256 varianceDelta = realizedVariance - strikeVariance;

    // 3. Transfer proportional to matched amount
    uint256 matchedAmount = min(longPool, shortPool);
    int256 pnl = matchedAmount × varianceDelta × timeFraction;

    // 4. If positive: short→long, if negative: long→short
    transfer(pnl);
}
```

### Variance Calculation

Rolling variance uses industry-standard zero-mean convention:

```
Realized Variance = (252 / N) × Σ r(t)²

Where:
├─ r(t) = ln(P(t) / P(t-1)) (log return)
├─ N = observations in rolling window (default: 7 days)
├─ 252 = trading days per year (annualization)
```

### User Flow

```
Deposit:
├─ User calls depositLong(assets) or depositShort(assets)
├─ Receives proportional pool shares
├─ No waiting for epoch or matching

Settlement:
├─ Anyone can call settle() after interval (1 day default)
├─ Variance P&L transfers between pools
├─ Share exchange rates adjust automatically

Withdraw:
├─ User calls withdrawLong(shares) or withdrawShort(shares)
├─ Receives proportional assets at current exchange rate
├─ Anytime withdrawal (no epoch lock)
```

### Edge Cases

| Scenario | Behavior |
|----------|----------|
| One-sided pool | No P&L transfer (matchedAmount = 0) |
| Pool depletion | Losing side can go to zero (max loss = deposit) |
| Settlement gap | Next settle() catches up accumulated variance |

### Parameters

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| STRIKE_VARIANCE | 4e16 (4%) | Historical average for vBTC |
| SETTLEMENT_INTERVAL | 1 day | Daily P&L settlement |
| VARIANCE_WINDOW | 7 days | Rolling observation window |
| MIN_DEPOSIT | 1e6 (0.01 vBTC) | Spam prevention |
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
| Issuer | Bull/Bear Vaults, yvBTC, VolatilityPool | Yes (new deployments) |

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

### Volatility Pool Risks (Volatility Exposure)

| Risk | Severity | Mitigation |
|------|----------|------------|
| Pool depletion | MEDIUM | Max loss = 100% of deposit; natural cap |
| One-sided pool | LOW | No P&L transfer if no counterparty; can withdraw anytime |
| Oracle manipulation | MEDIUM | Rolling 7-day variance; TWAP-based observations |
| Settlement delay | LOW | Permissionless settlement; MEV incentivized |
| Liquidation | NONE | No liquidations by design |

---

## Part VII: Comparison Summary

| Aspect | Bull/Bear Vault | yvBTC | Volatility Pool |
|--------|-----------------|-------|-----------------|
| **Exposure** | Price direction | Volume/fees | Price magnitude |
| **Collateral** | vBTC | vBTC | vBTC |
| **Leverage** | 1-5x (capped) | 1x | 1x |
| **Liquidation** | No | No | No |
| **Active Management** | None | None | None |
| **Settlement** | End of period | On withdrawal | Daily (perpetual) |
| **Oracle Dependency** | Settlement only | Low | Medium |

---

## Related Documents

- [Native Volatility Farming Architecture](../research/Native_Volatility_Farming_Architecture.md) - ERC-4626 vault design
- [Curve Liquidity Pool](./Curve_Liquidity_Pool.md) - Base LP design
- [Peapods Finance Analysis](../research/Peapods_Finance_Analysis.md) - External protocol comparison
