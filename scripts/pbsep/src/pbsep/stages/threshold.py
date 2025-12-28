"""Stage 6: Binary decision via adaptive thresholding."""

import cv2
import numpy as np

from pbsep.types import ThresholdParams


def apply_adaptive_threshold(
    image: np.ndarray, params: ThresholdParams
) -> np.ndarray:
    """
    Convert grayscale to binary using adaptive thresholding.

    Adaptive threshold handles uneven lighting better than global threshold.

    Args:
        image: Grayscale image as float32 [0, 1]
        params: Threshold parameters

    Returns:
        Binary image as uint8 (0 or 255)
    """
    if params.method != "adaptive_gaussian":
        raise ValueError(f"Unknown threshold method: {params.method}")

    img_uint8 = (image * 255).astype(np.uint8)

    binary = cv2.adaptiveThreshold(
        img_uint8,
        255,
        cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY,
        params.block_size,
        params.c_constant,
    )

    return binary
