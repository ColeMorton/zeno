# Issuer Layer Documentation

> **Version:** 1.0
> **Status:** Draft
> **Last Updated:** 2025-12-16

---

## What is an Issuer?

An issuer is any entity that creates minting opportunities for the BTCNFT Protocol. Issuers control access mechanisms, Treasure design, and participant engagement without modifying core protocol parameters.

### Issuer Types

| Type | Description | Examples |
|------|-------------|----------|
| **Personal Brand** | Individual-driven with unique series | Content creators, influencers |
| **DAO** | Community-governed with token/NFT voting | DeFi protocols, NFT communities |
| **Corporation** | Enterprise-managed with formal governance | Companies, institutions |
| **Artist Collective** | Creator-focused with art-centric Treasures | Artists, galleries |
| **Community** | Group-managed with shared objectives | Discord communities, clubs |

### Issuer Capabilities

| Capability | Protocol Control | Issuer Control |
|------------|------------------|----------------|
| Withdrawal rates | Fixed by protocol | - |
| Vesting period | Fixed (1093 days) | - |
| Collateral matching | Protocol-managed | - |
| Entry requirements | - | Open vs badge-gated |
| Treasure design | - | Art, metadata, series |
| Minting windows | - | Timing, campaigns |
| Achievements | Protocol provides | Issuer can extend |
| Gamification | - | Leaderboards, tiers |

---

## Reading Order

### For New Issuers

1. **[Issuer Guide](./Issuer_Guide.md)** - How to become an issuer
   - Registration, minting modes, entry strategies
   - Revenue models, Treasure strategy
   - Achievement integration, gamification options

2. **[Holder Experience](./Holder_Experience.md)** - What your users experience
   - User journey, withdrawal mechanics
   - FAQ, common questions

3. **[Competitive Positioning](./Competitive_Positioning.md)** - Market context
   - Target markets, differentiators
   - Competitive analysis

### Protocol Reference

| Document | Purpose |
|----------|---------|
| [Technical Specification](../protocol/Technical_Specification.md) | Contract mechanics |
| [Product Specification](../protocol/Product_Specification.md) | Product definition |
| [Issuer Integration](../protocol/Issuer_Integration.md) | Integration patterns |
| [Collateral Matching](../protocol/Collateral_Matching.md) | Match pool mechanics |

---

## Example Implementations

See [examples/](./examples/) for concrete implementation patterns:

- Hypothetical examples with different issuer types
- Reference architectures
- Integration patterns

---

## Quick Start

### 1. Register as Issuer

```solidity
// Permissionless registration
protocol.registerIssuer();
```

### 2. Choose Minting Mode

| Mode | Use Case |
|------|----------|
| **Instant Mint** | Standard permissionless minting |
| **Window Mint** | Campaign-based coordinated releases |

### 3. Define Entry Strategy

| Strategy | Description |
|----------|-------------|
| **Open** | Anyone can mint with eligible Treasure |
| **Badge-Gated** | Require credential for access |
| **Hybrid** | Open minting + badge bonuses |

### 4. Design Treasure Collection

- Create ERC-721 Treasure contract
- Define art/metadata for each series
- Configure allowed Treasures per window

### 5. Launch

- Create minting window (if using window mint)
- Announce to community
- Monitor analytics

---

## Related Documentation

| Layer | Documents |
|-------|-----------|
| **Protocol** | [Technical Spec](../protocol/Technical_Specification.md), [Product Spec](../protocol/Product_Specification.md), [Issuer Integration](../protocol/Issuer_Integration.md) |
| **Issuer (Generic)** | [Issuer Guide](./Issuer_Guide.md), [Holder Experience](./Holder_Experience.md), [Competitive Positioning](./Competitive_Positioning.md) |
| **Examples** | [examples/README.md](./examples/README.md) |
