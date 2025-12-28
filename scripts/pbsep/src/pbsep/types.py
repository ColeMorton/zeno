"""Type definitions for PBSEP-256 pipeline."""

from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class NormalizeParams:
    """Parameters for input normalization stage."""

    gamma: float = 2.2
    percentile_low: int = 1
    percentile_high: int = 99


@dataclass(frozen=True)
class LuminanceParams:
    """Parameters for luminance extraction stage."""

    method: str = "lab_l"


@dataclass(frozen=True)
class AbstractionParams:
    """Parameters for edge-aware abstraction stage."""

    diameter: int = 9
    sigma_color: float = 75.0
    sigma_space: float = 75.0


@dataclass(frozen=True)
class DownscaleParams:
    """Parameters for downscaling stage."""

    interpolation: str = "area"


@dataclass(frozen=True)
class ThresholdParams:
    """Parameters for binary thresholding stage."""

    method: str = "adaptive_gaussian"
    block_size: int = 11
    c_constant: int = 2


@dataclass(frozen=True)
class ContrastParams:
    """Parameters for local contrast enhancement stage."""

    method: str = "clahe"
    clip_limit: float = 2.0
    tile_size: int = 8


@dataclass(frozen=True)
class BinarizeParams:
    """Parameters for binarization stage (supports multiple methods)."""

    # Common params
    method: str = "canny"  # canny, adaptive_gaussian, adaptive_mean
    pre_blur_sigma: float = 0.5

    # Canny-specific params
    low_threshold: int = 50
    high_threshold: int = 150
    dilate_kernel: int = 3
    dilate_iterations: int = 0

    # Adaptive threshold-specific params
    block_size: int = 15  # Must be odd
    c_constant: int = 5


# Keep EdgesParams as alias for backwards compatibility during transition
EdgesParams = BinarizeParams


@dataclass(frozen=True)
class MorphologyParams:
    """Parameters for morphological correction stage."""

    kernel_shape: str = "ellipse"
    kernel_size: int = 3
    close_iterations: int = 1
    open_iterations: int = 1
    erode_iterations: int = 0
    skeletonize: bool = False


@dataclass(frozen=True)
class ExportParams:
    """Parameters for export stage."""

    format: str = "1bit_png"
    foreground_color: str = "000000"
    vectorize: bool = True  # Use potrace for smooth bezier SVG


@dataclass(frozen=True)
class StageParams:
    """All stage parameters combined."""

    normalize: NormalizeParams
    luminance: LuminanceParams
    downscale: DownscaleParams
    binarize: BinarizeParams
    morphology: MorphologyParams
    export: ExportParams
    contrast: ContrastParams | None = None  # Optional, used with adaptive methods


@dataclass(frozen=True)
class ProfileConfig:
    """Profile configuration."""

    name: str
    stages: StageParams


@dataclass(frozen=True)
class PipelineConfig:
    """Immutable pipeline configuration."""

    input_path: Path
    output_name: str
    output_dir: Path
    size: int
    profile_name: str
    invert: bool


@dataclass
class PipelineResult:
    """Pipeline execution result."""

    bitmap: bytes
    opaque_count: int
    total_pixels: int
    metadata: dict
    processing_time_ms: float


class PipelineError(Exception):
    """Raised when pipeline processing fails."""


class ProfileNotFoundError(Exception):
    """Raised when a profile cannot be found."""
