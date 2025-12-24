#!/usr/bin/env node
/**
 * SVG to Pixel Art Converter
 *
 * Converts SVG to pixel art with 16-color indexed palette.
 * Index 0 reserved for transparent pixels.
 *
 * Usage: node svg-to-pixelart.js <input.svg> [output-prefix] [options]
 *
 * Options:
 *   --size <n>       Output resolution (default: 64)
 *   --crop <x,y,w,h> Crop region in original viewBox units
 *
 * Examples:
 *   node svg-to-pixelart.js input.svg output
 *   node svg-to-pixelart.js input.svg output --size 128
 *   node svg-to-pixelart.js input.svg output --size 128 --crop "100,106,330,356"
 *
 * Dependencies: npm install sharp
 */

const fs = require('fs');
const path = require('path');

// Default configuration
const CONFIG = {
  size: 64,
  maxColors: 16,
  transparentIndex: 0,
  crop: null, // { x, y, width, height }
};

/**
 * Parse command line arguments
 */
function parseArgs(args) {
  const result = {
    inputPath: null,
    outputPrefix: null,
    size: CONFIG.size,
    crop: null,
  };

  let i = 0;
  while (i < args.length) {
    if (args[i] === '--size' && args[i + 1]) {
      result.size = parseInt(args[i + 1], 10);
      i += 2;
    } else if (args[i] === '--crop' && args[i + 1]) {
      const parts = args[i + 1].split(',').map(n => parseFloat(n.trim()));
      if (parts.length === 4) {
        result.crop = { x: parts[0], y: parts[1], width: parts[2], height: parts[3] };
      }
      i += 2;
    } else if (!result.inputPath) {
      result.inputPath = args[i];
      i++;
    } else if (!result.outputPrefix) {
      result.outputPrefix = args[i];
      i++;
    } else {
      i++;
    }
  }

  return result;
}

/**
 * Modify SVG to apply crop (change viewBox)
 */
function applyCropToSVG(svgContent, crop) {
  if (!crop) return svgContent;

  // Replace viewBox attribute
  const viewBoxRegex = /viewBox="[^"]*"/;
  const newViewBox = `viewBox="${crop.x} ${crop.y} ${crop.width} ${crop.height}"`;

  if (viewBoxRegex.test(svgContent)) {
    return svgContent.replace(viewBoxRegex, newViewBox);
  }

  // If no viewBox, add one after <svg
  return svgContent.replace(/<svg\s/, `<svg ${newViewBox} `);
}

/**
 * Convert RGB to grayscale luminance
 */
function rgbToLuminance(r, g, b) {
  return Math.round(0.299 * r + 0.587 * g + 0.114 * b);
}

/**
 * Convert RGB to hex color string
 */
function rgbToHex(r, g, b) {
  return '#' + [r, g, b].map(c => c.toString(16).padStart(2, '0')).join('');
}

/**
 * Euclidean distance between two colors
 */
function colorDistance(c1, c2) {
  const dr = c1.r - c2.r;
  const dg = c1.g - c2.g;
  const db = c1.b - c2.b;
  return Math.sqrt(dr * dr + dg * dg + db * db);
}

/**
 * Find nearest color in palette
 */
function findNearestColor(color, palette) {
  let minDist = Infinity;
  let nearest = 0;

  for (let i = 1; i < palette.length; i++) { // Skip index 0 (transparent)
    const dist = colorDistance(color, palette[i]);
    if (dist < minDist) {
      minDist = dist;
      nearest = i;
    }
  }

  return nearest;
}

/**
 * Median cut quantization to generate palette
 */
function quantize(pixels, maxColors) {
  // Collect unique non-transparent colors
  const colors = [];

  for (let i = 0; i < pixels.length; i += 4) {
    const r = pixels[i];
    const g = pixels[i + 1];
    const b = pixels[i + 2];
    const a = pixels[i + 3];

    // Skip transparent pixels
    if (a < 128) continue;

    colors.push({ r, g, b });
  }

  if (colors.length === 0) {
    throw new Error('No opaque pixels found in image');
  }

  // Simple median cut implementation
  function medianCut(colorList, depth) {
    if (depth === 0 || colorList.length <= 1) {
      // Return average color of the bucket
      const avg = { r: 0, g: 0, b: 0 };
      colorList.forEach(c => {
        avg.r += c.r;
        avg.g += c.g;
        avg.b += c.b;
      });
      avg.r = Math.round(avg.r / colorList.length);
      avg.g = Math.round(avg.g / colorList.length);
      avg.b = Math.round(avg.b / colorList.length);
      return [avg];
    }

    // Find channel with greatest range
    let rMin = 255, rMax = 0, gMin = 255, gMax = 0, bMin = 255, bMax = 0;
    colorList.forEach(c => {
      rMin = Math.min(rMin, c.r); rMax = Math.max(rMax, c.r);
      gMin = Math.min(gMin, c.g); gMax = Math.max(gMax, c.g);
      bMin = Math.min(bMin, c.b); bMax = Math.max(bMax, c.b);
    });

    const rRange = rMax - rMin;
    const gRange = gMax - gMin;
    const bRange = bMax - bMin;

    let sortChannel;
    if (rRange >= gRange && rRange >= bRange) {
      sortChannel = 'r';
    } else if (gRange >= bRange) {
      sortChannel = 'g';
    } else {
      sortChannel = 'b';
    }

    // Sort by that channel and split
    colorList.sort((a, b) => a[sortChannel] - b[sortChannel]);
    const mid = Math.floor(colorList.length / 2);

    return [
      ...medianCut(colorList.slice(0, mid), depth - 1),
      ...medianCut(colorList.slice(mid), depth - 1),
    ];
  }

  // Calculate depth for maxColors - 1 (reserve index 0 for transparent)
  const paletteSize = maxColors - 1;
  const depth = Math.ceil(Math.log2(paletteSize));

  let palette = medianCut([...colors], depth);

  // Ensure we have exactly paletteSize colors (pad with black if needed)
  while (palette.length < paletteSize) {
    palette.push({ r: 0, g: 0, b: 0 });
  }

  // Truncate if we have too many
  palette = palette.slice(0, paletteSize);

  // Insert transparent at index 0
  palette.unshift({ r: 0, g: 0, b: 0, transparent: true });

  return palette;
}

/**
 * Apply Floyd-Steinberg dithering
 */
function applyDithering(pixels, width, height, palette) {
  const indexed = new Uint8Array(width * height);
  const errors = new Float32Array(width * height * 3); // RGB error buffer

  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const idx = (y * width + x) * 4;
      const errIdx = (y * width + x) * 3;

      const a = pixels[idx + 3];

      // Transparent pixel
      if (a < 128) {
        indexed[y * width + x] = CONFIG.transparentIndex;
        continue;
      }

      // Get color with accumulated error
      const r = Math.max(0, Math.min(255, pixels[idx] + errors[errIdx]));
      const g = Math.max(0, Math.min(255, pixels[idx + 1] + errors[errIdx + 1]));
      const b = Math.max(0, Math.min(255, pixels[idx + 2] + errors[errIdx + 2]));

      const color = { r, g, b };

      // Find nearest palette color
      const nearestIdx = findNearestColor(color, palette);
      indexed[y * width + x] = nearestIdx;

      const nearest = palette[nearestIdx];

      // Calculate quantization error
      const errR = r - nearest.r;
      const errG = g - nearest.g;
      const errB = b - nearest.b;

      // Floyd-Steinberg error distribution
      const distribute = (dx, dy, factor) => {
        const nx = x + dx;
        const ny = y + dy;
        if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
          const nErrIdx = (ny * width + nx) * 3;
          errors[nErrIdx] += errR * factor;
          errors[nErrIdx + 1] += errG * factor;
          errors[nErrIdx + 2] += errB * factor;
        }
      };

      distribute(1, 0, 7 / 16);  // Right
      distribute(-1, 1, 3 / 16); // Bottom-left
      distribute(0, 1, 5 / 16);  // Bottom
      distribute(1, 1, 1 / 16);  // Bottom-right
    }
  }

  return indexed;
}

/**
 * Pack 4-bit indexed pixels into bytes (two pixels per byte)
 */
function packBitmap(indexed) {
  const packed = new Uint8Array(Math.ceil(indexed.length / 2));

  for (let i = 0; i < indexed.length; i += 2) {
    const high = indexed[i] & 0x0F;
    const low = (indexed[i + 1] || 0) & 0x0F;
    packed[i / 2] = (high << 4) | low;
  }

  return packed;
}

/**
 * Convert palette to bytes (RGB triplets)
 */
function packPalette(palette) {
  const packed = new Uint8Array(palette.length * 3);

  for (let i = 0; i < palette.length; i++) {
    packed[i * 3] = palette[i].r;
    packed[i * 3 + 1] = palette[i].g;
    packed[i * 3 + 2] = palette[i].b;
  }

  return packed;
}

/**
 * Convert bytes to Solidity hex literal
 */
function toHexLiteral(bytes) {
  return 'hex"' + Array.from(bytes).map(b => b.toString(16).padStart(2, '0')).join('') + '"';
}

/**
 * Generate preview SVG from indexed pixels
 */
function generatePreviewSVG(indexed, palette, size) {
  let svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${size} ${size}" width="${size * 8}" height="${size * 8}" shape-rendering="crispEdges">`;
  svg += `<rect width="${size}" height="${size}" fill="none"/>`;

  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const idx = indexed[y * size + x];
      if (idx === CONFIG.transparentIndex) continue;

      const color = palette[idx];
      const hex = rgbToHex(color.r, color.g, color.b);
      svg += `<rect x="${x}" y="${y}" width="1" height="1" fill="${hex}"/>`;
    }
  }

  svg += '</svg>';
  return svg;
}

/**
 * Generate Solidity library code
 */
function generateSolidity(name, packedPalette, packedBitmap, palette, size) {
  const paletteHex = toHexLiteral(packedPalette);
  const bitmapHex = toHexLiteral(packedBitmap);
  const bitmapBytes = size * size / 2;
  const renderFunc = size === 128 ? 'render128' : 'render';

  return `// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PixelArtRenderer} from "./PixelArtRenderer.sol";

/**
 * @title ${name}
 * @dev On-chain pixel art storage (${size}x${size}, 16-color indexed)
 * @notice Generated by svg-to-pixelart.js - Do not edit manually
 *
 * Palette (${palette.length} colors):
 * ${palette.map((c, i) => `  [${i}] ${c.transparent ? 'transparent' : rgbToHex(c.r, c.g, c.b)}`).join('\n * ')}
 */
library ${name} {
    /// @notice 16-color RGB palette (48 bytes)
    function getPalette() internal pure returns (bytes memory) {
        return ${paletteHex};
    }

    /// @notice ${size}x${size} pixel bitmap, 4-bit indexed (${bitmapBytes} bytes)
    function getBitmap() internal pure returns (bytes memory) {
        return ${bitmapHex};
    }

    /// @notice Render as SVG data URI
    function getSVG() internal pure returns (string memory) {
        return PixelArtRenderer.${renderFunc}(getPalette(), getBitmap());
    }
}
`;
}

async function main() {
  const rawArgs = process.argv.slice(2);
  const args = parseArgs(rawArgs);

  if (!args.inputPath) {
    console.log('Usage: node svg-to-pixelart.js <input.svg> [output-prefix] [options]');
    console.log('');
    console.log('Options:');
    console.log('  --size <n>       Output resolution (default: 64)');
    console.log('  --crop <x,y,w,h> Crop region in original viewBox units');
    console.log('');
    console.log('Examples:');
    console.log('  node svg-to-pixelart.js input.svg output');
    console.log('  node svg-to-pixelart.js input.svg output --size 128');
    console.log('  node svg-to-pixelart.js input.svg output --size 128 --crop "100,106,330,356"');
    console.log('');
    console.log('Dependencies: npm install sharp');
    process.exit(1);
  }

  const inputPath = path.resolve(args.inputPath);
  const outputPrefix = args.outputPrefix || path.basename(inputPath, path.extname(inputPath));
  const outputDir = path.dirname(inputPath);
  const size = args.size;
  const crop = args.crop;

  console.log(`Converting ${inputPath} to ${size}x${size} pixel art...`);
  if (crop) {
    console.log(`  Crop region: x=${crop.x}, y=${crop.y}, w=${crop.width}, h=${crop.height}`);
  }

  // Dynamic import for sharp (ESM compatibility)
  let sharp;
  try {
    sharp = require('sharp');
  } catch (e) {
    console.error('Error: sharp not installed. Run: npm install sharp');
    process.exit(1);
  }

  // Read SVG and optionally apply crop
  let svgContent = fs.readFileSync(inputPath, 'utf8');
  if (crop) {
    svgContent = applyCropToSVG(svgContent, crop);
  }

  // Rasterize SVG from buffer
  console.log('  Rasterizing SVG...');
  const { data, info } = await sharp(Buffer.from(svgContent))
    .resize(size, size, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } })
    .raw()
    .toBuffer({ resolveWithObject: true });

  console.log(`  Input: ${info.width}x${info.height}, ${info.channels} channels`);

  // Generate palette via median cut
  console.log('  Quantizing to 16 colors...');
  const palette = quantize(data, CONFIG.maxColors);

  console.log('  Palette:');
  palette.forEach((c, i) => {
    if (c.transparent) {
      console.log(`    [${i}] transparent`);
    } else {
      console.log(`    [${i}] ${rgbToHex(c.r, c.g, c.b)}`);
    }
  });

  // Apply dithering and index pixels
  console.log('  Applying Floyd-Steinberg dithering...');
  const indexed = applyDithering(data, size, size, palette);

  // Count non-transparent pixels
  let opaqueCount = 0;
  for (let i = 0; i < indexed.length; i++) {
    if (indexed[i] !== CONFIG.transparentIndex) opaqueCount++;
  }
  console.log(`  Opaque pixels: ${opaqueCount}/${size * size} (${Math.round(opaqueCount / (size * size) * 100)}%)`);

  // Pack for Solidity
  console.log('  Packing bitmap...');
  const packedPalette = packPalette(palette);
  const packedBitmap = packBitmap(indexed);

  console.log(`  Palette size: ${packedPalette.length} bytes`);
  console.log(`  Bitmap size: ${packedBitmap.length} bytes`);
  console.log(`  Total: ${packedPalette.length + packedBitmap.length} bytes`);

  // Generate outputs
  const libraryName = outputPrefix.replace(/[^a-zA-Z0-9]/g, '').replace(/^(\d)/, '_$1');
  const solLibName = libraryName.charAt(0).toUpperCase() + libraryName.slice(1) + 'PixelArt';

  // Preview SVG
  const previewSVG = generatePreviewSVG(indexed, palette, size);
  const previewPath = path.join(outputDir, `${outputPrefix}_${size}x${size}.svg`);
  fs.writeFileSync(previewPath, previewSVG);
  console.log(`  Preview SVG: ${previewPath}`);

  // Solidity library
  const solidity = generateSolidity(solLibName, packedPalette, packedBitmap, palette, size);
  const solidityPath = path.join(outputDir, `${solLibName}.sol`);
  fs.writeFileSync(solidityPath, solidity);
  console.log(`  Solidity library: ${solidityPath}`);

  // JSON metadata for debugging
  const metadata = {
    source: inputPath,
    size: size,
    crop: crop,
    palette: palette.map((c, i) => ({
      index: i,
      transparent: c.transparent || false,
      hex: c.transparent ? null : rgbToHex(c.r, c.g, c.b),
      rgb: c.transparent ? null : [c.r, c.g, c.b],
    })),
    opaquePixels: opaqueCount,
    totalPixels: size * size,
    bytes: {
      palette: packedPalette.length,
      bitmap: packedBitmap.length,
      total: packedPalette.length + packedBitmap.length,
    },
  };
  const metadataPath = path.join(outputDir, `${outputPrefix}_metadata.json`);
  fs.writeFileSync(metadataPath, JSON.stringify(metadata, null, 2));
  console.log(`  Metadata: ${metadataPath}`);

  console.log('\nDone!');
}

main().catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});
