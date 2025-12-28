"""Main PBSEP-256 pipeline orchestrator."""

import time

import cv2
import numpy as np

from pbsep.profiles import load_profile
from pbsep.stages import (
    apply_morphological_correction,
    binarize,
    downscale,
    enhance_local_contrast,
    export_outputs,
    extract_luminance,
    normalize_input,
)
from pbsep.types import PipelineConfig, PipelineError, PipelineResult, ProfileConfig


class PBSEP256Pipeline:
    """
    Photorealistic -> Binary Symbol Extraction Pipeline (256x256).

    Deterministic pipeline for converting high-resolution photorealistic
    images to 1-bit monochrome bitmaps.
    """

    def __init__(self, config: PipelineConfig, profile: ProfileConfig | None = None):
        """
        Initialize pipeline.

        Args:
            config: Pipeline configuration
            profile: Optional profile config (loads from config.profile_name if None)
        """
        self.config = config
        self.profile = profile or load_profile(config.profile_name)
        self._validate()

    def _validate(self) -> None:
        """Validate configuration. Fail fast on invalid config."""
        if self.config.size not in (128, 256):
            raise ValueError(
                f"Invalid size: {self.config.size}. Must be 128 or 256."
            )

        if not self.config.input_path.exists():
            raise FileNotFoundError(
                f"Input file not found: {self.config.input_path}"
            )

    def execute(self) -> PipelineResult:
        """
        Execute the complete PBSEP-256 pipeline.

        Returns:
            PipelineResult with bitmap and metadata

        Raises:
            PipelineError: On processing failure
        """
        start_time = time.perf_counter()
        stages = self.profile.stages

        # Load image
        image = cv2.imread(str(self.config.input_path), cv2.IMREAD_COLOR)
        if image is None:
            raise PipelineError(f"Failed to load image: {self.config.input_path}")

        # Convert BGR to RGB
        image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

        # Stage 1: Input normalization (full resolution)
        normalized = normalize_input(image, stages.normalize)

        # Stage 2: Semantic luminance extraction (full resolution)
        luminance = extract_luminance(normalized, stages.luminance)

        # Stage 3: Optional contrast enhancement (for adaptive threshold modes)
        if stages.contrast is not None:
            luminance = enhance_local_contrast(luminance, stages.contrast)

        # Stage 4: Downscale to target size
        scaled = downscale(luminance, self.config.size, stages.downscale)

        # Stage 5: Binarization (Canny or adaptive threshold)
        binary = binarize(scaled, stages.binarize)

        # Stage 6: Morphological correction
        corrected = apply_morphological_correction(binary, stages.morphology)

        # Count opaque pixels (edges are 255, background is 0)
        opaque_count = int(np.count_nonzero(corrected > 127))

        total_pixels = self.config.size * self.config.size

        # Build metadata
        # Edge detection always outputs edges as 255, so invert=True for display
        metadata = {
            "source": str(self.config.input_path),
            "size": self.config.size,
            "format": "1-bit monochrome (outline)",
            "profile": self.profile.name,
            "opaquePixels": opaque_count,
            "totalPixels": total_pixels,
            "bytes": total_pixels // 8,
        }

        # Stage 6: Export
        # Edge detection outputs edges as 255, so we always use invert=True
        # to display them as black foreground on white background
        bitmap, svg_path, png_path, metadata_path = export_outputs(
            corrected,
            self.config.output_dir,
            self.config.output_name,
            self.config.size,
            True,  # Always invert for edge detection (edges=255 → black foreground)
            metadata,
        )

        elapsed_ms = (time.perf_counter() - start_time) * 1000

        return PipelineResult(
            bitmap=bitmap,
            opaque_count=opaque_count,
            total_pixels=total_pixels,
            metadata=metadata,
            processing_time_ms=elapsed_ms,
        )
