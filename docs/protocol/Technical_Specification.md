# BTCNFT Protocol Technical Specification

> **Version:** 2.1
> **Status:** Draft
> **Last Updated:** 2025-12-16
> **Related Documents:**
> - [Product Specification](./Product_Specification.md)
> - [Quantitative Validation](./Quantitative_Validation.md)
> - [Market Analysis](../issuer/Market_Analysis.md)

---

## Table of Contents

1. [Token Lifecycle](#1-token-lifecycle)
   - 1.1 [Minting](#11-minting)
   - 1.2 [Multi-Issuer Architecture](#12-multi-issuer-architecture)
   - 1.3 [Dynamic Minting Windows](#13-dynamic-minting-windows)
   - 1.4 [Vesting Period](#14-vesting-period)
   - 1.5 [Post-Vesting Withdrawals](#15-post-vesting-withdrawals)
   - 1.6 [Early Redemption](#16-early-redemption)
2. [Collateral Separation (vestedBTC)](#2-collateral-separation-btctoken)
   - 2.1 [Purpose](#21-purpose)
   - 2.2 [vestedBTC Properties](#22-btctoken-properties)
   - 2.3 [Value Proposition](#23-value-proposition)
   - 2.4 [Minting vestedBTC](#24-minting-btctoken)
   - 2.5 [Rights Comparison](#25-rights-comparison)
   - 2.6 [Recombination](#26-recombination)
   - 2.7 [DeFi Advantages](#27-defi-advantages)
   - 2.8 [Use Cases](#28-use-cases)
3. [Early Redemption](#3-early-redemption)
   - 3.1 [Linear Unlock Formula](#31-linear-unlock-formula)
   - 3.2 [Redemption Schedule](#32-redemption-schedule)
   - 3.3 [Forfeited Collateral Destination](#33-forfeited-collateral-destination)
4. [Contract Parameters](#4-contract-parameters)
   - 4.1 [Immutable Parameters](#41-immutable-parameters)
   - 4.2 [Per-Token Parameters](#42-per-token-parameters)
   - 4.3 [vestedBTC Parameters](#43-btctoken-parameters)
   - 4.4 [Dormancy Parameters](#44-dormancy-parameters)
   - 4.5 [Window Parameters](#45-window-parameters)
5. [Dormant NFT Claim](#5-dormant-nft-claim)
   - 5.1 [Purpose](#51-purpose)
   - 5.2 [Dormancy Criteria](#52-dormancy-criteria)
   - 5.3 [State Machine](#53-state-machine)
   - 5.4 [Activity Tracking](#54-activity-tracking)
   - 5.5 [Functions](#55-functions)
   - 5.6 [Events](#56-events)
   - 5.7 [Errors](#57-errors)
   - 5.8 [Security Considerations](#58-security-considerations)
6. [Operational Considerations](#6-operational-considerations)
   - 6.1 [Gas Cost Analysis](#61-gas-cost-analysis-ethereum-mainnet)
   - 6.2 [L2 Deployment Considerations](#62-l2-deployment-considerations)
   - 6.3 [Withdrawal Automation](#63-withdrawal-automation)
7. [Design Decisions](#7-design-decisions)

---

## 1. Token Lifecycle

### 1.1 Minting

**Required Inputs:**
1. Treasure NFT (ERC-721) - transferred to Vault
2. BTC collateral (WBTC or cbBTC) - locked in Vault

**Process:**
1. User approves Treasure NFT transfer
2. User approves BTC collateral transfer
3. Contract mints ERC-998 Vault NFT
4. Treasure stored in Vault (ERC-998 ownership)
5. BTC collateral stored in Vault (ERC-20 balance)

**Result:**
- Vault NFT minted with:
  - Treasure stored (provides identity/art)
  - BTC collateral stored (provides backing)
  - Mint timestamp recorded

### 1.2 Multi-Issuer Architecture

The protocol supports multiple issuers operating concurrently within a single contract deployment.

#### 1.2.1 Issuer Registration

Any address can register as an issuer (permissionless).

```solidity
/// @notice Register as an issuer (permissionless)
function registerIssuer() external {
    if (registeredIssuers[msg.sender]) revert AlreadyRegistered(msg.sender);

    registeredIssuers[msg.sender] = true;

    emit IssuerRegistered(msg.sender, block.timestamp);
}
```

| State Variable | Type | Description |
|----------------|------|-------------|
| `registeredIssuers` | mapping(address => bool) | Issuer registration status |
| `issuerWindows` | mapping(address => uint256[]) | Windows created by issuer |

#### 1.2.2 Minting Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| **Instant Mint** | Immediate Vault NFT creation | Standard minting, no coordination required |
| **Window Mint** | Deferred batch minting | Campaign-based releases, community goals |

**Instant Mint:**

```solidity
/// @notice Mint a Vault NFT instantly (bypasses window mechanism)
function instantMint(
    address treasureContract,
    uint256 treasureTokenId,
    address collateralToken,
    uint256 collateralAmount
) external returns (uint256 vaultTokenId);
```

### 1.3 Dynamic Minting Windows

Issuers can create minting windows for campaign-based NFT releases after protocol deployment.

#### 1.3.1 Window Configuration

| Parameter | Type | Description |
|-----------|------|-------------|
| `issuer` | address | Creator of the window |
| `startTime` | uint48 | When window opens for pending mints |
| `endTime` | uint48 | When window closes for new pending mints |
| `executionTime` | uint48 | When mints can be executed (>= endTime) |
| `executionDeadline` | uint48 | Deadline to execute (0 = no deadline); enables `emergencyWithdraw()` after |
| `pendingMintCount` | uint32 | Number of pending mints in window |
| `executedMintCount` | uint32 | Number of mints executed |
| `nextPendingMintId` | uint32 | Counter for pending mint IDs within window |
| `lastExecutedIndex` | uint32 | Resume point for batch execution |
| `executed` | bool | Terminal state: all mints finalized |
| `cancelled` | bool | Terminal state: window cancelled by issuer |

**Storage Layout (2 slots):**

```solidity
struct MintingWindow {
    // Slot 1 (32 bytes)
    address issuer;            // 20 bytes
    uint48 startTime;          // 6 bytes (timestamps until year 8.9M)
    uint48 endTime;            // 6 bytes

    // Slot 2 (32 bytes)
    uint48 executionTime;      // 6 bytes
    uint48 executionDeadline;  // 6 bytes (0 = no deadline)
    uint32 pendingMintCount;   // 4 bytes (max 4B pending mints)
    uint32 executedMintCount;  // 4 bytes
    uint32 nextPendingMintId;  // 4 bytes (per-window counter)
    uint32 lastExecutedIndex;  // 4 bytes (batch resume point)
    bool executed;             // 1 byte (terminal)
    bool cancelled;            // 1 byte (terminal)
    // 2 bytes padding
}

// WindowState is COMPUTED, not stored (gas optimization)
enum WindowState { CREATED, OPEN, CLOSED, EXECUTED, CANCELLED }

// Allowed treasures stored in separate mapping (gas efficient lookups)
mapping(uint256 => mapping(address => bool)) public windowAllowsTreasure;
```

**Design Notes:**
- `windowId` is NOT stored in struct (redundant with mapping key)
- `state` is computed via `getWindowState()` view function
- `allowedTreasures` stored in separate mapping to avoid dynamic array costs
- `uint48` timestamps valid until year 8,921,556

#### 1.3.2 Window Lifecycle

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                         MINTING WINDOW LIFECYCLE                                │
│                                                                                 │
│  ┌─────────────┐    startTime    ┌─────────────┐    endTime    ┌─────────────┐ │
│  │   CREATED   │   reached       │    OPEN     │   reached     │   CLOSED    │ │
│  │  (computed) │ ──────────────► │  (computed) │ ────────────► │  (computed) │ │
│  └─────────────┘                 └─────────────┘               └──────┬──────┘ │
│        │                               │                              │        │
│        │ cancelWindow()                │ pendingMint()               │        │
│        │ (issuer only,                 │ increaseCollateral()         │        │
│        │  if pendingMintCount == 0)    │ cancelPendingMint()          │        │
│        ▼                               │                              │        │
│  ┌─────────────┐                       │                     executionTime     │
│  │  CANCELLED  │                       │                      reached          │
│  │  (stored)   │                       │                              │        │
│  └─────────────┘                       │                              ▼        │
│                                        │                       ┌─────────────┐ │
│                                        │   executeMints()      │  EXECUTED   │ │
│                                        │                       │  (stored)   │ │
│                                        │                       └─────────────┘ │
└────────────────────────────────────────────────────────────────────────────────┘
```

| State | Storage | Derivation |
|-------|---------|------------|
| `CREATED` | Computed | `block.timestamp < startTime` |
| `OPEN` | Computed | `startTime <= block.timestamp < endTime` |
| `CLOSED` | Computed | `block.timestamp >= endTime` |
| `EXECUTED` | Stored | `executed == true` (terminal) |
| `CANCELLED` | Stored | `cancelled == true` (terminal) |

**State Resolution Function:**

```solidity
/// @notice Get current window state (computed from timestamps + stored flags)
function getWindowState(uint256 windowId) public view returns (WindowState) {
    MintingWindow storage w = mintingWindows[windowId];
    if (w.issuer == address(0)) revert WindowNotFound(windowId);

    // Terminal states checked first (stored)
    if (w.cancelled) return WindowState.CANCELLED;
    if (w.executed) return WindowState.EXECUTED;

    // Computed states from timestamps
    if (block.timestamp < w.startTime) return WindowState.CREATED;
    if (block.timestamp < w.endTime) return WindowState.OPEN;
    return WindowState.CLOSED;
}
```

**Design Rationale:** Only terminal states (`EXECUTED`, `CANCELLED`) require storage. Transient states are derived from timestamps, saving ~20,000 gas per state transition.

#### 1.3.3 Window Creation

```solidity
/// @notice Create a new minting window
/// @param startTime When window opens for pending mints (uint48)
/// @param endTime When window closes for new pending mints (uint48)
/// @param executionTime When mints can be executed (uint48, >= endTime)
/// @param executionDeadline Deadline to execute, enables emergencyWithdraw after (uint48, 0 = no deadline)
/// @param allowedTreasures Array of allowed Treasure NFT contract addresses
function createWindow(
    uint48 startTime,
    uint48 endTime,
    uint48 executionTime,
    uint48 executionDeadline,
    address[] calldata allowedTreasures
) external returns (uint256 windowId) {
    if (!registeredIssuers[msg.sender]) revert NotRegisteredIssuer(msg.sender);
    if (startTime <= block.timestamp) revert InvalidStartTime(startTime);
    if (endTime <= startTime) revert InvalidEndTime(endTime, startTime);
    if (executionTime < endTime) revert InvalidExecutionTime(executionTime, endTime);
    if (executionDeadline != 0 && executionDeadline <= executionTime)
        revert InvalidExecutionDeadline(executionDeadline, executionTime);
    if (allowedTreasures.length == 0) revert EmptyTreasureList();

    windowId = nextWindowId++;

    MintingWindow storage w = mintingWindows[windowId];
    w.issuer = msg.sender;
    w.startTime = startTime;
    w.endTime = endTime;
    w.executionTime = executionTime;
    w.executionDeadline = executionDeadline;

    // Populate allowed treasures mapping
    for (uint256 i = 0; i < allowedTreasures.length; i++) {
        windowAllowsTreasure[windowId][allowedTreasures[i]] = true;
    }

    issuerWindows[msg.sender].push(windowId);

    emit WindowCreated(windowId, msg.sender, startTime, endTime, executionTime, executionDeadline, allowedTreasures);
}
```

#### 1.3.4 Pending Mint Operations

**Pending Mint Storage (4 slots):**

```solidity
struct PendingMint {
    // Slot 1 (32 bytes)
    address minter;            // 20 bytes
    uint8 collateralTokenIdx;  // 1 byte (index into acceptedBTCTokens[])
    // 11 bytes padding

    // Slot 2 (32 bytes)
    address treasureContract;  // 20 bytes
    // 12 bytes padding

    // Slot 3 (32 bytes)
    uint256 treasureTokenId;   // 32 bytes

    // Slot 4 (32 bytes)
    uint256 collateralAmount;  // 32 bytes
}
```

**Design Notes:**
- `windowId` NOT stored (redundant with mapping key)
- `collateralTokenIdx` indexes into `acceptedBTCTokens[]` (saves 20 bytes per pending mint)
- `createdAt` removed (vesting starts at execution, not pending mint creation)
- Existence check: `minter != address(0)`

**Create Pending Mint:**

```solidity
/// @notice Create a pending mint within a window
/// @dev Uses collateralTokenIdx to reference acceptedBTCTokens array
function pendingMint(
    uint256 windowId,
    address treasureContract,
    uint256 treasureTokenId,
    uint8 collateralTokenIdx,
    uint256 collateralAmount
) external returns (uint256 pendingMintId) {
    MintingWindow storage w = mintingWindows[windowId];

    // CHECKS
    if (getWindowState(windowId) != WindowState.OPEN) revert WindowNotOpen(windowId);
    if (!windowAllowsTreasure[windowId][treasureContract]) revert TreasureNotAllowed(windowId, treasureContract);
    if (collateralTokenIdx >= acceptedBTCTokens.length) revert InvalidCollateralToken(collateralTokenIdx);
    if (collateralAmount == 0) revert ZeroCollateral();

    address collateralToken = acceptedBTCTokens[collateralTokenIdx];

    // EFFECTS
    pendingMintId = w.nextPendingMintId++;
    w.pendingMintCount++;

    PendingMint storage pm = pendingMints[windowId][pendingMintId];
    pm.minter = msg.sender;
    pm.collateralTokenIdx = collateralTokenIdx;
    pm.treasureContract = treasureContract;
    pm.treasureTokenId = treasureTokenId;
    pm.collateralAmount = collateralAmount;

    // INTERACTIONS
    IERC721(treasureContract).transferFrom(msg.sender, address(this), treasureTokenId);
    IERC20(collateralToken).transferFrom(msg.sender, address(this), collateralAmount);

    emit PendingMintCreated(windowId, pendingMintId, msg.sender, treasureContract, treasureTokenId, collateralAmount);
}
```

**Collateral Operations:**

| Action | Actor | CREATED | OPEN | CLOSED | EXECUTED/CANCELLED |
|--------|-------|---------|------|--------|-------------------|
| Create pending mint | Anyone | No | Yes | No | No |
| Increase collateral | Minter | No | Yes | Yes | No |
| Cancel pending mint | **Issuer** | No | Yes | Yes | No |

**Increase Collateral:**

```solidity
/// @notice Increase collateral for a pending mint (minter only)
function increaseCollateral(
    uint256 windowId,
    uint256 pendingMintId,
    uint256 additionalAmount
) external nonReentrant {
    MintingWindow storage w = mintingWindows[windowId];
    PendingMint storage pm = pendingMints[windowId][pendingMintId];

    // CHECKS
    if (pm.minter == address(0)) revert PendingMintNotFound(windowId, pendingMintId);
    if (pm.minter != msg.sender) revert NotPendingMintOwner(windowId, pendingMintId);
    WindowState state = getWindowState(windowId);
    if (state != WindowState.OPEN && state != WindowState.CLOSED)
        revert CannotModifyPendingMint(windowId);
    if (additionalAmount == 0) revert ZeroCollateral();

    address collateralToken = acceptedBTCTokens[pm.collateralTokenIdx];

    // EFFECTS
    pm.collateralAmount += additionalAmount;

    // INTERACTIONS
    IERC20(collateralToken).transferFrom(msg.sender, address(this), additionalAmount);

    emit CollateralIncreased(windowId, pendingMintId, additionalAmount, pm.collateralAmount);
}
```

**Cancel Pending Mint (Issuer Only):**

```solidity
/// @notice Cancel a pending mint and return assets to minter (issuer only)
/// @dev Only the window issuer can cancel pending mints. Assets are returned to the original minter.
function cancelPendingMint(
    uint256 windowId,
    uint256 pendingMintId
) external nonReentrant {
    MintingWindow storage w = mintingWindows[windowId];
    PendingMint storage pm = pendingMints[windowId][pendingMintId];

    // CHECKS - ISSUER ONLY
    if (w.issuer != msg.sender) revert NotWindowIssuer(windowId);
    if (pm.minter == address(0)) revert PendingMintNotFound(windowId, pendingMintId);
    WindowState state = getWindowState(windowId);
    if (state == WindowState.EXECUTED || state == WindowState.CANCELLED)
        revert WindowFinalized(windowId);

    // Cache values before deletion
    address minter = pm.minter;
    address treasureContract = pm.treasureContract;
    uint256 treasureTokenId = pm.treasureTokenId;
    address collateralToken = acceptedBTCTokens[pm.collateralTokenIdx];
    uint256 collateralAmount = pm.collateralAmount;

    // EFFECTS - clear state BEFORE transfers (re-entrancy protection)
    delete pendingMints[windowId][pendingMintId];
    w.pendingMintCount--;

    // INTERACTIONS - assets return to original minter (not issuer)
    IERC721(treasureContract).safeTransferFrom(address(this), minter, treasureTokenId);
    IERC20(collateralToken).transfer(minter, collateralAmount);

    emit PendingMintCancelled(windowId, pendingMintId, minter);
}
```

#### 1.3.5 Mint Execution

```solidity
/// @notice Execute pending mints in a window (resumable batch processing)
/// @param windowId Window to execute
/// @param batchSize Max mints to execute (0 = all remaining)
/// @return executed Number of mints executed in this call
function executeMints(
    uint256 windowId,
    uint256 batchSize
) external nonReentrant returns (uint256 executed) {
    MintingWindow storage w = mintingWindows[windowId];

    // CHECKS
    if (w.issuer == address(0)) revert WindowNotFound(windowId);
    if (block.timestamp < w.executionTime) revert ExecutionTimeNotReached(windowId, w.executionTime);
    if (w.executionDeadline != 0 && block.timestamp > w.executionDeadline)
        revert ExecutionDeadlinePassed(windowId, w.executionDeadline);
    if (w.executed) revert WindowFinalized(windowId);

    // Batch bounds
    uint256 startIdx = w.lastExecutedIndex;
    uint256 endIdx = batchSize == 0
        ? w.nextPendingMintId
        : min(startIdx + batchSize, w.nextPendingMintId);

    uint256 mintTimestamp = block.timestamp; // All mints in batch share same timestamp

    // Execute pending mints
    for (uint256 i = startIdx; i < endIdx; i++) {
        PendingMint storage pm = pendingMints[windowId][i];
        if (pm.minter == address(0)) continue; // Skip cancelled mints

        uint256 vaultTokenId = _mintVault(
            pm.minter,
            pm.treasureContract,
            pm.treasureTokenId,
            acceptedBTCTokens[pm.collateralTokenIdx],
            pm.collateralAmount,
            mintTimestamp
        );

        executed++;
        emit VaultMintedFromWindow(windowId, i, vaultTokenId, pm.minter);
    }

    // EFFECTS
    w.lastExecutedIndex = uint32(endIdx);
    w.executedMintCount += uint32(executed);

    // Mark as executed if all processed
    if (w.lastExecutedIndex >= w.nextPendingMintId) {
        w.executed = true;
        emit WindowExecuted(windowId, w.executedMintCount);
    }

    return executed;
}
```

**Key Properties:**
- Any address can call `executeMints()` after `executionTime`
- Reverts if `executionDeadline` has passed (use `emergencyWithdraw()` instead)
- Resumable: `lastExecutedIndex` tracks progress across calls
- All mints in window share same `mintTimestamp`
- Vesting period begins from execution timestamp
- Skips cancelled pending mints (where `minter == address(0)`)

#### 1.3.6 Emergency Withdrawal

When `executionDeadline` passes without execution, pending minters can recover their assets:

```solidity
/// @notice Withdraw assets from a pending mint after execution deadline passed
/// @dev Only callable when executionDeadline > 0 AND block.timestamp > executionDeadline
function emergencyWithdraw(
    uint256 windowId,
    uint256 pendingMintId
) external nonReentrant {
    MintingWindow storage w = mintingWindows[windowId];
    PendingMint storage pm = pendingMints[windowId][pendingMintId];

    // CHECKS
    if (w.executionDeadline == 0) revert NoExecutionDeadline(windowId);
    if (block.timestamp <= w.executionDeadline) revert ExecutionDeadlineNotPassed(windowId, w.executionDeadline);
    if (pm.minter == address(0)) revert PendingMintNotFound(windowId, pendingMintId);
    if (pm.minter != msg.sender) revert NotPendingMintOwner(windowId, pendingMintId);

    // Cache values before deletion
    address minter = pm.minter;
    address treasureContract = pm.treasureContract;
    uint256 treasureTokenId = pm.treasureTokenId;
    address collateralToken = acceptedBTCTokens[pm.collateralTokenIdx];
    uint256 collateralAmount = pm.collateralAmount;

    // EFFECTS - clear state BEFORE transfers (re-entrancy protection)
    delete pendingMints[windowId][pendingMintId];
    w.pendingMintCount--;

    // INTERACTIONS
    IERC721(treasureContract).safeTransferFrom(address(this), minter, treasureTokenId);
    IERC20(collateralToken).transfer(minter, collateralAmount);

    emit EmergencyWithdraw(windowId, pendingMintId, minter, collateralAmount);
}
```

**Key Properties:**
- Only callable after `executionDeadline` passed
- Only the pending minter can withdraw their own assets
- Returns both Treasure NFT and collateral to minter
- Uses checks-effects-interactions pattern for re-entrancy protection

#### 1.3.7 Window Events

```solidity
// Issuer Registration
event IssuerRegistered(address indexed issuer, uint256 timestamp);

// Window Lifecycle
event WindowCreated(
    uint256 indexed windowId,
    address indexed issuer,
    uint48 startTime,
    uint48 endTime,
    uint48 executionTime,
    uint48 executionDeadline,
    address[] allowedTreasures
);
event WindowCancelled(uint256 indexed windowId, address indexed issuer);
event WindowExecuted(uint256 indexed windowId, uint32 totalMinted);

// Pending Mint Operations
event PendingMintCreated(
    uint256 indexed windowId,
    uint256 indexed pendingMintId,
    address indexed minter,
    address treasureContract,
    uint256 treasureTokenId,
    uint256 collateralAmount
);
event CollateralIncreased(
    uint256 indexed windowId,
    uint256 indexed pendingMintId,
    uint256 additionalAmount,
    uint256 newTotal
);
event PendingMintCancelled(
    uint256 indexed windowId,
    uint256 indexed pendingMintId,
    address indexed minter
);

// Vault Minting
event VaultMintedFromWindow(
    uint256 indexed windowId,
    uint256 indexed pendingMintId,
    uint256 indexed vaultTokenId,
    address minter
);
event VaultMintedInstant(
    uint256 indexed vaultTokenId,
    address indexed minter,
    address treasureContract,
    uint256 treasureTokenId,
    uint256 collateralAmount
);

// Emergency Withdrawal
event EmergencyWithdraw(
    uint256 indexed windowId,
    uint256 indexed pendingMintId,
    address indexed minter,
    uint256 collateralAmount
);
```

#### 1.3.8 Window Errors

```solidity
// Issuer Errors
error AlreadyRegistered(address issuer);
error NotRegisteredIssuer(address caller);

// Window Configuration Errors
error WindowNotFound(uint256 windowId);
error InvalidStartTime(uint256 startTime);
error InvalidEndTime(uint256 endTime, uint256 startTime);
error InvalidExecutionTime(uint256 executionTime, uint256 endTime);
error InvalidExecutionDeadline(uint256 executionDeadline, uint256 executionTime);
error EmptyTreasureList();

// Window State Errors
error WindowNotOpen(uint256 windowId);
error WindowNotExecutable(uint256 windowId);
error WindowFinalized(uint256 windowId);
error WindowAlreadyStarted(uint256 windowId);
error NotWindowIssuer(uint256 windowId);
error HasPendingMints(uint256 windowId);

// Execution Errors
error ExecutionTimeNotReached(uint256 windowId, uint256 executionTime);
error ExecutionDeadlinePassed(uint256 windowId, uint256 executionDeadline);
error NoExecutionDeadline(uint256 windowId);
error ExecutionDeadlineNotPassed(uint256 windowId, uint256 executionDeadline);

// Pending Mint Errors
error TreasureNotAllowed(uint256 windowId, address treasureContract);
error NotPendingMintOwner(uint256 windowId, uint256 pendingMintId);
error PendingMintNotFound(uint256 windowId, uint256 pendingMintId);
error CannotModifyPendingMint(uint256 windowId);

// General Errors
error InvalidCollateralToken(uint8 collateralTokenIdx);
error ZeroCollateral();
```

### 1.4 Vesting Period

- **Duration:** 1093 days (~3 years)
- **Withdrawals:** Not permitted during vesting
- **Rationale:** Ensures holder experiences at least one full BTC market cycle

### 1.5 Post-Vesting Withdrawals

- **Frequency:** Once per 30-day period
- **Amount:** 0.875% of remaining collateral (10.5% annually)
- **Property:** Collateral never fully depletes (Zeno's paradox)

### 1.6 Early Redemption

- Available at any time during vesting
- Burns (permanently destroys) the Vault NFT including the stored Treasure
- Returns:
  - Partial BTC collateral based on time elapsed
- Destroys:
  - Treasure (burned with Vault NFT - not recoverable)
- See [Section 3](#3-early-redemption) for details
- **Constraint:** If vestedBTC exists, Vault can only be redeemed when full vestedBTC amount is held at same address

---

## 2. Collateral Separation (vestedBTC)

Enables separation of collateral claim from withdrawal rights and Treasure ownership via a fungible ERC-20 token.

### 2.1 Purpose

- Separates principal (collateral) from withdrawal rights - analogous to bond stripping in traditional finance
- Enables collateral to be used as DeFi collateral while retaining withdrawal rights
- Creates tradeable principal-only and withdrawal-rights-only positions
- Fungible design enables DEX liquidity, fractional sales, and DeFi composability

### 2.2 vestedBTC Properties

| Property | Value |
|----------|-------|
| Token Standard | ERC-20 (Fungible) |
| Ratio | 1:1 with underlying BTC collateral |
| Collateral Claim | Dynamic (tracks current remaining collateral) |
| Withdrawal Rights | None |
| Treasure Ownership | None |
| Redemption | All-or-nothing (full amount required to restore redemption rights) |

### 2.3 Value Proposition

The vestedBTC represents a claim on **current remaining collateral**, which decreases as withdrawals are taken. However, historical BTC performance suggests USD-denominated value stability:

```
vestedBTC USD Value = remaining_collateral × BTC_price

Over time:
├─ remaining_collateral ↓ (withdrawals reduce it)
├─ BTC_price ↑ (historical expectation: +313% mean over 1093 days)
└─ Net effect: USD value expected to remain stable or grow
```

| Time Window | BTC Appreciation | Withdrawal Impact | Net USD Stability |
|-------------|------------------|-------------------|-------------------|
| Monthly | +4.61% mean | -0.875% | Variable |
| Yearly | +63.11% mean | -10.5% | **100%** (2017-2025 data) |
| 1093-Day | +313.07% mean | -27%* | **100%** (2017-2025 data) |

*Cumulative withdrawal impact accounting for compounding

### 2.4 Minting vestedBTC

```
┌─────────────────────────────────────────────────────────────────┐
│                    COLLATERAL SEPARATION                        │
│                                                                 │
│  ┌──────────────────────┐      ┌──────────────────────┐        │
│  │  Vault NFT           │      │  Vault NFT           │        │
│  │  ┌────────┬────────┐ │      │  ┌────────┬────────┐ │        │
│  │  │Treasure│  0.5   │ │      │  │Treasure│  0.5   │ │        │
│  │  │        │  BTC   │ │ ──►  │  │        │(locked)│ │        │
│  │  └────────┴────────┘ │      │  └────────┴────────┘ │        │
│  │  + Withdrawal Rights │      │  + Withdrawal Rights │        │
│  │  + Redemption Rights │      │  - Redemption Rights*│        │
│  └──────────────────────┘      └──────────────────────┘        │
│                                          +                      │
│                                ┌──────────────────────┐        │
│                                │  0.5 vestedBTC        │        │
│                                │  (ERC-20 Fungible)   │        │
│                                │  - No withdrawals    │        │
│                                │  - No Treasure       │        │
│                                │  - Collateral claim  │        │
│                                └──────────────────────┘        │
│                                                                 │
│  * Redemption requires full vestedBTC balance at same address   │
└─────────────────────────────────────────────────────────────────┘
```

**Process:**

1. Vault holder calls `mintVestedBTC(vaultTokenId)`
2. Contract verifies caller owns Vault NFT
3. Contract verifies no existing vestedBTC issued for this Vault
4. vestedBTC minted to caller (amount = Vault collateral amount)
5. Vault redemption rights locked
6. Mapping: `vaultTokenId → vestedBTCAmount` recorded

**Function Specification:**

```solidity
function mintVestedBTC(uint256 vaultTokenId) external returns (uint256 amount) {
    // Validation
    if (ownerOf(vaultTokenId) != msg.sender) revert NotTokenOwner(vaultTokenId);
    if (vestedBTCAmount[vaultTokenId] > 0) revert VestedBTCAlreadyMinted(vaultTokenId);
    if (block.timestamp < mintTimestamp[vaultTokenId] + VESTING_PERIOD) revert StillVesting(vaultTokenId);

    // Record original minted amount (required for all-or-nothing return)
    uint256 currentCollateral = collateralAmount[vaultTokenId];
    vestedBTCAmount[vaultTokenId] = currentCollateral;
    originalMintedAmount[vaultTokenId] = currentCollateral;

    // Mint vestedBTC to caller
    vestedBTC.mint(msg.sender, currentCollateral);

    // Update activity timestamp
    _updateActivity(vaultTokenId);

    emit VestedBTCMinted(vaultTokenId, msg.sender, currentCollateral);
    return currentCollateral;
}
```

**Collateral Claim Tracking:**

vestedBTC represents a claim on the **current remaining collateral** of the Vault NFT. As withdrawals occur, the underlying collateral decreases.

```solidity
// View function: returns vestedBTC holder's current claim value
function getCollateralClaim(uint256 vaultTokenId) external view returns (uint256) {
    if (vestedBTCAmount[vaultTokenId] == 0) return 0;
    return collateralAmount[vaultTokenId]; // Current remaining collateral
}

// vestedBTC holders can query their proportional claim
function getClaimValue(address holder, uint256 vaultTokenId) external view returns (uint256) {
    uint256 holderBalance = vestedBTC.balanceOf(holder);
    uint256 originalAmount = originalMintedAmount[vaultTokenId];
    if (originalAmount == 0 || holderBalance == 0) return 0;

    // Proportional claim on current collateral
    uint256 currentCollateral = collateralAmount[vaultTokenId];
    return (currentCollateral * holderBalance) / originalAmount;
}
```

**State After Separation:**

| State Variable | Before mintVestedBTC | After mintVestedBTC |
|----------------|---------------------|-------------------|
| `vestedBTCAmount[tokenId]` | 0 | original collateral amount |
| `originalMintedAmount[tokenId]` | 0 | original collateral amount |
| `collateralAmount[tokenId]` | X BTC | X BTC (unchanged) |
| Vault redemption rights | Enabled | Disabled* |
| BTC withdrawal rights | Enabled | Enabled |

*Redemption rights re-enabled when full vestedBTC amount returned

### 2.5 Rights Comparison

| Right | Vault (no vestedBTC) | Vault (vestedBTC exists) | vestedBTC Holder |
|-------|---------------------|-------------------------|-----------------|
| BTC withdrawals | Yes | Yes | No |
| Treasure ownership | Yes | Yes | No |
| Redeem collateral | Yes | Only with full vestedBTC* | No |
| Transfer | Yes | Yes | Yes (fungible) |
| Collateral claim | Yes | No (transferred to vestedBTC) | Yes |

*Vault can only be redeemed when full vestedBTC amount is held at same address

### 2.6 Recombination

vestedBTC can be returned to restore full rights to Vault:

1. Holder calls `returnVestedBTC(vaultTokenId, amount)`
2. Contract verifies `amount == originalMintedAmount` (all-or-nothing)
3. Contract verifies caller holds Vault at same address
4. vestedBTC burned (permanently destroyed)
5. Vault redemption rights restored

### 2.7 DeFi Advantages

| Feature | vestedBTC (ERC-20) | btcNFT (ERC-721) |
|---------|-------------------|------------------|
| DEX trading | Native (Uniswap, Curve) | Requires NFT marketplaces |
| Liquidity pools | Deep, automated | Fragmented, manual |
| Fractional sales | Native | Requires fractionalization protocol |
| Lending protocols | Direct (Aave, Compound) | Limited support |
| Price discovery | Continuous, transparent | Floor price mechanics |
| Gas efficiency | Lower | Higher |

### 2.8 Use Cases

| Use Case | Mechanism |
|----------|-----------|
| Liquidity access | Sell vestedBTC on DEX, retain Vault for withdrawal rights |
| DeFi collateral | Deposit vestedBTC in Aave/Compound |
| Partial liquidation | Sell portion of vestedBTC while retaining rest |
| Liquidity provision | Add vestedBTC to DEX liquidity pool |
| Structured products | Create principal-only and withdrawal-rights-only tranches |

---

## 3. Early Redemption

### 3.1 Linear Unlock Formula

```
redeemable(d) = collateral × (d / 1093)
forfeited(d) = collateral × (1 - d / 1093)
```

Where `d` = days since mint (0 to 1093)

### 3.2 Redemption Schedule

| Day | Elapsed | Forfeited | Returned |
|-----|---------|-----------|----------|
| 0 | 0% | 100% | 0% |
| 182 | ~6 mo | 83.3% | 16.7% |
| 365 | ~1 yr | 66.6% | 33.4% |
| 547 | ~18 mo | 50.0% | 50.0% |
| 730 | ~2 yr | 33.2% | 66.8% |
| 912 | ~2.5 yr | 16.6% | 83.4% |
| 1093 | ~3 yr | 0% | 100% |

### 3.3 Forfeited Collateral Destination

Configured at contract deployment (immutable):

| Destination | Description |
|-------------|-------------|
| `ISSUER` | Sent to issuer wallet address |
| `TREASURY` | Sent to protocol treasury address |
| `SERIES_HOLDERS` | Redistributed pro-rata among same NFT series |
| `ALL_HOLDERS` | Redistributed pro-rata among all NFT holders |

**Redistribution Logic:**
- Forfeited collateral added to redistribution pool
- Claimable pro-rata based on holder's collateral share

**Redistribution Claim Function (for SERIES_HOLDERS/ALL_HOLDERS):**

```solidity
// State variables for redistribution
mapping(uint256 => uint256) public redistributionPool; // seriesId => pool amount (or 0 for ALL_HOLDERS)
mapping(uint256 => uint256) public totalActiveCollateralAtSnapshot; // seriesId => snapshot
mapping(uint256 => mapping(uint256 => bool)) public hasClaimed; // seriesId => tokenId => claimed

function claimRedistribution(uint256 tokenId) external returns (uint256 claimed) {
    // Validation
    if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner(tokenId);
    if (block.timestamp < mintTimestamp[tokenId] + VESTING_PERIOD) revert StillVesting(tokenId);

    uint256 seriesId = penaltyDestinationType == PenaltyDestination.ALL_HOLDERS ? 0 : series[tokenId];
    if (hasClaimed[seriesId][tokenId]) revert AlreadyClaimed(tokenId);

    uint256 pool = redistributionPool[seriesId];
    if (pool == 0) revert NoPoolAvailable(seriesId);

    // Calculate pro-rata share using snapshot denominator
    uint256 holderCollateral = collateralAmount[tokenId];
    uint256 denominator = totalActiveCollateralAtSnapshot[seriesId];
    claimed = (pool * holderCollateral) / denominator;

    // Mark as claimed and transfer
    hasClaimed[seriesId][tokenId] = true;
    collateralToken[tokenId].transfer(msg.sender, claimed);

    // Update activity timestamp
    _updateActivity(tokenId);

    emit RedistributionClaimed(tokenId, seriesId, claimed);
    return claimed;
}
```

**Rounding Direction:**

All calculations use floor rounding (round down) for user-facing amounts to prevent protocol insolvency:

| Calculation | Rounding | Rationale |
|-------------|----------|-----------|
| Withdrawal amount | Floor | User receives ≤ entitled amount |
| Early redemption | Floor | User receives ≤ entitled amount |
| Redistribution claim | Floor | User receives ≤ entitled share |
| vestedBTC minting | Exact | 1:1 with collateral (no rounding) |

```solidity
// Standard rounding pattern (floor division)
uint256 amount = (numerator * multiplier) / denominator; // Solidity default: floor
```

---

## 4. Contract Parameters

### 4.1 Immutable Parameters (Set at Deployment)

| Parameter | Type | Description |
|-----------|------|-------------|
| `vestingPeriod` | uint256 | 1093 days (constant) |
| `withdrawalPeriod` | uint256 | 30 days (constant) |
| `withdrawalRate` | uint256 | 875 (basis points × 100, = 0.875% per period) |
| `penaltyDestinationType` | enum | ISSUER, TREASURY, SERIES_HOLDERS, ALL_HOLDERS |
| `penaltyDestinationAddress` | address | Target for ISSUER/TREASURY types |
| `acceptedBTCTokens` | address[] | [WBTC, cbBTC] accepted collateral tokens |

### 4.2 Per-Token Parameters (Set at Mint)

| Parameter | Type | Description |
|-----------|------|-------------|
| `treasureContract` | address | ERC-721 contract of stored Treasure |
| `treasureTokenId` | uint256 | Token ID of stored Treasure |
| `collateralToken` | address | WBTC or cbBTC address used |
| `collateralAmount` | uint256 | BTC amount deposited |
| `mintTimestamp` | uint256 | Block timestamp at mint |
| `lastWithdrawal` | uint256 | Timestamp of last withdrawal |
| `vestedBTCAmount` | uint256 | Amount of vestedBTC minted (0 if none exists) |

### 4.3 vestedBTC Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `vaultTokenId` | uint256 | Token ID of Vault NFT |
| `vaultContract` | address | Address of Vault NFT contract |
| `originalAmount` | uint256 | Amount minted (required for all-or-nothing return) |
| `mintTimestamp` | uint256 | When vestedBTC was minted |

### 4.4 Dormancy Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `DORMANCY_THRESHOLD` | uint256 | 1093 days (constant) - Inactivity period before dormant-eligible |
| `GRACE_PERIOD` | uint256 | 30 days (immutable) - Time for owner to respond after poke |
| `lastActivity` | mapping(uint256 => uint256) | Per-token timestamp of last activity |
| `pokeTimestamp` | mapping(uint256 => uint256) | Per-token timestamp when poked (0 = not poked) |

### 4.5 Window Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `nextWindowId` | uint256 | Counter for window IDs |
| `registeredIssuers` | mapping(address => bool) | Issuer registration status |
| `issuerWindows` | mapping(address => uint256[]) | Windows created by each issuer |
| `mintingWindows` | mapping(uint256 => MintingWindow) | Window configurations (2 slots per window) |
| `windowAllowsTreasure` | mapping(uint256 => mapping(address => bool)) | Allowed Treasure contracts per window |
| `pendingMints` | mapping(uint256 => mapping(uint256 => PendingMint)) | Pending mint data (4 slots per mint) |

**MintingWindow Struct (2 storage slots):**

| Field | Type | Slot | Description |
|-------|------|------|-------------|
| `issuer` | address | 1 | Creator of window (20 bytes) |
| `startTime` | uint48 | 1 | Window open time (6 bytes) |
| `endTime` | uint48 | 1 | Window close time (6 bytes) |
| `executionTime` | uint48 | 2 | Mint execution time (6 bytes) |
| `executionDeadline` | uint48 | 2 | Deadline for execution (6 bytes) |
| `pendingMintCount` | uint32 | 2 | Pending mints count (4 bytes) |
| `executedMintCount` | uint32 | 2 | Executed mints count (4 bytes) |
| `nextPendingMintId` | uint32 | 2 | Per-window mint ID counter (4 bytes) |
| `lastExecutedIndex` | uint32 | 2 | Batch execution resume point (4 bytes) |
| `executed` | bool | 2 | Terminal: all mints done (1 byte) |
| `cancelled` | bool | 2 | Terminal: cancelled (1 byte) |

**PendingMint Struct (4 storage slots):**

| Field | Type | Slot | Description |
|-------|------|------|-------------|
| `minter` | address | 1 | Recipient of Vault (20 bytes) |
| `collateralTokenIdx` | uint8 | 1 | Index into acceptedBTCTokens (1 byte) |
| `treasureContract` | address | 2 | Treasure NFT contract (20 bytes) |
| `treasureTokenId` | uint256 | 3 | Treasure NFT token ID (32 bytes) |
| `collateralAmount` | uint256 | 4 | BTC collateral amount (32 bytes) |

---

## 5. Dormant Vault Claim

Prevents permanently locked BTC by allowing vestedBTC holders to claim abandoned Vaults.

### 5.1 Purpose

When a Vault holder:
1. Separates collateral into vestedBTC (vestedBTC)
2. Sells or transfers the vestedBTC away
3. Becomes inactive for an extended period (1093+ days)

The underlying BTC collateral becomes inaccessible - the Vault holder cannot redeem (lacks vestedBTC), and vestedBTC holders cannot recombine (lack the Vault). This mechanism allows vestedBTC holders to reclaim dormant positions.

### 5.2 Dormancy Criteria

A Vault is **dormant-eligible** when ALL conditions are met:

| Condition | Requirement | Rationale |
|-----------|-------------|-----------|
| vestedBTC Exists | `vestedBTCAmount[tokenId] > 0` | Collateral must be separated |
| vestedBTC Not at Owner | `vestedBTC.balanceOf(owner) < vestedBTCAmount[tokenId]` | Owner sold/transferred their claim |
| Inactivity Period | `block.timestamp >= lastActivity[tokenId] + DORMANCY_THRESHOLD` | 1093 days without any interaction |

### 5.3 State Machine

```
                                    ┌─────────────────────────────────┐
                                    │  Any activity (withdraw,        │
                                    │  transfer, proveActivity, etc.) │
                                    └────────────────┬────────────────┘
                                                     │
                                                     ▼
┌─────────────────┐                         ┌─────────────────┐
│                 │   1093+ days inactive   │                 │
│     ACTIVE      │   + vestedBTC separated  │ DORMANT_ELIGIBLE│
│                 │ ◄────────────────────── │ (logical state) │
│  lastActivity   │                         │                 │
│    updated      │                         └────────┬────────┘
└─────────────────┘                                  │
        ▲                                            │ pokeDormant()
        │                                            │
        │   Owner calls                              ▼
        │   proveActivity()              ┌─────────────────┐
        │   or any activity              │                 │
        │                                │  POKE_PENDING   │
        └────────────────────────────────│                 │
                                         │  Grace period   │
                                         │  (30 days)      │
                                         └────────┬────────┘
                                                  │
                                                  │ Grace period expires
                                                  │ (owner did not respond)
                                                  ▼
                                         ┌─────────────────┐
                                         │                 │
                                         │   CLAIMABLE     │
                                         │                 │
                                         └────────┬────────┘
                                                  │
                                                  │ claimDormantVault()
                                                  ▼
                                         ┌─────────────────┐
                                         │ CLAIM RESULT:   │
                                         │                 │
                                         │ Claimer gets:   │
                                         │ - BTC collateral│
                                         │   (directly)    │
                                         │                 │
                                         │ Original gets:  │
                                         │ - Treasure      │
                                         │                 │
                                         │ Vault NFT:      │
                                         │ - Burned        │
                                         │                 │
                                         │ vestedBTC:           │
                                         │ - Burned        │
                                         └─────────────────┘
```

**Dormancy States:**

| State | pokeTimestamp | Condition |
|-------|---------------|-----------|
| `ACTIVE` | 0 | Not dormant-eligible OR poke cleared by activity |
| `POKE_PENDING` | > 0 | Poked, within grace period |
| `CLAIMABLE` | > 0 | Poked, grace period expired |

### 5.4 Activity Tracking

The `lastActivity` timestamp is updated on ALL meaningful interactions:

| Function | Activity Update |
|----------|-----------------|
| `mint()` | Initialize `lastActivity[tokenId] = block.timestamp` |
| `withdraw()` | Update `lastActivity` at function start |
| `transfer()` / `safeTransferFrom()` | Update via ERC-721 `_beforeTokenTransfer` hook |
| `mintVestedBTC()` | Update `lastActivity` |
| `returnVestedBTC()` | Update `lastActivity` |
| `claimMatch()` | Update `lastActivity` |
| `proveActivity()` | Update `lastActivity` (explicit activity proof) |

**Internal Activity Update:**

```solidity
function _updateActivity(uint256 tokenId) internal {
    lastActivity[tokenId] = block.timestamp;

    // Clear any pending poke state when activity is proven
    if (pokeTimestamp[tokenId] != 0) {
        pokeTimestamp[tokenId] = 0;
        emit DormancyStateChanged(tokenId, DormancyState.ACTIVE);
    }
}
```

### 5.5 Functions

#### `isDormantEligible(tokenId)` - View

Returns dormancy eligibility and current state.

```solidity
function isDormantEligible(uint256 tokenId) public view
    returns (bool eligible, DormancyState state)
{
    // Requirement 1: vestedBTC must exist for this Vault
    if (vestedBTCAmount[tokenId] == 0) {
        return (false, DormancyState.ACTIVE);
    }

    // Requirement 2: vestedBTC NOT held at same address as Vault owner
    address vaultOwner = ownerOf(tokenId);
    if (vestedBTC.balanceOf(vaultOwner) >= vestedBTCAmount[tokenId]) {
        return (false, DormancyState.ACTIVE);
    }

    // Requirement 3: No activity for DORMANCY_THRESHOLD (1093 days)
    if (block.timestamp < lastActivity[tokenId] + DORMANCY_THRESHOLD) {
        return (false, DormancyState.ACTIVE);
    }

    // Check poke state
    if (pokeTimestamp[tokenId] == 0) {
        return (true, DormancyState.ACTIVE); // Eligible but not yet poked
    }

    // Grace period check
    if (block.timestamp < pokeTimestamp[tokenId] + GRACE_PERIOD) {
        return (true, DormancyState.POKE_PENDING);
    }

    // Grace period expired
    return (true, DormancyState.CLAIMABLE);
}
```

#### `pokeDormant(tokenId)` - Initiate Grace Period

Marks a dormant-eligible NFT as poke-pending, starting the grace period.

```solidity
function pokeDormant(uint256 tokenId) external {
    (bool eligible, DormancyState state) = isDormantEligible(tokenId);

    if (!eligible) revert NotDormantEligible(tokenId);
    if (state != DormancyState.ACTIVE) revert AlreadyPoked(tokenId);

    pokeTimestamp[tokenId] = block.timestamp;

    address owner = ownerOf(tokenId);
    emit DormantPoked(tokenId, owner, msg.sender, block.timestamp + GRACE_PERIOD);
    emit DormancyStateChanged(tokenId, DormancyState.POKE_PENDING);
}
```

#### `proveActivity(tokenId)` - Owner Response

Owner proves activity to exit dormancy state.

```solidity
function proveActivity(uint256 tokenId) external {
    if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner(tokenId);

    _updateActivity(tokenId);

    emit ActivityProven(tokenId, msg.sender);
}
```

#### `claimDormantCollateral(tokenId)` - vestedBTC Holder Claims Collateral

Claims BTC collateral from a dormant Vault by burning the required vestedBTC amount.

```solidity
function claimDormantCollateral(uint256 tokenId) external {
    (bool eligible, DormancyState state) = isDormantEligible(tokenId);

    if (!eligible) revert NotDormantEligible(tokenId);
    if (state != DormancyState.CLAIMABLE) revert NotClaimable(tokenId);

    uint256 requiredStableBTC = vestedBTCAmount[tokenId];
    if (vestedBTC.balanceOf(msg.sender) < requiredStableBTC) {
        revert InsufficientVestedBTC(requiredStableBTC, vestedBTC.balanceOf(msg.sender));
    }

    address originalOwner = ownerOf(tokenId);
    uint256 collateralToClaim = collateralAmount[tokenId];

    // Step 1: Burn vestedBTC from claimer (permanent destruction)
    vestedBTC.burnFrom(msg.sender, requiredStableBTC);

    // Step 2: Extract Treasure and return to original owner
    (address treasureContract, uint256 treasureTokenId) = getTreasure(tokenId);
    _extractTreasure(tokenId, originalOwner);

    // Step 3: Transfer BTC collateral to claimer
    collateralToken[tokenId].transfer(msg.sender, collateralToClaim);

    // Step 4: Burn the Vault NFT (now empty - no value)
    _burn(tokenId);

    emit DormantCollateralClaimed(
        tokenId,
        originalOwner,
        msg.sender,
        treasureContract,
        treasureTokenId,
        collateralToClaim,
        requiredStableBTC
    );
}
```

### 5.6 Events

```solidity
event DormantPoked(
    uint256 indexed tokenId,
    address indexed owner,
    address indexed poker,
    uint256 graceDeadline
);

event DormancyStateChanged(
    uint256 indexed tokenId,
    DormancyState newState
);

event ActivityProven(
    uint256 indexed tokenId,
    address indexed owner
);

event DormantCollateralClaimed(
    uint256 indexed tokenId,
    address indexed originalOwner,
    address indexed claimer,
    address treasureContract,
    uint256 treasureTokenId,
    uint256 collateralClaimed,
    uint256 vestedBTCBurned
);
```

### 5.7 Errors

```solidity
error NotDormantEligible(uint256 tokenId);
error AlreadyPoked(uint256 tokenId);
error NotClaimable(uint256 tokenId);
error NotTokenOwner(uint256 tokenId);
error InsufficientVestedBTC(uint256 required, uint256 available);
```

### 5.8 Security Considerations

| Attack Vector | Mitigation |
|--------------|------------|
| Flash loan attack | Balance check is atomic; claimer must actually hold tokens |
| Front-running poke | Poke caller has no advantage; anyone can poke |
| Malicious poke spam | No harm to owner; they can respond anytime during grace period |
| Self-poke then claim | Requires vestedBTC amount; if owner has it, not dormant-eligible |
| Race condition (claim vs prove) | Atomic state: first valid transaction wins, second reverts |

**Race Condition Resolution (claim vs prove):**

When both `claimDormantCollateral()` and `proveActivity()` are pending in the mempool:

```
Scenario: Both transactions submitted simultaneously

Transaction A: proveActivity(tokenId)
Transaction B: claimDormantCollateral(tokenId)

Outcome depends on which transaction is mined first:

Case 1: proveActivity() executes first
├─ Updates lastActivity[tokenId]
├─ Clears pokeTimestamp[tokenId]
├─ NFT returns to ACTIVE state
└─ claimDormantCollateral() reverts with NotClaimable(tokenId)

Case 2: claimDormantCollateral() executes first
├─ Burns vestedBTC from claimer
├─ Extracts Child NFT to original owner
├─ Transfers BTC collateral to claimer
├─ Burns Parent NFT
└─ proveActivity() reverts with NotTokenOwner(tokenId) (NFT burned)
```

**Design Choice:** No special ordering guarantees. Both transactions check state atomically. The first valid transaction to execute wins. This is fair because:

1. **Owner has 30-day grace period** - ample time to respond before claiming is possible
2. **proveActivity() is instant** - owner can respond immediately when poked
3. **claimDormantCollateral() requires vestedBTC** - claimer must hold tokens
4. **Standard EVM semantics** - consistent with other DeFi protocols

**Recommended Owner Behavior:**
- Use `proveActivity()` as soon as possible after being poked
- Use a priority fee if concerned about timing
- Any activity (withdraw, transfer) also clears dormancy state

**Edge Cases:**

| Edge Case | Handling |
|-----------|----------|
| vestedBTC partially at owner address | Not dormant-eligible unless owner holds < required amount |
| Owner transfers Vault during POKE_PENDING | Transfer calls `_updateActivity()`, resets to ACTIVE |
| Multiple people try to poke | First poke sets timestamp; subsequent reverts with `AlreadyPoked` |
| Owner responds at last second | `proveActivity()` clears poke state regardless of timing |
| vestedBTC repurchased during grace | Claimer no longer meets criteria; `isDormantEligible` returns false |
| Treasure contract refuses transfer | Fail-fast: revert if Treasure extraction fails |

---

## 6. Operational Considerations

### 6.1 Gas Cost Analysis (Ethereum Mainnet)

| Operation | Gas Units | Cost @ 30 gwei | Cost @ 100 gwei |
|-----------|-----------|----------------|-----------------|
| Mint Vault NFT | ~250,000 | ~$15 | ~$50 |
| Withdraw BTC | ~80,000 | ~$5 | ~$16 |
| mintVestedBTC | ~120,000 | ~$7 | ~$24 |
| returnVestedBTC | ~100,000 | ~$6 | ~$20 |
| claimRedistribution | ~90,000 | ~$5 | ~$18 |
| pokeDormant | ~50,000 | ~$3 | ~$10 |
| claimDormantCollateral | ~150,000 | ~$9 | ~$30 |

### 6.2 L2 Deployment Considerations

| Chain | Gas Reduction | Trade-off |
|-------|---------------|-----------|
| Arbitrum | 90%+ | Security assumptions |
| Base | 90%+ | Coinbase ecosystem |
| Optimism | 90%+ | OP token incentives |

**Deployment Notes:**
- Core protocol is chain-agnostic
- vestedBTC requires bridging for cross-chain liquidity
- L2 deployments share same contract code
- Collateral token availability varies by chain (WBTC, cbBTC)

### 6.3 Withdrawal Automation

```
┌─────────────────────────────────────────────────────────────────┐
│                    WITHDRAWAL AUTOMATION                        │
│                                                                 │
│  Option A: Manual                                              │
│  └─ Holder calls withdraw() every 30 days                      │
│                                                                 │
│  Option B: Gelato Automation                                   │
│  └─ Automated transaction execution                            │
│  └─ Pay gas in ETH or task-specific token                      │
│                                                                 │
│  Option C: Account Abstraction (ERC-4337)                      │
│  └─ Scheduled withdrawals via smart account                    │
│  └─ Gas sponsorship options                                    │
└─────────────────────────────────────────────────────────────────┘
```

**Automation Considerations:**
- Withdrawals are permissionless (Vault owner only)
- No state changes required for automation setup
- Third-party services can trigger withdrawals on behalf of owner
- Gas costs are borne by transaction initiator

---

## 7. Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Early exit | Redeem with linear unlock | Discourages early exit, fair value return |
| Treasure on early redemption | Burned with Vault NFT | Commitment mechanism; disincentivizes early exit |
| Penalty destination | Issuer-configured | Flexibility for different use cases |
| Minting window | Optional (0 = instant) | Supports series/time-based releases |
| Collateral increase | Allowed during window | Enables DCA-style accumulation |
| Collateral withdrawal | Never during window | Prevents gaming/front-running |
| Cancel pending mint | Allowed during window | User protection before commitment |
| vestedBTC standard | ERC-20 (fungible) | DEX liquidity, DeFi composability, fractional sales |
| vestedBTC ratio | 1:1 with collateral | Simple valuation, direct BTC price tracking |
| vestedBTC collateral claim | Dynamic (current) | Simplifies mechanics, no replenishment required |
| vestedBTC withdrawal rights | None | Clear separation of principal from withdrawal rights |
| vestedBTC recombination | All-or-nothing | Prevents partial redemption gaming |
| Redemption lock mechanism | Requires full vestedBTC balance | Prevents unauthorized collateral redemption |
| Dormancy threshold | 1093 days (same as vesting) | Full market cycle of inactivity |
| Grace period | 30 days | One withdrawal period; reasonable response time |
| Poke mechanism | Anyone can initiate | Decentralized detection, no privileged actor |
| Owner notification | Grace period before claim | Fair warning to recover position |
| Treasure on dormant claim | Returned to original owner | Preserves user's original property |
| vestedBTC on dormant claim | Burned | Economic equivalence with normal recombination |
| Collateral on dormant claim | Transferred to claimer | Claimer receives BTC directly |
| Vault NFT on dormant claim | Burned | Empty shell after extraction - no value |
| Claim amount required | Original vestedBTCAmount | Full amount ensures economic fairness |
