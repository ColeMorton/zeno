# Medallion Visual Architecture

> **Version:** 1.0
> **Status:** Draft
> **Last Updated:** 2025-12-28

The foundational visual metaphor for Achievement NFTs: physical medallions with progressive embellishment based on holder wealth tier.

---

## Philosophy

### The Medallion Metaphor

Medallions are physical markers of achievement—struck in metal, worn on chains, displayed with pride. They carry weight both literal and symbolic. When you hold a medallion, you hold proof of something earned.

This NFT system translates that metaphor to the blockchain with a key insight: the **essence** of a medallion (what it represents) can be separated from its **ornamentation** (how elaborately it's displayed).

### Progressive Embellishment

Not all medallions are equal. A bronze medal and a gold medal represent the same category of achievement but signal different levels of investment. Similarly, our visual system layers embellishment onto a core visual based on the holder's wealth percentile.

The core visual—what distinguishes one achievement from another—remains constant. The frame, background, hoop, and chain that surround it grow more elaborate as collateral increases.

### Permanence Gradient

This architecture creates a deliberate permanence gradient:

| Layer | Storage | Permanence |
|-------|---------|------------|
| Core visual (Tier 0) | On-chain SVG | Eternal (blockchain survival) |
| Medallion elements (Bronze–Diamond) | IPFS/Arweave | Long-term (economic incentives) |

The most essential element—what makes each achievement recognizable—lives on-chain. The ornamental layers that reflect wealth status live off-chain, where storage is abundant and inexpensive.

If off-chain storage eventually decays, the core visual survives. The essence remains even if the embellishment fades.

---

## Tier 0: The Blueprint

Tier 0 Achievement NFTs are **on-chain blueprints**—the minimal visual content required to distinguish one achievement from another.

### Design Constraints

| Constraint | Value | Rationale |
|------------|-------|-----------|
| File size | ~8KB max | On-chain storage efficiency |
| Canvas | 400×400 viewBox | Consistent composition |
| Colors | 6-8 unique | Visual clarity |
| Paths | <100 total | Render performance |

### What's Included

- **Distinguishing icon/symbol**: The visual element unique to this achievement type
- **Minimal background**: Simple dark circle (#0d0d14)
- **Border gradient**: BTC Orange to Gold (protocol identity)
- **Soulbound indicator**: X-mark showing non-transferability
- **Typography**: Achievement name

### What's Excluded

These elements appear only in Bronze tier and above:

- Ornate decorative frame
- Radial or animated background
- Hoop attachment point
- Chain or ribbon elements
- Tier-specific color treatments

### Current Implementation

8 achievements implemented, all under 8KB:

| Achievement | Size | Core Visual |
|-------------|------|-------------|
| MINTER | ~3KB | Vault icon with entry arrow |
| MATURED | ~3KB | Star with completion dots |
| HODLER_SUPREME | ~5KB | Eight-pointed crystal formation |
| FIRST_MONTH | ~3KB | Ring 1/12 filled |
| QUARTER_STACK | ~3KB | Ring 3/12 filled |
| HALF_YEAR | ~3KB | Ring 6/12 filled |
| ANNUAL | ~3KB | Ring 12/12 filled |
| DIAMOND_HANDS | ~4KB | Double rings + diamond |

---

## Display Tier Medallion Progression

Medallion embellishment corresponds to the wealth-based Display Tier system. As collateral percentile increases, more medallion layers appear.

### Tier Breakdown

```
Tier 0 (On-Chain)          Bronze              Silver              Gold
┌─────────────┐         ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│             │         │ ░░░░░░░░░░░ │     │ ▒▒▒▒▒▒▒▒▒▒▒ │     │      ○      │
│             │         │ ░┌───────┐░ │     │ ▒┌───────┐▒ │     │   ┌──┴──┐   │
│   [core]    │    →    │ ░│ core  │░ │  →  │ ▒│ core  │▒ │  →  │   │ core │   │
│             │         │ ░└───────┘░ │     │ ▒└───────┘▒ │     │   └─────┘   │
│             │         │ ░░░░░░░░░░░ │     │ ▒▒▒▒▒▒▒▒▒▒▒ │     │ ╔═════════╗ │
└─────────────┘         └─────────────┘     └─────────────┘     └─────────────┘
  Blueprint              + background        + detailed          + hoop
                         + minimal frame       frame             + ornate frame


    Platinum                   Diamond
┌─────────────┐         ┌─────────────┐
│    ╭─╮      │         │    ╭─╮ ~~~~ │
│    │○│      │         │    │○│      │
│ ┌──┴─┴──┐   │         │ ╔══╧═╧══╗   │
│ │◆ core◆│   │         │ ║◆ core◆║   │
│ └───────┘   │         │ ╚═══════╝   │
│ ╔═════════╗ │         │ ≈≈≈≈≈≈≈≈≈≈≈ │
└─────────────┘         └─────────────┘
  + chain                 + animated chain
  + elaborate frame       + crystalline frame
  + refined bg            + prismatic bg
```

### Layer Matrix

| Layer | Tier 0 | Bronze | Silver | Gold | Platinum | Diamond |
|-------|--------|--------|--------|------|----------|---------|
| Core visual | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Background | — | Simple | Subtle | Radiant | Refined | Prismatic |
| Frame | — | Minimal | Detailed | Ornate | Elaborate | Crystalline |
| Hoop | — | — | — | Simple | Detailed | Complete |
| Chain | — | — | — | — | Static | Animated |

### Percentile Thresholds

| Tier | Percentile Range | Collateral Context |
|------|-----------------|-------------------|
| Bronze | 0–50th | Entry-level collectors |
| Silver | 50–75th | Established holders |
| Gold | 75–90th | Significant commitment |
| Platinum | 90–99th | Top 10% by collateral |
| Diamond | 99th+ | Top 1% elite |

---

## Visual Specifications

### Medallion Proportions

```
┌────────────────────────────────────┐
│              chain                 │
│                │                   │
│            ┌───┴───┐               │
│            │ hoop  │ ← 10% height  │
│            └───┬───┘               │
│         ┌─────────────┐            │
│         │    frame    │            │
│         │  ┌───────┐  │ ← 15% frame│
│         │  │ core  │  │   width    │
│         │  │       │  │            │
│         │  └───────┘  │            │
│         └─────────────┘            │
│                                    │
│            background              │
└────────────────────────────────────┘

Total canvas: 512×512 (off-chain)
Core visual: 300×300 (centered)
Frame width: 15% of canvas
Hoop: 10% of canvas height
```

### Frame Design by Tier

**Bronze**
- Single-stroke border
- Solid bronze color (#cd7f32)
- No ornamentation
- 2px stroke width

**Silver**
- Double-stroke border
- Silver gradient (#a8a8a8 → #e0e0e0)
- Subtle beveled edge effect
- 3px stroke width

**Gold**
- Triple-stroke border
- Gold gradient (#ffd700 → #ffecb3)
- Decorative corner flourishes
- Inner glow effect
- 4px stroke width

**Platinum**
- Faceted border segments
- Refined gradient (#E5E4E2 → #F0F0EE)
- Subtle shimmer effects
- Metallic highlights
- 5px stroke width

**Diamond**
- Crystalline gradient (#E8F4FF → #FFFFFF)
- Animated prismatic cycle (8s loop)
- Light refraction effects
- Subtle outer glow pulse
- 6px stroke width

### Background Design by Tier

**Bronze**: Solid dark with 5% lighter center
**Silver**: Radial gradient, subtle rays
**Gold**: Pronounced radial rays, warm glow center
**Platinum**: Refined metallic facets, elegant aesthetic
**Diamond**: Animated prismatic effect, slow-moving crystalline waves

### Hoop & Chain Specifications

**Gold Hoop**
- Simple ring, 40px diameter
- Gold color matching frame
- No chain attached

**Platinum Hoop + Chain**
- Detailed ring with inner bevel, 50px diameter
- 5 chain links visible
- Static positioning
- Diamond-tone metallic

**Diamond Hoop + Chain**
- Complete decorative ring, 60px diameter
- 8+ chain links extending upward
- Subtle sway animation (3s loop)
- Crystalline metallic matching frame

### Color Palette

| Element | Bronze | Silver | Gold | Platinum | Diamond |
|---------|--------|--------|------|----------|---------|
| Primary | #CD7F32 | #C0C0C0 | #FFD700 | #E5E4E2 | #E8F4FF |
| Secondary | #A0522D | #A8A8A8 | #FFECB3 | #F0F0EE | #FFFFFF |
| Glow | — | — | #FFF8DC | #F5F5F3 | Animated |

### Animation Standards

All animations respect `prefers-reduced-motion`:

```css
@media (prefers-reduced-motion: reduce) {
  * { animation: none !important; }
}
```

| Tier | Animated Elements |
|------|-------------------|
| Bronze–Gold | None (static) |
| Platinum | Optional shimmer (subtle) |
| Diamond | Background + chain + frame glow |

Animation timing:
- Background aurora: 8s loop
- Chain sway: 3s loop
- Frame glow pulse: 4s loop

---

## Composition Architecture

### On-Chain to Off-Chain Relationship

The off-chain medallion **wraps** the on-chain core:

```
Off-Chain Medallion (IPFS/Arweave)
├── Chain layer (topmost, Diamond only)
├── Hoop layer (Gold+)
├── Frame layer
├── Core visual ← referenced from on-chain
└── Background layer (bottommost)
```

### Reference Method

Off-chain metadata includes a pointer to the on-chain SVG:

```json
{
  "name": "MINTER Achievement - Diamond Tier",
  "image": "ipfs://Qm.../diamond-minter.svg",
  "on_chain_core": {
    "contract": "0x...",
    "tokenId": 1,
    "method": "tokenURI"
  },
  "tier": "diamond",
  "layers": ["background", "frame", "hoop", "chain"]
}
```

### Composition Process

1. Fetch on-chain core SVG via contract call
2. Extract core visual elements (ignoring Tier 0 background/border)
3. Compose into off-chain medallion template
4. Apply tier-appropriate layers
5. Store composed result on IPFS/Arweave

---

## Implementation Path

### Current State

- **Tier 0**: Complete. 8 achievements on-chain, 2-5KB each.
- **Bronze–Diamond**: Not implemented. Specification only.

### Future Implementation

1. **Design medallion layers** (SVG templates for each tier)
2. **Build composition service** (combines core + layers)
3. **Deploy to IPFS/Arweave** (off-chain storage)
4. **Update metadata resolver** (return tier-appropriate image)

### Storage Strategy

| Layer | Storage | Pinning |
|-------|---------|---------|
| Core (Tier 0) | On-chain | N/A (permanent) |
| Templates | IPFS + Arweave | Pinata + Arweave |
| Composed results | IPFS | CDN-backed |

---

## Summary

The medallion architecture separates **essence** from **ornamentation**:

- **Tier 0 (On-Chain)**: The permanent, minimal core—what makes each achievement recognizable
- **Bronze–Diamond (Off-Chain)**: Progressive embellishment that reflects holder wealth tier

This creates a visual language where:
- Every holder sees the same core achievement identity
- Wealthier holders display more elaborate medallion treatments
- The core survives even if off-chain storage degrades
- Visual progression incentivizes collateral accumulation

The medallion metaphor grounds abstract blockchain achievements in a familiar physical artifact: something earned, displayed, and worn with pride.
