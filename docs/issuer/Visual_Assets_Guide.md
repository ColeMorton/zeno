# Visual Assets Guide

> **Version:** 1.0
> **Status:** Draft
> **Last Updated:** 2025-12-22
> **Related Documents:**
> - [Pixel Art Guide](./Pixel_Art_Guide.md) - Raster/off-chain pixel art standards
> - [NFT Artwork Creation](./NFT_Artwork_Creation.md) - AI-assisted artwork workflow
> - [Achievements Specification](./Achievements_Specification.md)
> - [Vault Percentile Specification](./Vault_Percentile_Specification.md)
> - [Integration Guide](./Integration_Guide.md)

---

This guide covers the complete visual asset requirements, SVG technical standards, and NFT metadata patterns for the BTCNFT Protocol. It serves as the authoritative reference for implementing on-chain and off-chain visual assets.

---

## Table of Contents

1. [Visual Asset Architecture](#1-visual-asset-architecture)
2. [Achievement Badge Visual System](#2-achievement-badge-visual-system)
3. [Display Tier Visual System](#3-display-tier-visual-system)
4. [SVG Technical Standards](#4-svg-technical-standards)
5. [NFT Metadata Standards](#5-nft-metadata-standards)
6. [Cross-Renderer Compatibility](#6-cross-renderer-compatibility)
7. [Color Palette Standards](#7-color-palette-standards)
8. [Implementation Roadmap](#8-implementation-roadmap)
9. [File Deliverables Checklist](#9-file-deliverables-checklist)

---

## 1. Visual Asset Architecture

### Current State Analysis

The BTCNFT Protocol uses a **hybrid on-chain/off-chain architecture**:

| Component | On-Chain | Off-Chain |
|-----------|----------|-----------|
| Vault state | Token data, timestamps, collateral | - |
| Achievement SVGs | Base64-encoded in bytecode | - |
| Pixel art | Packed bitmap + palette (2KB) | Preview SVGs |
| Treasure NFT art | - | IPFS/Arweave |
| Metadata URI | `baseTokenURI` reference | JSON generation |
| Tier calculation | Collateral amounts | Percentile computation |

**On-chain rendering is available** for Achievement badges (`AchievementSVG.sol`) and pixel art (`PixelArtRenderer.sol`).

### Token Taxonomy

```
┌─────────────────────────────────────────────────────────────────┐
│                     VISUAL TOKEN HIERARCHY                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  TIER 0: Achievement NFT (Soulbound ERC-5192)                   │
│  └─ Base visual vocabulary, merit-based, simplest SVG           │
│                                                                  │
│  TIER 1: Treasure NFT (ERC-721)                                 │
│  └─ Issuer art with percentile-based display tier frames        │
│                                                                  │
│  TIER 2: Vault NFT (ERC-998 Composable)                         │
│  └─ Container displaying Treasure + collateral metadata         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Achievement Badge Visual System

### 2.1 Badge Categories & Visual Concepts

| Category | Visual Theme | Shape | Animation |
|----------|--------------|-------|-----------|
| **Lifecycle** | Growth/phases | Circle with segments | Pulse |
| **Duration** | Time rings | Concentric rings | Rotate |
| **Activity** | Action marks | Hexagon | Glow |
| **Social** | Connection | Linked nodes | Fade |
| **Collection** | Multiples | Stacked shapes | Stack |
| **Campaign** | Limited edition | Shield | Shimmer |

### 2.2 Implemented Achievement Badges

```
┌─────────────────────────────────────────────────────────────────┐
│                    CORE ACHIEVEMENT BADGES                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  MINTER                    MATURED                               │
│  ┌───────────┐             ┌───────────┐                         │
│  │    ●      │             │   ★       │                         │
│  │   /│\     │             │  /│\      │                         │
│  │  Entry    │             │ Complete  │                         │
│  └───────────┘             └───────────┘                         │
│  First vault created       Vault vested + match claimed          │
│                                                                  │
│  HODLER_SUPREME                                                  │
│  ┌───────────┐                                                   │
│  │   ◆◆◆     │                                                   │
│  │  Supreme  │                                                   │
│  │  Diamond  │                                                   │
│  └───────────┘                                                   │
│  Composite: MINTER + MATURED                                     │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                   DURATION ACHIEVEMENT BADGES                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  FIRST_MONTH (30d)         QUARTER_STACK (91d)                  │
│  ┌───────────┐             ┌───────────┐                         │
│  │  ○───     │             │  ○═══     │                         │
│  │  1/12     │             │  3/12     │                         │
│  └───────────┘             └───────────┘                         │
│                                                                  │
│  HALF_YEAR (182d)          ANNUAL (365d)                        │
│  ┌───────────┐             ┌───────────┐                         │
│  │  ◐        │             │  ●        │                         │
│  │  6/12     │             │  12/12    │                         │
│  └───────────┘             └───────────┘                         │
│                                                                  │
│  DIAMOND_HANDS (730d)                                            │
│  ┌───────────┐                                                   │
│  │   ◇◇◇     │                                                   │
│  │  2 YEARS  │                                                   │
│  └───────────┘                                                   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 2.3 Soulbound Visual Indicators

Achievement badges must visually communicate non-transferability:

| State | Visual Treatment |
|-------|------------------|
| **Earned** | Full color, active animation, solid outline |
| **Locked** | Grayscale, static, dashed outline, lock icon overlay |
| **Soul-Bound Mark** | Subtle chain link or anchor symbol in corner |

### 2.4 Badge SVG Template

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">
  <title>Achievement: [NAME]</title>
  <desc>Earned for [DESCRIPTION]</desc>

  <!-- Soulbound indicator -->
  <g class="soulbound-mark" transform="translate(340, 20)">
    <circle r="15" fill="#1a1a2e" stroke="#f7931a"/>
    <path d="M-5,-5 L5,5 M-5,5 L5,-5" stroke="#f7931a" stroke-width="2"/>
  </g>

  <!-- Background -->
  <circle cx="200" cy="200" r="180" fill="#0d0d14"/>

  <!-- Category ring -->
  <circle cx="200" cy="200" r="170" fill="none"
          stroke="url(#category-gradient)" stroke-width="4"/>

  <!-- Achievement icon placeholder -->
  <g class="achievement-icon" transform="translate(200, 200)">
    <!-- Icon paths here -->
  </g>

  <!-- Achievement name -->
  <text x="200" y="350" text-anchor="middle"
        font-family="monospace" font-size="24" fill="#ffffff">
    [ACHIEVEMENT_NAME]
  </text>

  <!-- CSS Animation -->
  <style>
    @media (prefers-reduced-motion: no-preference) {
      .achievement-icon { animation: pulse 2s ease-in-out infinite; }
    }
    @keyframes pulse {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.7; }
    }
  </style>

  <defs>
    <linearGradient id="category-gradient" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#f7931a"/>
      <stop offset="100%" stop-color="#ffcd00"/>
    </linearGradient>
  </defs>
</svg>
```

---

## 3. Display Tier Visual System

### 3.1 Tier Definitions

| Tier | Percentile | Frame Color | Effects |
|------|------------|-------------|---------|
| **Diamond** | 99th+ | `#E8F4FF` | Crystalline frame + prismatic animation |
| **Platinum** | 90-99th | `#E5E4E2` | Platinum frame + shimmer |
| **Gold** | 75-90th | `#FFD700` | Subtle gold shimmer |
| **Silver** | 50-75th | `#C0C0C0` | Clean metallic |
| **Bronze** | 0-50th | `#CD7F32` | Standard frame |

### 3.2 Tier Frame Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    TIER FRAME STRUCTURE                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ ┌────────────────────────────────────────────────────────┐ │ │
│  │ │ OUTER GLOW (Diamond/Platinum only)                      │ │ │
│  │ │ ┌────────────────────────────────────────────────────┐ │ │ │
│  │ │ │ TIER FRAME (color by tier)                         │ │ │ │
│  │ │ │ ┌────────────────────────────────────────────────┐ │ │ │ │
│  │ │ │ │                                                │ │ │ │ │
│  │ │ │ │           TREASURE NFT ARTWORK                 │ │ │ │ │
│  │ │ │ │           (Issuer's art)                       │ │ │ │ │
│  │ │ │ │                                                │ │ │ │ │
│  │ │ │ └────────────────────────────────────────────────┘ │ │ │ │
│  │ │ │ TIER BADGE (corner) ◆                              │ │ │ │
│  │ │ └────────────────────────────────────────────────────┘ │ │ │
│  │ └────────────────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 3.3 Frame SVG Template

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 500 500">
  <title>Treasure NFT with [TIER] Frame</title>

  <!-- Outer glow (Diamond/Platinum only) -->
  <filter id="tier-glow">
    <feGaussianBlur stdDeviation="8" result="blur"/>
    <feMerge>
      <feMergeNode in="blur"/>
      <feMergeNode in="SourceGraphic"/>
    </feMerge>
  </filter>

  <!-- Frame background -->
  <rect x="10" y="10" width="480" height="480" rx="24"
        fill="url(#tier-frame-gradient)" filter="url(#tier-glow)"/>

  <!-- Inner content area (Treasure art goes here) -->
  <rect x="30" y="30" width="440" height="440" rx="16" fill="#0d0d14"/>
  <image x="30" y="30" width="440" height="440"
         href="[TREASURE_IMAGE_URI]" preserveAspectRatio="xMidYMid slice"/>

  <!-- Tier badge -->
  <g class="tier-badge" transform="translate(440, 60)">
    <polygon points="0,-25 22,-8 14,20 -14,20 -22,-8"
             fill="url(#tier-badge-gradient)"/>
    <text y="8" text-anchor="middle" font-size="16" fill="#000">
      [TIER_ICON]
    </text>
  </g>

  <defs>
    <!-- Gold tier gradient example -->
    <linearGradient id="tier-frame-gradient" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#ffd700"/>
      <stop offset="50%" stop-color="#ffec8b"/>
      <stop offset="100%" stop-color="#ffd700"/>
    </linearGradient>

    <linearGradient id="tier-badge-gradient" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#ffd700"/>
      <stop offset="100%" stop-color="#b8860b"/>
    </linearGradient>
  </defs>
</svg>
```

---

## 4. SVG Technical Standards

### 4.1 On-Chain Constraints

| Constraint | Limit | Rationale |
|------------|-------|-----------|
| **Contract size** | < 24KB | Ethereum hard limit |
| **Individual SVG** | < 8KB recommended | Headroom for multiple assets |
| **Base64 size** | < 32KB | Contract storage limits |
| **Path complexity** | < 500 points per path | Render performance |
| **Total paths** | < 100 | File size |
| **Colors** | 6-8 unique | Visual clarity, smaller palette |
| **Animation** | CSS only (no SMIL) | Wallet compatibility |
| **External refs** | None | On-chain completeness |

#### 4.1.1 Understanding Storage Gas Costs

**Storage Pattern Distinction:**

| Pattern | When Gas Paid | SVG Size Impact on Mint |
|---------|---------------|-------------------------|
| **Bytecode storage** (library) | Contract deployment (once) | None |
| **State storage** (per-token) | Every mint | ~20,000 gas per 32 bytes |

This protocol uses **bytecode storage** - SVGs are hardcoded in `AchievementSVG.sol` and retrieved via `pure` functions. Gas implications:

- **Deployment**: ~200 gas per byte of bytecode (one-time)
- **Per-mint**: Zero additional cost for SVG data
- **Per-transfer**: Zero (also soulbound)
- **tokenURI read**: Free (view function)

**Example costs at 30 gwei, $3,500 ETH:**

| SVG Size | Deployment Gas | One-Time Cost |
|----------|----------------|---------------|
| 4KB | ~800,000 | ~$84 |
| 8KB | ~1,600,000 | ~$168 |
| 16KB | ~3,200,000 | ~$336 |

**The Real Constraint**: Ethereum's 24KB contract size limit. With 8 achievement types at 3-4KB each, keeping individual SVGs small leaves room for contract logic.

**Guideline Tiers:**

| Individual SVG | Recommendation |
|----------------|----------------|
| < 8KB | Ideal - comfortable headroom |
| 8-16KB | Acceptable - monitor total contract size |
| > 16KB | Split into multiple library contracts |

### 4.1.2 On-Chain Pixel Art Storage

For pixel art, raw SVG storage is inefficient (~50 bytes per pixel). The protocol uses **packed indexed bitmaps**:

```
┌─────────────────────────────────────────────────────────────┐
│  On-Chain Storage (PixelArtRenderer Pattern)                │
├─────────────────────────────────────────────────────────────┤
│  Palette: 48 bytes (16 colors × 3 bytes RGB)                │
│  Bitmap:  2,048 bytes (64×64 pixels × 4 bits)               │
│  Total:   2,096 bytes (42x smaller than raw SVG)            │
└─────────────────────────────────────────────────────────────┘
```

**Storage Format:**
- **4-bit indexed color**: Each pixel is 0-15, packed 2 pixels per byte
- **Index 0 = transparent**: Skipped during SVG generation
- **16-color palette**: RGB values stored as 48 bytes

**Rendering Flow:**
```solidity
// Stored as packed binary (2KB)
function getBitmap() returns (bytes memory);
function getPalette() returns (bytes memory);

// Rendered on-demand (free to call)
function getSVG() returns (string memory);     // Returns full SVG
function getDataURI() returns (string memory); // Returns base64 data URI
```

**Compression Comparison:**

| Format | 64×64 Pixel Art | Compression |
|--------|-----------------|-------------|
| Raw SVG (~50 bytes/pixel) | ~80 KB | 1x |
| Packed bitmap (0.5 bytes/pixel) | 2 KB | **40x** |

**Implementation**: `contracts/issuer/src/PixelArtRenderer.sol`

### 4.2 SVG Optimization Checklist

```
□ Remove editor metadata (Illustrator, Inkscape artifacts)
□ Remove comments and unnecessary whitespace
□ Simplify paths (reduce Bezier control points)
□ Merge overlapping shapes where possible
□ Use <use> for repeated elements
□ Use <symbol> for reusable components
□ Convert strokes to fills (if smaller)
□ Remove hidden/clipped elements
□ Optimize viewBox (remove excess padding)
□ Minify IDs to single characters
□ Use hex colors instead of named colors
□ Remove default attribute values
□ Use path shorthand commands (h, v, s, t)
□ Round decimal values to 2 places max
```

### 4.3 SVGO Configuration

```javascript
// svgo.config.js - Recommended settings for on-chain SVG
module.exports = {
  multipass: true,
  plugins: [
    'preset-default',
    'removeDimensions',
    'removeXMLNS',
    { name: 'removeAttrs', params: { attrs: ['data-*'] } },
    { name: 'cleanupNumericValues', params: { floatPrecision: 2 } },
    { name: 'convertPathData', params: { floatPrecision: 2 } },
    'reusePaths',
    'convertStyleToAttrs',
    'removeUnknownsAndDefaults',
    'removeUselessStrokeAndFill'
  ]
};
```

### 4.4 Base64 Encoding for On-Chain

```javascript
// Convert SVG to data URI for on-chain storage
function svgToDataUri(svgString) {
  const encoded = Buffer.from(svgString).toString('base64');
  return `data:image/svg+xml;base64,${encoded}`;
}

// Estimate gas cost (rough calculation)
function estimateStorageGas(dataUri) {
  const bytes = Buffer.byteLength(dataUri, 'utf8');
  // ~20,000 gas per 32 bytes of storage
  return Math.ceil(bytes / 32) * 20000;
}
```

---

## 5. NFT Metadata Standards

### 5.1 Achievement NFT Metadata

```json
{
  "name": "BTCNFT Achievement: Diamond Hands",
  "description": "Awarded for holding a vault for 730+ days. This soulbound token represents exceptional commitment to the BTCNFT Protocol.",
  "image": "data:image/svg+xml;base64,[BASE64_SVG]",
  "external_url": "https://btcnft.protocol/achievements/diamond-hands",
  "background_color": "0d0d14",
  "attributes": [
    {
      "trait_type": "Category",
      "value": "Duration"
    },
    {
      "trait_type": "Achievement",
      "value": "Diamond Hands"
    },
    {
      "trait_type": "Required Duration",
      "display_type": "number",
      "value": 730
    },
    {
      "trait_type": "Transferable",
      "value": "No (Soulbound)"
    },
    {
      "trait_type": "Earned At",
      "display_type": "date",
      "value": 1703980800
    }
  ]
}
```

### 5.2 Treasure NFT Metadata

```json
{
  "name": "Treasure #1234",
  "description": "A Treasure NFT wrapped within a BTCNFT Vault. Display tier reflects collateral percentile ranking.",
  "image": "[TREASURE_IMAGE_URI]",
  "external_url": "https://issuer.example/treasures/1234",
  "animation_url": "[OPTIONAL_ANIMATED_VERSION]",
  "background_color": "0d0d14",
  "attributes": [
    {
      "trait_type": "Collection",
      "value": "Issuer Genesis Collection"
    },
    {
      "trait_type": "Display Tier",
      "value": "Gold"
    },
    {
      "trait_type": "Percentile",
      "display_type": "number",
      "value": 82
    },
    {
      "trait_type": "Vault ID",
      "display_type": "number",
      "value": 5678
    }
  ]
}
```

### 5.3 Vault NFT Metadata

```json
{
  "name": "Vault #5678",
  "description": "BTCNFT Protocol Vault containing Treasure #1234 with 0.5 BTC collateral.",
  "image": "[COMPOSITE_IMAGE_URI]",
  "external_url": "https://btcnft.protocol/vaults/5678",
  "attributes": [
    {
      "trait_type": "Collateral Amount",
      "display_type": "number",
      "value": 0.5
    },
    {
      "trait_type": "Collateral Token",
      "value": "WBTC"
    },
    {
      "trait_type": "Treasure Contract",
      "value": "0x1234...abcd"
    },
    {
      "trait_type": "Treasure ID",
      "display_type": "number",
      "value": 1234
    },
    {
      "trait_type": "Vesting Status",
      "value": "Vesting"
    },
    {
      "trait_type": "Days Until Vested",
      "display_type": "number",
      "value": 847
    },
    {
      "trait_type": "Display Tier",
      "value": "Gold"
    },
    {
      "trait_type": "Percentile Rank",
      "display_type": "number",
      "value": 82
    }
  ]
}
```

---

## 6. Cross-Renderer Compatibility

### 6.1 Testing Matrix

| Renderer | SVG 1.1 | SVG 2.0 | CSS Anim | SMIL | Notes |
|----------|---------|---------|----------|------|-------|
| OpenSea | ✓ | Partial | ✓ | ✗ | Strict CSP |
| Blur | ✓ | ✓ | ✓ | ✗ | Good support |
| Etherscan | ✓ | ✗ | ✗ | ✗ | Static only |
| MetaMask | ✓ | ✗ | ✗ | ✗ | Static only |
| Rainbow | ✓ | Partial | ✓ | ✗ | Mobile-focused |
| Chrome | ✓ | ✓ | ✓ | ✓ | Full support |
| Firefox | ✓ | ✓ | ✓ | ✓ | Full support |
| Safari | ✓ | ✓ | ✓ | Partial | iOS quirks |

### 6.2 Safe SVG Features

**Always Safe:**
- Basic shapes (rect, circle, ellipse, line, polygon, polyline, path)
- Fill and stroke attributes
- Linear and radial gradients
- ClipPath and mask (simple)
- Text (without external fonts)
- Transform (translate, scale, rotate)
- ViewBox

**Use with Caution:**
- CSS animations (test thoroughly)
- Filters (blur, shadow - performance impact)
- Patterns (some renderers struggle)
- Foreign object (avoid)

**Avoid:**
- SMIL animations
- External resources (fonts, images)
- JavaScript
- Complex filter chains

### 6.3 Graceful Degradation

```svg
<!-- Animation with graceful degradation -->
<style>
  /* Animation only when supported and preferred */
  @media (prefers-reduced-motion: no-preference) {
    .animated {
      animation: glow 2s ease-in-out infinite;
    }
  }

  @keyframes glow {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.8; }
  }
</style>

<!-- Static fallback is the default state -->
<circle class="animated" cx="100" cy="100" r="50" fill="#ffd700"/>
```

---

## 7. Color Palette Standards

### 7.1 Protocol Colors

| Name | Hex | RGB | Usage |
|------|-----|-----|-------|
| BTC Orange | `#f7931a` | 247, 147, 26 | Primary brand, BTC elements |
| BTC Gold | `#ffcd00` | 255, 205, 0 | Accents, highlights |
| Vault Dark | `#0d0d14` | 13, 13, 20 | Backgrounds |
| Vault Surface | `#1a1a2e` | 26, 26, 46 | Cards, containers |
| Text Primary | `#ffffff` | 255, 255, 255 | Headlines |
| Text Secondary | `#a0a0b0` | 160, 160, 176 | Body text |

### 7.2 Tier Colors

| Tier | Primary | Gradient Start | Gradient End |
|------|---------|----------------|--------------|
| Diamond | `#E8F4FF` | `#D0E8FF` | `#F0F8FF` |
| Platinum | `#E5E4E2` | `#D8D8D6` | `#F0F0EE` |
| Gold | `#FFD700` | `#FFEC8B` | `#B8860B` |
| Silver | `#C0C0C0` | `#E0E0E0` | `#808080` |
| Bronze | `#CD7F32` | `#DAA520` | `#8B4513` |

### 7.3 Achievement Category Colors

| Category | Primary | Accent |
|----------|---------|--------|
| Lifecycle | `#4ade80` | `#22c55e` |
| Duration | `#60a5fa` | `#3b82f6` |
| Activity | `#f472b6` | `#ec4899` |
| Social | `#a78bfa` | `#8b5cf6` |
| Collection | `#fbbf24` | `#f59e0b` |
| Campaign | `#f87171` | `#ef4444` |

---

## 8. Implementation Roadmap

### Phase 1: Achievement Badge Library
1. Design base badge template (SVG)
2. Create category-specific icon sets
3. Implement duration progression ring system
4. Add soulbound visual indicators
5. Optimize all badges for on-chain (< 8KB each)

### Phase 2: Tier Frame System
1. Design 5 tier frame variants
2. Create frame overlay compositing logic
3. Implement dynamic badge positioning
4. Add tier-specific animations
5. Build frame application service

### Phase 3: Metadata Service
1. Define metadata generation endpoints
2. Implement percentile calculation service
3. Build dynamic image composition
4. Add caching layer for tier frames
5. Deploy indexer for vault state

### Phase 4: Renderer Testing
1. Create test suite for all renderers
2. Document compatibility issues
3. Implement fallbacks where needed
4. Validate across wallet providers

---

## 9. File Deliverables Checklist

```
□ Achievement Badges (SVG)
  □ MINTER badge
  □ MATURED badge
  □ HODLER_SUPREME badge
  □ FIRST_MONTH badge
  □ QUARTER_STACK badge
  □ HALF_YEAR badge
  □ ANNUAL badge
  □ DIAMOND_HANDS badge

□ Tier Frames (SVG)
  □ Bronze frame
  □ Silver frame
  □ Gold frame
  □ Platinum frame
  □ Diamond frame

□ Design System
  □ Color palette documentation
  □ Typography guidelines
  □ Spacing system
  □ Icon library

□ Technical Assets
  □ SVGO configuration
  □ Base64 encoding utilities
  □ Metadata JSON schemas
  □ Renderer test harness
```

---

## Related Documents

| Document | Purpose |
|----------|---------|
| [NFT Artwork Creation](./NFT_Artwork_Creation.md) | AI-assisted artwork workflow |
| [Achievements Specification](./Achievements_Specification.md) | Achievement taxonomy |
| [Vault Percentile Specification](./Vault_Percentile_Specification.md) | Tier calculation |
| [Integration Guide](./Integration_Guide.md) | Issuer implementation |
| [Technical Specification](../protocol/Technical_Specification.md) | Protocol mechanics |

---

*This guide establishes the visual standards for BTCNFT Protocol. All visual assets should conform to these specifications to ensure consistency, gas efficiency, and cross-platform compatibility.*

---

## Navigation

← [Issuer Layer](./README.md) | [Documentation Home](../README.md)
