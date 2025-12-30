# Delegation Subgraph Schema

> **Version:** 1.0
> **Status:** Draft
> **Last Updated:** 2025-12-30
> **Related Documents:**
> - [Withdrawal Delegation](../protocol/Withdrawal_Delegation.md)
> - [Audit Trail](../issuer/custody/Audit_Trail.md)
> - [SDK README](./README.md)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Entity Definitions](#2-entity-definitions)
3. [Event Handlers](#3-event-handlers)
4. [Query Examples](#4-query-examples)
5. [Deployment](#5-deployment)

---

## 1. Overview

### Purpose

This schema defines GraphQL entities for indexing withdrawal delegation events from the VaultNFT contract. Use this for:

- Institutional audit trails
- Compliance reporting
- Delegation lifecycle tracking
- Portfolio analytics

### Indexed Events

| Event | Description |
|-------|-------------|
| `WithdrawalDelegateGranted` | New delegation or permission update |
| `WithdrawalDelegateRevoked` | Single delegate revocation |
| `AllWithdrawalDelegatesRevoked` | Bulk revocation for vault |
| `DelegatedWithdrawal` | Delegate executes withdrawal |

### Data Sources

```yaml
dataSources:
  - kind: ethereum
    name: VaultNFT
    source:
      address: "<VAULT_NFT_ADDRESS>"
      abi: VaultNFT
      startBlock: <DEPLOYMENT_BLOCK>
    mapping:
      entities:
        - VaultDelegation
        - DelegationGrant
        - DelegationRevocation
        - DelegatedWithdrawal
```

---

## 2. Entity Definitions

### schema.graphql

```graphql
type Vault @entity {
  id: ID!                                  # tokenId
  owner: Bytes!
  collateralToken: Bytes!
  collateralAmount: BigInt!
  mintTimestamp: BigInt!
  delegations: [VaultDelegation!]! @derivedFrom(field: "vault")
  totalDelegatedBPS: BigInt!
}

type VaultDelegation @entity {
  "Unique ID: tokenId-delegateAddress"
  id: ID!

  "Reference to the Vault entity"
  vault: Vault!

  "Delegate wallet address"
  delegate: Bytes!

  "Delegation percentage in basis points (10000 = 100%)"
  percentageBPS: BigInt!

  "Block timestamp when delegation was granted"
  grantedAt: BigInt!

  "Block timestamp of most recent withdrawal (null if never withdrawn)"
  lastWithdrawal: BigInt

  "Whether this delegation is currently active"
  active: Boolean!

  "Cumulative amount withdrawn by this delegate"
  totalWithdrawn: BigInt!

  "Number of withdrawals executed"
  withdrawalCount: Int!

  "All grant events for this delegation"
  grants: [DelegationGrant!]! @derivedFrom(field: "delegation")

  "All revocation events for this delegation"
  revocations: [DelegationRevocation!]! @derivedFrom(field: "delegation")

  "All withdrawal events for this delegation"
  withdrawals: [DelegatedWithdrawal!]! @derivedFrom(field: "delegation")
}

type DelegationGrant @entity {
  "Unique ID: transactionHash-logIndex"
  id: ID!

  "Parent delegation entity"
  delegation: VaultDelegation!

  "Vault that granted delegation"
  vault: Vault!

  "Delegate address"
  delegate: Bytes!

  "Percentage granted in basis points"
  percentageBPS: BigInt!

  "Block timestamp"
  timestamp: BigInt!

  "Block number"
  blockNumber: BigInt!

  "Transaction hash"
  transactionHash: Bytes!

  "Transaction sender (vault owner)"
  grantor: Bytes!
}

type DelegationRevocation @entity {
  "Unique ID: transactionHash-logIndex"
  id: ID!

  "Parent delegation (null for revokeAll events)"
  delegation: VaultDelegation

  "Vault that revoked delegation"
  vault: Vault!

  "Delegate address (null for revokeAll events)"
  delegate: Bytes

  "True if this was a revokeAllWithdrawalDelegates call"
  isRevokeAll: Boolean!

  "Block timestamp"
  timestamp: BigInt!

  "Block number"
  blockNumber: BigInt!

  "Transaction hash"
  transactionHash: Bytes!

  "Transaction sender (vault owner)"
  revoker: Bytes!
}

type DelegatedWithdrawal @entity {
  "Unique ID: transactionHash-logIndex"
  id: ID!

  "Parent delegation entity"
  delegation: VaultDelegation!

  "Vault withdrawn from"
  vault: Vault!

  "Delegate who executed withdrawal"
  delegate: Bytes!

  "Amount withdrawn (in collateral token units)"
  amount: BigInt!

  "Block timestamp"
  timestamp: BigInt!

  "Block number"
  blockNumber: BigInt!

  "Transaction hash"
  transactionHash: Bytes!
}

type DelegationStats @entity {
  "Singleton: 'global'"
  id: ID!

  "Total active delegations"
  activeDelegations: Int!

  "Total delegations ever created"
  totalDelegations: Int!

  "Total revocations"
  totalRevocations: Int!

  "Total withdrawals via delegation"
  totalWithdrawals: Int!

  "Total amount withdrawn via delegation"
  totalWithdrawnAmount: BigInt!
}
```

---

## 3. Event Handlers

### mapping.ts

```typescript
import {
  WithdrawalDelegateGranted,
  WithdrawalDelegateRevoked,
  AllWithdrawalDelegatesRevoked,
  DelegatedWithdrawal as DelegatedWithdrawalEvent
} from "../generated/VaultNFT/VaultNFT";
import {
  Vault,
  VaultDelegation,
  DelegationGrant,
  DelegationRevocation,
  DelegatedWithdrawal,
  DelegationStats
} from "../generated/schema";
import { BigInt, Bytes } from "@graphprotocol/graph-ts";

// Helper: Get or create delegation entity
function getOrCreateDelegation(tokenId: BigInt, delegate: Bytes): VaultDelegation {
  let id = tokenId.toString() + "-" + delegate.toHexString();
  let delegation = VaultDelegation.load(id);

  if (delegation == null) {
    delegation = new VaultDelegation(id);
    delegation.vault = tokenId.toString();
    delegation.delegate = delegate;
    delegation.percentageBPS = BigInt.fromI32(0);
    delegation.grantedAt = BigInt.fromI32(0);
    delegation.lastWithdrawal = null;
    delegation.active = false;
    delegation.totalWithdrawn = BigInt.fromI32(0);
    delegation.withdrawalCount = 0;
  }

  return delegation;
}

// Helper: Get or create global stats
function getOrCreateStats(): DelegationStats {
  let stats = DelegationStats.load("global");

  if (stats == null) {
    stats = new DelegationStats("global");
    stats.activeDelegations = 0;
    stats.totalDelegations = 0;
    stats.totalRevocations = 0;
    stats.totalWithdrawals = 0;
    stats.totalWithdrawnAmount = BigInt.fromI32(0);
  }

  return stats;
}

// Handler: WithdrawalDelegateGranted
export function handleWithdrawalDelegateGranted(event: WithdrawalDelegateGranted): void {
  let tokenId = event.params.tokenId;
  let delegate = event.params.delegate;
  let percentageBPS = event.params.percentageBPS;

  // Update or create delegation
  let delegation = getOrCreateDelegation(tokenId, delegate);
  let wasActive = delegation.active;

  delegation.percentageBPS = percentageBPS;
  delegation.grantedAt = event.block.timestamp;
  delegation.active = true;
  delegation.save();

  // Create grant record
  let grantId = event.transaction.hash.toHexString() + "-" + event.logIndex.toString();
  let grant = new DelegationGrant(grantId);
  grant.delegation = delegation.id;
  grant.vault = tokenId.toString();
  grant.delegate = delegate;
  grant.percentageBPS = percentageBPS;
  grant.timestamp = event.block.timestamp;
  grant.blockNumber = event.block.number;
  grant.transactionHash = event.transaction.hash;
  grant.grantor = event.transaction.from;
  grant.save();

  // Update stats
  let stats = getOrCreateStats();
  if (!wasActive) {
    stats.activeDelegations = stats.activeDelegations + 1;
    stats.totalDelegations = stats.totalDelegations + 1;
  }
  stats.save();
}

// Handler: WithdrawalDelegateRevoked
export function handleWithdrawalDelegateRevoked(event: WithdrawalDelegateRevoked): void {
  let tokenId = event.params.tokenId;
  let delegate = event.params.delegate;

  // Update delegation
  let delegation = getOrCreateDelegation(tokenId, delegate);
  delegation.active = false;
  delegation.save();

  // Create revocation record
  let revocationId = event.transaction.hash.toHexString() + "-" + event.logIndex.toString();
  let revocation = new DelegationRevocation(revocationId);
  revocation.delegation = delegation.id;
  revocation.vault = tokenId.toString();
  revocation.delegate = delegate;
  revocation.isRevokeAll = false;
  revocation.timestamp = event.block.timestamp;
  revocation.blockNumber = event.block.number;
  revocation.transactionHash = event.transaction.hash;
  revocation.revoker = event.transaction.from;
  revocation.save();

  // Update stats
  let stats = getOrCreateStats();
  stats.activeDelegations = stats.activeDelegations - 1;
  stats.totalRevocations = stats.totalRevocations + 1;
  stats.save();
}

// Handler: AllWithdrawalDelegatesRevoked
export function handleAllWithdrawalDelegatesRevoked(event: AllWithdrawalDelegatesRevoked): void {
  let tokenId = event.params.tokenId;

  // Create revocation record (delegation is null for revokeAll)
  let revocationId = event.transaction.hash.toHexString() + "-" + event.logIndex.toString();
  let revocation = new DelegationRevocation(revocationId);
  revocation.delegation = null;
  revocation.vault = tokenId.toString();
  revocation.delegate = null;
  revocation.isRevokeAll = true;
  revocation.timestamp = event.block.timestamp;
  revocation.blockNumber = event.block.number;
  revocation.transactionHash = event.transaction.hash;
  revocation.revoker = event.transaction.from;
  revocation.save();

  // Note: Individual delegation.active flags should be updated
  // via a separate indexing pass or template-based approach

  // Update stats
  let stats = getOrCreateStats();
  stats.totalRevocations = stats.totalRevocations + 1;
  stats.save();
}

// Handler: DelegatedWithdrawal
export function handleDelegatedWithdrawal(event: DelegatedWithdrawalEvent): void {
  let tokenId = event.params.tokenId;
  let delegate = event.params.delegate;
  let amount = event.params.amount;

  // Update delegation
  let delegation = getOrCreateDelegation(tokenId, delegate);
  delegation.lastWithdrawal = event.block.timestamp;
  delegation.totalWithdrawn = delegation.totalWithdrawn.plus(amount);
  delegation.withdrawalCount = delegation.withdrawalCount + 1;
  delegation.save();

  // Create withdrawal record
  let withdrawalId = event.transaction.hash.toHexString() + "-" + event.logIndex.toString();
  let withdrawal = new DelegatedWithdrawal(withdrawalId);
  withdrawal.delegation = delegation.id;
  withdrawal.vault = tokenId.toString();
  withdrawal.delegate = delegate;
  withdrawal.amount = amount;
  withdrawal.timestamp = event.block.timestamp;
  withdrawal.blockNumber = event.block.number;
  withdrawal.transactionHash = event.transaction.hash;
  withdrawal.save();

  // Update stats
  let stats = getOrCreateStats();
  stats.totalWithdrawals = stats.totalWithdrawals + 1;
  stats.totalWithdrawnAmount = stats.totalWithdrawnAmount.plus(amount);
  stats.save();
}
```

---

## 4. Query Examples

### Active Delegations for a Vault

```graphql
query VaultDelegations($vaultId: ID!) {
  vaultDelegations(
    where: { vault: $vaultId, active: true }
    orderBy: percentageBPS
    orderDirection: desc
  ) {
    id
    delegate
    percentageBPS
    grantedAt
    lastWithdrawal
    totalWithdrawn
    withdrawalCount
  }
}
```

### Delegation History (Audit Trail)

```graphql
query DelegationHistory($vaultId: ID!, $first: Int = 100) {
  grants: delegationGrants(
    where: { vault: $vaultId }
    orderBy: timestamp
    orderDirection: desc
    first: $first
  ) {
    delegate
    percentageBPS
    timestamp
    transactionHash
    grantor
  }

  revocations: delegationRevocations(
    where: { vault: $vaultId }
    orderBy: timestamp
    orderDirection: desc
    first: $first
  ) {
    delegate
    isRevokeAll
    timestamp
    transactionHash
    revoker
  }
}
```

### Withdrawal Report (Compliance)

```graphql
query WithdrawalReport(
  $delegate: Bytes!
  $startTime: BigInt!
  $endTime: BigInt!
) {
  delegatedWithdrawals(
    where: {
      delegate: $delegate
      timestamp_gte: $startTime
      timestamp_lte: $endTime
    }
    orderBy: timestamp
    orderDirection: asc
  ) {
    vault { id }
    amount
    timestamp
    transactionHash
  }
}
```

### All Delegations by Delegate

```graphql
query DelegatePortfolio($delegate: Bytes!) {
  vaultDelegations(
    where: { delegate: $delegate, active: true }
  ) {
    vault {
      id
      collateralAmount
      collateralToken
    }
    percentageBPS
    grantedAt
    lastWithdrawal
    totalWithdrawn
  }
}
```

### Global Statistics

```graphql
query GlobalStats {
  delegationStats(id: "global") {
    activeDelegations
    totalDelegations
    totalRevocations
    totalWithdrawals
    totalWithdrawnAmount
  }
}
```

### Upcoming Withdrawals (30-day check)

```graphql
query UpcomingWithdrawals($currentTime: BigInt!, $thirtyDaysAgo: BigInt!) {
  vaultDelegations(
    where: {
      active: true
      lastWithdrawal_lt: $thirtyDaysAgo
    }
  ) {
    vault { id, collateralAmount }
    delegate
    percentageBPS
    lastWithdrawal
  }
}
```

---

## 5. Deployment

### subgraph.yaml

```yaml
specVersion: 0.0.5
schema:
  file: ./schema.graphql
dataSources:
  - kind: ethereum
    name: VaultNFT
    network: mainnet
    source:
      address: "<VAULT_NFT_ADDRESS>"
      abi: VaultNFT
      startBlock: <DEPLOYMENT_BLOCK>
    mapping:
      kind: ethereum/events
      apiVersion: 0.0.7
      language: wasm/assemblyscript
      entities:
        - Vault
        - VaultDelegation
        - DelegationGrant
        - DelegationRevocation
        - DelegatedWithdrawal
        - DelegationStats
      abis:
        - name: VaultNFT
          file: ./abis/VaultNFT.json
      eventHandlers:
        - event: WithdrawalDelegateGranted(indexed uint256,indexed address,uint256)
          handler: handleWithdrawalDelegateGranted
        - event: WithdrawalDelegateRevoked(indexed uint256,indexed address)
          handler: handleWithdrawalDelegateRevoked
        - event: AllWithdrawalDelegatesRevoked(indexed uint256)
          handler: handleAllWithdrawalDelegatesRevoked
        - event: DelegatedWithdrawal(indexed uint256,indexed address,uint256)
          handler: handleDelegatedWithdrawal
      file: ./src/mapping.ts
```

### Deploy Commands

```bash
# Install dependencies
npm install

# Generate types
graph codegen

# Build
graph build

# Deploy to The Graph hosted service
graph deploy --product hosted-service <GITHUB_USER>/btcnft-delegation

# Or deploy to Subgraph Studio
graph deploy --studio btcnft-delegation
```

### Network Configurations

| Network | Subgraph Studio | Hosted Service |
|---------|-----------------|----------------|
| Mainnet | Supported | Supported |
| Base | Supported | Limited |
| Arbitrum | Supported | Supported |
