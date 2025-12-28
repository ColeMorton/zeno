"""Stage 5: Downscaling to target resolution."""

import cv2
import numpy as np

from pbsep.types import DownscaleParams


def downscale(
    image: np.ndarray, target_size: int, params: DownscaleParams
) -> np.ndarray:
    """
    Downscale to target resolution using area interpolation.

    INTER_AREA is optimal for downscaling - preserves detail better
    than bilinear interpolation.

    Args:
        image: Input image as float32 [0, 1]
        target_size: Target dimension (square output)
        params: Downscale parameters

    Returns:
        Downscaled image as float32 [0, 1]
    """
    if params.interpolation != "area":
        raise ValueError(f"Unknown interpolation: {params.interpolation}")

    return cv2.resize(
        image,
        (target_size, target_size),
        interpolation=cv2.INTER_AREA,
    )
