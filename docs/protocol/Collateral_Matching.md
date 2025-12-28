# BTCNFT Protocol Collateral Matching Mechanism

> **Version:** 2.2
> **Status:** Draft
> **Last Updated:** 2025-12-28
> **Related Documents:**
> - [Technical Specification](./Technical_Specification.md)
> - [Product Specification](./Product_Specification.md)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Mechanism Design](#2-mechanism-design)
3. [Contract Specification](#3-contract-specification)
4. [Example Flow](#4-example-flow)
5. [Design Rationale](#5-design-rationale)

---

## 1. Overview

### Purpose

The Collateral Matching mechanism utilizes forfeited BTC from early redemptions to reward Vault holders who complete the full 1129-day vesting period.

### Core Principle

**No allocation at mint. No governance parameters.**

Match amounts are derived deterministically from on-chain state at claim time.

```
┌─────────────────────────────────────────────────────────────────┐
│              COLLATERAL MATCHING                                │
│                                                                 │
│  Early Redemptions                   Vested Holders             │
│  ┌──────────┐                       ┌──────────────────┐       │
│  │ Forfeit  │                       │ Complete 1129    │       │
│  │ BTC      │──────► Match Pool ───►│ days → claim     │       │
│  └──────────┘         (accrues)     │ pro-rata share   │       │
│                                     └──────────────────┘       │
│                                                                 │
│  Match amount = matchPool × (holderCollateral / totalActive)   │
└─────────────────────────────────────────────────────────────────┘
```

### Isolated Match Pools Per Collateral Type

Each protocol deployment (one per collateral type) maintains its own independent match pool:

| Collateral | Match Pool | vestedBTC Token |
|------------|------------|-----------------|
| wBTC | Isolated wBTC pool | vWBTC |
| cbBTC | Isolated cbBTC pool | vCBBTC |
| tBTC | Isolated tBTC pool | vTBTC |

**Key Implications:**
- Early redemptions from vWBTC vaults only benefit vWBTC holders
- Match pool distributions cannot cross collateral boundaries
- If one wrapped BTC experiences issues, other pools remain unaffected
- Users can choose which match pool to participate in based on collateral risk profile

### Relationship to Base Specification

This mechanism extends the existing `penaltyDestinationType` options defined in the Technical Specification:

| Destination | Description | Status |
|-------------|-------------|--------|
| `ISSUER` | Sent to issuer wallet address | Original |
| `TREASURY` | Sent to protocol treasury address | Original |
| `SERIES_HOLDERS` | Redistributed pro-rata among same NFT series | Original |
| `ALL_HOLDERS` | Redistributed pro-rata among all NFT holders | Original |
| **`MATCH_POOL`** | **Pro-rata distribution to vested holders** | **Extension** |

---

## 2. Mechanism Design

### Claim Formula

When a vested Vault holder triggers `claimMatch(tokenId)`:

```
matchShare = matchPool × (holderCollateral / totalActiveCollateral)
```

Where:
- `matchPool` = total forfeited BTC available
- `holderCollateral` = caller's Vault collateral amount
- `totalActiveCollateral` = sum of collateral in all unvested Vaults

**Important:** Pending mints (within minting windows) are **NOT** part of `totalActiveCollateral`. Collateral only enters the active pool when Vault NFTs are minted (either via instant mint or window execution).

### Key Properties

| Property | Value |
|----------|-------|
| Governance parameters | **0** |
| Match allocation timing | At vesting completion (not mint) |
| Claim gas | O(1) |
| Housekeeping required | None (lazy self-maturing) |
| Claim order fairness | Yes (snapshot denominator) |

Note: "NFT" in this document refers to Vault NFTs (ERC-998).

### Flywheel Effect

```
┌─────────────────────────────────────────────────────────────────┐
│                    SELF-FUNDING FLYWHEEL                        │
│                                                                 │
│                    ┌─────────────────┐                         │
│                    │   Match Pool    │                         │
│                    │   (BTC balance) │                         │
│                    └────────┬────────┘                         │
│                             │                                   │
│         ┌───────────────────┼───────────────────┐              │
│         │                   │                   │              │
│         ▼                   │                   ▼              │
│  ┌─────────────┐            │            ┌─────────────┐       │
│  │ Early       │            │            │ Vested      │       │
│  │ (forfeit)   │────────────┘────────────│ Claims      │       │
│  │             │         funds           │ (pro-rata)  │       │
│  └─────────────┘                         └─────────────┘       │
│                                                                 │
│  Result: Redemptions fund claims → More mints → Growth         │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Contract Specification

### State Variables

```solidity
// Match pool balance (forfeited BTC)
uint256 public matchPool;

// Sum of collateral in unvested Vaults
uint256 public totalActiveCollateral;

// Vault marked as matured (vesting complete)
mapping(uint256 => bool) public matured;

// Match claimed for Vault
mapping(uint256 => bool) public matchClaimed;
```

### Functions

```solidity
// At mint - add to active collateral pool
function _onMint(uint256 collateral) internal {
    totalActiveCollateral += collateral;
}

// At early redemption - remove from active pool, add forfeit to match pool
function _onRedeem(uint256 tokenId, uint256 daysHeld) internal {
    if (!matured[tokenId]) {
        totalActiveCollateral -= collateralAmount[tokenId];
    }

    // Forfeited amount flows to matchPool
    uint256 forfeited = collateralAmount[tokenId] * (1129 - daysHeld) / 1129;
    matchPool += forfeited;
}

// Claim match (after vesting)
function claimMatch(uint256 tokenId) external {
    require(ownerOf(tokenId) == msg.sender, "Not owner");
    require(block.timestamp >= mintTimestamp[tokenId] + VESTING_PERIOD, "Not vested");
    require(!matchClaimed[tokenId], "Already claimed");

    // Snapshot denominator BEFORE any state changes (fair ordering)
    uint256 denominator = totalActiveCollateral;

    // Lazy self-maturing: mark as matured, remove from active pool
    if (!matured[tokenId]) {
        matured[tokenId] = true;
        totalActiveCollateral -= collateralAmount[tokenId];
    }

    // Pro-rata share based on snapshot denominator
    uint256 matchAmount = matchPool * collateralAmount[tokenId] / denominator;

    // Transfer match to collateral
    matchPool -= matchAmount;
    collateralAmount[tokenId] += matchAmount;
    matchClaimed[tokenId] = true;

    emit MatchClaimed(tokenId, matchAmount);
}
```

### Events

```solidity
event MatchClaimed(uint256 indexed tokenId, uint256 amount);
event MatchPoolFunded(uint256 amount, uint256 newBalance);
```

---

## 4. Example Flow

```
Day 0:   Alice mints with 1.0 BTC
         Bob mints with 0.5 BTC
         totalActiveCollateral = 1.5 BTC
         matchPool = 0

Day 365: Carol mints with 2.0 BTC
         totalActiveCollateral = 3.5 BTC

Day 547: Dave mints with 0.5 BTC
         totalActiveCollateral = 4.0 BTC

Day 912: Dave redeems early (365 days held)
         - Dave returns: 0.5 × (365/1129) = 0.162 BTC
         - Dave forfeits: 0.5 × (764/1129) = 0.338 BTC → matchPool
         totalActiveCollateral = 3.5 BTC
         matchPool = 0.338 BTC

Day 1129: Alice vests, calls claimMatch()
          denominator (snapshot) = 3.5 BTC
          matchAmount = 0.338 × (1.0 / 3.5) = 0.097 BTC
          Alice's collateral: 1.0 + 0.097 = 1.097 BTC
          matchPool = 0.241 BTC
          totalActiveCollateral = 2.5 BTC (after self-mature)

Day 1129: Bob vests, calls claimMatch()
          denominator (snapshot) = 2.5 BTC
          matchAmount = 0.241 × (0.5 / 2.5) = 0.048 BTC
          Bob's collateral: 0.5 + 0.048 = 0.548 BTC
          matchPool = 0.193 BTC
          totalActiveCollateral = 2.0 BTC (Carol remains)

Day 1494: Carol vests, calls claimMatch()
          denominator (snapshot) = 2.0 BTC
          matchAmount = 0.193 × (2.0 / 2.0) = 0.193 BTC
          Carol's collateral: 2.0 + 0.193 = 2.193 BTC
          matchPool = 0 BTC
```

---

## 5. Design Rationale

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Allocation timing | At vesting (not mint) | Eliminates governance parameters |
| Denominator | `totalActiveCollateral` | On-chain, deterministic |
| Self-maturing | Lazy (at claim time) | No housekeeping required |
| Snapshot denominator | Before state change | Fair regardless of claim order |
| Governance params | Zero | Maximum elegance, minimum attack surface |
| Claim gas | O(1) | Scalable to any number of NFTs |

---

## Navigation

← [Protocol Layer](./README.md) | [Documentation Home](../README.md)
