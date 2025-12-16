# Issuer Implementation Examples

> **Version:** 1.0
> **Status:** Draft
> **Last Updated:** 2025-12-16
> **Related Documents:**
> - [Issuer Guide](../Issuer_Guide.md)
> - [Issuer Integration](../../protocol/Issuer_Integration.md)

---

## Overview

This directory contains example implementation patterns for different issuer types. Use these as reference when designing your own issuer implementation.

---

## Live Implementations

### [BRAND_NAME]

Personal brand with badge-gated entry and series model.

**Documentation:** [/docs/[BRAND_NAME]/](../../[BRAND_NAME]/)

| Aspect | Implementation |
|--------|----------------|
| Entry | Badge-gated (soulbound Entry Badges) |
| Series | Ongoing (Bitcoin Series) + future Limited Editions |
| Governance | Sole issuer |
| Withdrawal Rate | 10.5% annual (0.875% monthly) |
| Stacking | Protocol achievements → additional Vaults |

---

## Hypothetical Examples

### Example: Artist Collective

Open minting with artist-created Treasures.

| Aspect | Implementation |
|--------|----------------|
| Entry | Open (no badge required) |
| Treasures | Artist-created NFTs |
| Series | Limited edition drops per artist |
| Governance | Artist multisig |
| Revenue | Primary sales via auction |

**Use Case:**
- Multiple artists contribute Treasure designs
- Each artist series has limited supply
- Auction proceeds become user collateral
- Artists share governance via multisig

**Key Decisions:**
- Open minting maximizes accessibility
- Auction mechanism for price discovery
- No badge requirement removes entry friction
- Artist-specific series creates collectibility

---

### Example: Corporate Treasury

Institutional-grade implementation for corporate BTC allocation.

| Aspect | Implementation |
|--------|----------------|
| Entry | KYC-gated (verified badges only) |
| Treasures | Corporate-branded NFTs |
| Series | Single ongoing series |
| Governance | Corporate board |
| Withdrawal Rate | 10.5% annual (regulatory comfort) |

**Use Case:**
- Corporation wants BTC treasury exposure
- Regulatory compliance requires KYC
- Structured withdrawals for cash flow planning
- Non-custodial design for security

**Key Decisions:**
- Badge-gated entry with KYC verification
- Fixed withdrawal rate (10.5% annually) for stability
- Corporate governance for accountability
- Branded Treasures for corporate identity

---

### Example: DAO

Community-governed with token/NFT-weighted voting.

| Aspect | Implementation |
|--------|----------------|
| Entry | NFT-gated (existing collection holders) |
| Treasures | Community-created designs |
| Series | Proposal-based releases |
| Governance | Token/NFT voting |
| Gamification | DAO-specific achievements |

**Use Case:**
- Existing NFT community wants BTC utility
- Community votes on Treasure designs
- DAO treasury holds protocol-owned liquidity
- Members earn DAO-specific achievements

**Key Decisions:**
- Entry gated by existing NFT ownership
- Governance via existing token/NFT
- Community proposals for series releases
- Extended achievement system

---

### Example: Content Creator

Individual creator with audience engagement model.

| Aspect | Implementation |
|--------|----------------|
| Entry | Badge-gated (subscriber/member badges) |
| Treasures | Creator-designed art |
| Series | Tied to content milestones |
| Governance | Sole creator |
| Revenue | Premium content access |

**Use Case:**
- YouTuber/podcaster/writer with audience
- Subscribers earn Entry Badges
- Exclusive Treasure art for supporters
- vestedBTC unlocks premium content

**Key Decisions:**
- Entry tied to platform subscription
- Content milestone series (e.g., 100 episodes)
- Premium services denominated in vestedBTC
- Sole governance for fast iteration

---

## Implementation Checklist

When designing your issuer implementation:

### 1. Entry Strategy

- [ ] Open vs badge-gated
- [ ] Badge types and issuance criteria
- [ ] Soulbound vs transferable badges

### 2. Treasure Design

- [ ] Art direction and style
- [ ] Per-series or per-badge-type designs
- [ ] Limited editions vs ongoing

### 3. Series Model

- [ ] Ongoing series definition
- [ ] Limited edition plan
- [ ] Pricing mechanism (fixed vs auction)

### 4. Governance

- [ ] Decision-making structure
- [ ] Multisig configuration (if applicable)
- [ ] Community input mechanisms

### 5. Gamification

- [ ] Leaderboard configuration
- [ ] Vanity tier thresholds
- [ ] Brand-specific achievements (if any)

### 6. Revenue Model

- [ ] Premium services
- [ ] Partnership opportunities
- [ ] vestedBTC economy design

### 7. Technical

- [ ] BadgeRedemptionController deployment
- [ ] Treasure contract deployment
- [ ] Frontend/dApp development

---

## Adding New Examples

To add a new example implementation:

1. Create a new section in this file with the issuer type
2. Document key aspects (entry, treasures, governance, etc.)
3. Explain the use case and key decisions
4. For live implementations, create a dedicated directory

---

## Related Documentation

| Document | Purpose |
|----------|---------|
| [Issuer Guide](../Issuer_Guide.md) | How to become an issuer |
| [Issuer Integration](../../protocol/Issuer_Integration.md) | Protocol integration patterns |
| [Holder Experience](../Holder_Experience.md) | User journey |
