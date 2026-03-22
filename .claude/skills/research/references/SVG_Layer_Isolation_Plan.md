# SVG Layer Isolation Plan: Diamond Hands Medallion

> **Version:** 1.0
> **Status:** Technical
> **Last Updated:** 2025-12-28

## Objective
Isolate the 16-colour SVG into 4 independent semantic layers using geometric reconstruction.

## Source File
`assets/diamond_hands_16_colours.svg` (530×568 viewBox, 16 paths by color)

## Target Layers

| Layer | Description | Geometric Criteria |
|-------|-------------|-------------------|
| **Medallion** | Circular double-rimmed frame with hoop and chain | Outer annular ring + top attachment region |
| **Background** | Polished metallic surface | Inner circular fill behind hands |
| **Primary** | Two hands grasping + diamond above | Central subject matter bounded by hands contour |
| **Secondary** | Diamond studs within hands | Small convex shapes within hands region |

## Output Files
```
assets/layers/
├── medallion.svg          # Frame + chain + hoop
├── background.svg         # Inner metallic surface
├── primary.svg            # Hands + large diamond
├── secondary.svg          # Diamond studs on hands
└── diamond_hands_layered.svg  # Combined with <g> groups
```

## Implementation Steps

### 1. Create Layer Parser Script
Create `scripts/svg-layer-parser.js` to:
- Parse SVG path data using path-data-parser
- Convert `M`, `C`, `L`, `Z` commands to coordinate arrays
- Extract bounding boxes per path segment

### 2. Define Geometric Boundaries
Based on 530×568 viewBox analysis of actual path coordinates:

**Medallion Center:** (265, 320) - offset due to chain at top
**Coordinate ranges observed:** x[68-470], y[66-568]

```
┌─────────────────────────────────────────┐
│           CHAIN/HOOP (y < 140)          │
│                  ┌───┐                   │
│              ┌───┤   ├───┐              │
│            ┌─┘   │   │   └─┐            │
│           ┌┴─────┴───┴─────┴┐           │
│          ╱   OUTER RIM      ╲          │
│         │ ╱──────────────╲   │          │
│         │╱  INNER RIM     ╲  │          │
│         ││  ┌───────────┐  ││          │
│         ││  │ BACKGROUND│  ││          │
│         ││  │  ┌─────┐  │  ││          │
│         ││  │  │HANDS│  │  ││          │
│         ││  │  │  ◇  │  │  ││          │
│         ││  │  └─────┘  │  ││          │
│         ││  └───────────┘  ││          │
│         │╲                 ╱│          │
│         │ ╲───────────────╱ │          │
│          ╲                  ╱           │
│           └────────────────┘            │
└─────────────────────────────────────────┘

Medallion Frame (outer ring + rim + chain):
- Chain/hoop: y < 140 AND x in [260-420]
- Outer ring: dist_from_center > 190
- Inner rim (silver): colors rgb(159,156,150), rgb(197,191,182)

Background (polished gold surface):
- Inner circle: 120 < dist_from_center < 190
- Excludes hands bounding box
- Colors: mid-golds rgb(141,101,54) to rgb(189,164,130)

Primary (Hands + Diamond above):
- Central bounding box: x[175-385], y[250-470]
- Large diamond: x[235-295], y[240-310]
- Colors: full range (shadows through highlights)

Secondary (Diamond studs):
- Small closed subpaths within Primary bounds
- Lightest colors: rgb(239,221,191), rgb(240,239,233)
- Convex hull area < 400px²
```

### 3. Path Segmentation Algorithm
For each of the 16 color paths:

```javascript
// 1. Split path into subpaths (each M...Z sequence is a subpath)
const subpaths = splitByMoveTo(pathData);

// 2. For each subpath, extract all coordinate points
for (const subpath of subpaths) {
  const points = extractAllPoints(subpath); // From M, L, C, Q commands

  // 3. Calculate bounding box and centroid
  const bbox = getBoundingBox(points);
  const centroid = getCentroid(points);

  // 4. Calculate distance from medallion center (265, 320)
  const distFromCenter = Math.sqrt(
    (centroid.x - 265)**2 + (centroid.y - 320)**2
  );

  // 5. Classify by geometric criteria
  let layer;
  if (centroid.y < 140 && centroid.x > 260) {
    layer = 'medallion'; // Chain/hoop region
  } else if (distFromCenter > 190) {
    layer = 'medallion'; // Outer frame ring
  } else if (isWithinHandsBounds(centroid) && bbox.area < 400) {
    layer = 'secondary'; // Small diamond stud
  } else if (isWithinHandsBounds(centroid)) {
    layer = 'primary'; // Hands or large diamond
  } else {
    layer = 'background'; // Gold surface behind hands
  }

  // 6. Append subpath to appropriate layer collection
  layers[layer].push({ path: subpath, color: fillColor });
}
```

**Hands Bounding Box Check:**
```javascript
function isWithinHandsBounds(point) {
  return point.x >= 175 && point.x <= 385 &&
         point.y >= 250 && point.y <= 470;
}
```

### 4. SVG Generation
- Create individual SVG files with isolated paths
- Create combined SVG with `<g>` elements:
  ```xml
  <g id="layer-medallion">...</g>
  <g id="layer-background">...</g>
  <g id="layer-primary">...</g>
  <g id="layer-secondary">...</g>
  ```

### 5. Validation
- Visual comparison with original PNG
- Verify no missing regions
- Check layer boundaries align at edges

## Technical Approach

**Path Decomposition:**
SVG paths contain multiple subpaths separated by `M` (moveto) commands. Each closed subpath (ending with `Z`) represents a distinct region.

**Centroid Calculation:**
For bezier curves, approximate centroid using:
```
centroid = average(control_points) per subpath
```

**Distance-based Classification:**
```javascript
function classifyPoint(x, y, centerX=265, centerY=310) {
  const dist = Math.sqrt((x-centerX)**2 + (y-centerY)**2);
  if (dist > 200) return 'medallion';
  if (dist > 150 && !inHandsBounds(x,y)) return 'background';
  if (isSmallConvex(subpath)) return 'secondary';
  return 'primary';
}
```

## Files to Create/Modify
- `scripts/svg-layer-parser.js` - Parser and classifier
- `assets/layers/*.svg` - Output layer files

## Dependencies
- Node.js for script execution
- `svg-path-parser` npm package (or manual regex parsing)

## Risk Assessment
- **Complex overlapping regions**: Some colors span multiple layers
- **Bezier curve accuracy**: Centroid approximation may misclassify edge cases
- **Manual refinement**: May need post-processing for pixel-perfect results

## Expected Output Structure

```xml
<!-- diamond_hands_layered.svg -->
<svg xmlns="http://www.w3.org/2000/svg" width="530" height="568" viewBox="0 0 530 568">
  <g id="layer-medallion" data-description="Circular frame with hoop and chain">
    <!-- Paths for outer ring, rim, chain, hoop -->
  </g>
  <g id="layer-background" data-description="Polished metallic surface">
    <!-- Paths for inner gold surface -->
  </g>
  <g id="layer-primary" data-description="Hands grasping with diamond above">
    <!-- Paths for hands contour and large diamond -->
  </g>
  <g id="layer-secondary" data-description="Diamond studs within hands">
    <!-- Paths for small diamond shapes on hands -->
  </g>
</svg>
```

## Execution Summary
1. Parse 16-colour SVG (16 paths × ~100s of subpaths)
2. Classify ~500-1000 subpaths by geometric region
3. Generate 5 output files (4 individual + 1 combined)
4. Visual validation against source PNG

---

## Implementation Complete (Perspective-Corrected)

**Script:** `scripts/svg-layer-parser.js`

**Perspective Correction Applied:**
The medallion is viewed at an angle (tilted UP and LEFT), requiring elliptical geometry:
- Ellipse Center: (270, 330)
- Horizontal Semi-Axis: 232px
- Vertical Semi-Axis: 214px
- Outer Ring Threshold: ellipseDist > 0.82

**Results:**
| Layer | Subpaths | File Size |
|-------|----------|-----------|
| medallion | 273 | 99KB |
| background | 362 | 149KB |
| primary | 166 | 282KB |
| secondary | 405 | 83KB |
| **combined** | 1206 | 613KB |

**Output Files:**
```
assets/layers/
├── medallion.svg           # 99KB - Frame + chain + hoop
├── background.svg          # 149KB - Inner metallic surface
├── primary.svg             # 282KB - Hands + large diamond
├── secondary.svg           # 83KB - Diamond studs on hands
└── diamond_hands_layered.svg  # 613KB - Combined with <g> groups
```

**Run Command:**
```bash
node scripts/svg-layer-parser.js
```

---

## Vector Tracing Comparison (Advanced)

Two additional approaches were implemented to compare vector tracing accuracy:

### Approach 1: Raster Mask Tracing
- Generate binary masks from PNG using ellipse geometry + color clustering
- Apply masks to extract layer pixels
- Trace each layer with potrace (silhouette) or autotrace (color)

**Output:** `assets/layers_v2_raster/` (968KB total)

### Approach 2: Boundary Contour Clipping
- Define mathematical ellipse contours as SVG clipPaths
- Apply clipPaths to existing 16-color vectors
- Preserves original bezier curves and colors

**Output:** `assets/layers_v2_clipped/` (600KB total)

### Comparison Results

| Metric | Raster Tracing | Contour Clipping |
|--------|---------------|------------------|
| Total Size | 968 KB | **600 KB** |
| Color Fidelity | Re-quantized | **Original 16** |
| Curve Quality | Re-traced | **Original** |
| Edge Precision | Pixel-based | **Mathematical** |

**Winner:** Contour Clipping - 38% smaller, preserves quality.

**Comparison Viewer:** `assets/comparison/compare.html`

**Scripts:**
```bash
# Approach 1
python3 scripts/generate_masks.py && ./scripts/trace_layers.sh

# Approach 2
node scripts/define_contours.js && node scripts/generate_clipped_layers.js
```
