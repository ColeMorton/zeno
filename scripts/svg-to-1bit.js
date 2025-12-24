#!/usr/bin/env node
/**
 * SVG to 1-bit Bitmap Converter
 * Converts SVG pixel art to monochrome bitmap for on-chain storage
 *
 * Usage: node svg-to-1bit.js <input.svg> <output_name> [--size 128|256] [--crop "x,y,w,h"]
 *
 * Supported sizes:
 * - 128×128: 2,048 bytes bitmap
 * - 256×256: 8,192 bytes bitmap
 *
 * Output:
 * - assets/<output_name>_<size>x<size>_1bit.svg (preview)
 * - assets/<output_name>_<size>x<size>_metadata.json
 * - Solidity library file
 */

const fs = require('fs');
const path = require('path');

function parseArgs() {
    const args = process.argv.slice(2);
    if (args.length < 2) {
        console.error('Usage: node svg-to-1bit.js <input.svg> <output_name> [--size 128|256] [--crop "x,y,w,h"]');
        process.exit(1);
    }

    const config = {
        input: args[0],
        outputName: args[1],
        size: 128,
        crop: null
    };

    const sizeIndex = args.indexOf('--size');
    if (sizeIndex !== -1 && args[sizeIndex + 1]) {
        const size = parseInt(args[sizeIndex + 1], 10);
        if (size !== 128 && size !== 256) {
            console.error('Error: --size must be 128 or 256');
            process.exit(1);
        }
        config.size = size;
    }

    const cropIndex = args.indexOf('--crop');
    if (cropIndex !== -1 && args[cropIndex + 1]) {
        const [x, y, w, h] = args[cropIndex + 1].split(',').map(Number);
        config.crop = { x, y, width: w, height: h };
    }

    return config;
}

function parseSVG(content) {
    // Extract viewBox
    const viewBoxMatch = content.match(/viewBox="([^"]+)"/);
    const [vbX, vbY, vbWidth, vbHeight] = viewBoxMatch
        ? viewBoxMatch[1].split(/\s+/).map(Number)
        : [0, 0, 64, 64];

    // Extract all rect elements
    const rectRegex = /<rect[^>]+>/g;
    const rects = [];
    let match;

    while ((match = rectRegex.exec(content)) !== null) {
        const rect = match[0];
        const x = parseFloat(rect.match(/x="([^"]+)"/)?.[1] || 0);
        const y = parseFloat(rect.match(/y="([^"]+)"/)?.[1] || 0);
        const width = parseFloat(rect.match(/width="([^"]+)"/)?.[1] || 1);
        const height = parseFloat(rect.match(/height="([^"]+)"/)?.[1] || 1);
        const fill = rect.match(/fill="([^"]+)"/)?.[1] || '#000000';

        // Skip transparent pixels
        if (fill === 'none' || fill === 'transparent') continue;

        rects.push({ x, y, width, height, fill });
    }

    return { viewBox: { x: vbX, y: vbY, width: vbWidth, height: vbHeight }, rects };
}

function createBitmap(rects, sourceViewBox, crop, size) {
    const bytesPerRow = size / 8;
    const totalBytes = size * bytesPerRow;
    const bitmap = new Uint8Array(totalBytes);
    let opaqueCount = 0;

    // Determine source region
    const source = crop || sourceViewBox;

    for (const rect of rects) {
        // Map source coordinates to target size
        const srcX = rect.x - source.x;
        const srcY = rect.y - source.y;

        // Scale to target size
        const destX = Math.floor((srcX / source.width) * size);
        const destY = Math.floor((srcY / source.height) * size);
        const destWidth = Math.max(1, Math.round((rect.width / source.width) * size));
        const destHeight = Math.max(1, Math.round((rect.height / source.height) * size));

        // Fill pixels
        for (let dy = 0; dy < destHeight; dy++) {
            for (let dx = 0; dx < destWidth; dx++) {
                const px = destX + dx;
                const py = destY + dy;

                if (px >= 0 && px < size && py >= 0 && py < size) {
                    const pixelIndex = py * size + px;
                    const byteIndex = Math.floor(pixelIndex / 8);
                    const bitPosition = 7 - (pixelIndex % 8);

                    if ((bitmap[byteIndex] & (1 << bitPosition)) === 0) {
                        bitmap[byteIndex] |= (1 << bitPosition);
                        opaqueCount++;
                    }
                }
            }
        }
    }

    return { bitmap, opaqueCount, totalBytes };
}

function bitmapToHex(bitmap) {
    return Array.from(bitmap)
        .map(b => b.toString(16).padStart(2, '0'))
        .join('');
}

function generatePreviewSVG(bitmap, size, color = '#000000') {
    let svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${size} ${size}" shape-rendering="crispEdges">\n`;

    for (let y = 0; y < size; y++) {
        for (let x = 0; x < size; x++) {
            const pixelIndex = y * size + x;
            const byteIndex = Math.floor(pixelIndex / 8);
            const bitPosition = 7 - (pixelIndex % 8);

            if ((bitmap[byteIndex] >> bitPosition) & 1) {
                svg += `<rect x="${x}" y="${y}" width="1" height="1" fill="${color}"/>\n`;
            }
        }
    }

    svg += '</svg>';
    return svg;
}

function generateSolidityLibrary(name, hexBitmap, size, totalBytes, color = '000000') {
    const libName = name.charAt(0).toUpperCase() + name.slice(1) + `${size}Mono`;
    const renderFunc = size === 256 ? 'render1bit256' : 'render1bit128';

    return `// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PixelArtRenderer} from "./PixelArtRenderer.sol";

/**
 * @title ${libName}
 * @dev On-chain pixel art storage (${size}x${size}, monochrome 1-bit)
 * @notice Generated by svg-to-1bit.js - Do not edit manually
 */
library ${libName} {
    /// @notice Foreground color (RGB)
    function getColor() internal pure returns (bytes3) {
        return hex"${color}";
    }

    /// @notice ${size}x${size} pixel bitmap, 1-bit (${totalBytes} bytes)
    function getBitmap() internal pure returns (bytes memory) {
        return hex"${hexBitmap}";
    }

    /// @notice Render as SVG string
    function getSVG() internal pure returns (string memory) {
        return PixelArtRenderer.${renderFunc}(getColor(), getBitmap());
    }
}
`;
}

function main() {
    const config = parseArgs();
    const size = config.size;

    // Read input SVG
    const inputPath = path.resolve(config.input);
    if (!fs.existsSync(inputPath)) {
        console.error(`File not found: ${inputPath}`);
        process.exit(1);
    }

    const svgContent = fs.readFileSync(inputPath, 'utf-8');
    const { viewBox, rects } = parseSVG(svgContent);

    console.log(`Target size: ${size}x${size}`);
    console.log(`Parsed ${rects.length} rect elements`);
    console.log(`ViewBox: ${viewBox.x},${viewBox.y},${viewBox.width},${viewBox.height}`);

    if (config.crop) {
        console.log(`Crop: ${config.crop.x},${config.crop.y},${config.crop.width},${config.crop.height}`);
    }

    // Generate bitmap
    const { bitmap, opaqueCount, totalBytes } = createBitmap(rects, viewBox, config.crop, size);
    const hexBitmap = bitmapToHex(bitmap);

    console.log(`\nOpaque pixels: ${opaqueCount} / ${size * size} (${((opaqueCount / (size * size)) * 100).toFixed(1)}%)`);
    console.log(`Bitmap size: ${totalBytes} bytes`);

    // Generate outputs
    const assetsDir = path.join(path.dirname(inputPath), '..', 'assets');

    // Preview SVG
    const previewSVG = generatePreviewSVG(bitmap, size);
    const previewPath = path.join(assetsDir, `${config.outputName}_${size}x${size}_1bit.svg`);
    fs.writeFileSync(previewPath, previewSVG);
    console.log(`\nPreview: ${previewPath}`);

    // Metadata
    const metadata = {
        source: inputPath,
        size: size,
        format: '1-bit monochrome',
        crop: config.crop,
        opaquePixels: opaqueCount,
        totalPixels: size * size,
        bytes: totalBytes
    };
    const metadataPath = path.join(assetsDir, `${config.outputName}_${size}x${size}_metadata.json`);
    fs.writeFileSync(metadataPath, JSON.stringify(metadata, null, 2));
    console.log(`Metadata: ${metadataPath}`);

    // Solidity library
    const solidityCode = generateSolidityLibrary(config.outputName, hexBitmap, size, totalBytes);
    const solidityPath = path.join(assetsDir, `${config.outputName.charAt(0).toUpperCase() + config.outputName.slice(1)}${size}Mono.sol`);
    fs.writeFileSync(solidityPath, solidityCode);
    console.log(`Solidity: ${solidityPath}`);

    // Output hex to stdout
    console.log(`\nBitmap hex (${hexBitmap.length / 2} bytes):`);
    console.log(hexBitmap);
}

main();
