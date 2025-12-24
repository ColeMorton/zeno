# Protocol Layer Documentation

> **Version:** 1.0
> **Last Updated:** 2025-12-21

Developer-focused documentation for the BTCNFT Protocol smart contracts.

---

## Overview

The BTCNFT Protocol is an immutable permissionless smart contract providing perpetual withdrawals through percentage-based collateral access. No admin functions, no upgrade mechanism, no governance.

---

## Documents

### Core Specifications

| Document | Description | Audience |
|----------|-------------|----------|
| [Technical Specification](./Technical_Specification.md) | Contract mechanics, function specs, state machines | Developers, Auditors |
| [Product Specification](./Product_Specification.md) | Product definition, use cases, value proposition | Product, Business |

### Mechanisms

| Document | Description |
|----------|-------------|
| [Collateral Matching](./Collateral_Matching.md) | Match pool mechanics for early redemption distribution |
| [Withdrawal Delegation](./Withdrawal_Delegation.md) | Delegation permissions for automated withdrawals |
| [Quantitative Validation](./Quantitative_Validation.md) | Historical BTC data analysis supporting design constraints |

### Extensions

| Document | Description |
|----------|-------------|
| [Hybrid Vault](./Hybrid_Vault.md) | Phase 2 hybrid vault mechanics |

---

## Reading Order

### For Smart Contract Developers

1. [Technical Specification](./Technical_Specification.md) - Start here
2. [Collateral Matching](./Collateral_Matching.md) - Understand distribution
3. [Withdrawal Delegation](./Withdrawal_Delegation.md) - Automation patterns

### For Auditors

1. [Technical Specification](./Technical_Specification.md) - All contract mechanics
2. [Product Specification](./Product_Specification.md) - Business context
3. [Quantitative Validation](./Quantitative_Validation.md) - Parameter justification

### For Integrators

1. [Product Specification](./Product_Specification.md) - What the protocol does
2. [Technical Specification](./Technical_Specification.md) - How to interact
3. [Issuer Integration Guide](../issuer/Integration_Guide.md) - Integration patterns

---

## Key Technical Concepts

### Immutability

All core parameters are embedded in bytecode using Solidity's `immutable` keyword:

```solidity
immutable uint256 VESTING_PERIOD = 1129 days;
immutable uint256 WITHDRAWAL_RATE = 1000; // 1.0%
```

No function exists to modify these values.

### Token Architecture

```
┌─────────────────────────────────────────┐
│ Vault NFT (ERC-998 Composable)          │
│ ├─ Treasure NFT (ERC-721)               │
│ ├─ BTC Collateral (WBTC)                │
│ └─ Withdrawal Rights                    │
└─────────────────────────────────────────┘
            │
            │ mintBtcToken()
            ▼
┌─────────────────────────────────────────┐
│ vestedBTC (ERC-20 Fungible)             │
│ └─ Collateral Claim                     │
└─────────────────────────────────────────┘
```

### State Machine

Vault lifecycle: `VESTING` → `ACTIVE` → `DORMANT*` → `CLAIMED*`

*Only applicable if vestedBTC has been separated

---

## Related Documentation

| Layer | Documents |
|-------|-----------|
| **Protocol** | This directory |
| **Issuer** | [issuer/](../issuer/) |
| **SDK** | [sdk/](../sdk/) |
| **Glossary** | [GLOSSARY.md](../GLOSSARY.md) |
