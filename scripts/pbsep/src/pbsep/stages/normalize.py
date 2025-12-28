"""Stage 1: Input normalization - gamma linearization and exposure normalization."""

import numpy as np

from pbsep.types import NormalizeParams


def normalize_input(image: np.ndarray, params: NormalizeParams) -> np.ndarray:
    """
    Normalize input image for consistent processing.

    Steps:
    1. Convert to linear color space (sRGB gamma -> linear)
    2. Exposure normalization via percentile stretching

    Args:
        image: Input RGB image as uint8 numpy array (H, W, 3)
        params: Normalization parameters

    Returns:
        Normalized image in linear space as float32 [0, 1]
    """
    # Convert to float and apply gamma correction (sRGB -> linear)
    linear = np.power(image.astype(np.float32) / 255.0, params.gamma)

    # Exposure normalization via percentile stretch
    low = np.percentile(linear, params.percentile_low)
    high = np.percentile(linear, params.percentile_high)

    if high - low > 1e-6:
        linear = (linear - low) / (high - low)
        linear = np.clip(linear, 0.0, 1.0)

    return linear
