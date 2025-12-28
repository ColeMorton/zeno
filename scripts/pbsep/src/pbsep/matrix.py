"""Matrix configuration batch processing for parameter exploration."""

from dataclasses import dataclass
from pathlib import Path

import cv2
import numpy as np

from pbsep.stages import (
    apply_morphological_correction,
    binarize,
    downscale,
    enhance_local_contrast,
    export_outputs,
    extract_luminance,
    normalize_input,
)
from pbsep.types import (
    BinarizeParams,
    ContrastParams,
    DownscaleParams,
    ExportParams,
    LuminanceParams,
    MorphologyParams,
    NormalizeParams,
    PipelineError,
)


@dataclass
class MatrixConfig:
    """Single configuration in the matrix."""

    id: int
    method: str = "canny"  # "canny", "adaptive_gaussian", "adaptive_mean"

    # Common params
    pre_blur_sigma: float = 0.5
    pipeline_order: str = "down_edge"  # "down_edge" or "edge_down"

    # Canny-specific params
    low_threshold: int = 50
    high_threshold: int = 150
    dilate_iterations: int = 0
    dilate_kernel: int = 0

    # Adaptive threshold-specific params
    block_size: int = 15
    c_constant: int = 5
    use_clahe: bool = False

    # Morphology params
    erode_iterations: int = 0
    skeletonize: bool = False


@dataclass
class MatrixResult:
    """Result from a single matrix configuration run."""

    config: MatrixConfig
    opaque_count: int
    total_pixels: int
    opacity_pct: float
    png_path: Path


# Phase 20: Adaptive-only matrix - No block=7, opacity ≥16% (10 configs)
MATRIX_CONFIGS = [
    # block_size=9
    MatrixConfig(1, method="adaptive_gaussian", pre_blur_sigma=0.0,
                 block_size=9, c_constant=2, use_clahe=False),
    MatrixConfig(2, method="adaptive_gaussian", pre_blur_sigma=0.0,
                 block_size=9, c_constant=2, use_clahe=True),
    MatrixConfig(3, method="adaptive_gaussian", pre_blur_sigma=0.0,
                 block_size=9, c_constant=3, use_clahe=False),
    MatrixConfig(4, method="adaptive_gaussian", pre_blur_sigma=0.0,
                 block_size=9, c_constant=3, use_clahe=True),

    # block_size=11
    MatrixConfig(5, method="adaptive_gaussian", pre_blur_sigma=0.0,
                 block_size=11, c_constant=2, use_clahe=False),
    MatrixConfig(6, method="adaptive_gaussian", pre_blur_sigma=0.0,
                 block_size=11, c_constant=2, use_clahe=True),
    MatrixConfig(7, method="adaptive_gaussian", pre_blur_sigma=0.0,
                 block_size=11, c_constant=3, use_clahe=False),
    MatrixConfig(8, method="adaptive_gaussian", pre_blur_sigma=0.0,
                 block_size=11, c_constant=3, use_clahe=True),

    # block_size=15
    MatrixConfig(9, method="adaptive_gaussian", pre_blur_sigma=0.0,
                 block_size=15, c_constant=2, use_clahe=True),
    MatrixConfig(10, method="adaptive_gaussian", pre_blur_sigma=0.0,
                 block_size=15, c_constant=3, use_clahe=True),
]


def run_matrix(
    input_path: Path,
    output_dir: Path,
    output_name: str,
    size: int = 256,
) -> list[MatrixResult]:
    """
    Run all matrix configurations and generate comparison outputs.

    Args:
        input_path: Input image path
        output_dir: Output directory for matrix results
        output_name: Base name for outputs
        size: Target size (128 or 256)

    Returns:
        List of MatrixResult for each configuration
    """
    output_dir.mkdir(parents=True, exist_ok=True)

    # Load and prepare image once
    image = cv2.imread(str(input_path), cv2.IMREAD_COLOR)
    if image is None:
        raise PipelineError(f"Failed to load image: {input_path}")

    image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

    # Normalize and extract luminance (shared across all configs)
    normalize_params = NormalizeParams(gamma=2.2, percentile_low=1, percentile_high=99)
    luminance_params = LuminanceParams(method="lab_l")
    downscale_params = DownscaleParams(interpolation="area")

    normalized = normalize_input(image, normalize_params)
    luminance = extract_luminance(normalized, luminance_params)

    results: list[MatrixResult] = []
    total_configs = len(MATRIX_CONFIGS)

    for config in MATRIX_CONFIGS:
        # Build unified binarization params
        binarize_params = BinarizeParams(
            method=config.method,
            pre_blur_sigma=config.pre_blur_sigma,
            low_threshold=config.low_threshold,
            high_threshold=config.high_threshold,
            dilate_kernel=config.dilate_kernel,
            dilate_iterations=config.dilate_iterations,
            block_size=config.block_size,
            c_constant=config.c_constant,
        )

        # Per-config morphology params with erode/skeletonize
        morphology_params = MorphologyParams(
            kernel_shape="ellipse",
            kernel_size=3,
            close_iterations=1,
            open_iterations=1,
            erode_iterations=config.erode_iterations,
            skeletonize=config.skeletonize,
        )

        # Prepare luminance (optionally with CLAHE for adaptive methods)
        lum_input = luminance
        if config.use_clahe:
            contrast_params = ContrastParams(method="clahe", clip_limit=2.0, tile_size=8)
            lum_input = enhance_local_contrast(luminance, contrast_params)

        if config.method == "canny" and config.pipeline_order == "edge_down":
            # Edge detection first, then downscale (Canny only)
            binary_highres = binarize(lum_input, binarize_params)
            binary_scaled = downscale(
                binary_highres.astype(np.float32) / 255.0,
                size,
                downscale_params,
            )
            binary = (binary_scaled > 0.1).astype(np.uint8) * 255
        else:
            # Downscale first, then binarize (default for all methods)
            scaled = downscale(lum_input, size, downscale_params)
            binary = binarize(scaled, binarize_params)

        corrected = apply_morphological_correction(binary, morphology_params)

        opaque_count = int(np.count_nonzero(corrected > 127))
        total_pixels = size * size
        opacity_pct = (opaque_count / total_pixels) * 100

        # Generate filename with method-specific details
        if config.method == "canny":
            config_name = (
                f"{output_name}_{config.id:03d}_canny_"
                f"low{config.low_threshold}_high{config.high_threshold}_"
                f"blur{config.pre_blur_sigma}"
            )
            if config.pipeline_order == "edge_down":
                config_name += f"_dilate{config.dilate_kernel}"
            if config.erode_iterations > 0:
                config_name += f"_erode{config.erode_iterations}"
            if config.skeletonize:
                config_name += "_skel"
        else:
            # Adaptive threshold methods
            config_name = (
                f"{output_name}_{config.id:03d}_adaptive_"
                f"block{config.block_size}_c{config.c_constant}"
            )
            if config.use_clahe:
                config_name += "_clahe"

        metadata = {
            "source": str(input_path),
            "size": size,
            "format": "1-bit monochrome",
            "profile": "matrix",
            "config_id": config.id,
            "method": config.method,
            "pre_blur_sigma": config.pre_blur_sigma,
            "opaquePixels": opaque_count,
            "totalPixels": total_pixels,
            "opacity_pct": round(opacity_pct, 2),
        }
        # Add method-specific metadata
        if config.method == "canny":
            metadata.update({
                "low_threshold": config.low_threshold,
                "high_threshold": config.high_threshold,
                "pipeline_order": config.pipeline_order,
                "dilate_kernel": config.dilate_kernel,
                "dilate_iterations": config.dilate_iterations,
                "erode_iterations": config.erode_iterations,
                "skeletonize": config.skeletonize,
            })
        else:
            metadata.update({
                "block_size": config.block_size,
                "c_constant": config.c_constant,
                "use_clahe": config.use_clahe,
            })

        export_params = ExportParams(format="1bit_png", foreground_color="000000")
        _, _, png_path, _ = export_outputs(
            corrected,
            output_dir,
            config_name,
            size,
            True,  # invert for display
            metadata,
        )

        results.append(
            MatrixResult(
                config=config,
                opaque_count=opaque_count,
                total_pixels=total_pixels,
                opacity_pct=opacity_pct,
                png_path=png_path,
            )
        )

        print(f"  [{config.id:02d}/{total_configs}] {opacity_pct:5.1f}% opaque - {png_path.name}")

    return results
