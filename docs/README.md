# BTCNFT Protocol Documentation

> **Version:** 1.0
> **Last Updated:** 2025-12-21

---

## Quick Navigation

### By Audience

| Audience | Entry Point | Description |
|----------|-------------|-------------|
| **Developers** | [Technical Specification](./protocol/Technical_Specification.md) | Contract mechanics, function specs |
| **Auditors** | [Technical Specification](./protocol/Technical_Specification.md) | Security model, immutability guarantees |
| **Issuers** | [Integration Guide](./issuer/Integration_Guide.md) | How to build on the protocol |
| **End Users** | [Holder Experience](./issuer/Holder_Experience.md) | User journey, FAQ |

---

## Documentation Layers

### Layer 1: Protocol

Smart contract specifications for developers, auditors, and technical integrators.

| Document | Purpose |
|----------|---------|
| [Technical Specification](./protocol/Technical_Specification.md) | Core contract mechanics |
| [Product Specification](./protocol/Product_Specification.md) | Product definition |
| [Collateral Matching](./protocol/Collateral_Matching.md) | Match pool mechanics |
| [Quantitative Validation](./protocol/Quantitative_Validation.md) | Historical data analysis |
| [Withdrawal Delegation](./protocol/Withdrawal_Delegation.md) | Delegation mechanics |
| [Hybrid Vault](./protocol/Hybrid_Vault.md) | Phase 2 product spec |

See [protocol/README.md](./protocol/README.md) for detailed navigation.

### Layer 2: Issuer

Documentation for NFT issuers building on the protocol.

| Document | Purpose |
|----------|---------|
| [Integration Guide](./issuer/Integration_Guide.md) | Complete issuer integration |
| [Holder Experience](./issuer/Holder_Experience.md) | End-user documentation |
| [Competitive Positioning](./issuer/Competitive_Positioning.md) | Market context |
| [Examples](./issuer/examples/) | Implementation templates |

See [issuer/README.md](./issuer/README.md) for detailed navigation.

### SDK

Developer tools and integration libraries.

| Document | Purpose |
|----------|---------|
| [SDK Overview](./sdk/README.md) | Package index and integration patterns |
| [vault-analytics](../packages/vault-analytics/README.md) | Vault ranking and percentile analytics |

---

## Terminology

See [GLOSSARY.md](./GLOSSARY.md) for standardized terminology.

**Key Terms:**
- **Vault NFT**: ERC-998 composable NFT holding Treasure + BTC collateral
- **Treasure NFT**: ERC-721 NFT wrapped within a Vault
- **vestedBTC (vBTC)**: ERC-20 token representing fungible collateral claims
- **Vesting Period**: 1129 days before withdrawals are enabled

---

## Development Resources

| Document | Purpose |
|----------|---------|
| [Testing Stack](./Testing_Stack.md) | Smart contract testing methodology |

---

## Architecture

```
Layer 0: Blockchain (Ethereum/L2)
    │
Layer 1: BTCNFT Protocol (This repository)
    │   └─ Immutable smart contracts
    │   └─ Core withdrawal mechanics
    │   └─ vestedBTC token
    │
Layer 2: NFT Issuers
    │   └─ Treasure design
    │   └─ Badge-gated minting
    │   └─ Custom experiences
    │
End Users: Vault Holders
        └─ Withdraw BTC monthly
        └─ Trade vestedBTC on DEX
        └─ Use protocol directly or via issuer
```
