"""Stage: Local contrast enhancement using CLAHE."""

import cv2
import numpy as np

from pbsep.types import ContrastParams


def enhance_local_contrast(image: np.ndarray, params: ContrastParams) -> np.ndarray:
    """
    Apply CLAHE (Contrast Limited Adaptive Histogram Equalization).

    CLAHE enhances local contrast, making edges more distinguishable
    in low-contrast regions. This improves adaptive thresholding results.

    Args:
        image: Grayscale image as float32 [0, 1] or uint8 [0, 255]
        params: Contrast enhancement parameters

    Returns:
        Enhanced image as float32 [0, 1]
    """
    if params.method != "clahe":
        raise ValueError(f"Unknown contrast method: {params.method}")

    # Convert to uint8 if needed
    if image.dtype == np.float32 or image.dtype == np.float64:
        img_uint8 = (image * 255).astype(np.uint8)
    else:
        img_uint8 = image

    # Create CLAHE object
    clahe = cv2.createCLAHE(
        clipLimit=params.clip_limit,
        tileGridSize=(params.tile_size, params.tile_size),
    )

    # Apply CLAHE
    enhanced = clahe.apply(img_uint8)

    # Return as float32 [0, 1]
    return enhanced.astype(np.float32) / 255.0
