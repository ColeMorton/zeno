# Protocol Hybrid Vault Specification

> **Version:** 2.0
> **Status:** Canonical
> **Last Updated:** 2026-07-07
> **Layer:** Protocol
> **Related Documents:**
> - [Technical Specification](./Technical_Specification.md)
> - [Issuer Hybrid Vault Specification](../issuer/Hybrid_Vault_Specification.md)

---

## Overview

The protocol hybrid vault is a **composition of two immutable primitives**, not a dedicated contract. A standard `VaultNFT` holds the primary leg; a `VestingEscrow` holds the secondary leg, keyed to the same vault token ID and the same vesting clock:

| Component | Contract | Collateral | Withdrawal Model |
|-----------|----------|-----------|------------------|
| **Primary** | `VaultNFT` | cbBTC (or any ERC-20) | 1% monthly perpetual (Zeno's paradox) |
| **Secondary** | `VestingEscrow` | Any ERC-20 (LP tokens) | 100% one-time claim at vesting |

```
Protocol Layer (Immutable):
├─ VaultNFT.sol (primary leg)
│   ├─ 1% monthly withdrawal
│   ├─ vestedBTC stripping (strip/recombine)
│   ├─ Shared match pool
│   ├─ Dormancy mechanics
│   ├─ Withdrawal delegation
│   └─ setRedeemHook → atomic early-exit binding
│
└─ VestingEscrow.sol (secondary leg)
    ├─ 100% unlock at vesting (claim)
    ├─ Own match accumulator (forfeited escrow)
    └─ IRedeemHook.onEarlyRedeem (settled by vault's earlyRedeem)
```

---

## Design Principles

### 1. Single Vault Primitive

There is no dual-collateral vault contract. The vault knows nothing about the escrow beyond a one-time hook address; the escrow reads the vault's owner, mint timestamp, and hook binding. Callers (issuer contracts) compose the two:

```solidity
// Issuer contract composes the legs
uint256 vaultId = vaultNFT.mint(treasure, tokenId, address(cbBTC), primaryAmount);
vaultNFT.setRedeemHook(vaultId, address(escrow));   // owner-only, one-time
escrow.deposit(vaultId, lpTokensFromCurve);         // requires hook binding
```

### 2. Asymmetric Withdrawal

Different legs have different withdrawal models:

| Model | Rationale |
|-------|-----------|
| Primary: 1% monthly (`VaultNFT.withdraw`) | Perpetual income stream (Zeno's paradox) |
| Secondary: 100% one-time (`VestingEscrow.claim`) | Liquidity event for LP tokens |

### 3. Separate Match Accounting

Each leg accrues early-redemption forfeitures independently:

- `VaultNFT.matchPool` — forfeited primary collateral (shared with all standard vaults)
- `VestingEscrow.matchPool` — forfeited escrow, distributed pro-rata via an order-independent accumulator (`accMatchPerEscrowed`)

### 4. Atomic Early Exit

`VaultNFT.earlyRedeem` calls `IRedeemHook.onEarlyRedeem(tokenId, redeemer)` at the end. `VestingEscrow` implements the hook and settles the secondary leg with the **same pro-rata forfeiture curve** in the same transaction. `VestingEscrow.deposit` reverts unless the hook is already bound, so an escrowed position can never strand on vault burn.

### 5. Immutability

All parameters are bytecode constants. No governance, no admin functions on either contract.

---

## Specification

### Immutable Parameters

| Parameter | Value | Source |
|-----------|-------|--------|
| `VaultNFT.collateralToken` | Fixed at deployment | Constructor |
| `VestingEscrow.vault` | VaultNFT instance | Constructor |
| `VestingEscrow.token` | Escrowed ERC-20 | Constructor |
| `VESTING_PERIOD` | 1129 days | VaultMath library |
| `WITHDRAWAL_RATE` | 1% monthly (1000 BPS) | VaultMath library |
| `WITHDRAWAL_PERIOD` | 30 days | VaultMath library |

### Core Functions

#### Compose (Mint + Bind + Deposit)

```solidity
// VaultNFT
function mint(address treasureContract, uint256 treasureTokenId, address collateralToken, uint256 collateralAmount) external returns (uint256 tokenId);
function setRedeemHook(uint256 tokenId, address hook) external;  // owner-only, one-time

// VestingEscrow
function deposit(uint256 tokenId, uint256 amount) external;  // requires redeemHook(tokenId) == escrow
```

- One escrow position per vault (`AlreadyDeposited` otherwise)
- Deposit copies the vault's mint timestamp as the position's vesting clock (survives vault burn)

#### Withdraw Primary

```solidity
function withdraw(uint256 tokenId) external returns (uint256 amount);  // VaultNFT
```

- 1% of primary collateral monthly, perpetual (Zeno's paradox)
- Requires full vesting (1129 days); 30-day cooldown

#### Claim Secondary

```solidity
function claim(uint256 tokenId) external returns (uint256 amount);  // VestingEscrow
```

- 100% of escrowed amount (plus accrued match share), one-time — position cleared after claim
- Requires full vesting (same clock as the vault)
- Claim rights follow vault ownership (`vault.ownerOf(tokenId)`)

#### Early Redemption (Atomic)

```solidity
// VaultNFT — settles both legs in one transaction
function earlyRedeem(uint256 tokenId) external returns (uint256 returned, uint256 forfeited);

// VestingEscrow — called by the vault, not by users
function onEarlyRedeem(uint256 tokenId, address redeemer) external;
```

- Both legs use the same linear ramp formula (`VaultMath.calculateEarlyRedemption`)
- Primary forfeiture → `VaultNFT.matchPool`; secondary forfeiture → `VestingEscrow` accumulator
- Burns vault and treasure NFTs; escrow position cleared, returned tokens sent to the redeemer

### vestedBTC Stripping (Primary Only)

```solidity
function strip(uint256 tokenId, uint256 amount) external;      // VaultNFT
function recombine(uint256 tokenId, uint256 amount) external;  // VaultNFT
```

- Only the vault's primary collateral can be stripped into vestedBTC
- The escrowed secondary leg is never strippable

### Match Claims

```solidity
function claimMatch(uint256 tokenId) external returns (uint256 amount);  // VaultNFT (primary)
function claimMatch(uint256 tokenId) external returns (uint256 amount);  // VestingEscrow (secondary)
function pendingMatch(uint256 tokenId) external view returns (uint256);  // both
```

- Vault match: standard `VaultNFT` mechanics, shared pool with all vaults
- Escrow match: settles the position's accrued share into `escrowAmount` (pull-based accumulator)

### Dormancy

Standard `VaultNFT` mechanics apply to the primary leg:
- `pokeDormant()` — Start grace period
- `proveActivity()` — Reset dormancy
- `claimDormantCollateral()` — Claim primary collateral

The escrowed secondary leg is not subject to dormancy; it remains claimable by the vault owner at vesting.

### Withdrawal Delegation

Standard `VaultNFT` pattern, applies to the primary leg only:
- Wallet-level delegation (all vaults)
- Vault-specific delegation (single vault)
- `withdrawAsDelegate()` — Delegate withdrawal
- The secondary leg is NOT delegatable

---

## State Storage

```solidity
// VaultNFT — standard single-collateral vault state (see Technical Specification)

// VestingEscrow
mapping(uint256 => uint256) public escrowAmount;     // per vault token ID
mapping(uint256 => uint256) public mintTimestamp;    // copied from vault at deposit
mapping(uint256 => uint256) private _matchDebt;      // accumulator checkpoint

uint256 public matchPool;             // forfeited escrow not yet settled
uint256 public totalEscrowed;         // settled escrow across all positions
uint256 public accMatchPerEscrowed;   // forfeit accrued per unit escrowed (1e18 fixed-point)
```

---

## Withdrawal Timeline

```
Day 0:      Vault minted (primary leg)
            Hook bound, secondary leg escrowed

Day 0-1129: Vesting period
            Both legs locked

Day 1129:   Maturity
            Primary: 1% monthly withdrawals begin (VaultNFT.withdraw)
            Secondary: 100% claimable (VestingEscrow.claim, one-time)

Day 1129+:  Post-maturity
            Primary: Perpetual asymptotic depletion
            Secondary: Zero (already claimed)
```

---

## Comparison: Standard vs Hybrid

| Property | Standard Vault | Hybrid (VaultNFT + VestingEscrow) |
|----------|----------------|-----------------------------------|
| Collateral | Single (cbBTC) | Dual (vault primary + escrowed secondary) |
| Withdrawal | 1% monthly | Primary: 1% monthly, Secondary: 100% one-time |
| Match Pool | Single | Vault pool + escrow accumulator |
| vestedBTC | Full collateral | Primary only |
| Delegation | Full withdrawal | Primary only |
| Extra contracts | None | VestingEscrow bound as redeem hook |

---

## Usage Pattern

### Issuer Integration

The issuer layer composes the primitives (see `HybridMintController`):

```solidity
contract HybridMintController {
    IVaultNFT public vaultNFT;
    VestingEscrow public vestingEscrow;
    ICurveCryptoSwap public curvePool;

    function mintHybridVault(uint256 cbBTCAmount) external returns (uint256 vaultId) {
        // Split per dynamic LP ratio (e.g., 70/30)
        uint256 lpPortion = cbBTCAmount * 3000 / 10000;
        uint256 vaultPortion = cbBTCAmount - lpPortion;

        // Add LP leg to Curve
        uint256 lpTokens = curvePool.add_liquidity([lpPortion, 0], 0);

        // Compose: mint vault, bind hook, escrow LP, hand vault to user
        uint256 treasureId = treasureNFT.mint(address(this));
        vaultId = vaultNFT.mint(address(treasureNFT), treasureId, address(cbBTC), vaultPortion);
        vaultNFT.setRedeemHook(vaultId, address(vestingEscrow));
        vestingEscrow.deposit(vaultId, lpTokens);
        IERC721(address(vaultNFT)).transferFrom(address(this), msg.sender, vaultId);
    }
}
```

---

## Contract Files

| File | Description |
|------|-------------|
| `contracts/protocol/src/VaultNFT.sol` | Primary leg (standard vault + redeem hook) |
| `contracts/protocol/src/VestingEscrow.sol` | Secondary leg escrow |
| `contracts/protocol/src/interfaces/IRedeemHook.sol` | Atomic early-exit callback |
| `contracts/issuer/src/HybridMintController.sol` | Issuer-layer composition |

---

## Navigation

← [Technical Specification](./Technical_Specification.md) | [Documentation Home](../README.md)
