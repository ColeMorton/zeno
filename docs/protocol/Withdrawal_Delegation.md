# BTCNFT Protocol - Withdrawal Delegation Specification

> **Version:** 1.0
> **Status:** Draft
> **Last Updated:** 2025-12-19
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

---

## 1. Overview

The Withdrawal Delegation feature allows Vault NFT holders to grant withdrawal permissions to other wallets. This enables flexible treasury management while maintaining security through owner-controlled, revocable permissions.

**Important: The 0.875% monthly withdrawal limit is cumulative - it represents the TOTAL amount that can be withdrawn by the owner and all delegates combined, not a per-wallet amount.**

### Key Features

- **Percentage-based delegation**: Grant a fixed percentage (0-100%) of monthly withdrawal allowance
- **Revocable permissions**: Vault owner can revoke at any time
- **Independent withdrawal periods**: Delegates have separate 30-day cooldowns
- **Multiple delegates**: Support multiple delegates per vault with different percentages

### Design Principles

1. **Non-custodial**: Vault ownership never transfers
2. **Owner sovereignty**: Only vault owner can grant/revoke permissions
3. **Proportional access**: Delegates can only access their granted percentage
4. **Activity preservation**: Delegate actions prevent vault dormancy

---

## 2. Use Cases

### 2.1 DAO Treasury Management

A DAO holds multiple Vault NFTs and wants to delegate withdrawal permissions:
- Treasury committee: 60% withdrawal rights
- Operations wallet: 30% withdrawal rights
- Emergency fund: 10% withdrawal rights

### 2.2 Family Wealth Distribution

Parents vault assets and delegate withdrawal rights to children:
- Child 1: 33% monthly allowance
- Child 2: 33% monthly allowance
- Child 3: 34% monthly allowance

### 2.3 Automated Services

Vault holder delegates to a smart contract for:
- DCA (Dollar Cost Averaging) strategies: 25% monthly
- Bill payments: 20% monthly
- Investment allocation: 55% monthly

### 2.4 Multi-signature Security

Vault held by multi-sig, with delegated withdrawals to:
- Hot wallet for operations: 40%
- Cold storage rotation: 60%

---

## 3. Technical Implementation

### 3.1 Data Structures

```solidity
// Delegation permissions mapping
// vaultTokenId => delegate => DelegatePermission
mapping(uint256 => mapping(address => DelegatePermission)) public withdrawalDelegates;

struct DelegatePermission {
    uint256 percentageBPS;      // Basis points (100 = 1%, 10000 = 100%)
    uint256 lastWithdrawal;     // Timestamp of delegate's last withdrawal
    uint256 grantedAt;          // When permission was granted
    bool active;                // Permission status
}

// Track total delegated percentage per vault
mapping(uint256 => uint256) public totalDelegatedBPS;
```

### 3.2 Functions

#### Grant Withdrawal Delegation

```solidity
/// @notice Grant withdrawal permission to a delegate
/// @param tokenId The Vault NFT token ID
/// @param delegate Address to grant permission to
/// @param percentageBPS Percentage in basis points (100 = 1%)
function grantWithdrawalDelegate(
    uint256 tokenId,
    address delegate,
    uint256 percentageBPS
) external {
    // Validation
    if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner(tokenId);
    if (delegate == address(0)) revert ZeroAddress();
    if (delegate == msg.sender) revert CannotDelegateSelf();
    if (percentageBPS == 0 || percentageBPS > 10000) revert InvalidPercentage(percentageBPS);
    
    // Check total delegation doesn't exceed 100%
    uint256 currentDelegated = totalDelegatedBPS[tokenId];
    if (withdrawalDelegates[tokenId][delegate].active) {
        currentDelegated -= withdrawalDelegates[tokenId][delegate].percentageBPS;
    }
    if (currentDelegated + percentageBPS > 10000) revert ExceedsDelegationLimit();
    
    // Update state
    withdrawalDelegates[tokenId][delegate] = DelegatePermission({
        percentageBPS: percentageBPS,
        lastWithdrawal: 0,
        grantedAt: block.timestamp,
        active: true
    });
    
    totalDelegatedBPS[tokenId] = currentDelegated + percentageBPS;
    
    // Update activity
    _updateActivity(tokenId);
    
    emit WithdrawalDelegateGranted(tokenId, delegate, percentageBPS);
}
```

#### Revoke Withdrawal Delegation (Single)

```solidity
/// @notice Revoke withdrawal permission from a specific delegate
/// @param tokenId The Vault NFT token ID
/// @param delegate Address to revoke permission from
function revokeWithdrawalDelegate(
    uint256 tokenId,
    address delegate
) external {
    // Validation
    if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner(tokenId);
    
    DelegatePermission storage permission = withdrawalDelegates[tokenId][delegate];
    if (!permission.active) revert DelegateNotActive(tokenId, delegate);
    
    // Update state
    totalDelegatedBPS[tokenId] -= permission.percentageBPS;
    permission.active = false;
    
    // Update activity
    _updateActivity(tokenId);
    
    emit WithdrawalDelegateRevoked(tokenId, delegate);
}
```

#### Revoke All Withdrawal Delegations

```solidity
/// @notice Revoke ALL withdrawal permissions for a vault
/// @param tokenId The Vault NFT token ID
/// @dev This function is gas-intensive if many delegates exist
function revokeAllWithdrawalDelegates(uint256 tokenId) external {
    // Validation
    if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner(tokenId);
    
    // Reset total delegation
    totalDelegatedBPS[tokenId] = 0;
    
    // Note: Individual delegate mappings are not cleared to save gas
    // The totalDelegatedBPS reset effectively disables all delegations
    // Future grant calls will overwrite old inactive entries
    
    // Update activity
    _updateActivity(tokenId);
    
    emit AllWithdrawalDelegatesRevoked(tokenId);
}

/// @notice Alternative implementation with delegate tracking
/// @dev More gas expensive but cleaner state
function revokeAllWithdrawalDelegatesTracked(
    uint256 tokenId,
    address[] calldata delegates
) external {
    // Validation
    if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner(tokenId);
    
    // Revoke each delegate
    for (uint256 i = 0; i < delegates.length; i++) {
        DelegatePermission storage permission = withdrawalDelegates[tokenId][delegates[i]];
        if (permission.active) {
            permission.active = false;
            emit WithdrawalDelegateRevoked(tokenId, delegates[i]);
        }
    }
    
    // Reset total
    totalDelegatedBPS[tokenId] = 0;
    
    // Update activity
    _updateActivity(tokenId);
    
    emit AllWithdrawalDelegatesRevoked(tokenId);
}
```

#### Withdraw as Delegate

```solidity
/// @notice Withdraw BTC as a delegate
/// @param tokenId The Vault NFT token ID to withdraw from
/// @return withdrawnAmount Amount of BTC withdrawn
function withdrawAsDelegate(uint256 tokenId) external returns (uint256 withdrawnAmount) {
    // Check vesting complete
    if (block.timestamp < mintTimestamp[tokenId] + VESTING_PERIOD) 
        revert StillVesting(tokenId);
    
    // Check delegation
    DelegatePermission storage permission = withdrawalDelegates[tokenId][msg.sender];
    if (!permission.active) revert NotActiveDelegate(tokenId, msg.sender);
    
    // Check withdrawal period (30 days for delegate)
    if (permission.lastWithdrawal > 0 && 
        block.timestamp < permission.lastWithdrawal + WITHDRAWAL_PERIOD) {
        revert WithdrawalPeriodNotMet(tokenId, msg.sender);
    }
    
    // Calculate delegate's withdrawal amount
    uint256 currentCollateral = collateralAmount[tokenId];
    uint256 maxWithdrawal = (currentCollateral * WITHDRAWAL_RATE) / 100000;
    withdrawnAmount = (maxWithdrawal * permission.percentageBPS) / 10000;
    
    if (withdrawnAmount == 0) revert ZeroWithdrawal();
    
    // Update state BEFORE transfer
    collateralAmount[tokenId] = currentCollateral - withdrawnAmount;
    permission.lastWithdrawal = block.timestamp;
    
    // Update activity
    _updateActivity(tokenId);
    
    // Transfer BTC to delegate
    IERC20 token = IERC20(collateralToken[tokenId]);
    token.transfer(msg.sender, withdrawnAmount);
    
    emit DelegatedWithdrawal(tokenId, msg.sender, withdrawnAmount);
    
    return withdrawnAmount;
}
```

#### View Functions

```solidity
/// @notice Check if a delegate can withdraw and how much
/// @param tokenId The Vault NFT token ID
/// @param delegate The delegate address to check
/// @return canWithdraw Whether the delegate can withdraw now
/// @return amount Amount the delegate can withdraw
function canDelegateWithdraw(
    uint256 tokenId,
    address delegate
) external view returns (bool canWithdraw, uint256 amount) {
    // Check vesting
    if (block.timestamp < mintTimestamp[tokenId] + VESTING_PERIOD) {
        return (false, 0);
    }
    
    DelegatePermission storage permission = withdrawalDelegates[tokenId][delegate];
    if (!permission.active) {
        return (false, 0);
    }
    
    // Check withdrawal period
    if (permission.lastWithdrawal > 0 && 
        block.timestamp < permission.lastWithdrawal + WITHDRAWAL_PERIOD) {
        return (false, 0);
    }
    
    // Calculate available amount
    uint256 currentCollateral = collateralAmount[tokenId];
    uint256 maxWithdrawal = (currentCollateral * WITHDRAWAL_RATE) / 100000;
    amount = (maxWithdrawal * permission.percentageBPS) / 10000;
    
    return (amount > 0, amount);
}

/// @notice Get all active delegates for a vault
/// @param tokenId The Vault NFT token ID
/// @return delegates Array of delegate addresses
/// @return permissions Array of their permissions
function getActiveDelegates(uint256 tokenId) 
    external view 
    returns (address[] memory delegates, DelegatePermission[] memory permissions) {
    // Implementation would iterate through events or maintain a separate array
}
```

### 3.3 Access Control

| Function | Caller Requirement |
|----------|-------------------|
| `grantWithdrawalDelegate` | Vault NFT owner only |
| `revokeWithdrawalDelegate` | Vault NFT owner only |
| `withdrawAsDelegate` | Active delegate only |
| `withdraw` (original) | Vault NFT owner only (unchanged) |

### 3.4 Withdrawal Calculations

**CRITICAL: The 0.875% monthly withdrawal is CUMULATIVE across all parties (owner + delegates combined).**

For a vault with 1 BTC collateral after vesting:

**Total Monthly Withdrawal Pool: 0.00875 BTC (0.875% of 1 BTC)**

| Actor | Delegation % | Share of Monthly Pool | Annual Impact |
|-------|--------------|----------------------|---------------|
| Owner | 0% (if 100% delegated) | 0 BTC | 0 BTC |
| Delegate A | 60% | 0.00525 BTC | 0.063 BTC |
| Delegate B | 40% | 0.00350 BTC | 0.042 BTC |
| **TOTAL** | **100%** | **0.00875 BTC** | **0.105 BTC** |

**Key Points:**
- The 0.875% (0.00875 BTC) is the TOTAL monthly withdrawal available
- This amount is SHARED among owner and all delegates based on percentages
- Each wallet (owner/delegate) has its OWN 30-day cooldown period
- Percentages apply to the withdrawal pool, NOT the vault's total collateral
- If owner delegates 100%, they cannot withdraw until revoking some delegation

**Example Timeline:**
- Day 1: Delegate A withdraws 0.00525 BTC (their 60% share)
- Day 15: Delegate B withdraws 0.00350 BTC (their 40% share)
- Day 31: Delegate A can withdraw again (30-day cooldown satisfied)
- Day 45: Delegate B can withdraw again (30-day cooldown satisfied)

Each party tracks their own 30-day period independently.

---

## 4. Integration with Existing Features

### 4.1 Activity Tracking

Delegate withdrawals update `lastActivity[tokenId]` to prevent dormancy:
```solidity
// In withdrawAsDelegate()
_updateActivity(tokenId);
```

### 4.2 vestedBTC Compatibility

- Delegation affects only withdrawal rights, not redemption
- vestedBTC holders cannot delegate (no withdrawal rights)
- Recombining vestedBTC preserves existing delegations

### 4.3 Dormancy Protection

- Any delegate withdrawal resets dormancy timer
- Active delegations indicate vault is managed
- Dormant claim process considers delegate activity

### 4.4 Window Minting

- Delegations can be pre-configured before window execution
- Batch minting preserves individual delegation settings

---

## 5. Security Considerations

### 5.1 Attack Vectors and Mitigations

| Attack Vector | Mitigation |
|--------------|------------|
| Self-delegation | Explicit check: `delegate != msg.sender` |
| Over-delegation | Total percentage tracked and limited to 100% |
| Withdrawal racing | Independent cooldowns per delegate |
| Griefing via revocation | Owner control; delegates accept revocation risk |
| Flash loan attacks | Standard ERC-20 transfer; no special risks |

### 5.2 Edge Cases

| Scenario | Handling |
|----------|----------|
| Vault transferred | Delegations remain active with new owner |
| Delegate = owner later | Delegate uses standard withdraw, not delegation |
| Zero collateral | Withdrawals return 0; no reverts |
| Rounding errors | Use basis points; floor division for safety |

### 5.3 Gas Optimization

- Single storage slot per delegation (packed struct)
- Separate cooldowns avoid owner state modification
- View functions for off-chain calculations

---

## 6. Example Scenarios

### 6.1 DAO Treasury Setup

```solidity
// DAO owns vault #1234 with 10 BTC collateral
// Grant 60% to treasury committee multisig
grantWithdrawalDelegate(1234, treasuryMultisig, 6000);

// Grant 30% to operations wallet  
grantWithdrawalDelegate(1234, operationsWallet, 3000);

// Grant 10% to emergency fund
grantWithdrawalDelegate(1234, emergencyWallet, 1000);

// Monthly withdrawals available:
// - Treasury: 0.0525 BTC (60% of 0.0875)
// - Operations: 0.02625 BTC (30% of 0.0875)
// - Emergency: 0.00875 BTC (10% of 0.0875)
```

### 6.2 Revocation Flow

```solidity
// Owner decides to revoke operations wallet access
revokeWithdrawalDelegate(1234, operationsWallet);

// Operations wallet can no longer withdraw
// 30% allocation becomes available for re-delegation
```

### 6.3 Automated Service Integration

```solidity
// User delegates to DCA bot
grantWithdrawalDelegate(5678, dcaBotAddress, 2500); // 25%

// Bot calls monthly (via automation service)
withdrawAsDelegate(5678);
// Receives 25% of monthly withdrawal to execute DCA strategy
```

---

## 7. Events and Monitoring

### 7.1 Events

```solidity
event WithdrawalDelegateGranted(
    uint256 indexed tokenId,
    address indexed delegate,
    uint256 percentageBPS
);

event WithdrawalDelegateRevoked(
    uint256 indexed tokenId,
    address indexed delegate
);

event AllWithdrawalDelegatesRevoked(
    uint256 indexed tokenId
);

event DelegatedWithdrawal(
    uint256 indexed tokenId,
    address indexed delegate,
    uint256 amount
);
```

### 7.2 Monitoring Queries

Off-chain services can monitor:
- Active delegations per vault
- Upcoming withdrawal opportunities
- Historical delegation patterns
- Total value accessible by delegates

### 7.3 Indexing

Recommended indexes for efficient queries:
- `tokenId` → all delegates
- `delegate` → all vaults with access
- `timestamp` → upcoming withdrawals

---

## Errors

```solidity
error NotTokenOwner(uint256 tokenId);
error NotActiveDelegate(uint256 tokenId, address delegate);
error CannotDelegateSelf();
error InvalidPercentage(uint256 percentage);
error ExceedsDelegationLimit();
error DelegateNotActive(uint256 tokenId, address delegate);
error WithdrawalPeriodNotMet(uint256 tokenId, address delegate);
error ZeroWithdrawal();
error ZeroAddress();
error StillVesting(uint256 tokenId);
```