# vestedBTC (vBTC) - Comprehensive Guide

## Table of Contents

1. [Overview](#1-overview)
2. [Token Specification](#2-token-specification)
3. [Separation Mechanics](#3-separation-mechanics)
4. [Recombination Mechanics](#4-recombination-mechanics)
5. [Rights & Ownership Model](#5-rights--ownership-model)
6. [Price Discovery & Discount Dynamics](#6-price-discovery--discount-dynamics)
7. [DeFi Integration Stack](#7-defi-integration-stack)
8. [Yield Strategies](#8-yield-strategies)
9. [Dormant Collateral Claims](#9-dormant-collateral-claims)
10. [Risk Framework](#10-risk-framework)
11. [Technical Reference](#11-technical-reference)

---

## 1. Overview

### What is vestedBTC?

vestedBTC (vBTC) is an ERC-20 token representing a fungible claim on BTC collateral locked within a Vault NFT. It enables liquidity access without sacrificing perpetual withdrawal rights.

### Core Value Proposition

```
┌─────────────────────────────────────────────────────────────┐
│                    VAULT NFT SEPARATION                     │
│                                                             │
│   Vault NFT (before)           Vault NFT + vBTC (after)    │
│   ┌─────────────────┐          ┌─────────────────┐         │
│   │ BTC Collateral  │          │ Withdrawal      │         │
│   │ Withdrawals     │    →     │ Rights Only     │         │
│   │ Treasure NFT    │          │ Treasure NFT    │         │
│   └─────────────────┘          └─────────────────┘         │
│                                        +                    │
│                                ┌─────────────────┐         │
│                                │ vBTC (ERC-20)   │         │
│                                │ Collateral Claim│         │
│                                │ Tradeable       │         │
│                                └─────────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

### Key Properties

| Property | Value |
|----------|-------|
| Standard | ERC-20 |
| Backing | 1:1 with Vault collateral at mint |
| Withdrawals | 0.875%/month (10.5%/year) decreases backing |
| Fungibility | Fully fungible across all vBTC holders |
| Redemption | Requires recombination with originating Vault |

---

## 2. Token Specification

### ERC-20 Properties

| Property | Value |
|----------|-------|
| Name | vBTC |
| Symbol | vBTC |
| Decimals | 8 (matches WBTC) |
| Total Supply | Dynamic (minted/burned per Vault) |

### Contract Architecture

```solidity
contract BtcToken is ERC20, IBtcToken {
    address public immutable vault;  // Only VaultNFT can mint/burn

    constructor(address _vault) ERC20("vBTC", "vBTC") {
        vault = _vault;
    }

    function mint(address to, uint256 amount) external onlyVault;
    function burnFrom(address from, uint256 amount) external onlyVault;
    function decimals() public pure override returns (uint8) { return 8; }
}
```

### Immutability Guarantees

- No admin functions
- No pause mechanism
- No upgrade path
- Mint/burn exclusively controlled by VaultNFT contract
- Zero extraction risk (no withdrawal functions)

---

## 3. Separation Mechanics

### Function: `mintBtcToken(uint256 tokenId)`

Separates vBTC from a fully-vested Vault NFT.

### Prerequisites

| Requirement | Description |
|-------------|-------------|
| Ownership | Caller must own the Vault NFT |
| Vesting | 1093 days must have elapsed since mint |
| First-time | vBTC not previously minted for this Vault |

### Execution Flow

```
┌─────────────────────────────────────────────────────────────┐
│  1. Validate ownership: ownerOf(tokenId) == msg.sender      │
│  2. Validate vesting: block.timestamp >= mintTimestamp +    │
│                       1093 days                             │
│  3. Validate first-time: _btcTokenAmount[tokenId] == 0      │
│  4. Record amounts:                                         │
│     - _btcTokenAmount[tokenId] = currentCollateral          │
│     - _originalMintedAmount[tokenId] = currentCollateral    │
│  5. Mint vBTC: btcToken.mint(msg.sender, currentCollateral) │
│  6. Update activity: _updateActivity(tokenId)               │
│  7. Emit: BtcTokenMinted(tokenId, msg.sender, amount)       │
└─────────────────────────────────────────────────────────────┘
```

### State Changes

| Variable | Before | After |
|----------|--------|-------|
| `_btcTokenAmount[tokenId]` | 0 | collateral amount |
| `_originalMintedAmount[tokenId]` | 0 | collateral amount |
| `_collateralAmount[tokenId]` | X BTC | X BTC (unchanged) |
| Vault redemption rights | Enabled | Disabled |
| BTC withdrawal rights | Enabled | Enabled |

---

## 4. Recombination Mechanics

### Function: `returnBtcToken(uint256 tokenId)`

Returns vBTC to restore full Vault rights.

### All-or-Nothing Requirement

vBTC must be returned in full. Partial returns are not permitted.

```
Required amount = _originalMintedAmount[tokenId]
Available = btcToken.balanceOf(msg.sender)

if (available < required) revert InsufficientBtcToken(required, available);
```

### Execution Flow

```
┌─────────────────────────────────────────────────────────────┐
│  1. Validate ownership: ownerOf(tokenId) == msg.sender      │
│  2. Validate separation exists: _btcTokenAmount[tokenId] > 0│
│  3. Calculate required: _originalMintedAmount[tokenId]      │
│  4. Verify balance: btcToken.balanceOf(msg.sender) >=       │
│                     required                                │
│  5. Burn vBTC: btcToken.burnFrom(msg.sender, required)      │
│  6. Clear state:                                            │
│     - _btcTokenAmount[tokenId] = 0                          │
│     - _originalMintedAmount[tokenId] = 0                    │
│  7. Update activity: _updateActivity(tokenId)               │
│  8. Emit: BtcTokenReturned(tokenId, msg.sender, required)   │
└─────────────────────────────────────────────────────────────┘
```

### Post-Recombination State

- vBTC permanently burned (supply decreases)
- Vault redemption rights fully restored
- Collateral matching eligibility restored

---

## 5. Rights & Ownership Model

### Rights Comparison Matrix

| Right | Vault (No Separation) | Vault (Post-Separation) | vBTC Holder |
|-------|----------------------|------------------------|-------------|
| BTC withdrawals | Yes | Yes | No |
| Treasure ownership | Yes | Yes | No |
| Redeem collateral | Yes | Only with full vBTC | No |
| Transfer position | Yes (NFT) | Yes (NFT) | Yes (fungible) |
| Collateral claim | Yes | No | Yes |
| Collateral matching | Yes | Yes | No |
| DEX trading | NFT markets | NFT markets | Native |
| DeFi collateral | Limited | Limited | Full |

### What Separators Forfeit

1. **Collateral Matching Benefits** - When early redeemers forfeit BTC, it's distributed to Vault holders, not vBTC holders
2. **Redemption Rights** - Cannot redeem collateral without re-acquiring full vBTC amount
3. **Integrated Position** - Must manage two assets instead of one

### What Separators Gain

1. **Liquidity** - Sell vBTC on DEX without selling Vault
2. **Fungibility** - vBTC is interchangeable; NFTs are unique
3. **DeFi Access** - Use vBTC as collateral in Aave, Compound
4. **Yield Stacking** - Deploy vBTC to earn LP fees while retaining withdrawals

---

## 6. Price Discovery & Discount Dynamics

### Why vBTC Trades at a Discount to WBTC

vBTC structurally trades below WBTC due to:

1. **Shrinking Collateral** - Underlying BTC decreases at 0.875%/month due to withdrawals
2. **Forfeited Upside** - Separators lose withdrawal rights and collateral matching
3. **Redemption Friction** - Requires recombination with specific Vault NFT

### Mean-Reversion Mechanisms

| Mechanism | Effect on Discount |
|-----------|-------------------|
| **Arbitrage** | If vBTC trades at significant discount, arbitrageurs buy cheap vBTC for future recombination profit |
| **BTC Backing** | Unlike reflexive tokens, vBTC has real BTC floor value (collateral claim) |
| **Collateral Matching** | Long-term Vault holders benefit when others exit early, stabilizing ecosystem |
| **Redemption Path** | vBTC can always be recombined with Vault to claim underlying BTC |

### Discount Harvesting Strategy

The vBTC/WBTC LP is a volatility-harvesting position on the discount spread:

```
┌─────────────────────────────────────────────────────────────┐
│  LP Position: vBTC/WBTC Pool                                │
│                                                             │
│  Scenario: vBTC trades at 8% discount to WBTC               │
│                                                             │
│  1. LP deposits equal value of vBTC + WBTC                  │
│  2. Arbitrageurs trade between them:                        │
│     - Buy cheap vBTC → Sell for WBTC                        │
│     - Each trade generates LP fees                          │
│  3. Discount mean-reverts toward fair value:                │
│     - BTC backing provides intrinsic floor                  │
│     - Arbitrage compresses discount over time               │
│  4. LP profits from:                                        │
│     - Trading fees (continuous)                             │
│     - Discount compression (capital gain)                   │
└─────────────────────────────────────────────────────────────┘
```

---

## 7. DeFi Integration Stack

### Layer Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    DeFi COMPOSABILITY                        │
│                                                              │
│  Layer 1: Base Asset                                         │
│  └─ vBTC (ERC-20): BTC-denominated, fungible                │
│                                                              │
│  Layer 2: Liquidity                                          │
│  ├─ Curve: vBTC/WBTC stable-like pool                       │
│  ├─ Uniswap V3: vBTC/WBTC [0.80-1.00] concentrated          │
│  └─ Balancer: vBTC/WBTC/USDC weighted pool                  │
│                                                              │
│  Layer 3: Lending                                            │
│  ├─ Aave: vBTC as collateral (borrow WBTC/ETH)              │
│  ├─ Compound: vBTC lending market                           │
│  └─ Morpho: Optimized vBTC lending                          │
│                                                              │
│  Layer 4: Yield Strategies                                   │
│  ├─ Yearn: vBTC vault auto-compound                         │
│  ├─ Convex: Boosted Curve vBTC LP                           │
│  └─ Pendle: vBTC yield tokenization                         │
└─────────────────────────────────────────────────────────────┘
```

### Why BTC-Denominated Pairs

| Benefit | Explanation |
|---------|-------------|
| Minimized IL | Correlated assets move together (like stETH/ETH) |
| Direct NAV arbitrage | No oracle dependency for price discovery |
| BTC ecosystem | Users remain in BTC without USD exposure |

### DeFi Advantages vs NFT

| Feature | vBTC (ERC-20) | Vault NFT (ERC-721) |
|---------|---------------|---------------------|
| DEX trading | Native (Uniswap, Curve) | NFT marketplaces only |
| Liquidity pools | Deep, automated | Fragmented, manual |
| Fractional sales | Native | Requires fractionalization |
| Lending protocols | Direct (Aave, Compound) | Limited support |
| Price discovery | Continuous, transparent | Floor price mechanics |
| Gas efficiency | Lower | Higher |

---

## 8. Yield Strategies

### Withdrawal Stacking

Separate vBTC to stack yields while retaining withdrawal rights:

```
Base: Vault NFT
├─ BTC Withdrawals: 10.5% annually
│
Separation: mintBtcToken() → vBTC
├─ Retain: Withdrawal rights (10.5%)
├─ vBTC → Curve LP → Convex boost
│   ├─ LP fees: ~2-5% APY
│   ├─ CRV rewards: ~3-8% APY
│   └─ CVX boost: ~2-4% APY
│
Total Stack: 10.5% + 7-17% = 17.5-27.5% APY
```

### Use Cases

| Strategy | Mechanism |
|----------|-----------|
| Liquidity access | Sell vBTC on DEX, retain Vault for withdrawal rights |
| DeFi collateral | Deposit vBTC in Aave/Compound to borrow |
| Partial liquidation | Sell portion of vBTC while retaining rest |
| Liquidity provision | Add vBTC to DEX pools, earn trading fees |
| Structured products | Separate principal (vBTC) from yield (withdrawals) |

---

## 9. Dormant Collateral Claims

### Mechanism

vBTC holders can claim collateral from abandoned Vaults.

### Dormancy Eligibility

A Vault becomes dormant-eligible when:

1. vBTC has been separated (`_btcTokenAmount[tokenId] > 0`)
2. No activity for dormancy threshold (1093 days)
3. Grace period expired (30 days after threshold)

### Function: `claimDormantCollateral(uint256 tokenId)`

```
┌─────────────────────────────────────────────────────────────┐
│  1. Verify dormancy eligible: threshold + grace passed      │
│  2. Calculate claim: proportional to vBTC held              │
│  3. Burn vBTC: btcToken.burnFrom(claimer, required)         │
│  4. Transfer collateral: WBTC.transfer(claimer, amount)     │
│  5. Burn Treasure NFT                                       │
│  6. Burn empty Vault NFT                                    │
│  7. Emit: DormantCollateralClaimed(...)                     │
└─────────────────────────────────────────────────────────────┘
```

### Protection for Vault Owners

- Activity resets dormancy timer (withdrawals, transfers)
- 30-day grace period after threshold
- Treasure NFT burned (commitment mechanism)

---

## 10. Risk Framework

### Market Risks

| Risk | Description | Mitigation |
|------|-------------|------------|
| Discount widening | Reduced confidence → vBTC trades at larger discount | BTC backing provides intrinsic floor; arbitrage compresses discount |
| Low volume | Less arbitrage → fewer LP fees, slower mean-reversion | Deep liquidity pools reduce slippage |
| BTC price crash | Underlying value declines | Historical 1093-day periods show 100% positive returns |

### Structural Risks

| Risk | Description | Mitigation |
|------|-------------|------------|
| Smart contract | vBTC contract vulnerabilities | Immutable, minimal code, audited |
| Redemption friction | All-or-nothing requirement | By design (prevents partial claims) |
| Dormancy (for Vault holders) | Vault can become dormant if inactive | Activity resets timer; grace period |

### What vBTC Does NOT Have

| Risk | Status | Explanation |
|------|--------|-------------|
| Liquidation risk | None | No CDP mechanics; position is permanent |
| Oracle dependency | None | Price discovery is market-driven |
| Admin key risk | None | No admin functions exist |
| Pause risk | None | No pause mechanism |

---

## 11. Technical Reference

### Contract Interface

```solidity
interface IBtcToken is IERC20 {
    function mint(address to, uint256 amount) external;
    function burnFrom(address from, uint256 amount) external;
}
```

### VaultNFT Functions (vBTC-related)

```solidity
function mintBtcToken(uint256 tokenId) external returns (uint256 amount);
function returnBtcToken(uint256 tokenId) external;
function claimDormantCollateral(uint256 tokenId) external returns (uint256 collateral);
function getCollateralClaim(uint256 tokenId) external view returns (uint256);
function getClaimValue(address holder, uint256 tokenId) external view returns (uint256);
function isDormantEligible(uint256 tokenId) external view returns (bool eligible, DormancyState state);
```

### Events

```solidity
event BtcTokenMinted(uint256 indexed tokenId, address indexed to, uint256 amount);
event BtcTokenReturned(uint256 indexed tokenId, address indexed from, uint256 amount);
event DormantCollateralClaimed(
    uint256 indexed tokenId,
    address indexed originalOwner,
    address indexed claimer,
    uint256 collateralClaimed
);
```

### Errors

```solidity
error BtcTokenAlreadyMinted(uint256 tokenId);  // Cannot mint vBTC twice
error BtcTokenRequired(uint256 tokenId);        // Vault has no separated vBTC
error InsufficientBtcToken(uint256 required, uint256 available);
error NotClaimable(uint256 tokenId);            // Dormancy conditions not met
```

### Gas Costs (Ethereum Mainnet)

| Operation | Gas | Cost @ 30 gwei | Cost @ 100 gwei |
|-----------|-----|----------------|-----------------|
| mintBtcToken | ~120,000 | ~$7 | ~$24 |
| returnBtcToken | ~100,000 | ~$6 | ~$20 |
| claimDormantCollateral | ~150,000 | ~$9 | ~$30 |
