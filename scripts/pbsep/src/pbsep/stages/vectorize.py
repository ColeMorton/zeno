"""Vector tracing using potrace for smooth bezier curves."""

import subprocess
import tempfile
from pathlib import Path

import numpy as np

from pbsep.types import PipelineError


def vectorize_bitmap(
    binary: np.ndarray,
    size: int,
    invert: bool = False,
    turdsize: int = 2,
    alphamax: float = 1.0,
    opttolerance: float = 0.2,
) -> str:
    """
    Convert binary bitmap to SVG using potrace for smooth bezier curves.

    Args:
        binary: Binary image as uint8 (0 or 255)
        size: Output SVG dimension
        invert: If True, light areas become foreground
        turdsize: Suppress speckles up to this size (default 2)
        alphamax: Corner threshold parameter (default 1.0)
        opttolerance: Curve optimization tolerance (default 0.2)

    Returns:
        SVG string with bezier paths
    """
    # Potrace traces white (foreground) pixels in PBM
    # Invert determines which pixels are foreground
    if invert:
        foreground = binary > 127
    else:
        foreground = binary < 128

    # Create temporary PBM file
    with tempfile.NamedTemporaryFile(suffix=".pbm", delete=False) as pbm_file:
        pbm_path = Path(pbm_file.name)

        # Write PBM header and data
        # PBM format: P4 (binary) or P1 (ASCII)
        height, width = foreground.shape
        pbm_file.write(f"P4\n{width} {height}\n".encode())

        # Pack bits (8 pixels per byte, MSB first)
        packed = np.packbits(foreground.astype(np.uint8), axis=1)
        pbm_file.write(packed.tobytes())

    try:
        # Run potrace
        result = subprocess.run(
            [
                "potrace",
                "-s",  # SVG output
                "-t",
                str(turdsize),  # Turd size
                "-a",
                str(alphamax),  # Corner threshold
                "-O",
                str(opttolerance),  # Optimization tolerance
                "-W",
                f"{size}pt",  # Width
                "-H",
                f"{size}pt",  # Height
                "--tight",  # Remove whitespace
                str(pbm_path),
                "-o",
                "-",  # Output to stdout
            ],
            capture_output=True,
            check=True,
            text=True,
        )

        svg_content = result.stdout

        # Normalize SVG viewBox to match our size
        svg_content = _normalize_svg_viewbox(svg_content, size)

        return svg_content

    except subprocess.CalledProcessError as e:
        raise PipelineError(f"Potrace failed: {e.stderr}") from e
    except FileNotFoundError:
        raise PipelineError(
            "potrace not found. Install with: brew install potrace"
        ) from None
    finally:
        # Clean up temp file
        pbm_path.unlink(missing_ok=True)


def _normalize_svg_viewbox(svg: str, size: int) -> str:
    """
    Normalize potrace SVG output to standard viewBox.

    Potrace outputs SVG with arbitrary viewBox based on content.
    We normalize to 0 0 size size for consistency.
    """
    import re

    # Replace viewBox with normalized version
    svg = re.sub(
        r'viewBox="[^"]*"',
        f'viewBox="0 0 {size} {size}"',
        svg,
    )

    # Replace width/height attributes
    svg = re.sub(r'width="[^"]*"', f'width="{size}"', svg)
    svg = re.sub(r'height="[^"]*"', f'height="{size}"', svg)

    return svg
