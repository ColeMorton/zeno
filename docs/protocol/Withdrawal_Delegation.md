# BTCNFT Protocol - Wallet-Level Withdrawal Delegation

> **Version:** 2.0
> **Status:** Draft
> **Last Updated:** 2025-12-30
> **Related Documents:**
> - [Technical Specification](./Technical_Specification.md)
> - [Product Specification](./Product_Specification.md)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Use Cases](#2-use-cases)
3. [Technical Implementation](#3-technical-implementation)
   - 3.1 [Data Structures](#31-data-structures)
   - 3.2 [Functions](#32-functions)
   - 3.3 [Access Control](#33-access-control)
   - 3.4 [Withdrawal Calculations](#34-withdrawal-calculations)
4. [Integration with Existing Features](#4-integration-with-existing-features)
5. [Security Considerations](#5-security-considerations)
6. [Example Scenarios](#6-example-scenarios)
7. [Events and Monitoring](#7-events-and-monitoring)
8. [ERC-4337 Withdrawal Automation](#8-erc-4337-withdrawal-automation)

---

## 1. Overview

The Withdrawal Delegation feature allows wallet owners to grant withdrawal permissions to delegate addresses. **Wallet-level delegation** means a single grant applies to ALL vaults owned by that wallet, eliminating the need for per-vault configuration.

### Key Features

- **Wallet-level delegation**: One grant covers ALL vaults owned by the granting wallet
- **Per-vault cooldowns**: Each vault tracks its own 30-day cooldown per delegate
- **Revocable permissions**: Wallet owner can revoke at any time
- **Multiple delegates**: Support multiple delegates with different percentages (up to 100% total)

### Design Principles

1. **Non-custodial**: Vault ownership never transfers
2. **Owner sovereignty**: Only wallet owner can grant/revoke permissions
3. **Proportional access**: Delegates can only access their granted percentage
4. **Activity preservation**: Delegate actions prevent vault dormancy
5. **Simplicity**: One delegation covers all current and future vaults

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

## 3. Technical Implementation

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

### 3.3 Access Control

| Function | Caller Requirement |
|----------|-------------------|
| `grantWithdrawalDelegate` | Any wallet (grants for their own vaults) |
| `revokeWithdrawalDelegate` | Any wallet (revokes their own grants) |
| `withdrawAsDelegate` | Active delegate of vault's current owner |
| `withdraw` (original) | Vault NFT owner only (unchanged) |

### 3.4 Withdrawal Calculations

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
- A single delegation grant applies to ALL vaults owned by the granting wallet

---

## 4. Integration with Existing Features

### 4.1 Ownership Transfer Behavior

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

### 4.2 Activity Tracking

Delegate withdrawals update `lastActivity[tokenId]` to prevent dormancy.

### 4.3 vestedBTC Compatibility

- Delegation affects only withdrawal rights, not redemption
- vestedBTC holders cannot delegate (no withdrawal rights)

### 4.4 Dormancy Protection

- Any delegate withdrawal resets dormancy timer
- Active delegations indicate vault is managed

---

## 5. Security Considerations

### 5.1 Attack Vectors and Mitigations

| Attack Vector | Mitigation |
|--------------|------------|
| Self-delegation | Explicit check: `delegate != msg.sender` |
| Over-delegation | Total percentage tracked and limited to 100% |
| Cooldown gaming | Cooldowns persist across ownership transfers |
| Withdrawal racing | Independent cooldowns per delegate per vault |

### 5.2 Edge Cases

| Scenario | Handling |
|----------|----------|
| Vault transferred | New owner's delegation applies; cooldowns persist |
| Same delegate, multiple owners | Each vault operates independently |
| Revoke then re-grant | Cooldowns NOT reset (prevents gaming) |
| Zero collateral | Withdrawals return 0; no reverts |

---

## 6. Example Scenarios

### 6.1 Multi-Vault Setup

```solidity
// Alice owns 5 Vault NFTs and wants to delegate to Bob
// Single grant covers ALL 5 vaults!
grantWithdrawalDelegate(bob, 6000); // 60% of each vault's monthly pool

// Bob can now withdraw from any of Alice's vaults
withdrawAsDelegate(vault1); // Works
withdrawAsDelegate(vault2); // Works (independent cooldown)
withdrawAsDelegate(vault3); // Works (independent cooldown)
```

### 6.2 Ownership Transfer

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

## 7. Events and Monitoring

### 7.1 Events

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

---

## 8. ERC-4337 Withdrawal Automation

### 8.1 Overview

With wallet-level delegation, ERC-4337 automation becomes simpler:
- **One session key** covers ALL vaults owned by a smart account
- **One Gelato task** can manage multiple vaults

### 8.2 Architecture

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

### 8.3 Helper Contract

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

```solidity
error ZeroAddress();
error CannotDelegateSelf();
error InvalidPercentage(uint256 percentage);
error ExceedsDelegationLimit();
error DelegateNotActive(address owner, address delegate);
error NotActiveDelegate(uint256 tokenId, address delegate);
error WithdrawalPeriodNotMet(uint256 tokenId, address delegate);
error StillVesting(uint256 tokenId);
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
