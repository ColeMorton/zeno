# Protocol HybridVaultNFT Specification

> **Version:** 1.0
> **Status:** Canonical
> **Last Updated:** 2026-01-03
> **Layer:** Protocol
> **Related Documents:**
> - [Technical Specification](./Technical_Specification.md)
> - [Issuer Hybrid Vault Specification](../issuer/Hybrid_Vault_Specification.md)

---

## Overview

The protocol-layer `HybridVaultNFT` is an immutable dual-collateral vault that accepts two ERC-20 tokens with asymmetric withdrawal models:

| Component | Collateral | Withdrawal Model |
|-----------|-----------|------------------|
| **Primary** | cbBTC (or any ERC-20) | 1% monthly perpetual (Zeno's paradox) |
| **Secondary** | Any ERC-20 (LP tokens) | 100% one-time at vesting |

```
Protocol Layer (Immutable):
├─ HybridVaultNFT.sol
│   ├─ Primary: 1% monthly withdrawal
│   ├─ Secondary: 100% unlock at vesting
│   ├─ vestedBTC separation (primary only)
│   ├─ Dual match pools
│   ├─ Dormancy mechanics
│   └─ Withdrawal delegation (primary only)
```

---

## Design Principles

### 1. Ratio Agnostic

The protocol has **zero knowledge** of collateral ratios. Callers (issuer contracts) determine the split:

```solidity
// Issuer contract determines ratio
uint256 primaryAmount = totalCbBTC * 7000 / 10000;  // 70%
uint256 secondaryAmount = lpTokensFromCurve;        // 30%

hybridVault.mint(treasure, tokenId, primaryAmount, secondaryAmount);
```

### 2. Asymmetric Withdrawal

Different collateral types have different withdrawal models:

| Model | Rationale |
|-------|-----------|
| Primary: 1% monthly | Perpetual income stream (Zeno's paradox) |
| Secondary: 100% one-time | Liquidity event for LP tokens |

### 3. Dual Match Pools

Both collateral types have separate match pools funded by early redemption forfeitures:

- `primaryMatchPool` — forfeited cbBTC
- `secondaryMatchPool` — forfeited LP tokens

### 4. Immutability

All parameters are bytecode constants. No governance, no admin functions.

---

## Specification

### Immutable Parameters

| Parameter | Value | Source |
|-----------|-------|--------|
| `primaryToken` | Fixed at deployment | Constructor |
| `secondaryToken` | Fixed at deployment | Constructor |
| `btcToken` | vestedBTC instance | Constructor |
| `VESTING_PERIOD` | 1129 days | VaultMath library |
| `WITHDRAWAL_RATE` | 1% monthly (1000 BPS) | VaultMath library |
| `WITHDRAWAL_PERIOD` | 30 days | VaultMath library |

### Core Functions

#### Mint

```solidity
function mint(
    address treasureContract,
    uint256 treasureTokenId,
    uint256 primaryAmount,
    uint256 secondaryAmount
) external returns (uint256 tokenId);
```

Creates a hybrid vault with:
- Treasure NFT (transferred to contract)
- Primary collateral (cbBTC)
- Secondary collateral (any ERC-20)

#### Withdraw Primary

```solidity
function withdrawPrimary(uint256 tokenId) external returns (uint256 amount);
```

- 1% of primary collateral monthly
- Perpetual (Zeno's paradox)
- Requires full vesting (1129 days)
- 30-day cooldown between withdrawals

#### Withdraw Secondary

```solidity
function withdrawSecondary(uint256 tokenId) external returns (uint256 amount);
```

- 100% of secondary collateral
- One-time only (flag set after withdrawal)
- Requires full vesting (1129 days)

#### Early Redemption

```solidity
function earlyRedeem(uint256 tokenId) external returns (
    uint256 primaryReturned,
    uint256 primaryForfeited,
    uint256 secondaryReturned,
    uint256 secondaryForfeited
);
```

- Both collaterals use same linear ramp formula
- Forfeited amounts go to respective match pools
- Burns vault and treasure NFTs

### vestedBTC Separation (Primary Only)

```solidity
function mintBtcToken(uint256 tokenId) external returns (uint256 amount);
function returnBtcToken(uint256 tokenId) external;
```

- Only primary collateral can be separated
- Mints vestedBTC tokens representing collateral claim
- Enables DeFi composability (trading, lending)

### Match Pool Claims

```solidity
function claimPrimaryMatch(uint256 tokenId) external returns (uint256 amount);
function claimSecondaryMatch(uint256 tokenId) external returns (uint256 amount);
```

- Vested vaults can claim proportional share of match pools
- Increases respective collateral balance

### Dormancy

Same mechanics as VaultNFT:
- `pokeDormant()` — Start grace period
- `proveActivity()` — Reset dormancy
- `claimDormantCollateral()` — Claim both collateral types

### Withdrawal Delegation

Same pattern as VaultNFT, applies to primary only:
- Wallet-level delegation (all vaults)
- Vault-specific delegation (single vault)
- `withdrawPrimaryAsDelegate()` — Delegate withdrawal
- Secondary is NOT delegatable

---

## State Storage

```solidity
// Per-vault state
mapping(uint256 => uint256) private _primaryAmount;
mapping(uint256 => uint256) private _secondaryAmount;
mapping(uint256 => uint256) private _mintTimestamp;
mapping(uint256 => uint256) private _lastPrimaryWithdrawal;
mapping(uint256 => bool) private _secondaryWithdrawn;
mapping(uint256 => uint256) private _lastActivity;
mapping(uint256 => uint256) private _pokeTimestamp;

// Treasure state
mapping(uint256 => address) private _treasureContract;
mapping(uint256 => uint256) private _treasureTokenId;

// vestedBTC separation (primary only)
mapping(uint256 => uint256) private _btcTokenAmount;
mapping(uint256 => uint256) private _originalMintedAmount;

// Match pools
uint256 public primaryMatchPool;
uint256 public secondaryMatchPool;
uint256 public totalActivePrimary;
uint256 public totalActiveSecondary;
```

---

## Withdrawal Timeline

```
Day 0:      Vault created
            Primary + Secondary deposited

Day 0-1129: Vesting period
            Both components locked

Day 1129:   Maturity
            Primary: 1% monthly withdrawals begin
            Secondary: 100% available (one-time)

Day 1129+:  Post-maturity
            Primary: Perpetual asymptotic depletion
            Secondary: Zero (already withdrawn)
```

---

## Comparison: VaultNFT vs HybridVaultNFT

| Property | VaultNFT | HybridVaultNFT |
|----------|----------|----------------|
| Collateral | Single (cbBTC) | Dual (primary + secondary) |
| Withdrawal | 1% monthly | Primary: 1% monthly, Secondary: 100% one-time |
| Match Pool | Single | Dual (primary + secondary) |
| vestedBTC | Full collateral | Primary only |
| Delegation | Full withdrawal | Primary only |
| Complexity | Lower | Higher |

---

## Usage Pattern

### Issuer Integration

The issuer layer wraps HybridVaultNFT with additional logic:

```solidity
// Issuer contract (e.g., IssuerHybridController)
contract IssuerHybridController {
    IHybridVaultNFT public hybridVault;
    ICurvePool public curvePool;

    function mintHybridVault(uint256 cbBTCAmount) external {
        // Calculate split (e.g., 70/30)
        uint256 primaryAmount = cbBTCAmount * 7000 / 10000;
        uint256 lpAmount = cbBTCAmount * 3000 / 10000;

        // Add LP to Curve
        uint256 lpTokens = curvePool.add_liquidity([lpAmount, 0], 0);

        // Mint treasure
        uint256 treasureId = treasureNFT.mint(msg.sender);

        // Mint hybrid vault
        hybridVault.mint(
            address(treasureNFT),
            treasureId,
            primaryAmount,
            lpTokens
        );
    }
}
```

---

## Contract Files

| File | Description |
|------|-------------|
| `contracts/protocol/src/HybridVaultNFT.sol` | Main contract |
| `contracts/protocol/src/interfaces/IHybridVaultNFT.sol` | Interface |
| `contracts/protocol/test/unit/HybridVaultNFT.t.sol` | Unit tests |
| `contracts/protocol/script/DeployHybrid.s.sol` | Deployment |

---

## Navigation

← [Technical Specification](./Technical_Specification.md) | [Documentation Home](../README.md)
