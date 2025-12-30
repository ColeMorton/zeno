# Fireblocks Custody Integration

> **Version:** 1.0
> **Status:** Draft
> **Last Updated:** 2025-12-30
> **Related Documents:**
> - [Withdrawal Delegation](../../protocol/Withdrawal_Delegation.md)
> - [Integration Guide](../Integration_Guide.md)
> - [Audit Trail](./Audit_Trail.md)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Custody Architecture](#3-custody-architecture)
4. [Setup Procedure](#4-setup-procedure)
5. [Delegation Workflow](#5-delegation-workflow)
6. [Withdrawal Operations](#6-withdrawal-operations)
7. [Revocation Procedures](#7-revocation-procedures)
8. [Security Best Practices](#8-security-best-practices)

---

## 1. Overview

### Purpose

This guide details institutional custody integration for BTCNFT Protocol VaultNFTs using Fireblocks as the custody platform with Gnosis Safe as the cold storage owner.

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   INSTITUTIONAL CUSTODY MODEL                    │
│                                                                  │
│  Cold Storage (Gnosis Safe)        Hot Trading Desk (Fireblocks)│
│  ├── Holds VaultNFT               ├── Delegated withdrawal      │
│  ├── Multi-sig (3/5)              ├── 100% withdrawal rights    │
│  ├── Rare signing required        ├── Cannot transfer NFT       │
│  └── Full custody control         └── Operational access only   │
│                                                                  │
│  Security Separation:                                            │
│  ├── NFT ownership: Cold storage ONLY                           │
│  ├── Withdrawal execution: Hot wallet via delegation            │
│  └── Compromise impact: Limited to 1% monthly (worst case)      │
└─────────────────────────────────────────────────────────────────┘
```

### Security Model

| Layer | Control | Compromise Impact |
|-------|---------|-------------------|
| Cold Storage (Safe) | NFT ownership, delegation grants | Full custody loss |
| Hot Wallet (Fireblocks) | Withdrawal execution only | 1% monthly max |
| Protocol | 30-day cooldown, percentage caps | None (immutable) |

---

## 2. Prerequisites

### Fireblocks Workspace

- [ ] Fireblocks workspace with API access
- [ ] ERC-721 raw signing enabled
- [ ] Vault configured for Ethereum mainnet (or target network)
- [ ] Transaction Authorization Policy (TAP) configured

### Gnosis Safe

- [ ] Safe deployed on target network
- [ ] Multi-sig threshold configured (recommended: 3/5)
- [ ] Hardware wallet signers enrolled
- [ ] Safe Apps interface available

### Network Requirements

| Network | Safe Factory | VaultNFT Address |
|---------|--------------|------------------|
| Mainnet | `0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2` | *deployment address* |
| Base | `0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2` | *deployment address* |
| Arbitrum | `0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2` | *deployment address* |

---

## 3. Custody Architecture

### Token Flow

```
1. INITIAL SETUP
   Safe deploys → VaultNFT minted to Safe → Safe owns NFT

2. DELEGATION GRANT
   Safe (3/5 signers) → grantWithdrawalDelegate(tokenId, fireblocksWallet, 10000)

3. OPERATIONAL WITHDRAWALS
   Fireblocks wallet → withdrawAsDelegate(tokenId) → collateral to Fireblocks

4. REVOCATION (if needed)
   Safe (3/5 signers) → revokeWithdrawalDelegate(tokenId, fireblocksWallet)
```

### Access Control Matrix

| Action | Safe Required | Fireblocks Required |
|--------|---------------|---------------------|
| Transfer VaultNFT | Yes (3/5) | No |
| Grant delegation | Yes (3/5) | No |
| Revoke delegation | Yes (3/5) | No |
| Execute withdrawal | No | Yes (TAP policy) |
| View vault state | No | No (public) |

---

## 4. Setup Procedure

### Step 1: Deploy Gnosis Safe

Deploy via Safe{Wallet} interface or programmatically:

```bash
# Recommended configuration
Owners: 5 hardware wallet addresses
Threshold: 3/5
Network: Ethereum mainnet (or target L2)
```

### Step 2: Transfer or Mint VaultNFT to Safe

**Option A: Transfer existing VaultNFT**
```solidity
// From current owner
vaultNFT.transferFrom(currentOwner, safeAddress, tokenId);
```

**Option B: Mint directly to Safe**
```solidity
// Mint with Safe as recipient
vaultNFT.mint(treasureContract, treasureTokenId, collateralToken, amount);
// VaultNFT minted to msg.sender - transfer to Safe immediately
```

### Step 3: Configure Fireblocks Vault

1. Create Ethereum vault in Fireblocks console
2. Enable **ERC-721 Raw Signing** for the vault
3. Whitelist VaultNFT contract address
4. Configure Transaction Authorization Policy (TAP):

```json
{
  "type": "CONTRACT_CALL",
  "asset": "ETH",
  "contractAddress": "<VAULT_NFT_ADDRESS>",
  "functionSignatures": ["withdrawAsDelegate(uint256)"],
  "authorization": "AUTO_APPROVED",
  "amountScope": "ANY"
}
```

### Step 4: Record Fireblocks Wallet Address

```
Fireblocks Vault ID: vault_xxxx
Deposit Address: 0x... (use this for delegation)
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

**Calldata Encoding:**
```
Function selector: 0x... (first 4 bytes of keccak256("grantWithdrawalDelegate(uint256,address,uint256)"))
Parameters:
  - tokenId: uint256 (your VaultNFT token ID)
  - delegate: address (Fireblocks deposit address)
  - percentageBPS: uint256 (10000 for 100%)
```

**Safe Transaction Builder:**

1. Open Safe{Wallet} → Transaction Builder
2. Enter VaultNFT contract address
3. Paste ABI or enter function manually:

```json
{
  "inputs": [
    {"name": "tokenId", "type": "uint256"},
    {"name": "delegate", "type": "address"},
    {"name": "percentageBPS", "type": "uint256"}
  ],
  "name": "grantWithdrawalDelegate",
  "type": "function"
}
```

4. Fill parameters:
   - `tokenId`: Your VaultNFT token ID
   - `delegate`: Fireblocks deposit address
   - `percentageBPS`: `10000` (100% of monthly allocation)
5. Create transaction → Collect 3/5 signatures → Execute

### Verify Delegation

```solidity
// Query delegation status
(bool canWithdraw, uint256 amount) = vaultNFT.canDelegateWithdraw(tokenId, fireblocksAddress);

// Get full permission details
DelegatePermission memory perm = vaultNFT.getDelegatePermission(tokenId, fireblocksAddress);
// perm.percentageBPS = 10000
// perm.active = true
// perm.grantedAt = <timestamp>
```

---

## 6. Withdrawal Operations

### Execute Withdrawal from Fireblocks

**Function:**
```solidity
function withdrawAsDelegate(uint256 tokenId) external returns (uint256 withdrawnAmount);
```

**Via Fireblocks API:**
```typescript
const response = await fireblocks.createTransaction({
  assetId: "ETH",
  source: { type: "VAULT_ACCOUNT", id: vaultId },
  destination: {
    type: "EXTERNAL_WALLET",
    id: vaultNftContractId
  },
  operation: "CONTRACT_CALL",
  extraParameters: {
    contractCallData: encodeWithdrawAsDelegate(tokenId)
  }
});
```

**Via Fireblocks Console:**
1. Navigate to vault → Transactions → Create
2. Select "Contract Call"
3. Enter VaultNFT address
4. Method: `withdrawAsDelegate(uint256)`
5. Parameter: token ID
6. Submit → TAP policy auto-approves

### Withdrawal Timing

| Constraint | Value |
|------------|-------|
| Cooldown period | 30 days between withdrawals |
| Monthly rate | 1% of collateral |
| Vesting requirement | 1129 days from mint |

---

## 7. Revocation Procedures

### Single Delegate Revocation

Via Safe Transaction Builder:

```solidity
// Revoke specific delegate
vaultNFT.revokeWithdrawalDelegate(tokenId, fireblocksAddress);
```

Requires 3/5 Safe signatures.

### Emergency Revoke All

```solidity
// Revoke ALL delegates immediately
vaultNFT.revokeAllWithdrawalDelegates(tokenId);
```

Use when:
- Fireblocks account compromised
- Key rotation required
- Operational shutdown

### Key Rotation Workflow

1. Revoke current Fireblocks address:
   ```solidity
   revokeWithdrawalDelegate(tokenId, oldFireblocksAddress);
   ```

2. Create new Fireblocks vault (or rotate keys)

3. Grant delegation to new address:
   ```solidity
   grantWithdrawalDelegate(tokenId, newFireblocksAddress, 10000);
   ```

---

## 8. Security Best Practices

### Percentage Allocation Strategy

Consider splitting delegation for operational flexibility:

| Delegate | Percentage | Purpose |
|----------|------------|---------|
| Primary Fireblocks | 75% | Standard operations |
| Secondary Fireblocks | 25% | Backup/emergency |

### Multi-sig Threshold Recommendations

| Custody Value | Recommended Threshold |
|---------------|----------------------|
| < $1M | 2/3 |
| $1M - $10M | 3/5 |
| > $10M | 4/7 or 5/9 |

### Monitoring Setup

1. **On-chain alerts** (via Tenderly/OpenZeppelin Defender):
   - `WithdrawalDelegateGranted` events
   - `WithdrawalDelegateRevoked` events
   - `DelegatedWithdrawal` events

2. **Fireblocks notifications**:
   - Transaction completion webhooks
   - Failed transaction alerts

3. **Safe notifications**:
   - Signature request emails
   - Execution confirmations

### Incident Response

**If Fireblocks wallet compromised:**
1. Execute `revokeAllWithdrawalDelegates(tokenId)` from Safe (priority)
2. Maximum exposure: 1% of collateral (monthly cap)
3. Create new Fireblocks vault
4. Re-grant delegation after incident review

**If Safe signer compromised:**
1. Remaining signers execute ownership change
2. Remove compromised signer
3. Add replacement signer
4. Review and re-grant delegations if needed
