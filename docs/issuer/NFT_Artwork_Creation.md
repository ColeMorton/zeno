# NFT Artwork Creation Specification

> **Version:** 1.0
> **Status:** Active
> **Last Updated:** 2025-12-24
> **Related Documents:**
> - [Visual Assets Guide](./Visual_Assets_Guide.md)
> - [Pixel Art Guide](./Pixel_Art_Guide.md)
> - [Medallion Visual Architecture](./Medallion_Visual_Architecture.md)
> - [Achievement NFT Visual Implementation](./Achievement_NFT_Visual_Implementation.md)

---

This specification documents the AI-assisted workflow for creating medallion-style NFT artwork for Achievement NFTs. It covers reference-based generation, prompt engineering standards, and the conversion pipeline to on-chain 1-bit storage.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Reference-Based AI Generation](#2-reference-based-ai-generation)
3. [Prompt Engineering Standards](#3-prompt-engineering-standards)
4. [Achievement Prompt Templates](#4-achievement-prompt-templates)
5. [Conversion Pipeline](#5-conversion-pipeline)
6. [Output Artifacts](#6-output-artifacts)
7. [Integration](#7-integration)

---

## 1. Overview

### 1.1 Workflow Purpose

The artwork creation workflow produces luxury medallion-style visuals for Achievement NFTs. These high-resolution AI-generated images are converted to 128×128 1-bit monochrome bitmaps for permanent on-chain storage.

### 1.2 Permanence Architecture

| Stage | Format | Storage | Permanence |
|-------|--------|---------|------------|
| AI Generation | High-res PNG | Local/backup | Working file |
| Source Archive | `*_nano.png` | Repository | Version controlled |
| On-Chain | 128×128 1-bit | Contract bytecode | Ethereum-permanent |

### 1.3 Visual Style

All Achievement NFTs follow the **luxury medallion** aesthetic:

- **Materials**: Polished gold, brushed gold, silver, pavé diamonds
- **Structure**: Circular medallion with layered borders
- **Photography**: Macro 3D render, soft studio lighting, 8K resolution
- **Chain**: Gold bail and chain attachment at top

---

## 2. Reference-Based AI Generation

### 2.1 Process Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    AI GENERATION WORKFLOW                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. REFERENCE INPUT                                              │
│     └─ Upload existing bitmap (e.g., diamond_hands.png)          │
│                                                                  │
│  2. PROMPT COMPOSITION                                           │
│     └─ Base medallion template + achievement-specific element    │
│                                                                  │
│  3. AI GENERATION                                                │
│     └─ Model: Google Gemini Nano Banana Pro (or equivalent)      │
│     └─ Output: High-resolution PNG                               │
│                                                                  │
│  4. VARIATION (if needed)                                        │
│     └─ Reference base NFT, specify central design difference     │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Reference Image Selection

For new achievements, use an existing medallion as visual anchor:

| Base Reference | Best For |
|----------------|----------|
| `hands_diamond_nano.png` | Duration achievements, complex central designs |
| `annual_nano.png` | Single-character/numeral designs |
| `hodler_supreme_nano.png` | Geometric/crystal formations |

### 2.3 Model Requirements

- **Recommended**: Google Gemini Nano Banana Pro
- **Alternatives**: Any model supporting image upload + text prompt
- **Key Capability**: Must accept reference image to maintain visual consistency

---

## 3. Prompt Engineering Standards

### 3.1 Base Medallion Template

This template establishes the consistent medallion aesthetic:

```
A realistic macro 3D render of a luxury gold medallion pendant. The central
design features [CENTRAL_ELEMENT]. [CENTRAL_ELEMENT_DETAILS]. The design is
set against a brushed gold background. The medallion has a complex border
featuring a silver ring with engraved lines and embedded diamond studs,
enclosed by a thick polished gold rim. A gold chain attaches to a bail at
the top. White background, soft studio lighting, high depth of field, 8k
resolution, jewelry photography style.
```

### 3.2 Prompt Components

| Component | Description | Example |
|-----------|-------------|---------|
| **Central Element** | Primary visual identifier | "two hands clasping a diamond" |
| **Material Treatment** | Surface finish and materials | "encrusted in pavé white diamonds" |
| **Background** | Inner medallion area | "brushed gold background" |
| **Border** | Ring and rim construction | "silver ring with engraved lines" |
| **Photography** | Lighting and rendering style | "macro 3D render, studio lighting" |

### 3.3 Variation Prompt Pattern

For creating related achievements from an existing base:

```
This [BASE_NFT_NAME] NFT is reward for [BASE_ACHIEVEMENT_DESCRIPTION].

The reward for [NEW_ACHIEVEMENT_DESCRIPTION] is called "[NEW_NAME]".

The [NEW_NAME] NFT should be 100% consistent with the [BASE_NFT_NAME] NFT
with the only exception being the central design.
```

**Example (Annual from Diamond Hands):**

```
This Diamond Hands NFT is reward for holding a Vault NFT for 730 days.

The reward for holding for 365 days (1 year) is called "Annual".

The Annual NFT should be 100% consistent with the Diamond Hands NFT with the
only exception being the central design.
```

---

## 4. Achievement Prompt Templates

### 4.1 Lifecycle Achievements

#### MINTER

**Central Element**: A stylized vault door icon with an entry arrow

```
A realistic macro 3D render of a luxury gold medallion pendant. The central
design features a stylized vault door with an inward-pointing arrow,
completely encrusted in pavé white diamonds. The vault icon represents the
first entry into the protocol. The design is set against a brushed gold
background. The medallion has a complex border featuring a silver ring with
engraved lines and embedded diamond studs, enclosed by a thick polished gold
rim. A gold chain attaches to a bail at the top. White background, soft
studio lighting, high depth of field, 8k resolution, jewelry photography style.
```

#### MATURED

**Central Element**: A radiating star symbol with completion rays

```
A realistic macro 3D render of a luxury gold medallion pendant. The central
design features a radiating star with eight completion rays emanating outward,
encrusted in pavé white diamonds. The star symbolizes full maturation and
completion. The design is set against a brushed gold background. The medallion
has a complex border featuring a silver ring with engraved lines and embedded
diamond studs, enclosed by a thick polished gold rim. A gold chain attaches to
a bail at the top. White background, soft studio lighting, high depth of field,
8k resolution, jewelry photography style.
```

### 4.2 Composite Achievement

#### HODLER_SUPREME

**Central Element**: An eight-pointed crystal formation

```
A realistic macro 3D render of a luxury gold medallion pendant. The central
design features an elaborate eight-pointed crystal formation, multi-faceted
and completely encrusted in brilliant white diamonds. The crystal represents
supreme commitment and composite achievement. The design is set against a
brushed gold background. The medallion has a complex border featuring a silver
ring with engraved lines and embedded diamond studs, enclosed by a thick
polished gold rim. A gold chain attaches to a bail at the top. White background,
soft studio lighting, high depth of field, 8k resolution, jewelry photography style.
```

### 4.3 Duration Achievements

#### FIRST_MONTH (30 days)

**Central Element**: The numeral "1" or "30"

```
A realistic macro 3D render of a luxury gold medallion pendant. The central
design features the numeral "1" in elegant Roman serif style, completely
encrusted in pavé white diamonds. The numeral represents the first month
milestone. The design is set against a brushed gold background. The medallion
has a complex border featuring a silver ring with engraved lines and embedded
diamond studs, enclosed by a thick polished gold rim. A gold chain attaches to
a bail at the top. White background, soft studio lighting, high depth of field,
8k resolution, jewelry photography style.
```

#### QUARTER_STACK (91 days)

**Central Element**: The numeral "3" or "Q"

```
A realistic macro 3D render of a luxury gold medallion pendant. The central
design features the letter "Q" for Quarter in elegant serif style, completely
encrusted in pavé white diamonds. The letter represents the three-month
milestone. The design is set against a brushed gold background. The medallion
has a complex border featuring a silver ring with engraved lines and embedded
diamond studs, enclosed by a thick polished gold rim. A gold chain attaches to
a bail at the top. White background, soft studio lighting, high depth of field,
8k resolution, jewelry photography style.
```

#### HALF_YEAR (182 days)

**Central Element**: The fraction "½" or numeral "6"

```
A realistic macro 3D render of a luxury gold medallion pendant. The central
design features a stylized half-circle or the numeral "6", completely encrusted
in pavé white diamonds. The design represents the six-month halfway milestone.
The design is set against a brushed gold background. The medallion has a complex
border featuring a silver ring with engraved lines and embedded diamond studs,
enclosed by a thick polished gold rim. A gold chain attaches to a bail at the top.
White background, soft studio lighting, high depth of field, 8k resolution,
jewelry photography style.
```

#### ANNUAL (365 days)

**Central Element**: The letter "A"

```
A realistic macro 3D render of a luxury gold medallion pendant. The central
design features the letter "A" for Annual in elegant serif style, completely
encrusted in pavé white diamonds. The letter represents the one-year milestone.
The design is set against a brushed gold background. The medallion has a complex
border featuring a silver ring with engraved lines and embedded diamond studs,
enclosed by a thick polished gold rim. A gold chain attaches to a bail at the top.
White background, soft studio lighting, high depth of field, 8k resolution,
jewelry photography style.
```

#### DIAMOND_HANDS (730 days)

**Central Element**: Two hands clasping a geometric diamond

```
A realistic macro 3D render of a luxury gold medallion pendant. The central
design features two hands completely encrusted in pavé white diamonds, clasping
a large geometric diamond shape. The hands are set against a brushed gold
background. The medallion has a complex border featuring a silver ring with
engraved lines and embedded diamond studs, enclosed by a thick polished gold
rim. A gold chain attaches to a bail at the top. White background, soft studio
lighting, high depth of field, 8k resolution, jewelry photography style.
```

---

## 5. Conversion Pipeline

### 5.1 Command

```bash
cd scripts/pbsep && uv run pbsep <input.png> <output_name> --size 256 --invert
```

**Flags:**
- `--size 128|256` - Output resolution (256 recommended for medallions)
- `--profile <name>` - Processing profile (default: `medallion`)
- `--invert` - Invert colors before threshold (required for light-colored medallions on white backgrounds)

### 5.2 Processing Steps (PBSEP-256 Pipeline)

```
High-Res PNG (e.g., annual_nano.png)
         │
         ▼
┌─────────────────────────────────────────┐
│ Stage 1: Input Normalization            │
│ - Gamma linearization (sRGB → linear)   │
│ - Exposure normalization (percentile)   │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ Stage 2: Luminance Extraction           │
│ - LAB L* channel (perceptually uniform) │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ Stage 3: Contrast Enhancement (Optional)│
│ - CLAHE (adaptive histogram)            │
│ - Enhances local contrast for threshold │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ Stage 4: Downscaling                    │
│ - INTER_AREA interpolation              │
│ - Resize to target (128 or 256)         │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ Stage 5: Binary Decision                │
│ - Adaptive Gaussian threshold           │
│ - Handles uneven lighting               │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ Stage 6: Morphological Correction       │
│ - Close gaps in foreground              │
│ - Remove isolated pixels (islands)      │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│ Stage 7: Export                         │
│ - 1-bit PNG via ImageMagick             │
│ - Preview SVG (rect-based)              │
│ - Metadata JSON (statistics)            │
│ - Solidity library (on-chain storage)   │
└─────────────────────────────────────────┘
```

### 5.3 Requirements

- **ImageMagick 7**: Required for final 1-bit export
- **Python 3.11+**: Pipeline runtime
- **uv**: Python package manager

```bash
# Verify ImageMagick installation
magick --version

# Install pbsep dependencies
cd scripts/pbsep && uv sync
```

---

## 6. Output Artifacts

### 6.1 File Structure

```
assets/
├── annual_nano.png                     # AI-generated source (archive)
├── annual_128x128_1bit.svg             # Preview SVG
├── annual_128x128_1bit.png             # Preview PNG
├── annual_128x128_metadata.json        # Statistics
└── Annual128Mono.sol                   # On-chain Solidity library
```

### 6.2 Naming Conventions

| File Type | Pattern | Example |
|-----------|---------|---------|
| AI Source | `{achievement}_nano.png` | `annual_nano.png` |
| Preview SVG | `{achievement}_{size}x{size}_1bit.svg` | `annual_128x128_1bit.svg` |
| Preview PNG | `{achievement}_{size}x{size}_1bit.png` | `annual_128x128_1bit.png` |
| Metadata | `{achievement}_{size}x{size}_metadata.json` | `annual_128x128_metadata.json` |
| Solidity | `{Achievement}{size}Mono.sol` | `Annual128Mono.sol` |

### 6.3 Metadata Format

```json
{
  "source": "/path/to/annual_nano.png",
  "size": 128,
  "format": "1-bit monochrome",
  "opaquePixels": 8234,
  "totalPixels": 16384,
  "bytes": 2048
}
```

### 6.4 Solidity Library Interface

```solidity
library Annual128Mono {
    function getColor() internal pure returns (bytes3);
    function getBitmap() internal pure returns (bytes memory);
    function getSVG() internal pure returns (string memory);
}
```

---

## 7. Integration

### 7.1 On-Chain Storage

Generated libraries integrate with `PixelArtRenderer.sol`:

```solidity
import {Annual128Mono} from "./Annual128Mono.sol";
import {PixelArtRenderer} from "./PixelArtRenderer.sol";

// Render on-demand (view function, zero gas for reads)
string memory svg = Annual128Mono.getSVG();
```

### 7.2 Storage Costs

| Format | Resolution | Storage | Deployment Gas |
|--------|------------|---------|----------------|
| 128×128 1-bit | 16,384 pixels | 2,048 bytes | ~400,000 |
| 256×256 1-bit | 65,536 pixels | 8,192 bytes | ~1,600,000 |

**Note**: Gas costs are one-time deployment costs. Per-mint and per-transfer costs are unaffected.

### 7.3 Complete Workflow Example

```bash
# 1. Generate AI artwork using Gemini with reference image
#    Upload: assets/hands_diamond_nano.png
#    Prompt: [Use Annual template from Section 4.3]
#    Save output as: assets/annual_nano.png

# 2. Convert to on-chain format (use --invert for light medallions)
cd scripts/pbsep && uv run pbsep ../../assets/annual_nano.png annual --size 256 --invert

# 3. Move Solidity library to contracts
cp ../../assets/Annual256Mono.sol ../../contracts/issuer/src/

# 4. Verify compilation
cd ../../contracts/issuer && forge build
```

---

## Related Documents

| Document | Relationship |
|----------|--------------|
| [Visual Assets Guide](./Visual_Assets_Guide.md) | SVG technical standards, tier frames |
| [Pixel Art Guide](./Pixel_Art_Guide.md) | On-chain pixel art storage formats |
| [Medallion Visual Architecture](./Medallion_Visual_Architecture.md) | Medallion metaphor and tier progression |
| [Achievement NFT Visual Implementation](./Achievement_NFT_Visual_Implementation.md) | Existing SVG achievement implementation |

---

*This specification documents the AI-assisted artwork creation workflow for BTCNFT Protocol Achievement NFTs. All generated artwork follows the luxury medallion aesthetic and is optimized for permanent on-chain storage.*
