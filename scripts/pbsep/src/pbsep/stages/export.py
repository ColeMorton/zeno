"""Stage 8: Export 1-bit PNG and generate output artifacts."""

import json
import subprocess
from pathlib import Path

import cv2
import numpy as np

from pbsep.stages.vectorize import vectorize_bitmap


def pack_bitmap(binary: np.ndarray, invert: bool = False) -> bytes:
    """
    Pack binary image to 1-bit bitmap (MSB-first, row-major).

    Args:
        binary: Binary image as uint8 (0 or 255)
        invert: If True, light areas become foreground

    Returns:
        Packed bitmap bytes
    """
    # Foreground = black pixels (0) by default, or white if inverted
    if invert:
        foreground = binary.flatten() > 127
    else:
        foreground = binary.flatten() < 128

    # Pack 8 pixels per byte, MSB first
    packed = np.packbits(foreground.astype(np.uint8))
    return bytes(packed)


def generate_rect_svg(binary: np.ndarray, size: int, invert: bool = False) -> str:
    """
    Generate rect-based SVG preview.

    Args:
        binary: Binary image as uint8 (0 or 255)
        size: Image dimension
        invert: If True, light areas become foreground

    Returns:
        SVG string
    """
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {size} {size}" shape-rendering="crispEdges">\n'

    for y in range(size):
        for x in range(size):
            pixel = binary[y, x]
            is_foreground = (pixel > 127) if invert else (pixel < 128)
            if is_foreground:
                svg += f'<rect x="{x}" y="{y}" width="1" height="1" fill="#000000"/>\n'

    svg += "</svg>"
    return svg


def export_outputs(
    binary: np.ndarray,
    output_dir: Path,
    output_name: str,
    size: int,
    invert: bool,
    metadata: dict,
    vectorize: bool = True,
) -> tuple[bytes, Path, Path, Path]:
    """
    Export all output artifacts.

    Args:
        binary: Binary image as uint8 (0 or 255)
        output_dir: Output directory
        output_name: Base name for output files
        size: Image dimension
        invert: If True, light areas become foreground
        metadata: Metadata dictionary
        vectorize: If True, use potrace for smooth bezier SVG

    Returns:
        Tuple of (bitmap_bytes, svg_path, png_path, metadata_path)
    """
    output_dir.mkdir(parents=True, exist_ok=True)

    # Pack bitmap
    bitmap = pack_bitmap(binary, invert)

    # Save raw bitmap for on-chain storage
    bin_path = output_dir / f"{output_name}_{size}x{size}.bin"
    bin_path.write_bytes(bitmap)

    # Generate SVG preview
    if vectorize:
        svg = vectorize_bitmap(binary, size, invert)
    else:
        svg = generate_rect_svg(binary, size, invert)

    svg_path = output_dir / f"{output_name}_{size}x{size}_1bit.svg"
    svg_path.write_text(svg)

    # Generate PNG preview using ImageMagick
    png_path = output_dir / f"{output_name}_{size}x{size}_1bit.png"
    subprocess.run(
        [
            "magick",
            str(svg_path),
            "-background",
            "white",
            "-flatten",
            str(png_path),
        ],
        check=True,
        capture_output=True,
    )

    # Write metadata
    metadata_path = output_dir / f"{output_name}_{size}x{size}_metadata.json"
    metadata_path.write_text(json.dumps(metadata, indent=2))

    return bitmap, svg_path, png_path, metadata_path
