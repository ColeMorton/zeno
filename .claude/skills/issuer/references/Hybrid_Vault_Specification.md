# Issuer Hybrid Collateral Vault Specification

> **Version:** 4.0
> **Status:** Canonical
> **Last Updated:** 2026-01-03
> **Layer:** Issuer
> **Related Documents:**
> - [Protocol HybridVaultNFT Specification](../protocol/Hybrid_Vault_Specification.md)
> - [Protocol Technical Specification](../protocol/Technical_Specification.md)
> - [Curve Liquidity Pool](../defi/Curve_Liquidity_Pool.md)
> - [Integration Guide](./Integration_Guide.md)

---

## Overview

The issuer-layer Hybrid Vault wraps the **protocol-layer `HybridVaultNFT`** with Curve LP integration, dynamic ratio formulas, and monthly configuration. The protocol layer is ratio-agnostic; all LP logic lives here.

```
ISSUER LAYER: IssuerHybridController (Wrapper)
├─ Dynamic ratio formula (70/30 default, 10-50% LP range)
├─ Curve pool integration (add_liquidity, get_dy)
├─ Monthly configuration (rate-limited updates)
├─ Self-calibrating slippage signal
└─ Calls protocol HybridVaultNFT.mint()

PROTOCOL LAYER: HybridVaultNFT (Immutable)
├─ Primary: cbBTC → 1% monthly withdrawal
├─ Secondary: Any ERC-20 → 100% unlock at vesting
├─ vestedBTC separation (primary only)
├─ Dual match pools
└─ Dormancy + delegation
```

### Key Architecture

```
Issuer Hybrid Vault Flow:
├─ User provides: 1.0 cbBTC
├─ Issuer calculates: 70% cbBTC + 30% LP (dynamic)
├─ Issuer adds 0.3 cbBTC to Curve pool → LP tokens
├─ Issuer calls: hybridVault.mint(treasure, tokenId, 0.7 cbBTC, LP tokens)
├─ Protocol stores: primary=0.7 cbBTC, secondary=LP tokens
├─ cbBTC Withdrawal: 1% monthly (protocol handles)
├─ LP Withdrawal: 100% at vesting (protocol handles)
└─ Protocol/Issuer Fees: $0 (all value to owner)
```

---

## Design Principles

### 1. Ground Truth Backing

Primary collateral is cbBTC (70% target), providing direct BTC exposure without recursive claims.

```
cbBTC → BTC (1 hop via Coinbase)

vs. deprecated approach:
vBTC → Vault → cbBTC → BTC (3 hops, recursive)
```

### 2. Structural Protocol-Owned Liquidity

LP component (30% target) automatically deepens vestedBTC/cbBTC pool at vault creation. No external flywheel required.

```
New Vault Created
    ↓
70% cbBTC held directly
30% cbBTC → Curve LP (vestedCBBTC/cbBTC)
    ↓
LP depth increases automatically
    ↓
Tighter vestedBTC spread
    ↓
More arbitrage-attractive minting
    ↓
Repeat
```

### 3. Dual Withdrawal Model

| Component | Withdrawal | Timing | Rationale |
|-----------|-----------|--------|-----------|
| cbBTC (70%) | 1% monthly perpetual | Post-vesting | Income stream (Zeno's paradox) |
| LP (30%) | 100% one-time | At vesting | Liquidity event (clean exit) |

### 4. Zero Rent Extraction

| Entity | Fee Collection |
|--------|----------------|
| Protocol | $0 |
| Issuer | $0 |
| Owner | 100% of LP fees + withdrawals |

LP swap fees accrue to the LP position. When owner withdraws LP at vesting, they receive LP tokens + all accumulated fees.

---

## Specification

### Parameters

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Base LP Ratio | 30% (3000 BPS) | Meaningful liquidity without barrier |
| Min LP Ratio | 10% (1000 BPS) | Floor during high-demand periods |
| Max LP Ratio | 50% (5000 BPS) | Ceiling during bootstrapping |
| LP Provider | Curve CryptoSwap V2 | Non-pegged volatile pair (vBTC is subordinated claim) |
| cbBTC Withdrawal | 1% monthly | Perpetual income stream |
| LP Withdrawal | 100% at vesting | One-time liquidity event |
| Protocol Fees | 0% | All value to owner |

### Dynamic Ratio Formula (v2.0)

The LP ratio adjusts based on market conditions via a self-calibrating formula. Parameters are managed monthly by the issuer with rate limits preventing sudden changes.

#### Monthly Configuration

```solidity
struct MonthlyConfig {
    uint256 baseLPRatioBPS;         // Default: 3000 (30%)
    uint256 minLPRatioBPS;          // Default: 1000 (10%)
    uint256 maxLPRatioBPS;          // Default: 5000 (50%)
    uint256 discountThresholdBPS;   // Default: 1000 (10%)
    uint256 discountSensitivity;    // Default: 2
    uint256 targetSlippageBPS;      // Default: 50 (0.5%)
    uint256 slippageSensitivity;    // Default: 20
    uint256 standardSwapBPS;        // Default: 10 (0.1% of TVL)
    uint256 effectiveTimestamp;
}
```

#### Rate Limits (Max Change Per Month)

| Parameter | Max Delta | Rationale |
|-----------|-----------|-----------|
| `baseLPRatioBPS` | ±500 BPS (5%) | Prevents sudden collateral shifts |
| `discountThresholdBPS` | ±300 BPS (3%) | Gradual sensitivity tuning |
| `discountSensitivity` | ±5 | Prevents aggressive multiplier changes |
| `slippageSensitivity` | ±5 | Prevents aggressive multiplier changes |
| `targetSlippageBPS` | ±25 BPS (0.25%) | Fine-tuning only |

#### Slippage-Based Signal (Self-Calibrating)

```solidity
/// @notice Measure slippage for standardized swap size
function measureSlippage(uint256 standardSwapBPS) public view returns (uint256) {
    uint256 totalCollateral = getTotalProtocolCollateral();
    uint256 swapAmount = (totalCollateral * standardSwapBPS) / 10000;
    if (swapAmount == 0) return 0;

    uint256 expectedOut = swapAmount;  // 1:1 at parity
    uint256 actualOut = curvePool.get_dy(0, 1, swapAmount);

    if (actualOut >= expectedOut) return 0;
    return ((expectedOut - actualOut) * 10000) / expectedOut;
}

function _calculateSlippageAdjustment(MonthlyConfig memory config)
    internal view returns (int256)
{
    uint256 currentSlippage = measureSlippage(config.standardSwapBPS);

    if (currentSlippage > config.targetSlippageBPS) {
        // High slippage → increase LP allocation
        uint256 excess = currentSlippage - config.targetSlippageBPS;
        return int256(excess * config.slippageSensitivity);
    } else {
        // Low slippage → decrease LP allocation (slower rate)
        uint256 margin = config.targetSlippageBPS - currentSlippage;
        return -int256((margin * config.slippageSensitivity) / 2);
    }
}
```

#### Combined Ratio Calculation

```solidity
function calculateTargetLPRatio() public view returns (uint256 ratioBPS) {
    MonthlyConfig memory config = _getActiveConfig();

    int256 ratio = int256(config.baseLPRatioBPS);

    // Signal 1: Slippage-based (self-calibrating)
    ratio += _calculateSlippageAdjustment(config);

    // Signal 2: Discount-based
    ratio += _calculateDiscountAdjustment(config);

    // Clamp to configured bounds
    if (ratio < int256(config.minLPRatioBPS)) return config.minLPRatioBPS;
    if (ratio > int256(config.maxLPRatioBPS)) return config.maxLPRatioBPS;
    return uint256(ratio);
}
```

#### Formula Components

| Signal | Effect on LP Ratio | Mechanism |
|--------|-------------------|-----------|
| Slippage > target (0.5%) | ↑ Increase | Pool needs depth |
| Slippage < target | ↓ Decrease (slow) | Excess depth, return to cbBTC |
| vestedBTC Discount > threshold | ↑ Increase | Absorb selling pressure |
| Normal conditions | 30% base | Optimal balance |

### Effective Exposure

```
Direct cbBTC:            70%
vestedCBBTC from LP:     15% (half of 30% LP)
cbBTC from LP:           15% (half of 30% LP)
─────────────────────────────
Total cbBTC exposure:    85%
Total vestedCBBTC exposure: 15%
```

---

## Withdrawal Mechanics

### Timeline

```
Day 0:      Vault created
            70% cbBTC deposited to VaultNFT
            30% cbBTC → Curve LP → stored in vault

Day 0-1129: Vesting period
            cbBTC: Locked
            LP: Locked (fees accruing to position)

Day 1129:   Maturity
            cbBTC: 1% monthly withdrawals begin
            LP: 100% release to owner (with accumulated fees)

Day 1129+:  Post-maturity
            cbBTC: Perpetual asymptotic depletion
            LP: Released (vault continues on cbBTC only)
```

### Collateral Evolution

```
Month 0:   70% cbBTC │ 30% LP (locked)
           ██████████████│██████

Month 37:  70% cbBTC │ 30% LP releases to owner
           ██████████████│→ with fees

Month 37+: 70% cbBTC │ 0% LP
           ██████████████│ (standard vault)

Month 120: ~38% cbBTC │ 0% LP
           ████████│ (perpetual via Zeno)
```

### Dual Withdrawal Functions (Protocol Layer)

Users call the Protocol `HybridVaultNFT` directly for withdrawals:

```solidity
// Protocol HybridVaultNFT interface (simplified)
interface IHybridVaultNFT {
    /// @notice Withdraw 1% of primary collateral monthly (Zeno's paradox)
    function withdrawPrimary(uint256 tokenId) external returns (uint256 amount);

    /// @notice Withdraw 100% of secondary collateral (one-time at vesting)
    function withdrawSecondary(uint256 tokenId) external returns (uint256 amount);
}

// User calls:
hybridVaultNFT.withdrawPrimary(tokenId);    // → cbBTC (1% monthly)
hybridVaultNFT.withdrawSecondary(tokenId);  // → LP tokens (100% at vesting)
```

The issuer layer is not involved in withdrawals—all vault mechanics are handled by the protocol.

---

## Flywheel Effect

The hybrid model creates a self-reinforcing liquidity cycle without external incentives:

```
                    ┌─────────────────────────────────────────┐
                    │           HYBRID VAULT NFT              │
                    │  ┌─────────────────┬─────────────────┐  │
                    │  │    70% cbBTC    │   30% Curve LP  │  │
                    │  │  (1% monthly)   │ (100% at vesting)│  │
                    │  └────────┬────────┴────────┬────────┘  │
                    └───────────┼─────────────────┼───────────┘
                                │                 │
           ┌────────────────────┘                 └────────────────────┐
           ▼                                                          ▼
┌─────────────────────┐                              ┌────────────────────────┐
│  cbBTC Withdrawals  │                              │   LP Withdrawal        │
│  1% monthly forever │                              │   100% at vesting      │
│  (Zeno's paradox)   │                              │   (one-time liquidity) │
└─────────────────────┘                              └───────────┬────────────┘
                                                                 │
                                                                 ▼
                                              ┌──────────────────────────────┐
                                              │  Owner receives LP + all     │
                                              │  accumulated swap fees       │
                                              │  Protocol/Issuer: $0         │
                                              └──────────────────────────────┘
```

**Self-Reinforcing Properties:**

1. Every new vault automatically deepens LP (structural POL)
2. LP fees accrue to owners, not protocol (trustless, no rent extraction)
3. Self-calibrating formula adjusts ratio based on market (monthly issuer optimization)
4. Dual withdrawal: perpetual income (cbBTC) + liquidity event (LP)
5. Deeper LP → tighter vestedBTC spread → more minting → more volume

---

## Implementation Architecture

### Contract Structure

```
contracts/issuer/src/
├── HybridMintController.sol          # Thin controller for minting Protocol HybridVaultNFT
│   ├── mintHybridVault(cbBTCAmount)  # Splits per formula, calls protocol.mint()
│   ├── calculateTargetLPRatio()      # Self-calibrating formula
│   ├── measureSlippage()             # Slippage measurement for ratio
│   └── updateMonthlyConfig()         # Issuer parameter updates (rate-limited)
│
├── interfaces/
│   ├── IHybridMintController.sol     # Controller interface
│   ├── IProtocolHybridVaultNFT.sol   # Minimal protocol interface
│   └── ICurveCryptoSwap.sol          # Curve CryptoSwap V2 interface
│
└── test/
    ├── mocks/
    │   ├── MockProtocolHybridVaultNFT.sol # Protocol vault mock
    │   └── MockCurvePool.sol              # Curve pool mock
    └── unit/
        └── HybridMintController.t.sol     # Unit tests
```

**Key Architecture Change:** Users own the Protocol `HybridVaultNFT` directly. The issuer layer is a thin minting controller—no wrapper NFT, no nested ownership. Withdrawals call protocol directly:
- `hybridVaultNFT.withdrawPrimary(tokenId)` → cbBTC
- `hybridVaultNFT.withdrawSecondary(tokenId)` → LP tokens

### Minting Flow

```
User provides: 1.0 cbBTC
                    │
                    ▼
         ┌─────────────────────────────────────────┐
         │ HybridMintController.mintHybridVault()  │
         │ 1. Calculate LP ratio (dynamic)         │
         │ 2. Split cbBTC: 70% vault, 30% LP       │
         │ 3. Mint TreasureNFT                     │
         │ 4. Add 30% cbBTC to Curve pool → LP     │
         │ 5. Call protocol.mint(treasure, cbBTC,  │
         │    LP tokens)                           │
         │ 6. Transfer vault NFT to user           │
         └─────────────────────────────────────────┘
                    │
       ┌────────────┴────────────┐
       ▼                         ▼
┌─────────────────────┐   ┌─────────────────────┐
│  Protocol           │   │  Curve Pool         │
│  HybridVaultNFT     │   │  add_liquidity()    │
│  primary: 0.7 cbBTC │   │  0.3 cbBTC → LP     │
│  secondary: LP      │   │                     │
│  + TreasureNFT      │   │                     │
└─────────────────────┘   └─────────────────────┘
       │
       ▼
User owns: Protocol HybridVaultNFT directly (no wrapper)
```

### Curve CryptoSwap V2 Integration

```solidity
interface ICurveCryptoSwap {
    function add_liquidity(uint256[2] memory amounts, uint256 min_mint_amount) external returns (uint256);
    function remove_liquidity_one_coin(uint256 _burn_amount, int128 i, uint256 _min_received) external returns (uint256);
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external returns (uint256);
    function get_virtual_price() external view returns (uint256);
    function balances(uint256 i) external view returns (uint256);
    function price_oracle() external view returns (uint256); // CryptoSwap-specific: EMA oracle
}

// Pool deployment parameters (CryptoSwap V2 for non-pegged pairs)
// A: 50-100 (non-pegged volatile pair)
// gamma: 0.000145 (standard for volatile pairs)
// mid_fee: 0.26% (between stable and volatile)
// Coins: [cbBTC, vestedCBBTC]
//
// Note: CryptoSwap selected because vBTC is a subordinated residual claim
// with structural decay, NOT a pegged asset. See Curve_Liquidity_Pool.md.
```

---

## Risk Analysis

### Robustness to vestedBTC Depeg

| Scenario | Vault Impact |
|----------|-------------|
| vestedBTC at 0.9x cbBTC (10% discount) | 1.5% loss (15% vestedBTC exposure) |
| vestedBTC at 0.8x cbBTC (20% discount) | 3% loss |
| vestedBTC at 0.5x cbBTC (50% discount) | 7.5% loss |

85% cbBTC exposure provides strong downside protection.

### LP Impermanent Loss

vestedCBBTC/cbBTC uses CryptoSwap V2 (not StableSwap) because vBTC is a subordinated residual claim:

- Both assets track BTC value but vBTC has structural decay (1% monthly)
- CryptoSwap V2 profit-offset rule minimizes IL (~2% expected at 25% discount)
- EMA oracle tracks evolving fair value without assuming a peg
- IL bounded by early redemption floor (arbitrage closes discount)

### Maturity Liquidity Risk

If many vaults mature simultaneously:

- Mass LP withdrawal could thin pool temporarily
- Mitigated by natural staggering of vault creation dates
- LP can be re-provided if yields remain attractive (flywheel continues)
- Formula auto-increases ratio for new vaults when pool is thin

---

## Comparison: Vault Types

| Property | Standard Vault | Hybrid Vault |
|----------|---------------|--------------|
| Primary Collateral | 100% cbBTC | 70% cbBTC (dynamic) |
| LP Component | None | 30% vestedCBBTC/cbBTC LP |
| LP Contribution | External flywheel required | Structural (automatic) |
| cbBTC Withdrawal | 1%/month | 1%/month |
| LP Withdrawal | N/A | 100% at maturity |
| Protocol Fees | $0 | $0 |
| Issuer Fees | $0 | $0 |
| vestedBTC Spread | Market-driven | Structurally tighter |

---

## Design Rationale

### Why 70:30 Target?

| Ratio | Ground Truth | Liquidity | Accessibility | Assessment |
|-------|-------------|-----------|---------------|------------|
| 90:10 | Maximum | Minimal | Easy | Insufficient liquidity |
| 80:20 | Strong | Moderate | Moderate | Previous design |
| **70:30** | **Strong** | **Meaningful** | **Moderate** | **Optimal balance** |
| 60:40 | Adequate | High | Difficult | Barrier too high |

### Why Dynamic Ratio?

| Benefit | Explanation |
|---------|-------------|
| Responsive | Adjusts to market conditions automatically |
| Bootstrapping | Higher LP allocation when pool is thin |
| Stress absorption | More LP when vestedBTC discount widens |
| Immutable | Formula is code-locked, no governance |

### Why Dual Withdrawal (Not Unified)?

| Benefit | Explanation |
|---------|-------------|
| Income clarity | "1% cbBTC monthly" is concrete |
| Liquidity event | LP release creates exit opportunity |
| Re-provision | Owner can add LP back to pool |
| UX simplicity | Owner receives cbBTC, not LP fragments |

### Why Zero Fees?

| Benefit | Explanation |
|---------|-------------|
| Trust minimization | No fee switches, no honeypots |
| Sales velocity | Buyers know ALL value stays with them |
| Alignment | LP fees benefit the person who locked collateral |
| Simplicity | No accounting for protocol/issuer extraction |

---

## Issuer Monthly Review

Each month, the issuer reviews market conditions and optimizes parameters:

| Step | Action | Data Source |
|------|--------|-------------|
| 1 | Review average slippage over past month | On-chain `measureSlippage()` |
| 2 | Review vestedBTC discount distribution | Oracle TWAP data |
| 3 | Review vault creation velocity | Protocol analytics |
| 4 | Evaluate if current parameters achieved 30% average | Historical ratio data |
| 5 | Adjust `targetSlippageBPS` if needed | Market conditions |
| 6 | Adjust `discountThresholdBPS` if needed | Liquidity requirements |
| 7 | Submit `updateMonthlyConfig()` | On-chain |
| 8 | Publish rationale | Off-chain (transparency) |

**Rate Limit Protection:** Even a malicious issuer cannot dramatically change the algorithm in a single month. Full parameter migration from defaults to extremes would require ~10 months.

---

## Navigation

← [Protocol Layer](./README.md) | [Documentation Home](../README.md)
