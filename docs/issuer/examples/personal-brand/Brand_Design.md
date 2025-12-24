# [BRAND_NAME] Brand Design

> **Version:** 1.0
> **Status:** Draft
> **Last Updated:** 2025-12-16
> **Related Documents:**
> - [Holder Guide](./Holder_Guide.md)
> - [Roadmap](./Roadmap.md)
> - [Issuer Guide](../issuer/Issuer_Guide.md)

---

## Table of Contents

1. [Series Model](#1-series-model)
2. [Entry Badges](#2-entry-badges)
3. [Treasure Art](#3-treasure-art)
4. [Achievement Integration](#4-achievement-integration)
5. [Gamification](#5-gamification)
6. [vestedBTC Economy](#6-vestedbtc-economy)
7. [Governance](#7-governance)

---

## 1. Series Model

### Series Types

| Type | Description | Examples |
|------|-------------|----------|
| **Ongoing** | Continuous releases, no end date | Bitcoin Series |
| **Limited Edition** | Capped quantity or time-limited | [Future series] |

### Bitcoin Series (Ongoing)

| Property | Value |
|----------|-------|
| Availability | Ongoing |
| Entry | Badge-gated |
| Withdrawal rate | 12% annual (1.0% monthly) |
| Treasure | Unique art per badge type |

### Future Series

[Placeholder for additional series as they are defined]

---

## 2. Entry Badges

### Badge Types

| Badge | Requirement | Transferable | Purpose |
|-------|-------------|--------------|---------|
| `MEMBER` | Complete brand onboarding | No (soulbound) | Gates first Vault |
| `CONTRIBUTOR` | Meaningful contribution | No (soulbound) | Alternative entry |
| `INVITEE` | Invitation from existing participant | No (soulbound) | Invitation-based entry |

### Badge Properties

- Entry Badges are **soulbound** (non-transferable)
- One Entry Badge = one Vault mint opportunity
- Badge remains at user's address but marked as "redeemed" after use
- Each badge type unlocks a unique Treasure design

### Badge Issuance

[Placeholder for badge issuance criteria and process]

---

## 3. Treasure Art

### Design Philosophy

Treasures are rendered with display tier frames based on the vault's collateral percentile. The base Treasure artwork (stored on IPFS) is composited with tier-specific SVG frames by the metadata service.

> Implementation details: [Visual_Assets_Guide.md](../../Visual_Assets_Guide.md) Section 3 (Display Tier Visual System)

### Badge-to-Treasure Mapping

| Badge Type | Treasure Design |
|------------|-----------------|
| `MEMBER` | [Design description] |
| `CONTRIBUTOR` | [Design description] |
| `INVITEE` | [Design description] |

### Art Direction

| Aspect | Approach |
|--------|----------|
| Style | [Art style] |
| Themes | [Thematic elements] |
| Rarity | [Rarity approach] |

---

## 4. Achievement Integration

### Protocol Achievements

Leverage protocol-provided achievements for Vault stacking:

**Duration Achievements:**

| Achievement | Requirement | Enables |
|-------------|-------------|---------|
| First Month | Hold 30 days | Stack Vault #2 |
| Quarter Stack | Hold 91 days | Stack additional Vault |
| Half Year | Hold 182 days | Stack additional Vault |
| Annual | Hold 365 days | Stack additional Vault |
| Diamond Hands | Hold 730 days | Stack additional Vault |
| Hodler Supreme | Hold 1129 days | Stack additional Vault |

### Brand-Specific Achievements

[Placeholder for any brand-specific achievements beyond protocol defaults]

### Vault Stacking Flow

```
Entry Badge + BTC → Vault #1 → Achievements → Achievement + BTC → Vault #2 → ...
```

---

## 5. Gamification

### Leaderboards

| Leaderboard | Metric | Type |
|-------------|--------|------|
| Longest Hold | Days held | Merit |
| Achievement Hunter | Total achievements | Merit |
| Whale Watch | Total BTC collateral | Vanity |

### Display Tiers

| Tier | Percentile | Frame Color | Cosmetic |
|------|------------|-------------|----------|
| Bronze | 0-50th | `#cd7f32` | Standard frame |
| Silver | 50-75th | `#c0c0c0` | Silver frame |
| Gold | 75-90th | `#ffd700` | Gold frame |
| Diamond | 90-99th | `#b9f2ff` | Diamond frame + effects |
| Whale | 99th+ | `#e0e0ff` | Unique frame + leaderboard feature |

> Frame SVG templates: [Visual_Assets_Guide.md](../../Visual_Assets_Guide.md) Section 3

**Note:** Display tiers are **cosmetic only** - no rate/reward advantage.

### Profile Features

| Feature | Description |
|---------|-------------|
| Display art | Treasure NFT |
| Frame | Vanity tier cosmetic |
| Badges | Earned achievements |
| Title | Selected from earned titles |

---

## 6. vestedBTC Economy

### Premium Services

| Category | Examples |
|----------|----------|
| Digital | Analytics, priority access |
| Support | Technical support, account management |
| Education | Training, workshops |
| Concierge | White-glove experience |

### Access Philosophy

| Principle | Implementation |
|-----------|----------------|
| Core functionality | Free and unrestricted |
| Paywall footprint | Minimal |
| Upgrade paths | Transparent and non-intrusive |
| Gatekeeping | None on protocol features |

### Revenue Uses

| Use | Description |
|-----|-------------|
| LP accumulation | Build protocol-owned liquidity |
| Brand development | Content, community |
| Partnership rewards | Campaign sponsorship |

---

## 7. Governance

### Governance Model

**Sole Issuer (Personal Brand):**

| Aspect | Design |
|--------|--------|
| Decision-making | Personal authority |
| Accountability | Brand reputation |
| Speed | Fast iteration |
| Transparency | Public communications |

### Responsibilities

| Area | Control |
|------|---------|
| Badge issuance | Full control |
| Treasure releases | Full control |
| Campaign launches | Full control |
| Partnership decisions | Full control |
| Gamification updates | Full control |

### Constraints

| Constraint | Source |
|------------|--------|
| Cannot modify core protocol | Protocol immutability |
| Cannot access user collateral | Non-custodial design |
| Cannot change withdrawal rates | Protocol immutability |
| Cannot create governance tokens | Design decision |

---

## Summary

| Aspect | [BRAND_NAME] Design |
|--------|---------------------|
| Entry | Badge-gated (soulbound Entry Badges) |
| Series | Ongoing (Bitcoin Series) + Limited Editions |
| Withdrawal rate | 12% annual (1.0% monthly) |
| Stacking | Protocol achievements → additional Vaults |
| Gamification | Merit leaderboards + vanity cosmetics |
| Governance | Sole issuer |
