# Pixel Art Guide

> **Version:** 1.0
> **Status:** Artist Guide
> **Last Updated:** 2025-12-28
> **Related Documents:**
> - [Visual Assets Guide](./Visual_Assets_Guide.md)
> - [NFT Artwork Creation](./NFT_Artwork_Creation.md) - AI-assisted artwork workflow
> - [Achievement NFT Visual Implementation](./Achievement_NFT_Visual_Implementation.md)
> - [Integration Guide](./Integration_Guide.md)
> - [Vault Percentile Specification](./Vault_Percentile_Specification.md)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Pixel Art Fundamentals](#2-pixel-art-fundamentals)
3. [NFT-Specific Considerations](#3-nft-specific-considerations)
4. [Color Theory for Pixel Art](#4-color-theory-for-pixel-art)
5. [Technique and Style](#5-technique-and-style)
6. [Animation](#6-animation)
7. [Generative Pixel Art](#7-generative-pixel-art)
8. [Technical Standards](#8-technical-standards)
9. [Tools and Workflows](#9-tools-and-workflows)
10. [Quality Checklist](#10-quality-checklist)
11. [Integration with BTCNFT Protocol](#11-integration-with-btcnft-protocol)

---

## 1. Overview

This guide establishes standards for creating raster/off-chain pixel art assets for Treasure NFTs within the BTCNFT Protocol. It complements the [Visual Assets Guide](./Visual_Assets_Guide.md), which covers SVG/on-chain artwork for Achievement NFTs and tier frames.

### 1.1 Scope

| Aspect | SVG (On-Chain) | Pixel Art (Off-Chain) |
|--------|----------------|----------------------|
| **Storage** | Contract bytecode | IPFS/Arweave |
| **Format** | Vector (scalable) | Raster (fixed resolution) |
| **File Size** | 2-8KB typical | 5KB-5MB |
| **Animation** | CSS animations | GIF/APNG/WebP frames |
| **Best For** | Achievement badges, tier frames | Treasure NFT artwork, PFPs |
| **Editing** | Path manipulation | Pixel-by-pixel |

### 1.2 Why Pixel Art for NFTs

Pixel art has become a defining aesthetic of the NFT space:

- **Nostalgic Resonance**: Evokes early digital art and gaming culture
- **File Efficiency**: Small source files at low resolutions
- **Display Clarity**: Crisp visual identity at small display sizes
- **Generative Suitability**: Trait layering works naturally with pixel grids
- **Collectible Heritage**: Connects to CryptoPunks and foundational NFT collections

---

## 2. Pixel Art Fundamentals

### 2.1 Canvas Size Standards

| Canvas Size | Pixels | Use Case | Recommendation |
|-------------|--------|----------|----------------|
| 16x16 | 256 | Favicons, micro icons | On-chain consideration |
| 24x24 | 576 | CryptoPunks standard | Classic, high constraint |
| 32x32 | 1,024 | Enhanced detail | Retro aesthetic |
| **64x64** | **4,096** | **Primary standard** | **BTCNFT Protocol default** |
| 128x128 | 16,384 | High detail | Premium collections |
| 256x256 | 65,536 | Complex scenes | Background-heavy art |

**Protocol Standard: 64x64**

The 64x64 canvas provides optimal balance:
- Sufficient detail for character expression
- Clean upscaling to common display sizes (512x512, 1024x1024)
- Reasonable file sizes for IPFS storage
- Compatible with generative trait systems

### 2.2 Resolution Philosophy

At small scales, every pixel carries meaning. This constraint breeds intentional design:

```
64x64 = 4,096 decisions

Each pixel must justify its existence:
- Does it add to the silhouette?
- Does it communicate form or texture?
- Does it enhance readability?
```

**Pixel Density Zones:**

```
┌────────────────────────────────────────────┐
│                                            │
│    ┌────────────────────────────────┐      │
│    │                                │      │
│    │   ┌────────────────────┐      │      │
│    │   │   HIGH DENSITY     │      │      │
│    │   │   (face, key       │      │      │
│    │   │    features)       │      │      │
│    │   └────────────────────┘      │      │
│    │       MEDIUM DENSITY          │      │
│    │       (body, clothing)        │      │
│    └────────────────────────────────┘      │
│            LOW DENSITY                     │
│            (background, edges)             │
└────────────────────────────────────────────┘
```

### 2.3 Aspect Ratios

| Ratio | Use Case | Example Dimensions |
|-------|----------|-------------------|
| **1:1 (Square)** | PFP standard | 64x64, 128x128 |
| 16:9 | Banners, headers | 256x144, 512x288 |
| 4:3 | Collection cards | 128x96, 256x192 |
| 2:1 | Wide banners | 256x128, 512x256 |

### 2.4 The Pixel Grid

Pixel art operates on a strict grid with no interpolation between pixels:

```
Clean grid alignment:          Broken grid (avoid):

████████                       ███▓████
████████                       ██▓█████
████████                       █▓██████
████████                       ▓███████

Every pixel sits exactly       Misaligned elements create
on the grid intersection       visual noise
```

**Rules:**
- No fractional positioning
- Elements must align to pixel boundaries
- Rotation should only occur at 90-degree increments (or use pre-calculated rotations)

---

## 3. NFT-Specific Considerations

### 3.1 Platform Display Standards

| Platform | Display Size | Crop Shape | Source Recommendation |
|----------|--------------|------------|----------------------|
| Twitter/X | 400x400 | Circular | 64x64 upscaled 8x |
| Discord | 128x128 | Rounded square | 32x32 or 64x64 |
| OpenSea | 350x350 | Square | 64x64 minimum |
| Blur | 240x240 | Square | 64x64 minimum |
| MetaMask | 64x64 | Square | 32x32 or 64x64 |
| ENS Avatar | Variable | Circular | 64x64 recommended |
| Farcaster | 256x256 | Circular | 64x64 upscaled 4x |

### 3.2 Upscaling Rules

**Critical: Use NEAREST-NEIGHBOR interpolation exclusively**

| Method | Result | Use |
|--------|--------|-----|
| Nearest-Neighbor | Sharp pixel edges | ALWAYS |
| Bilinear | Blurry, muddy | NEVER |
| Bicubic | Smooth blur | NEVER |
| Lanczos | Soft edges | NEVER |

```
Correct upscaling:           Incorrect upscaling:

████████████████             ▓▓▓▓████████▓▓▓▓
████████████████             ▓▓██████████████▓▓
████████████████             ████████████████
████████████████     vs      ████████████████
████████████████             ████████████████
████████████████             ▓▓██████████████▓▓
████████████████             ▓▓▓▓████████▓▓▓▓

Nearest-neighbor             Bilinear (blur at edges)
```

**Standard Upscale Factors:**

| Source | Target | Factor | Use Case |
|--------|--------|--------|----------|
| 64x64 | 256x256 | 4x | Medium display |
| 64x64 | 512x512 | 8x | Standard delivery |
| 64x64 | 1024x1024 | 16x | Large display |
| 32x32 | 256x256 | 8x | Retro collections |

### 3.3 Circular Crop Safety

Most social platforms display profile pictures in circles:

```
64x64 canvas with circular crop zones:

          CLIPPED
        ┌────────┐
     ┌──┤        ├──┐
    ┌┘  │        │  └┐
    │   │ SAFE   │   │    Safe zone: inner 48x48
    │   │ ZONE   │   │    (75% of canvas)
    │   │        │   │
    └┐  │        │  ┌┘    Danger zone: outer 8px ring
     └──┤        ├──┘     (corners will be clipped)
        └────────┘
          CLIPPED
```

**Guidelines:**
- Keep critical features (eyes, key identifiers) within center 75%
- Avoid important details in corners
- Test with circular mask before finalizing
- Background elements can extend to edges

### 3.4 Storage Tradeoffs

| Storage | Type | Cost | Permanence | Speed |
|---------|------|------|------------|-------|
| **IPFS (pinned)** | Decentralized | $5-20/GB/year | Requires pinning | Fast CDN |
| **Arweave** | Permanent | ~$5/MB one-time | Truly permanent | Moderate |
| **AWS S3** | Centralized | $0.023/GB/month | Depends on payment | Fastest |
| **On-chain (base64)** | Fully decentralized | $500+/KB | Permanent | Slowest |

**BTCNFT Protocol Recommendation:**

| Priority | Storage | Content |
|----------|---------|---------|
| Primary | IPFS (Pinata + NFT.Storage) | All assets |
| Backup | Arweave | Metadata + rare artwork |
| CDN | Cloudflare | Cached composed images |

---

## 4. Color Theory for Pixel Art

### 4.1 Limited Palette Design

Constraint creates cohesion. Limit your palette intentionally:

| Palette Size | Complexity | File Size | Recommendation |
|--------------|------------|-----------|----------------|
| 4 colors | Minimal, iconic | Smallest | Badges, simple icons |
| 8 colors | Constrained | Very small | Classic retro |
| **16 colors** | **Balanced** | **Small** | **Standard PFP (recommended)** |
| 32 colors | Detailed | Medium | Premium collections |
| 64+ colors | High detail | Larger | Complex illustrations |

### 4.2 Protocol Color Integration

Integrate with the established BTCNFT Protocol palette:

**Core Protocol Colors:**

| Name | Hex | RGB | Pixel Art Usage |
|------|-----|-----|-----------------|
| BTC Orange | `#f7931a` | 247, 147, 26 | Primary accent, highlights |
| BTC Gold | `#ffcd00` | 255, 205, 0 | Secondary accent, shine |
| Vault Dark | `#0d0d14` | 13, 13, 20 | Deep shadows, backgrounds |
| Vault Surface | `#1a1a2e` | 26, 26, 46 | Mid shadows |
| White | `#ffffff` | 255, 255, 255 | Highlights, text |
| Text Secondary | `#a0a0b0` | 160, 160, 176 | Neutral tones |

**Tier Colors (for rarity indicators):**

| Tier | Primary | Light | Dark |
|------|---------|-------|------|
| Diamond | `#E8F4FF` | `#F0F8FF` | `#D0E8FF` |
| Platinum | `#E5E4E2` | `#F0F0EE` | `#D8D8D6` |
| Gold | `#FFD700` | `#FFEC8B` | `#B8860B` |
| Silver | `#C0C0C0` | `#E0E0E0` | `#808080` |
| Bronze | `#CD7F32` | `#DAA520` | `#8B4513` |

**Usage Rules:**
- Reserve BTC Orange for rare traits
- Tier colors indicate rarity alignment
- Vault Dark provides consistent shadow grounding

### 4.3 Color Ramp Construction

A color ramp creates depth through graduated shades:

```
5-step BTC Orange ramp:

Step 1 (Highlight): #ffc266  ░░░░
Step 2 (Light):     #ffab40  ▒▒▒▒
Step 3 (Base):      #f7931a  ████  ← Protocol color
Step 4 (Shadow):    #cc7000  ▓▓▓▓
Step 5 (Deep):      #994d00  ████
```

**Ramp Construction Rules:**
- Each step differs by 20-30% value
- Warm colors: shift toward yellow in highlights, red in shadows
- Cool colors: shift toward cyan in highlights, purple in shadows
- Maintain consistent hue shift direction

### 4.4 Dithering Techniques

Dithering creates gradients with limited colors:

| Pattern | Visual | Best For |
|---------|--------|----------|
| Checkerboard | 50% blend | Quick transitions |
| Ordered (Bayer) | Structured gradient | Smooth gradients |
| Noise | Random dots | Texture, metal |
| Horizontal lines | Scanline effect | Retro CRT aesthetic |

```
Checkerboard dithering (2 colors → perceived 3rd):

Color A    50% Mix      Color B

████████   █ █ █ █ █   ░░░░░░░░
████████   █ █ █ █     ░░░░░░░░
████████   █ █ █ █ █   ░░░░░░░░
████████   █ █ █ █     ░░░░░░░░

Solid      Dithered     Solid
Dark       Transition   Light
```

**When to Dither:**
- Smooth skin tones
- Sky gradients
- Metallic surfaces
- Avoiding banding in gradients

### 4.5 Readability at Small Sizes

At 64x64 (or smaller when displayed), contrast is critical:

```
High Contrast (readable):    Low Contrast (avoid):

████░░░░                     ████▓▓▓▓
████░░░░                     ████▓▓▓▓
████░░░░                     ████▓▓▓▓
████░░░░                     ████▓▓▓▓

Clear separation             Colors blend together
```

**Rules:**
- Adjacent areas need 30%+ value difference
- Avoid low-saturation colors next to each other
- Test at 1x scale (actual pixel size)
- Outline dark subjects on light backgrounds (and vice versa)

---

## 5. Technique and Style

### 5.1 Anti-Aliasing Decisions

| Approach | Description | When to Use |
|----------|-------------|-------------|
| **No AA (Jaggies)** | Pure pixel edges | Retro style, small canvases, hard edges |
| **Manual AA** | Hand-placed transition pixels | Polished style, curves, organic shapes |
| **Selective AA** | AA on organic shapes only | Hybrid approach, characters |

```
Manual anti-aliasing on diagonal line:

Without AA:          With Manual AA:

████                     ██▓█
   ████                ██▓█
      ████          ██▓█
         ████    ██▓█

Stepped "jaggies"    Smoothed with
                     intermediate color
```

**AA Color Selection:**
- Use a color between the two adjacent colors
- Typically 50% blend of foreground and background
- Can use multiple AA colors for smoother curves

### 5.2 Silhouette Readability

At small display sizes, silhouette matters most:

```
Silhouette Test: Fill artwork with solid black

Good Silhouette:         Poor Silhouette:

      ██                       █ █
     ████                     █████
    ██████                    █ █ █
   ████████                  ███████
    ██  ██                    █   █

Recognizable shape       Unclear, fragmented
```

**Guidelines:**
- Design silhouette first, details second
- Key features should be identifiable as solid shapes
- Avoid thin protrusions that disappear at small sizes
- Test by squinting or viewing from across the room

### 5.3 Shading Approaches

| Technique | Description | Quality |
|-----------|-------------|---------|
| **Pillow Shading** | Light center, dark edges all around | AVOID - amateur look |
| **Directional** | Consistent light source | Professional, 3D |
| **Cel Shading** | Hard shadow edges | Graphic, bold |
| **Soft Gradient** | Dithered transitions | Subtle, organic |

```
Light source: Top-left (10 o'clock)

Pillow Shading (BAD):    Directional (GOOD):

    ░░░░░░░░                 ░░░░░░
   ░░▒▒▒▒▒▒░░               ░░▒▒▒▒▒▒
  ░░▒▒████▒▒░░             ░▒▒▒████▓
  ░░▒▒████▒▒░░             ▒▒████▓▓▓
   ░░▒▒▒▒▒▒░░              ▒████▓▓▓▓
    ░░░░░░░░                ████▓▓▓

Light from all sides     Light from top-left
(unnatural)              (natural, dimensional)
```

### 5.4 Outline Styles

| Style | Pixels | Best For |
|-------|--------|----------|
| **Thick (2px)** | Bold, heavy | Large displays, emphasis, icons |
| **Thin (1px)** | Standard | Most PFP art, general use |
| **Selective** | Variable | Organic subjects, sophisticated look |
| **No outline** | None | Painterly style, backgrounds |
| **Colored outline** | Darker hue | Soft integration with fill |

```
Outline comparison:

Thick (2px):    Thin (1px):     Selective:      Colored:

██████████      ████████        ████████        ░▒▓█████
██      ██      █      █        █      █        ▒████████
██      ██      █      █        █               ▓████████
██      ██      █      █        █               █████████
██████████      ████████             ███        █████████
```

**Colored Outline Technique:**
- Use a darker shade of the adjacent fill color
- Skin uses dark skin tone outline
- Hair uses dark hair color outline
- Creates softer, more integrated look

### 5.5 Sub-Pixel Techniques

Create perceived detail smaller than a pixel through strategic color placement:

```
Sub-pixel eye (3x3 area):

Standard:        Sub-pixel:

█ █              ░█░
 █                ▓█▓
█ █              ░█░

Basic X pattern  Transition colors create
                 rounder appearance
```

**Applications:**
- Eyes and facial features
- Small curved objects
- Text at tiny sizes
- Jewelry and small accessories

---

## 6. Animation

### 6.1 Frame Rates

| Frame Rate | Effect | File Size | Use Case |
|------------|--------|-----------|----------|
| 6 FPS | Choppy, retro | Smallest | Classic game aesthetic |
| **8 FPS** | **Smooth retro** | **Small** | **Standard pixel animation** |
| **12 FPS** | **Fluid** | **Medium** | **Quality animations** |
| 24 FPS | Very smooth | Large | Premium, short loops |

**Protocol Standard: 8-12 FPS**

### 6.2 Animation Principles

**Squash and Stretch:**
```
Frame 1:    Frame 2:    Frame 3:    Frame 4:

  ██          ██        ████         ██
 ████        ████        ██         ████
 ████        ████        ██         ████
  ██        ██████      ████         ██

Normal      Squash      Stretch     Normal
```

**Anticipation:**
- Wind up before action
- Slight movement opposite to intended direction
- Creates weight and expectation

**Follow-Through:**
- Elements continue moving after main action stops
- Hair, clothing, accessories trail behind
- Creates natural momentum

### 6.3 Sprite Sheet Organization

```
Horizontal strip (simple animations):

┌────┬────┬────┬────┐
│ F1 │ F2 │ F3 │ F4 │  4-frame idle
└────┴────┴────┴────┘

Grid layout (complex animations):

┌────┬────┬────┬────┐
│Idle│Walk│Walk│Walk│  Row 1: Idle + Walk
├────┼────┼────┼────┤
│Run │Run │Run │Run │  Row 2: Run
├────┼────┼────┼────┤
│Jump│Jump│Land│Land│  Row 3: Jump/Land
└────┴────┴────┴────┘
```

**Naming Convention:**
```
character_idle_f01.png
character_idle_f02.png
character_walk_f01.png
...
character_spritesheet.png (combined)
```

### 6.4 Format Comparison

| Format | Alpha | Colors | Animation | Support | Best For |
|--------|-------|--------|-----------|---------|----------|
| GIF | 1-bit | 256 | Yes | Universal | Simple loops, max compat |
| APNG | 8-bit | 16M | Yes | Good | Smooth transparency |
| **WebP** | **8-bit** | **16M** | **Yes** | **Modern** | **Best compression** |
| MP4 | N/A | 16M | Yes | Universal | Long animations |

**Recommendation Priority:**
1. **WebP (animated)** - Best size/quality ratio
2. APNG - When transparency is critical
3. GIF - Fallback for maximum compatibility

### 6.5 Loop Types

| Loop Type | Frames | Use Case |
|-----------|--------|----------|
| **Seamless** | 1→2→3→4→[1] | Idle, breathing, ambient |
| **Ping-pong** | 1→2→3→4→3→2→[1] | Bobbing, pulsing |
| **One-shot** | 1→2→3→4 (stop) | Reactions, reveals |

```
Seamless loop (8 frames):

F1 → F2 → F3 → F4 → F5 → F6 → F7 → F8 → [F1]
                                         ↑
                                         └── Returns to start

Frame 8 should transition smoothly to Frame 1
```

### 6.6 File Size Optimization

| Technique | Size Reduction | Quality Impact |
|-----------|----------------|----------------|
| Reduce colors | 30-50% | Visible if overdone |
| Reduce frames | 20-40% | Choppier |
| Lossy WebP (90%+) | 40-60% | Minimal |
| Optimize palette | 10-20% | None |
| Reduce dimensions | Proportional | Smaller display |

**Target File Sizes:**

| Animation Type | Frames | Size | Target |
|----------------|--------|------|--------|
| Simple idle | 4-8 | 64x64 | < 50KB |
| Complex loop | 12-24 | 64x64 | < 200KB |
| Premium animation | 24+ | 128x128 | < 500KB |
| Maximum | Any | Any | 5MB |

---

## 7. Generative Pixel Art

### 7.1 Trait Layer Architecture

```
Layer stack (bottom to top):

7. Effects      ─── Auras, particles, glows
6. Accessories  ─── Glasses, earrings, items
5. Face         ─── Eyes, mouth, expressions
4. Head         ─── Hair, hats, headwear
3. Clothing     ─── Shirts, jackets, armor
2. Body         ─── Base character, skin
1. Background   ─── Solid color, pattern
```

### 7.2 Layer Specifications

| Layer | Coverage | Transparency | Typical Variants |
|-------|----------|--------------|------------------|
| Background | Full canvas | None | 10-20 |
| Body | Character area | Full alpha | 5-10 (skin tones) |
| Clothing | Upper body | Partial alpha | 30-50 |
| Head | Top 40% | Partial alpha | 40-60 |
| Face | Center 30% | Full alpha | 20-30 |
| Accessories | Variable | Full alpha | 50-100 |
| Effects | Variable | Full alpha | 10-20 |

### 7.3 Rarity Through Visual Elements

| Rarity | Occurrence | Visual Indicators |
|--------|------------|-------------------|
| Common | 50-70% | Basic colors, simple designs |
| Uncommon | 20-30% | Unique patterns, accessories |
| Rare | 5-15% | Protocol colors (BTC Orange) |
| Legendary | 1-5% | Animated traits, tier colors |
| Mythic | <1% | 1/1 unique, full animation |

**Visual Rarity Signals:**

```
Common:          Rare:              Legendary:

████████         ████████           ░░████░░
█      █         █ ░░░░ █           ░████████░
█  ██  █         █ ░██░ █           █░░░██░░░█
█      █         █ ░░░░ █           █░░░░░░░░█
████████         ████████           ░████████░
                                    ░░████░░
Standard         Protocol orange    Animated glow
colors           highlights         effect
```

### 7.4 Trait Conflict Resolution

**Conflict Types:**

| Type | Example | Resolution |
|------|---------|------------|
| Overlap | Hat + tall hair | Exclusion rule |
| Visual clash | Red eyes + red background | Color swap |
| Logical | Glasses + eye patch | Mutual exclusion |
| Z-order | Earring behind hair | Layer adjustment |

**Compatibility Matrix:**

```
              Hat-A  Hat-B  Hair-L  Hair-S  Glasses
Hat-A           -      X       X       ✓       ✓
Hat-B           X      -       X       ✓       ✓
Hair-Long       X      X       -       X       ✓
Hair-Short      ✓      ✓       X       -       ✓
Glasses         ✓      ✓       ✓       ✓       -

X = mutually exclusive
✓ = compatible
```

### 7.5 Consistency Standards

**Master Palette:**
- Define shared palette across all traits
- Export as .pal or .ase file
- All artists use identical colors

**Lighting Direction:**
- Consistent top-left light source
- All shading follows same direction
- Document light angle in style guide

**Anchor Points:**
- Define pixel coordinates for layer alignment
- Head anchor, body anchor, accessory anchors
- Ensures perfect composition

```
Anchor point system (64x64):

Body anchor:    (32, 48)  ← center bottom
Head anchor:    (32, 16)  ← center top
Left ear:       (12, 20)
Right ear:      (52, 20)
Hat position:   (32, 8)
```

### 7.6 Programmatic Validation

Before minting, validate all combinations:

```
Validation checklist:

□ All trait combinations render without overlap errors
□ No visual conflicts between layers
□ Rarity weights sum to 100%
□ Each token has valid metadata
□ File sizes within limits
□ All images upscaled correctly
```

---

## 8. Technical Standards

### 8.1 File Format Specifications

| Format | Bit Depth | Max Colors | Transparency | Use Case |
|--------|-----------|------------|--------------|----------|
| PNG-8 | 8-bit | 256 | 1-bit alpha | Small palettes |
| **PNG-24** | **24-bit** | **16M** | **8-bit alpha** | **Standard delivery** |
| GIF | 8-bit | 256 | 1-bit alpha | Animations, legacy |
| **WebP** | **24-bit** | **16M** | **8-bit alpha** | **Optimal web/animated** |

### 8.2 Export Settings

**Static Pixel Art (PNG):**
```
Format:         PNG-24
Color Profile:  sRGB
Interlacing:    None
Compression:    Maximum (lossless)
Scaling:        Nearest-neighbor only
```

**Animated Pixel Art (WebP):**
```
Format:         WebP (animated)
Quality:        95-100 (for pixel art)
Effort:         6 (compression level)
Loop:           Infinite (0)
Frame Delay:    83ms (12 FPS) or 125ms (8 FPS)
```

### 8.3 Dimension Standards

| Use Case | Source | Delivery | Scale |
|----------|--------|----------|-------|
| IPFS storage | 64x64 | 512x512 | 8x |
| OpenSea thumbnail | 64x64 | 512x512 | 8x |
| Twitter PFP | 64x64 | 512x512 | 8x |
| Full display | 64x64 | 1024x1024 | 16x |
| Banner | 256x144 | 1024x576 | 4x |

### 8.4 Metadata Integration

Following the `TreasureMetadata` interface:

```json
{
  "name": "Treasure #1234",
  "description": "Pixel art Treasure NFT within BTCNFT Vault",
  "image": "ipfs://QmPixelArtHash/1234.png",
  "animation_url": "ipfs://QmAnimatedHash/1234.webp",
  "external_url": "https://issuer.example/treasures/1234",
  "background_color": "0d0d14",
  "attributes": [
    { "trait_type": "Art Style", "value": "Pixel Art" },
    { "trait_type": "Canvas Size", "value": "64x64" },
    { "trait_type": "Background", "value": "Vault Dark" },
    { "trait_type": "Body", "value": "Standard" },
    { "trait_type": "Head", "value": "Diamond Crown" },
    { "trait_type": "Eyes", "value": "Laser" },
    { "trait_type": "Display Tier", "value": "Gold" },
    { "display_type": "number", "trait_type": "Percentile", "value": 82 }
  ]
}
```

### 8.5 IPFS Directory Structure

```
ipfs://QmCollectionRoot/
├── images/              # Upscaled delivery images (512x512)
│   ├── 1.png
│   ├── 2.png
│   └── ...
├── source/              # Original resolution (64x64)
│   ├── 1.png
│   └── ...
├── animations/          # Animated versions
│   ├── 1.webp
│   └── ...
├── traits/              # Individual trait layers
│   ├── backgrounds/
│   │   ├── vault_dark.png
│   │   └── ...
│   ├── bodies/
│   ├── heads/
│   ├── faces/
│   └── accessories/
├── metadata/            # JSON metadata files
│   ├── 1.json
│   ├── 2.json
│   └── ...
└── collection.json      # Collection-level metadata
```

---

## 9. Tools and Workflows

### 9.1 Recommended Software

| Tool | Platform | Price | Best For |
|------|----------|-------|----------|
| **Aseprite** | All | $20 | Industry standard, animation |
| **Pixaki** | iPad | $25 | Mobile creation |
| **Piskel** | Web | Free | Browser-based, simple |
| GraphicsGale | Windows | Free | Animation focus |
| Photoshop | All | Subscription | Integration with design |
| GIMP | All | Free | Open source |
| Pyxel Edit | All | $9 | Tilemap focus |

### 9.2 Photoshop Pixel Art Setup

```
Image > Image Size:
├── Resample: Nearest Neighbor (hard edges)
└── Constrain Proportions: On

Edit > Preferences > General:
└── Image Interpolation: Nearest Neighbor

View > Show:
└── Pixel Grid (visible at 500%+ zoom)

Pencil Tool:
├── Mode: Normal
├── Opacity: 100%
├── Hardness: 100%
└── Size: 1px
```

### 9.3 Aseprite Export Pipeline

```bash
# Export sprite sheet with JSON data
aseprite -b input.aseprite --sheet output_sheet.png --data output.json

# Export individual frames
aseprite -b input.aseprite --save-as frame_{frame}.png

# Export as animated WebP
aseprite -b input.aseprite --save-as output.webp

# Batch upscale with nearest neighbor
aseprite -b input.aseprite --scale 8 --save-as output_8x.png

# Export all layers as separate files
aseprite -b input.aseprite --split-layers --save-as {layer}.png
```

### 9.4 Version Control

**File Naming Convention:**
```
[collection]_[tokenid]_[variant]_[version].[ext]

Examples:
treasure_0001_standard_v1.aseprite   # Source file
treasure_0001_standard_v1.png        # Export
treasure_0001_animated_v1.webp       # Animation
trait_background_vaultdark_v1.png    # Trait layer
```

**Git LFS Setup:**
```bash
# Track large art files with Git LFS
git lfs track "*.aseprite"
git lfs track "*.psd"
git lfs track "*.png"
git add .gitattributes
```

### 9.5 Team Collaboration Workflow

```
Production Pipeline:

1. Art Lead
   └── Creates master palette (.pal)
   └── Defines style guide
   └── Sets anchor points

2. Trait Artists
   └── Receive assigned categories
   └── Create traits using master palette
   └── Submit for review

3. QA Review
   └── Test at 1x, 2x, 8x scales
   └── Validate layer compatibility
   └── Check animation loops

4. Export Pipeline
   └── Automated script generates final assets
   └── Upscales to delivery resolution
   └── Optimizes file sizes

5. Upload
   └── Assets pinned to IPFS
   └── Metadata generated via SDK
   └── Final review before production
```

---

## 10. Quality Checklist

### 10.1 Common Mistakes

| Mistake | Problem | Fix |
|---------|---------|-----|
| Pillow shading | Flat, amateur look | Use directional lighting |
| Too many colors | Muddy, loses pixel feel | Limit to 16-32 colors |
| Inconsistent outlines | Visual noise | Standardize outline style |
| Bilinear upscaling | Blurry pixels | Nearest-neighbor only |
| Banding | Visible color steps | Add dithering |
| Jagged curves | Unintentional roughness | Manual anti-aliasing |
| Tangent lines | Shapes touching awkwardly | Adjust spacing |
| Single-pixel noise | Stray pixels | Clean up artifacts |

### 10.2 Pre-Export Checklist

```
Before exporting any asset:

□ Canvas size matches specification (64x64)
□ Color palette within limit (16 colors)
□ Protocol colors used correctly
□ Consistent light source (top-left)
□ Silhouette readable at 1x scale
□ No pillow shading
□ Outlines consistent throughout
□ Transparency set correctly
□ Animation loops seamlessly (if applicable)
□ No stray pixels or artifacts
□ File named according to convention
□ Metadata attributes documented
```

### 10.3 Cross-Platform Testing

| Platform | Test For |
|----------|----------|
| OpenSea (testnet) | Thumbnail display, metadata |
| Twitter/X | Circular crop, compression |
| Discord | Small avatar rendering |
| MetaMask | Tiny display, recognition |
| Mobile browser | Touch-screen viewing |
| Desktop browser | Large display rendering |

### 10.4 Scale Testing

Verify artwork at multiple scales:

```
1x  (64x64)    ← Check detail accuracy
2x  (128x128)  ← Small display verification
4x  (256x256)  ← Medium display
8x  (512x512)  ← Standard delivery
16x (1024x1024) ← Large display
```

At each scale, verify:
- Sharp pixel edges (no blur)
- Correct color representation
- Proper transparency handling
- Animation frame timing

---

## 11. Integration with BTCNFT Protocol

### 11.1 Tier Frame Compositing

Pixel art Treasure NFTs are displayed within SVG tier frames:

```
Composition Architecture:

┌─────────────────────────────────────────────┐
│ ┌─────────────────────────────────────────┐ │
│ │ SVG TIER FRAME                          │ │
│ │ (Gold/Platinum/Diamond frame)           │ │
│ │ ┌─────────────────────────────────────┐ │ │
│ │ │                                     │ │ │
│ │ │   PIXEL ART TREASURE                │ │ │
│ │ │   (64x64 → 512x512 upscaled)        │ │ │
│ │ │                                     │ │ │
│ │ └─────────────────────────────────────┘ │ │
│ │                              TIER BADGE │ │
│ └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

### 11.2 Compositing Specifications

| Tier | Frame Width | Glow | Animation |
|------|-------------|------|-----------|
| Bronze | 4% | None | None |
| Silver | 4% | None | None |
| Gold | 5% | Subtle | None |
| Platinum | 6% | Medium | Optional shimmer |
| Diamond | 8% | Strong | Required prismatic |

**Compositing Process:**

```
1. Load pixel art at source resolution (64x64)
           ↓
2. Upscale to 512x512 (nearest-neighbor)
           ↓
3. Apply tier-appropriate SVG frame
           ↓
4. Add tier badge in corner
           ↓
5. Apply glow/animation (Platinum/Diamond)
           ↓
6. Export as PNG (static) or WebP (animated)
```

### 11.3 Metadata Service Integration

The metadata service (per [Integration Guide](./Integration_Guide.md) Section 13) handles dynamic composition:

```
Request Flow:

1. Client requests token metadata
           ↓
2. Metadata service fetches pixel art from IPFS
           ↓
3. Calculates vault percentile → determines tier
           ↓
4. Composites pixel art with tier frame
           ↓
5. Caches composed image
           ↓
6. Returns complete metadata JSON
```

**Response Format:**
```json
{
  "name": "Treasure #42",
  "image": "https://metadata.issuer.io/composed/42.png",
  "attributes": [
    { "trait_type": "Art Style", "value": "Pixel Art" },
    { "trait_type": "Source Resolution", "value": "64x64" },
    { "trait_type": "Display Tier", "value": "Diamond" },
    { "display_type": "number", "trait_type": "Percentile", "value": 95 }
  ]
}
```

### 11.4 Rarity Alignment

Align pixel art trait rarity with the achievement rarity system:

| Achievement Rarity | Pixel Art Trait Rarity | Visual Treatment |
|--------------------|------------------------|------------------|
| Common | Common traits | Standard colors |
| Uncommon | Uncommon traits | Subtle patterns |
| Rare | Rare traits | BTC Orange accents |
| Legendary | Legendary traits | Animated, tier colors |

### 11.5 Off-Chain Storage Standards

| Priority | Storage | Content | Redundancy |
|----------|---------|---------|------------|
| Primary | IPFS (Pinata) | All assets | 3+ providers |
| Backup | Arweave | Metadata + rare art | Permanent |
| CDN | Cloudflare | Composed images | Edge cache |

### 11.6 On-Chain Pixel Art Storage

For permanent on-chain storage, the protocol uses **packed bitmaps** via `PixelArtRenderer.sol`:

#### Supported Formats

| Format | Resolution | Colors | Bitmap | Total Storage |
|--------|------------|--------|--------|---------------|
| **128×128 monochrome** | 16,384 px | 2 (B&W) | 2,048 B | ~2.1 KB |
| **256×256 monochrome** | 65,536 px | 2 (B&W) | 8,192 B | ~8.2 KB |

The 256×256 format provides 4× the resolution of 128×128 at 4× the storage cost.

#### 128×128 Monochrome (1-bit) Format

```
┌─────────────────────────────────────────────────────────────┐
│  Color:  3 bytes (RGB foreground)                           │
│  Bitmap: 2,048 bytes (16,384 pixels × 1 bit, MSB-first)     │
│  Total:  2,051 bytes                                        │
└─────────────────────────────────────────────────────────────┘
```

**Conversion:**
```bash
pbsep source.png output_name --size 128
```

**Solidity Library:**
```solidity
library MyPixelArt128Mono {
    function getColor() internal pure returns (bytes3);        // 3 bytes RGB
    function getBitmap() internal pure returns (bytes memory); // 2,048 bytes
    function getSVG() internal pure returns (string memory);
}
```

#### 256×256 Monochrome (1-bit) Format

```
┌─────────────────────────────────────────────────────────────┐
│  Color:  3 bytes (RGB foreground)                           │
│  Bitmap: 8,192 bytes (65,536 pixels × 1 bit, MSB-first)     │
│  Total:  8,195 bytes                                        │
└─────────────────────────────────────────────────────────────┘
```

**Conversion:**
```bash
pbsep source.png output_name --size 256
```

**Solidity Library:**
```solidity
library MyPixelArt256Mono {
    function getColor() internal pure returns (bytes3);        // 3 bytes RGB
    function getBitmap() internal pure returns (bytes memory); // 8,192 bytes
    function getSVG() internal pure returns (string memory);
}
```

#### When to Use Each Format

| Criteria | 128×128 monochrome | 256×256 monochrome |
|----------|---------------------|---------------------|
| Resolution | 16,384 pixels | 65,536 pixels (4×) |
| Colors | Single color only | Single color only |
| Best for | Compact silhouettes | Maximum detail silhouettes |
| Storage | ~2.1 KB | ~8.2 KB |

#### On-Chain vs Off-Chain Decision

| Criteria | On-Chain (PixelArtRenderer) | Off-Chain (IPFS) |
|----------|----------------------------|------------------|
| File size | < 5KB Solidity | Any size |
| Permanence | Immutable, Ethereum-guaranteed | Depends on pinning |
| Animation | Not supported | Supported (WebP/GIF) |
| Cost | ~65K gas deployment | ~$0.01 IPFS pin |

**Implementation**: See `contracts/issuer/src/PixelArtRenderer.sol` and [Visual Assets Guide](./Visual_Assets_Guide.md) Section 4.1.2.

---

## Appendix A: Protocol Color Palette Reference

```
BTCNFT Protocol Official Palette:

Core Colors:
┌─────────────┬─────────┬────────────────┐
│ BTC Orange  │ #f7931a │ Primary accent │
│ BTC Gold    │ #ffcd00 │ Secondary      │
│ Vault Dark  │ #0d0d14 │ Deep shadow    │
│ Vault Surface│ #1a1a2e │ Mid shadow    │
│ White       │ #ffffff │ Highlight      │
│ Text Secondary│ #a0a0b0 │ Neutral      │
└─────────────┴─────────┴────────────────┘

Tier Colors:
┌──────────┬─────────┬─────────┬─────────┐
│ Tier     │ Primary │ Light   │ Dark    │
├──────────┼─────────┼─────────┼─────────┤
│ Diamond  │ #E8F4FF │ #F0F8FF │ #D0E8FF │
│ Platinum │ #E5E4E2 │ #F0F0EE │ #D8D8D6 │
│ Gold     │ #FFD700 │ #FFEC8B │ #B8860B │
│ Silver   │ #C0C0C0 │ #E0E0E0 │ #808080 │
│ Bronze   │ #CD7F32 │ #DAA520 │ #8B4513 │
└──────────┴─────────┴─────────┴─────────┘
```

---

## Appendix B: Quick Reference Card

```
BTCNFT Pixel Art Quick Reference:

Canvas:      64x64 (protocol standard)
Palette:     16 colors (recommended)
Upscale:     8x to 512x512 (nearest-neighbor)
Format:      PNG-24 (static), WebP (animated)
Animation:   8-12 FPS
Storage:     IPFS (primary), Arweave (backup)
Light:       Top-left directional

Avoid:
✗ Pillow shading
✗ Bilinear upscaling
✗ More than 32 colors
✗ Corners for key features (circular crop)
✗ Single-pixel noise artifacts

Include:
✓ Protocol colors for rare traits
✓ Consistent outline style
✓ Clear silhouette at 1x
✓ Seamless animation loops
✓ Tier-aligned rarity visuals
```

---

## Related Documents

| Document | Relationship |
|----------|--------------|
| [Visual Assets Guide](./Visual_Assets_Guide.md) | SVG/on-chain standards, tier frames |
| [NFT Artwork Creation](./NFT_Artwork_Creation.md) | AI-assisted artwork workflow |
| [Achievement NFT Visual Implementation](./Achievement_NFT_Visual_Implementation.md) | On-chain SVG patterns |
| [Vault Percentile Specification](./Vault_Percentile_Specification.md) | Tier calculation |
| [Integration Guide](./Integration_Guide.md) | Metadata service requirements |
| [SDK VISUAL_HIERARCHY.md](../sdk/VISUAL_HIERARCHY.md) | TypeScript visual types |
