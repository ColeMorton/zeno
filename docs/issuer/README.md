# Issuer Layer Documentation

> **Version:** 1.0
> **Status:** Draft
> **Last Updated:** 2025-12-22

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
| Vesting period | Fixed (1129 days) | - |
| Collateral matching | Protocol-managed | - |
| Entry requirements | - | Open vs badge-gated |
| Treasure design | - | Art, metadata, series |
| Minting windows | - | Timing, campaigns |
| Achievements | Protocol provides | Issuer can extend |
| Campaigns | - | Seasonal events, time-limited |

---

## Token Taxonomy

The issuer layer uses three distinct token types with orthogonal concerns:

| Token | Standard | Transferable | Visual Role | Tier Basis |
|-------|----------|--------------|-------------|------------|
| **Achievement NFT** | ERC-5192 | No (soulbound) | Tier 0 base blueprint | Merit (actions) |
| **Treasure NFT** | ERC-721 | Yes | Materialized artwork | Wealth (collateral %) |
| **Vault NFT** | ERC-998 | Yes | Container (holds Treasure) | N/A |

> Visual implementation details: [Visual_Assets_Guide.md](./Visual_Assets_Guide.md) (SVG/on-chain) | [Pixel_Art_Guide.md](./Pixel_Art_Guide.md) (raster/off-chain)

**Key Principle:** Merit (achievements) and wealth (percentile display) are orthogonal systems.

### Visual Hierarchy

```
Achievement NFT (Tier 0)
├─ Simplest visual form (base SVG)
├─ Earned through actions (soulbound)
└─ Defines visual vocabulary
         │
         ▼ informs base design

Treasure NFT (Materialized)
├─ Stored inside Vault
├─ Tradeable (ERC-721)
└─ Display tier = f(collateral percentile)
         │
         ▼ collateral percentile determines

Display Tier (Wealth-Based)
├─ Bronze (0-50th percentile)
├─ Silver (50-75th)
├─ Gold (75-90th)
├─ Platinum (90-99th)
└─ Diamond (99th+)
```

> **Implementation:** Achievement badges (Section 2), Tier frames (Section 3), Metadata schemas (Section 5) in [Visual_Assets_Guide.md](./Visual_Assets_Guide.md)

---

## Reading Order

### For New Issuers

1. **[Integration Guide](./Integration_Guide.md)** - Complete issuer integration
   - Registration, minting modes, entry strategies
   - Revenue models, Treasure strategy
   - Technical implementation patterns

2. **[Deployment Guide](./Deployment_Guide.md)** - Contract deployment for developers
   - Prerequisites and environment setup
   - Deployment commands and verification
   - Post-deployment configuration

3. **[The Ascent Design](./The_Ascent_Design.md)** - Achievement framework concept
   - Four-layer architecture
   - Personal journey narrative
   - Visual identity and cohort system

4. **[Achievements Specification](./Achievements_Specification.md)** - Achievement system technical spec
   - All 20 achievement definitions
   - Contract interfaces and claiming mechanics
   - On-chain verification and extension points

5. **[Holder Experience](./Holder_Experience.md)** - What your users experience
   - User journey, withdrawal mechanics
   - FAQ, common questions

6. **[Vault Percentile Specification](./Vault_Percentile_Specification.md)** - Analytics specification
   - Vault ranking by collateral
   - Filtering and display patterns

### Protocol Reference

| Document | Purpose |
|----------|---------|
| [Technical Specification](../protocol/Technical_Specification.md) | Contract mechanics |
| [Product Specification](../protocol/Product_Specification.md) | Product definition |
| [Collateral Matching](../protocol/Collateral_Matching.md) | Match pool mechanics |

---

## Example Implementations

See [examples/](./examples/) for concrete implementation patterns:

- Hypothetical examples with different issuer types
- Reference architectures
- Integration patterns

---

## Quick Start

For complete deployment instructions, see [Deployment Guide](./Deployment_Guide.md).

### 1. Deploy Issuer Contracts

```bash
cd contracts/issuer
forge build
forge script script/DeployIssuer.s.sol:DeployIssuer --rpc-url $RPC_URL --broadcast
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

## Glossary

| Term | Definition |
|------|------------|
| **Tier 0** | Base visual form (Achievement NFT) without wealth-based embellishments |
| **Display Tier** | Bronze/Silver/Gold/Platinum/Diamond ranking based on collateral percentile |
| **Merit** | Achievement system basis (actions, holding duration) |
| **Wealth** | Display tier basis (collateral amount relative to protocol TVL) |
| **Orthogonal** | Merit and wealth systems are independent; one does not affect the other |
| **Soulbound** | Non-transferable token bound permanently to the earning wallet (ERC-5192) |

---

## Background Reading

| Document | Purpose |
|----------|---------|
| [NFT Artwork Guide](../NFT_Artwork_Guide.md) | Philosophical exploration of digital art and NFT ownership |

---

## Related Documentation

| Layer | Documents |
|-------|-----------|
| **Protocol** | [Technical Spec](../protocol/Technical_Specification.md), [Product Spec](../protocol/Product_Specification.md) |
| **Issuer** | [Integration Guide](./Integration_Guide.md), [Deployment Guide](./Deployment_Guide.md), [The Ascent Design](./The_Ascent_Design.md), [Achievements Specification](./Achievements_Specification.md), [Holder Experience](./Holder_Experience.md), [Visual Assets Guide](./Visual_Assets_Guide.md), [Pixel Art Guide](./Pixel_Art_Guide.md), [Vault Percentile Spec](./Vault_Percentile_Specification.md) |
| **Custody** | [Fireblocks Integration](./custody/Fireblocks_Integration.md), [Copper Integration](./custody/Copper_Integration.md), [Audit Trail](./custody/Audit_Trail.md) |
| **SDK** | [SDK Overview](../sdk/README.md), [Visual Hierarchy](../sdk/VISUAL_HIERARCHY.md) |
| **Examples** | [examples/README.md](./examples/README.md) |
