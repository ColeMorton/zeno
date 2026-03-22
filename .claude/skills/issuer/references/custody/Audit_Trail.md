# Delegation Audit Trail

> **Version:** 1.0
> **Status:** Draft
> **Last Updated:** 2025-12-30
> **Related Documents:**
> - [Withdrawal Delegation](../../protocol/Withdrawal_Delegation.md)
> - [Delegation Subgraph Schema](../../sdk/Delegation_Subgraph_Schema.md)
> - [Fireblocks Integration](./Fireblocks_Integration.md)
> - [Copper Integration](./Copper_Integration.md)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Delegation Lifecycle](#2-delegation-lifecycle)
3. [On-Chain Events](#3-on-chain-events)
4. [Compliance Queries](#4-compliance-queries)
5. [Dune Analytics](#5-dune-analytics)
6. [Report Templates](#6-report-templates)

---

## 1. Overview

### Purpose

Complete audit trail documentation for institutional custody compliance. All delegation actions are recorded on-chain as immutable events, providing cryptographic proof of:

- Who granted/revoked permissions
- When actions occurred
- What amounts were withdrawn
- Transaction hashes for verification

### Data Sources

| Source | Use Case | Latency |
|--------|----------|---------|
| Direct RPC | Real-time verification | Immediate |
| The Graph | Historical queries | ~30 seconds |
| Dune Analytics | Aggregate reporting | Minutes |

---

## 2. Delegation Lifecycle

### State Diagram

```
                    ┌─────────────────────────────────────┐
                    │                                     │
                    ▼                                     │
┌──────────┐   grantWithdrawalDelegate()   ┌──────────┐  │
│  NONE    │ ─────────────────────────────▶│  ACTIVE  │──┘
└──────────┘                               └──────────┘
                                                │
                                                │ revokeWithdrawalDelegate()
                                                │ OR revokeAllWithdrawalDelegates()
                                                ▼
                                           ┌──────────┐
                                           │ REVOKED  │
                                           └──────────┘
                                                │
                                                │ grantWithdrawalDelegate()
                                                │ (can be re-granted)
                                                ▼
                                           ┌──────────┐
                                           │  ACTIVE  │
                                           └──────────┘
```

### Lifecycle Events

| State Transition | Event Emitted | Key Fields |
|------------------|---------------|------------|
| NONE → ACTIVE | `WithdrawalDelegateGranted` | tokenId, delegate, percentageBPS |
| ACTIVE → ACTIVE | `WithdrawalDelegateGranted` | (percentage update) |
| ACTIVE → REVOKED | `WithdrawalDelegateRevoked` | tokenId, delegate |
| ACTIVE (all) → REVOKED | `AllWithdrawalDelegatesRevoked` | tokenId |
| ACTIVE → withdrawal | `DelegatedWithdrawal` | tokenId, delegate, amount |

### Example Timeline

```
Day 0:   VaultNFT #123 minted to Safe
Day 1:   grantWithdrawalDelegate(123, 0xFireblocks, 10000)
         → WithdrawalDelegateGranted(123, 0xFireblocks, 10000)

Day 31:  withdrawAsDelegate(123) from Fireblocks
         → DelegatedWithdrawal(123, 0xFireblocks, 0.01 BTC)

Day 61:  withdrawAsDelegate(123) from Fireblocks
         → DelegatedWithdrawal(123, 0xFireblocks, 0.0099 BTC)

Day 90:  revokeWithdrawalDelegate(123, 0xFireblocks)
         → WithdrawalDelegateRevoked(123, 0xFireblocks)
```

---

## 3. On-Chain Events

### Event Signatures

```solidity
// Delegation granted
event WithdrawalDelegateGranted(
    uint256 indexed tokenId,
    address indexed delegate,
    uint256 percentageBPS
);

// Single delegation revoked
event WithdrawalDelegateRevoked(
    uint256 indexed tokenId,
    address indexed delegate
);

// All delegations revoked for vault
event AllWithdrawalDelegatesRevoked(
    uint256 indexed tokenId
);

// Withdrawal executed by delegate
event DelegatedWithdrawal(
    uint256 indexed tokenId,
    address indexed delegate,
    uint256 amount
);
```

### Topic Hashes

| Event | Topic0 (keccak256) |
|-------|-------------------|
| WithdrawalDelegateGranted | `0x...` (compute from signature) |
| WithdrawalDelegateRevoked | `0x...` |
| AllWithdrawalDelegatesRevoked | `0x...` |
| DelegatedWithdrawal | `0x...` |

### Direct Log Query (ethers.js)

```typescript
const filter = {
  address: VAULT_NFT_ADDRESS,
  topics: [
    ethers.id("DelegatedWithdrawal(uint256,address,uint256)"),
    ethers.zeroPadValue(tokenId, 32),       // indexed tokenId
    ethers.zeroPadValue(delegateAddress, 32) // indexed delegate
  ],
  fromBlock: startBlock,
  toBlock: "latest"
};

const logs = await provider.getLogs(filter);
```

---

## 4. Compliance Queries

### The Graph Queries

See [Delegation Subgraph Schema](../../sdk/Delegation_Subgraph_Schema.md) for complete schema.

#### All Delegations for a Vault

```graphql
query VaultAudit($vaultId: ID!) {
  vault(id: $vaultId) {
    id
    owner
    delegations(orderBy: grantedAt, orderDirection: desc) {
      delegate
      percentageBPS
      grantedAt
      active
      totalWithdrawn
      grants {
        timestamp
        transactionHash
        grantor
      }
      revocations {
        timestamp
        transactionHash
        revoker
      }
      withdrawals {
        amount
        timestamp
        transactionHash
      }
    }
  }
}
```

#### Withdrawals by Date Range

```graphql
query WithdrawalsByPeriod($startTime: BigInt!, $endTime: BigInt!) {
  delegatedWithdrawals(
    where: { timestamp_gte: $startTime, timestamp_lte: $endTime }
    orderBy: timestamp
  ) {
    vault { id }
    delegate
    amount
    timestamp
    transactionHash
  }
}
```

#### Active Delegations by Delegate

```graphql
query DelegateAccess($delegate: Bytes!) {
  vaultDelegations(where: { delegate: $delegate, active: true }) {
    vault {
      id
      owner
      collateralAmount
    }
    percentageBPS
    grantedAt
    totalWithdrawn
  }
}
```

---

## 5. Dune Analytics

### SQL Templates

#### Monthly Withdrawal Summary

```sql
SELECT
  date_trunc('month', block_time) AS month,
  COUNT(*) AS withdrawal_count,
  SUM(CAST(amount AS DOUBLE) / 1e8) AS total_btc_withdrawn,
  COUNT(DISTINCT delegate) AS unique_delegates
FROM vaultnft_ethereum.VaultNFT_evt_DelegatedWithdrawal
WHERE block_time >= NOW() - INTERVAL '12' MONTH
GROUP BY 1
ORDER BY 1 DESC
```

#### Delegation Grant/Revoke History

```sql
WITH grants AS (
  SELECT
    tokenId,
    delegate,
    percentageBPS,
    block_time AS event_time,
    'GRANT' AS event_type,
    tx_hash
  FROM vaultnft_ethereum.VaultNFT_evt_WithdrawalDelegateGranted
),
revokes AS (
  SELECT
    tokenId,
    delegate,
    NULL AS percentageBPS,
    block_time AS event_time,
    'REVOKE' AS event_type,
    tx_hash
  FROM vaultnft_ethereum.VaultNFT_evt_WithdrawalDelegateRevoked
)
SELECT * FROM grants
UNION ALL
SELECT * FROM revokes
ORDER BY event_time DESC
```

#### Top Delegates by Withdrawal Volume

```sql
SELECT
  delegate,
  COUNT(*) AS withdrawal_count,
  SUM(CAST(amount AS DOUBLE) / 1e8) AS total_btc,
  COUNT(DISTINCT tokenId) AS vault_count
FROM vaultnft_ethereum.VaultNFT_evt_DelegatedWithdrawal
GROUP BY delegate
ORDER BY total_btc DESC
LIMIT 20
```

#### Delegation Duration Analysis

```sql
WITH delegation_spans AS (
  SELECT
    g.tokenId,
    g.delegate,
    g.block_time AS grant_time,
    COALESCE(r.block_time, NOW()) AS end_time,
    r.block_time IS NULL AS still_active
  FROM vaultnft_ethereum.VaultNFT_evt_WithdrawalDelegateGranted g
  LEFT JOIN vaultnft_ethereum.VaultNFT_evt_WithdrawalDelegateRevoked r
    ON g.tokenId = r.tokenId AND g.delegate = r.delegate
    AND r.block_time > g.block_time
)
SELECT
  CASE
    WHEN still_active THEN 'Active'
    WHEN DATE_DIFF('day', grant_time, end_time) < 30 THEN '< 30 days'
    WHEN DATE_DIFF('day', grant_time, end_time) < 90 THEN '30-90 days'
    WHEN DATE_DIFF('day', grant_time, end_time) < 365 THEN '90-365 days'
    ELSE '> 1 year'
  END AS duration_bucket,
  COUNT(*) AS delegation_count
FROM delegation_spans
GROUP BY 1
ORDER BY 2 DESC
```

---

## 6. Report Templates

### Monthly Delegation Summary

```
══════════════════════════════════════════════════════════════════
                    MONTHLY DELEGATION REPORT
                    Period: [MONTH YEAR]
══════════════════════════════════════════════════════════════════

DELEGATION ACTIVITY
───────────────────────────────────────────────────────────────────
New Delegations Granted:     [COUNT]
Delegations Revoked:         [COUNT]
Active Delegations (EOM):    [COUNT]

WITHDRAWAL ACTIVITY
───────────────────────────────────────────────────────────────────
Total Withdrawals:           [COUNT]
Total Volume:                [AMOUNT] BTC
Average Withdrawal:          [AMOUNT] BTC
Unique Delegates Active:     [COUNT]

TOP WITHDRAWING DELEGATES
───────────────────────────────────────────────────────────────────
1. [ADDRESS]                 [AMOUNT] BTC
2. [ADDRESS]                 [AMOUNT] BTC
3. [ADDRESS]                 [AMOUNT] BTC

VAULT BREAKDOWN
───────────────────────────────────────────────────────────────────
Vault #[ID]    | Collateral: [AMOUNT] | Withdrawn: [AMOUNT]
Vault #[ID]    | Collateral: [AMOUNT] | Withdrawn: [AMOUNT]

══════════════════════════════════════════════════════════════════
```

### Quarterly Withdrawal Report

```
══════════════════════════════════════════════════════════════════
                  QUARTERLY WITHDRAWAL REPORT
                  Q[N] [YEAR]
══════════════════════════════════════════════════════════════════

EXECUTIVE SUMMARY
───────────────────────────────────────────────────────────────────
Total Delegated Withdrawals:     [AMOUNT] BTC
Withdrawal Count:                [COUNT]
Average Monthly Rate:            [PERCENT]%

BY MONTH
───────────────────────────────────────────────────────────────────
Month 1:   [AMOUNT] BTC   ([COUNT] withdrawals)
Month 2:   [AMOUNT] BTC   ([COUNT] withdrawals)
Month 3:   [AMOUNT] BTC   ([COUNT] withdrawals)

BY DELEGATE
───────────────────────────────────────────────────────────────────
[ADDRESS]:   [AMOUNT] BTC   [PERCENT]% of total
[ADDRESS]:   [AMOUNT] BTC   [PERCENT]% of total

COMPLIANCE NOTES
───────────────────────────────────────────────────────────────────
All withdrawals executed within protocol limits (1% monthly)
All transactions verified on-chain
No anomalous activity detected

══════════════════════════════════════════════════════════════════
```

### Annual Compliance Audit

```
══════════════════════════════════════════════════════════════════
                   ANNUAL COMPLIANCE AUDIT
                   Year: [YEAR]
══════════════════════════════════════════════════════════════════

CUSTODY OVERVIEW
───────────────────────────────────────────────────────────────────
Total Vaults Under Custody:      [COUNT]
Total Collateral (YE):           [AMOUNT] BTC
Total Delegated (YE):            [AMOUNT] BTC

DELEGATION LIFECYCLE
───────────────────────────────────────────────────────────────────
Delegations Granted:             [COUNT]
Delegations Revoked:             [COUNT]
Emergency Revoke-All Events:     [COUNT]
Average Delegation Duration:     [DAYS] days

WITHDRAWAL SUMMARY
───────────────────────────────────────────────────────────────────
Total Withdrawals:               [COUNT]
Total Volume:                    [AMOUNT] BTC
Average per Withdrawal:          [AMOUNT] BTC
Withdrawal Rate (actual):        [PERCENT]%
Protocol Max Rate:               12.0%

TRANSACTION HASHES (Sample)
───────────────────────────────────────────────────────────────────
Q1: [TX_HASH]...
Q2: [TX_HASH]...
Q3: [TX_HASH]...
Q4: [TX_HASH]...

ATTESTATION
───────────────────────────────────────────────────────────────────
All data sourced from immutable on-chain events.
Verification: query via [SUBGRAPH_URL] or Dune Analytics.

══════════════════════════════════════════════════════════════════
```
