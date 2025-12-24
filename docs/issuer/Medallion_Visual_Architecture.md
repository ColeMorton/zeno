# Medallion Visual Architecture

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
| Medallion elements (Bronze–Whale) | IPFS/Arweave | Long-term (economic incentives) |

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


    Diamond                    Whale
┌─────────────┐         ┌─────────────┐
│    ╭─╮      │         │    ╭─╮ ~~~~ │
│    │○│      │         │    │○│      │
│ ┌──┴─┴──┐   │         │ ╔══╧═╧══╗   │
│ │◆ core◆│   │         │ ║◆ core◆║   │
│ └───────┘   │         │ ╚═══════╝   │
│ ╔═════════╗ │         │ ≈≈≈≈≈≈≈≈≈≈≈ │
└─────────────┘         └─────────────┘
  + chain                 + animated chain
  + elaborate frame       + iridescent frame
  + crystalline bg        + animated bg
```

### Layer Matrix

| Layer | Tier 0 | Bronze | Silver | Gold | Diamond | Whale |
|-------|--------|--------|--------|------|---------|-------|
| Core visual | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Background | — | Simple | Subtle | Radiant | Crystalline | Animated |
| Frame | — | Minimal | Detailed | Ornate | Elaborate | Iridescent |
| Hoop | — | — | — | Simple | Detailed | Complete |
| Chain | — | — | — | — | Static | Animated |

### Percentile Thresholds

| Tier | Percentile Range | Collateral Context |
|------|-----------------|-------------------|
| Bronze | 0–50th | Entry-level collectors |
| Silver | 50–75th | Established holders |
| Gold | 75–90th | Significant commitment |
| Diamond | 90–99th | Top 10% by collateral |
| Whale | 99th+ | Top 1% elite |

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

**Diamond**
- Faceted border segments
- Crystalline gradient (#b9f2ff → #ffffff)
- Light refraction effects
- Sparkle points at vertices
- 5px stroke width

**Whale**
- Iridescent gradient (shifting hues)
- Animated color cycle (8s loop)
- Particle effects
- Subtle outer glow pulse
- 6px stroke width

### Background Design by Tier

**Bronze**: Solid dark with 5% lighter center
**Silver**: Radial gradient, subtle rays
**Gold**: Pronounced radial rays, warm glow center
**Diamond**: Crystalline facets, cold/pure aesthetic
**Whale**: Animated aurora effect, slow-moving color waves

### Hoop & Chain Specifications

**Gold Hoop**
- Simple ring, 40px diameter
- Gold color matching frame
- No chain attached

**Diamond Hoop + Chain**
- Detailed ring with inner bevel, 50px diameter
- 5 chain links visible
- Static positioning
- Diamond-tone metallic

**Whale Hoop + Chain**
- Complete decorative ring, 60px diameter
- 8+ chain links extending upward
- Subtle sway animation (3s loop)
- Iridescent metallic matching frame

### Color Palette

| Element | Bronze | Silver | Gold | Diamond | Whale |
|---------|--------|--------|------|---------|-------|
| Primary | #cd7f32 | #c0c0c0 | #ffd700 | #b9f2ff | Iridescent |
| Secondary | #a0522d | #a8a8a8 | #ffecb3 | #ffffff | Shifting |
| Glow | — | — | #fff8dc | #e0ffff | Animated |

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
| Diamond | Optional sparkle (subtle) |
| Whale | Background + chain + frame glow |

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
├── Chain layer (topmost, Whale only)
├── Hoop layer (Gold+)
├── Frame layer
├── Core visual ← referenced from on-chain
└── Background layer (bottommost)
```

### Reference Method

Off-chain metadata includes a pointer to the on-chain SVG:

```json
{
  "name": "MINTER Achievement - Whale Tier",
  "image": "ipfs://Qm.../whale-minter.svg",
  "on_chain_core": {
    "contract": "0x...",
    "tokenId": 1,
    "method": "tokenURI"
  },
  "tier": "whale",
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
- **Bronze–Whale**: Not implemented. Specification only.

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
- **Bronze–Whale (Off-Chain)**: Progressive embellishment that reflects holder wealth tier

This creates a visual language where:
- Every holder sees the same core achievement identity
- Wealthier holders display more elaborate medallion treatments
- The core survives even if off-chain storage degrades
- Visual progression incentivizes collateral accumulation

The medallion metaphor grounds abstract blockchain achievements in a familiar physical artifact: something earned, displayed, and worn with pride.
