# Copper Custody Integration

> **Version:** 1.0
> **Status:** Draft
> **Last Updated:** 2025-12-30
> **Related Documents:**
> - [Withdrawal Delegation](../../protocol/Withdrawal_Delegation.md)
> - [Integration Guide](../Integration_Guide.md)
> - [Fireblocks Integration](./Fireblocks_Integration.md)
> - [Audit Trail](./Audit_Trail.md)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Custody Architecture](#3-custody-architecture)
4. [Setup Procedure](#4-setup-procedure)
5. [Delegation Workflow](#5-delegation-workflow)
6. [Withdrawal Operations](#6-withdrawal-operations)
7. [Revocation and Key Rotation](#7-revocation-and-key-rotation)
8. [Copper-Specific Considerations](#8-copper-specific-considerations)

---

## 1. Overview

### Purpose

This guide details institutional custody integration for BTCNFT Protocol VaultNFTs using Copper as the custody platform with Gnosis Safe as the cold storage owner.

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   COPPER CUSTODY MODEL                           │
│                                                                  │
│  Cold Storage (Gnosis Safe)        Copper Operational Wallet    │
│  ├── Holds VaultNFT               ├── Delegated withdrawal      │
│  ├── Multi-sig (3/5)              ├── 100% withdrawal rights    │
│  ├── Rare signing required        ├── Cannot transfer NFT       │
│  └── Full custody control         └── Settlement to Copper      │
│                                                                  │
│  Collateral Flow:                                                │
│  VaultNFT → withdrawAsDelegate() → Copper wallet → Settlement   │
└─────────────────────────────────────────────────────────────────┘
```

### Security Model

| Layer | Control | Compromise Impact |
|-------|---------|-------------------|
| Cold Storage (Safe) | NFT ownership, delegation grants | Full custody loss |
| Copper Wallet | Withdrawal execution only | 1% monthly max |
| Protocol | 30-day cooldown, percentage caps | None (immutable) |

---

## 2. Prerequisites

### Copper Account

- [ ] Copper institutional account activated
- [ ] Ethereum custody vault created
- [ ] API credentials generated
- [ ] Address whitelisting configured

### Gnosis Safe

- [ ] Safe deployed on target network
- [ ] Multi-sig threshold configured (recommended: 3/5)
- [ ] Hardware wallet signers enrolled
- [ ] Copper operational addresses whitelisted

### Supported Collateral Tokens

| Token | Contract | Copper Support |
|-------|----------|----------------|
| WBTC | `0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599` | Native |
| cbBTC | *deployment address* | Verify with Copper |
| tBTC | `0x18084fba666a33d37592fa2633fd49a74dd93a88` | Verify with Copper |

---

## 3. Custody Architecture

### Token Flow

```
1. INITIAL SETUP
   Safe deploys → VaultNFT minted to Safe → Safe owns NFT

2. DELEGATION GRANT
   Safe (3/5 signers) → grantWithdrawalDelegate(tokenId, copperWallet, 10000)

3. OPERATIONAL WITHDRAWALS
   Copper wallet → withdrawAsDelegate(tokenId) → collateral to Copper
   Copper → Internal settlement → Client sub-accounts

4. REVOCATION (if needed)
   Safe (3/5 signers) → revokeWithdrawalDelegate(tokenId, copperWallet)
```

### Access Control Matrix

| Action | Safe Required | Copper Required |
|--------|---------------|-----------------|
| Transfer VaultNFT | Yes (3/5) | No |
| Grant delegation | Yes (3/5) | No |
| Revoke delegation | Yes (3/5) | No |
| Execute withdrawal | No | Yes (policy) |
| Settlement | No | Yes (internal) |

---

## 4. Setup Procedure

### Step 1: Deploy Gnosis Safe

Deploy via Safe{Wallet} interface:

```bash
# Recommended configuration
Owners: 5 hardware wallet addresses (Ledger/Trezor)
Threshold: 3/5
Network: Ethereum mainnet
```

### Step 2: Create Copper Ethereum Vault

1. Log into Copper console
2. Navigate to **Vaults** → **Create Vault**
3. Select Ethereum network
4. Generate deposit address
5. Record the operational address for delegation

### Step 3: Whitelist Addresses

In Copper console, whitelist:
- VaultNFT contract address (for contract calls)
- Collateral token addresses (WBTC, cbBTC, tBTC)

### Step 4: Transfer or Mint VaultNFT to Safe

**Option A: Transfer existing VaultNFT**
```solidity
vaultNFT.transferFrom(currentOwner, safeAddress, tokenId);
```

**Option B: Mint directly to Safe**
The minting process deposits collateral and creates VaultNFT. Mint to EOA first, then transfer to Safe.

### Step 5: Record Copper Wallet Address

```
Copper Vault ID: <vault_id>
Operational Address: 0x... (use for delegation)
```

---

## 5. Delegation Workflow

### Grant Delegation via Safe

**Function Signature:**
```solidity
function grantWithdrawalDelegate(
    uint256 tokenId,
    address delegate,
    uint256 percentageBPS
) external;
```

**Safe Transaction Builder:**

1. Open Safe{Wallet} → Apps → Transaction Builder
2. Enter VaultNFT contract address
3. Enter function details:

| Parameter | Value |
|-----------|-------|
| tokenId | Your VaultNFT token ID |
| delegate | Copper operational address |
| percentageBPS | `10000` (100%) |

4. Create transaction
5. Collect 3/5 signatures from hardware wallet owners
6. Execute transaction

### Verify Delegation

Query on-chain to confirm:

```solidity
// Check delegation status
(bool canWithdraw, uint256 amount) = vaultNFT.canDelegateWithdraw(tokenId, copperAddress);

// Get permission details
DelegatePermission memory perm = vaultNFT.getDelegatePermission(tokenId, copperAddress);
```

Expected values:
- `perm.active = true`
- `perm.percentageBPS = 10000`
- `perm.grantedAt = <grant timestamp>`

---

## 6. Withdrawal Operations

### Execute Withdrawal from Copper

**Function:**
```solidity
function withdrawAsDelegate(uint256 tokenId) external returns (uint256 withdrawnAmount);
```

**Via Copper API:**
```typescript
const transaction = await copper.createTransaction({
  vaultId: "<vault_id>",
  type: "CONTRACT_CALL",
  destination: VAULT_NFT_ADDRESS,
  data: encodeWithdrawAsDelegate(tokenId),
  gasLimit: 150000
});
```

**Via Copper Console:**
1. Navigate to vault → Transactions
2. Select "Smart Contract Interaction"
3. Enter VaultNFT address
4. Method: `withdrawAsDelegate(uint256)`
5. Parameter: token ID
6. Submit for approval

### Withdrawal Constraints

| Constraint | Value |
|------------|-------|
| Cooldown period | 30 days between withdrawals |
| Monthly rate | 1% of collateral |
| Vesting requirement | 1129 days from mint |

### Settlement Flow

After successful withdrawal:
1. Collateral (WBTC/cbBTC) arrives in Copper operational wallet
2. Copper internal settlement to designated sub-accounts
3. Optional: Bridge to trading venues via ClearLoop

---

## 7. Revocation and Key Rotation

### Single Delegate Revocation

Via Safe Transaction Builder:

```solidity
vaultNFT.revokeWithdrawalDelegate(tokenId, copperAddress);
```

Requires 3/5 Safe signatures.

### Emergency Revoke All

```solidity
vaultNFT.revokeAllWithdrawalDelegates(tokenId);
```

### Key Rotation Workflow

1. Create new Copper vault or rotate operational address
2. Revoke old address:
   ```solidity
   revokeWithdrawalDelegate(tokenId, oldCopperAddress);
   ```
3. Grant to new address:
   ```solidity
   grantWithdrawalDelegate(tokenId, newCopperAddress, 10000);
   ```

### Scheduled Rotation

Recommended rotation schedule:

| Custody Value | Rotation Frequency |
|---------------|-------------------|
| < $1M | Annual |
| $1M - $10M | Semi-annual |
| > $10M | Quarterly |

---

## 8. Copper-Specific Considerations

### ClearLoop Integration

If using Copper ClearLoop for exchange connectivity:

1. Collateral withdrawn to Copper operational wallet
2. Internal transfer to ClearLoop-enabled sub-account
3. Mirror to exchange for trading
4. No on-chain transaction for exchange access

**Benefits:**
- Reduced on-chain fees for trading
- Instant settlement with supported exchanges
- Collateral remains in Copper custody

### Supported Exchanges (ClearLoop)

| Exchange | WBTC Support | Settlement Time |
|----------|--------------|-----------------|
| Deribit | Yes | Instant |
| Bybit | Yes | Instant |
| OKX | Yes | Instant |

*Note: Verify current ClearLoop support with Copper.*

### Reporting and Reconciliation

**Monthly Reports:**
1. Copper provides transaction history via API
2. Cross-reference with on-chain `DelegatedWithdrawal` events
3. Reconcile with vault collateral balance

**API Endpoint:**
```
GET /v1/vaults/{vault_id}/transactions
```

**Required Fields:**
- Transaction hash
- Timestamp
- Amount
- Status

### Custody Policies

Configure Copper policies to match protocol constraints:

| Policy | Recommended Setting |
|--------|---------------------|
| Withdrawal frequency | Monthly (matches 30-day cooldown) |
| Amount limits | 1% of custody value |
| Approval workflow | Auto-approve (TAP equivalent) |

### Multi-Vault Strategy

For large positions, consider splitting across multiple VaultNFTs:

```
VaultNFT #1 (10 BTC) → Copper Vault A (100% delegation)
VaultNFT #2 (10 BTC) → Copper Vault B (100% delegation)
VaultNFT #3 (10 BTC) → Copper Vault C (100% delegation)
```

Benefits:
- Distributed risk
- Parallel withdrawal capability
- Granular revocation
