# BTCNFT Protocol - Withdrawal Delegation

> **Version:** 3.0
> **Status:** Draft
> **Last Updated:** 2026-01-01
> **Related Documents:**
> - [Technical Specification](./Technical_Specification.md)
> - [Product Specification](./Product_Specification.md)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Use Cases](#2-use-cases)
3. [Wallet-Level Delegation](#3-wallet-level-delegation)
   - 3.1 [Data Structures](#31-data-structures)
   - 3.2 [Functions](#32-functions)
4. [Vault-Level Delegation](#4-vault-level-delegation)
   - 4.1 [Data Structures](#41-data-structures)
   - 4.2 [Functions](#42-functions)
   - 4.3 [Time-Limited Delegation](#43-time-limited-delegation)
5. [Delegation Resolution](#5-delegation-resolution)
6. [Access Control](#6-access-control)
7. [Withdrawal Calculations](#7-withdrawal-calculations)
8. [Integration with Existing Features](#8-integration-with-existing-features)
9. [Security Considerations](#9-security-considerations)
10. [Example Scenarios](#10-example-scenarios)
11. [Events and Monitoring](#11-events-and-monitoring)
12. [ERC-4337 Withdrawal Automation](#12-erc-4337-withdrawal-automation)

---

## 1. Overview

The Withdrawal Delegation feature allows vault owners to grant withdrawal permissions to delegate addresses. The protocol supports **two delegation levels**:

| Level | Scope | Use Case |
|-------|-------|----------|
| **Wallet-Level** | All vaults owned by wallet | Multi-vault automation |
| **Vault-Level** | Single specific vault | Granular control, time-limited |

### Key Features

- **Dual-level delegation**: Wallet-wide or vault-specific grants
- **Vault-level precedence**: Vault-specific overrides wallet-level
- **Time-limited grants**: Vault-level supports optional expiry
- **Per-vault cooldowns**: Each vault tracks its own 30-day cooldown per delegate
- **Revocable permissions**: Owner can revoke at any time
- **Multiple delegates**: Support multiple delegates (up to 100% total per level)

### Design Principles

1. **Non-custodial**: Vault ownership never transfers
2. **Owner sovereignty**: Only owner can grant/revoke permissions
3. **Proportional access**: Delegates can only access their granted percentage
4. **Activity preservation**: Delegate actions prevent vault dormancy
5. **Vault-level precedence**: Vault-specific delegation always takes priority

---

## 2. Use Cases

### 2.1 Multi-Vault Holder

A user holds 5 Vault NFTs and wants to automate withdrawals:
- **Old approach**: 5 separate delegation grants, 5 session keys
- **New approach**: 1 wallet-level grant, 1 session key

### 2.2 DAO Treasury Management

A DAO holds multiple Vault NFTs and wants to delegate withdrawal permissions:
- Treasury committee: 60% withdrawal rights (all vaults)
- Operations wallet: 30% withdrawal rights (all vaults)
- Emergency fund: 10% withdrawal rights (all vaults)

### 2.3 Family Wealth Distribution

Parents vault assets across multiple NFTs and delegate withdrawal rights:
- Child 1: 33% monthly allowance (all family vaults)
- Child 2: 33% monthly allowance (all family vaults)
- Child 3: 34% monthly allowance (all family vaults)

### 2.4 Automated Services

Vault holder delegates to a smart contract for:
- DCA (Dollar Cost Averaging) strategies: 25% monthly (all vaults)
- Bill payments: 20% monthly (all vaults)
- Investment allocation: 55% monthly (all vaults)

---

## 3. Wallet-Level Delegation

**Wallet-level delegation** means a single grant applies to ALL vaults owned by that wallet, eliminating the need for per-vault configuration.

### 3.1 Data Structures

```solidity
/// @notice Wallet-level delegation permission (applies to all vaults owned by wallet)
struct WalletDelegatePermission {
    uint256 percentageBPS;      // Basis points (100 = 1%, 10000 = 100%)
    uint256 grantedAt;          // When permission was granted
    bool active;                // Permission status
}

// Wallet-level delegation: owner => delegate => permission
mapping(address => mapping(address => WalletDelegatePermission)) public walletDelegates;

// Total delegated percentage per wallet
mapping(address => uint256) public walletTotalDelegatedBPS;

// Per-delegate-per-vault cooldown tracking: delegate => tokenId => lastWithdrawal
mapping(address => mapping(uint256 => uint256)) public delegateVaultCooldown;
```

### 3.2 Functions

#### Grant Withdrawal Delegation

```solidity
/// @notice Grant withdrawal permission to a delegate (applies to all your vaults)
/// @param delegate Address to grant permission to
/// @param percentageBPS Percentage in basis points (100 = 1%)
function grantWithdrawalDelegate(address delegate, uint256 percentageBPS) external {
    if (delegate == address(0)) revert ZeroAddress();
    if (delegate == msg.sender) revert CannotDelegateSelf();
    if (percentageBPS == 0 || percentageBPS > 10000) revert InvalidPercentage(percentageBPS);

    uint256 currentDelegated = walletTotalDelegatedBPS[msg.sender];
    WalletDelegatePermission storage existingPermission = walletDelegates[msg.sender][delegate];
    bool isUpdate = existingPermission.active;
    uint256 oldPercentageBPS = existingPermission.percentageBPS;

    if (isUpdate) {
        currentDelegated -= oldPercentageBPS;
    }
    if (currentDelegated + percentageBPS > 10000) revert ExceedsDelegationLimit();

    walletDelegates[msg.sender][delegate] = WalletDelegatePermission({
        percentageBPS: percentageBPS,
        grantedAt: block.timestamp,
        active: true
    });

    walletTotalDelegatedBPS[msg.sender] = currentDelegated + percentageBPS;

    if (isUpdate) {
        emit WalletDelegateUpdated(msg.sender, delegate, oldPercentageBPS, percentageBPS);
    } else {
        emit WalletDelegateGranted(msg.sender, delegate, percentageBPS);
    }
}
```

#### Revoke Withdrawal Delegation

```solidity
/// @notice Revoke withdrawal permission from a delegate
/// @param delegate Address to revoke permission from
function revokeWithdrawalDelegate(address delegate) external {
    WalletDelegatePermission storage permission = walletDelegates[msg.sender][delegate];
    if (!permission.active) revert DelegateNotActive(msg.sender, delegate);

    walletTotalDelegatedBPS[msg.sender] -= permission.percentageBPS;
    permission.active = false;

    emit WalletDelegateRevoked(msg.sender, delegate);
}
```

#### Revoke All Withdrawal Delegations

```solidity
/// @notice Revoke ALL withdrawal permissions for your wallet
function revokeAllWithdrawalDelegates() external {
    walletTotalDelegatedBPS[msg.sender] = 0;
    emit AllWalletDelegatesRevoked(msg.sender);
}
```

#### Withdraw as Delegate

```solidity
/// @notice Withdraw from a vault as an authorized delegate
/// @param tokenId The Vault NFT token ID to withdraw from
/// @return withdrawnAmount Amount withdrawn
function withdrawAsDelegate(uint256 tokenId) external returns (uint256 withdrawnAmount) {
    _requireOwned(tokenId);
    address vaultOwner = ownerOf(tokenId);

    // Check vesting
    if (!VaultMath.isVested(_mintTimestamp[tokenId], block.timestamp)) {
        revert StillVesting(tokenId);
    }

    // Check WALLET-level delegation (from current vault owner)
    WalletDelegatePermission storage permission = walletDelegates[vaultOwner][msg.sender];
    if (!permission.active || walletTotalDelegatedBPS[vaultOwner] == 0) {
        revert NotActiveDelegate(tokenId, msg.sender);
    }

    // Check per-delegate-per-vault cooldown
    uint256 delegateLastWithdrawal = delegateVaultCooldown[msg.sender][tokenId];
    if (delegateLastWithdrawal > 0 && !VaultMath.canWithdraw(delegateLastWithdrawal, block.timestamp)) {
        revert WithdrawalPeriodNotMet(tokenId, msg.sender);
    }

    // Calculate and transfer
    uint256 currentCollateral = _collateralAmount[tokenId];
    uint256 totalPool = VaultMath.calculateWithdrawal(currentCollateral);
    withdrawnAmount = (totalPool * permission.percentageBPS) / 10000;

    if (withdrawnAmount == 0) return 0;

    _collateralAmount[tokenId] = currentCollateral - withdrawnAmount;
    delegateVaultCooldown[msg.sender][tokenId] = block.timestamp;
    _updateActivity(tokenId);

    IERC20(collateralToken).safeTransfer(msg.sender, withdrawnAmount);
    emit DelegatedWithdrawal(tokenId, msg.sender, vaultOwner, withdrawnAmount);

    return withdrawnAmount;
}
```

#### View Functions

```solidity
/// @notice Check if a delegate can withdraw from a vault
function canDelegateWithdraw(uint256 tokenId, address delegate)
    external view returns (bool canWithdraw, uint256 amount) {
    address vaultOwner;
    try this.ownerOf(tokenId) returns (address owner_) {
        vaultOwner = owner_;
    } catch {
        return (false, 0);
    }

    if (!VaultMath.isVested(_mintTimestamp[tokenId], block.timestamp)) {
        return (false, 0);
    }

    WalletDelegatePermission storage permission = walletDelegates[vaultOwner][delegate];
    if (!permission.active || walletTotalDelegatedBPS[vaultOwner] == 0) {
        return (false, 0);
    }

    uint256 delegateLastWithdrawal = delegateVaultCooldown[delegate][tokenId];
    if (delegateLastWithdrawal > 0 && !VaultMath.canWithdraw(delegateLastWithdrawal, block.timestamp)) {
        return (false, 0);
    }

    uint256 currentCollateral = _collateralAmount[tokenId];
    uint256 totalPool = VaultMath.calculateWithdrawal(currentCollateral);
    amount = (totalPool * permission.percentageBPS) / 10000;

    return (amount > 0, amount);
}

/// @notice Get wallet-level delegate permission
function getWalletDelegatePermission(address owner, address delegate)
    external view returns (WalletDelegatePermission memory) {
    return walletDelegates[owner][delegate];
}

/// @notice Get delegate's cooldown for a specific vault
function getDelegateCooldown(address delegate, uint256 tokenId)
    external view returns (uint256) {
    return delegateVaultCooldown[delegate][tokenId];
}

/// @notice Get total delegated BPS for a wallet
function walletTotalDelegatedBPS(address owner) external view returns (uint256) {
    return walletTotalDelegatedBPS[owner];
}
```

---

## 4. Vault-Level Delegation

**Vault-level delegation** allows granular control over individual vaults with optional time-limited grants. Vault-specific grants take precedence over wallet-level delegation.

### 4.1 Data Structures

```solidity
/// @notice Vault-specific delegation permission (applies to a single vault)
struct VaultDelegatePermission {
    uint256 percentageBPS;      // Basis points (100 = 1%, 10000 = 100%)
    uint256 grantedAt;          // When permission was granted
    uint256 expiresAt;          // 0 = no expiry, >0 = auto-expires at timestamp
    bool active;                // Permission status
}

/// @notice Delegation type for resolution reporting
enum DelegationType { None, WalletLevel, VaultSpecific }

// Vault-level delegation: tokenId => delegate => permission
mapping(uint256 => mapping(address => VaultDelegatePermission)) public vaultDelegates;

// Total delegated percentage per vault
mapping(uint256 => uint256) public vaultTotalDelegatedBPS;
```

### 4.2 Functions

#### Grant Vault-Level Delegation

```solidity
/// @notice Grant vault-specific withdrawal delegation
/// @param tokenId Vault token ID (caller must be owner)
/// @param delegate Address to delegate to
/// @param percentageBPS Percentage in basis points (100 = 1%)
/// @param durationSeconds Duration in seconds (0 = indefinite)
function grantVaultDelegate(
    uint256 tokenId,
    address delegate,
    uint256 percentageBPS,
    uint256 durationSeconds
) external {
    if (ownerOf(tokenId) != msg.sender) revert NotVaultOwner(tokenId);
    if (delegate == address(0)) revert ZeroAddress();
    if (delegate == msg.sender) revert CannotDelegateSelf();
    if (percentageBPS == 0 || percentageBPS > 10000) revert InvalidPercentage(percentageBPS);

    uint256 currentVaultDelegated = vaultTotalDelegatedBPS[tokenId];
    VaultDelegatePermission storage existing = vaultDelegates[tokenId][delegate];
    bool isUpdate = existing.active;
    uint256 oldPercentageBPS = existing.percentageBPS;

    if (isUpdate) {
        currentVaultDelegated -= oldPercentageBPS;
    }
    if (currentVaultDelegated + percentageBPS > 10000) revert ExceedsVaultDelegationLimit(tokenId);

    uint256 expiresAt = durationSeconds > 0 ? block.timestamp + durationSeconds : 0;
    vaultDelegates[tokenId][delegate] = VaultDelegatePermission({
        percentageBPS: percentageBPS,
        grantedAt: block.timestamp,
        expiresAt: expiresAt,
        active: true
    });
    vaultTotalDelegatedBPS[tokenId] = currentVaultDelegated + percentageBPS;

    if (isUpdate) {
        emit VaultDelegateUpdated(tokenId, delegate, oldPercentageBPS, percentageBPS, expiresAt);
    } else {
        emit VaultDelegateGranted(tokenId, delegate, percentageBPS, expiresAt);
    }
}
```

#### Revoke Vault-Level Delegation

```solidity
/// @notice Revoke a vault-specific delegate's permission
/// @param tokenId Vault token ID (caller must be owner)
/// @param delegate Address to revoke
function revokeVaultDelegate(uint256 tokenId, address delegate) external {
    if (ownerOf(tokenId) != msg.sender) revert NotVaultOwner(tokenId);

    VaultDelegatePermission storage permission = vaultDelegates[tokenId][delegate];
    if (!permission.active) revert VaultDelegateNotActive(tokenId, delegate);

    vaultTotalDelegatedBPS[tokenId] -= permission.percentageBPS;
    permission.active = false;

    emit VaultDelegateRevoked(tokenId, delegate);
}
```

#### View Functions

```solidity
/// @notice Get vault-specific delegate permission
function getVaultDelegatePermission(uint256 tokenId, address delegate)
    external view returns (VaultDelegatePermission memory) {
    return vaultDelegates[tokenId][delegate];
}

/// @notice Get total delegated BPS for a specific vault
function vaultTotalDelegatedBPS(uint256 tokenId) external view returns (uint256) {
    return vaultTotalDelegatedBPS[tokenId];
}

/// @notice Get effective delegation (resolves precedence)
function getEffectiveDelegation(uint256 tokenId, address delegate)
    external view returns (uint256 percentageBPS, DelegationType dtype, bool isExpired) {
    VaultDelegatePermission storage vaultPerm = vaultDelegates[tokenId][delegate];

    // Check vault-specific first (takes precedence)
    if (vaultPerm.active) {
        bool expired = vaultPerm.expiresAt > 0 && block.timestamp > vaultPerm.expiresAt;
        return (vaultPerm.percentageBPS, DelegationType.VaultSpecific, expired);
    }

    // Fall back to wallet-level
    address vaultOwner = ownerOf(tokenId);
    WalletDelegatePermission storage walletPerm = walletDelegates[vaultOwner][delegate];
    if (walletPerm.active && walletTotalDelegatedBPS[vaultOwner] > 0) {
        return (walletPerm.percentageBPS, DelegationType.WalletLevel, false);
    }

    return (0, DelegationType.None, false);
}
```

### 4.3 Time-Limited Delegation

Vault-level delegation supports optional expiry via the `durationSeconds` parameter:

| Duration | Behavior |
|----------|----------|
| `0` | No expiry (indefinite until revoked) |
| `> 0` | Auto-expires after `block.timestamp + durationSeconds` |

**Use Cases:**
- **Temporary contractor access**: 30-day delegation for service providers
- **Seasonal automation**: 90-day delegation for quarterly operations
- **Trial periods**: 7-day delegation for testing automation services

**Expiry Behavior:**
- Expired delegations remain in storage but are inactive
- `canDelegateWithdraw()` returns `false` for expired grants
- `getEffectiveDelegation()` returns `isExpired = true`
- Owner can re-grant at any time (creates new grant)

---

## 5. Delegation Resolution

When a delegate attempts withdrawal, the contract resolves which delegation applies:

```
withdrawAsDelegate(tokenId)
    │
    ├─ 1. Check vault-specific delegation for (tokenId, msg.sender)
    │      if active AND (no expiry OR not expired):
    │          → USE vault-specific percentage
    │
    └─ 2. Fall back to wallet-level delegation for (vaultOwner, msg.sender)
           if active:
               → USE wallet-level percentage
           else:
               → REVERT NotActiveDelegate
```

**Resolution Priority:**
1. **Vault-specific** takes precedence over wallet-level
2. An expired vault-specific grant falls back to wallet-level
3. Revoked vault-specific grant falls back to wallet-level

### Example: Override Scenario

```solidity
// Alice owns Vault #1, grants wallet-level to Bob at 50%
grantWithdrawalDelegate(bob, 5000);

// Later, Alice grants vault-specific to Bob at 30% for Vault #1 only
grantVaultDelegate(1, bob, 3000, 0);

// Bob withdraws from Vault #1
withdrawAsDelegate(1);
// → Uses 30% (vault-specific takes precedence)

// Bob withdraws from Vault #2 (no vault-specific grant)
withdrawAsDelegate(2);
// → Uses 50% (falls back to wallet-level)
```

---

## 6. Access Control

| Function | Caller Requirement | Level |
|----------|-------------------|-------|
| `grantWithdrawalDelegate` | Any wallet (for own vaults) | Wallet |
| `revokeWithdrawalDelegate` | Any wallet (own grants) | Wallet |
| `revokeAllWithdrawalDelegates` | Any wallet (own grants) | Wallet |
| `grantVaultDelegate` | Vault NFT owner | Vault |
| `revokeVaultDelegate` | Vault NFT owner | Vault |
| `withdrawAsDelegate` | Active delegate | Both |
| `withdraw` (original) | Vault NFT owner only | N/A |

---

## 7. Withdrawal Calculations

For a vault with 1 BTC collateral after vesting:

**Total Monthly Withdrawal Pool: 0.01 BTC (1.0% of 1 BTC)**

| Actor | Delegation % | Share of Monthly Pool |
|-------|--------------|----------------------|
| Delegate A | 60% | 0.006 BTC |
| Delegate B | 40% | 0.004 BTC |
| **TOTAL** | **100%** | **0.01 BTC** |

**Key Points:**
- Each delegate has their OWN 30-day cooldown PER VAULT
- Cooldowns are tracked independently: `delegateVaultCooldown[delegate][tokenId]`
- Wallet-level grants apply to ALL vaults owned by the granting wallet
- Vault-level grants apply to a SINGLE vault only

---

## 8. Integration with Existing Features

### 8.1 Ownership Transfer Behavior

| Scenario | Behavior |
|----------|----------|
| Vault transferred to new owner | Old owner's delegation no longer applies; new owner's delegation applies |
| Delegate's cooldown persists | Cooldown is tied to `delegate + tokenId`, not owner |
| Re-grant after transfer | Cooldown NOT reset (prevents gaming) |

**Example:**
1. Alice owns Vault #1, delegates to Bob
2. Bob withdraws (cooldown starts: 30 days)
3. Alice transfers Vault #1 to Dave
4. Dave delegates to Bob
5. Bob still can't withdraw until cooldown expires (tied to Bob + Vault #1)

### 8.2 Activity Tracking

Delegate withdrawals update `lastActivity[tokenId]` to prevent dormancy.

### 8.3 vestedBTC Compatibility

- Delegation affects only withdrawal rights, not redemption
- vestedBTC holders cannot delegate (no withdrawal rights)

### 8.4 Dormancy Protection

- Any delegate withdrawal resets dormancy timer
- Active delegations indicate vault is managed

---

## 9. Security Considerations

### 9.1 Attack Vectors and Mitigations

| Attack Vector | Mitigation |
|--------------|------------|
| Self-delegation | Explicit check: `delegate != msg.sender` |
| Over-delegation | Total percentage tracked and limited to 100% |
| Cooldown gaming | Cooldowns persist across ownership transfers |
| Withdrawal racing | Independent cooldowns per delegate per vault |

### 9.2 Edge Cases

| Scenario | Handling |
|----------|----------|
| Vault transferred | New owner's delegation applies; cooldowns persist |
| Same delegate, multiple owners | Each vault operates independently |
| Revoke then re-grant | Cooldowns NOT reset (prevents gaming) |
| Zero collateral | Withdrawals return 0; no reverts |

---

## 10. Example Scenarios

### 10.1 Multi-Vault Setup

```solidity
// Alice owns 5 Vault NFTs and wants to delegate to Bob
// Single grant covers ALL 5 vaults!
grantWithdrawalDelegate(bob, 6000); // 60% of each vault's monthly pool

// Bob can now withdraw from any of Alice's vaults
withdrawAsDelegate(vault1); // Works
withdrawAsDelegate(vault2); // Works (independent cooldown)
withdrawAsDelegate(vault3); // Works (independent cooldown)
```

### 10.2 Ownership Transfer

```solidity
// Alice owns Vault #1, delegates to Bob
grantWithdrawalDelegate(bob, 5000); // 50%

// Bob withdraws
withdrawAsDelegate(1); // Success, cooldown starts

// Alice transfers vault to Dave
transferFrom(alice, dave, 1);

// Bob can't withdraw anymore (Alice no longer owner)
withdrawAsDelegate(1); // Reverts: NotActiveDelegate

// Dave grants to Bob
grantWithdrawalDelegate(bob, 3000); // 30%

// Bob still on cooldown for this vault!
withdrawAsDelegate(1); // Reverts: WithdrawalPeriodNotMet

// After 30 days...
withdrawAsDelegate(1); // Success
```

---

## 11. Events and Monitoring

### 11.1 Wallet-Level Events

```solidity
event WalletDelegateGranted(
    address indexed owner,
    address indexed delegate,
    uint256 percentageBPS
);

event WalletDelegateUpdated(
    address indexed owner,
    address indexed delegate,
    uint256 oldPercentageBPS,
    uint256 newPercentageBPS
);

event WalletDelegateRevoked(
    address indexed owner,
    address indexed delegate
);

event AllWalletDelegatesRevoked(address indexed owner);

event DelegatedWithdrawal(
    uint256 indexed tokenId,
    address indexed delegate,
    address indexed owner,
    uint256 amount
);
```

### 11.2 Vault-Level Events

```solidity
event VaultDelegateGranted(
    uint256 indexed tokenId,
    address indexed delegate,
    uint256 percentageBPS,
    uint256 expiresAt
);

event VaultDelegateUpdated(
    uint256 indexed tokenId,
    address indexed delegate,
    uint256 oldPercentageBPS,
    uint256 newPercentageBPS,
    uint256 expiresAt
);

event VaultDelegateRevoked(
    uint256 indexed tokenId,
    address indexed delegate
);
```

---

## 12. ERC-4337 Withdrawal Automation

### 12.1 Overview

With wallet-level delegation, ERC-4337 automation becomes simpler:
- **One session key** covers ALL vaults owned by a smart account
- **One Gelato task** can manage multiple vaults

### 12.2 Architecture

```
Hardware Wallet (Owner)
        │
        ▼
Alchemy Modular Account (ERC-4337) ←── holds multiple VaultNFTs
        │
        ├── SessionKeyPlugin (ERC-7579)
        │       │
        │       ▼
        │   Session Key (scoped to withdrawAsDelegate)
        │
        ▼
Gelato Web3 Function (Cron: monthly)
        │
        ├── 1. Batch query all owner's vaults
        ├── 2. Check canDelegateWithdraw() for each
        ├── 3. Build UserOperations for eligible vaults
        └── 4. Submit via bundler
```

### 12.3 Helper Contract

The `WithdrawalAutomationHelper` provides batch query utilities:

```solidity
function batchCanDelegateWithdraw(
    uint256[] calldata tokenIds,
    address[] calldata delegates
) external view returns (bool[] memory, uint256[] memory);

function getNextWithdrawalTime(
    uint256 tokenId,
    address delegate
) external view returns (uint256);

function getAutomationStatus(
    uint256 tokenId,
    address delegate
) external view returns (
    bool canWithdraw,
    uint256 amount,
    uint256 nextWithdrawal,
    uint256 percentageBPS
);
```

---

## Errors

### Shared Errors

```solidity
error ZeroAddress();
error CannotDelegateSelf();
error InvalidPercentage(uint256 percentage);
error StillVesting(uint256 tokenId);
error WithdrawalPeriodNotMet(uint256 tokenId, address delegate);
```

### Wallet-Level Errors

```solidity
error ExceedsDelegationLimit();
error DelegateNotActive(address owner, address delegate);
error NotActiveDelegate(uint256 tokenId, address delegate);
```

### Vault-Level Errors

```solidity
error NotVaultOwner(uint256 tokenId);
error ExceedsVaultDelegationLimit(uint256 tokenId);
error VaultDelegateNotActive(uint256 tokenId, address delegate);
```

---

## Migration Notes (v1 → v2)

**Breaking Changes:**
- Function signatures changed (tokenId removed from grant/revoke)
- Existing vault-level delegations are abandoned
- Users must re-grant delegations at wallet level after upgrade

**Benefits:**
- Reduced gas: One grant covers all vaults
- Simplified automation: One session key per wallet
- Future-proof: New vaults automatically covered
