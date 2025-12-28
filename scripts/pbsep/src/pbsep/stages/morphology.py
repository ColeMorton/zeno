"""Stage 7: Morphological correction to clean binary output."""

import cv2
import numpy as np
from skimage.morphology import skeletonize as skimage_skeletonize

from pbsep.types import MorphologyParams


def apply_morphological_correction(
    binary: np.ndarray, params: MorphologyParams
) -> np.ndarray:
    """
    Clean up binary image using morphological operations.

    1. Close: Fill small gaps in foreground
    2. Open: Remove small isolated pixels (islands)
    3. Erode: Thin lines (optional)
    4. Skeletonize: Reduce to 1px width (optional)

    Args:
        binary: Binary image as uint8 (0 or 255)
        params: Morphology parameters

    Returns:
        Cleaned binary image as uint8 (0 or 255)
    """
    if params.kernel_shape != "ellipse":
        raise ValueError(f"Unknown kernel shape: {params.kernel_shape}")

    kernel = cv2.getStructuringElement(
        cv2.MORPH_ELLIPSE,
        (params.kernel_size, params.kernel_size),
    )

    result = binary

    # Close gaps first
    if params.close_iterations > 0:
        result = cv2.morphologyEx(
            result,
            cv2.MORPH_CLOSE,
            kernel,
            iterations=params.close_iterations,
        )

    # Then remove islands
    if params.open_iterations > 0:
        result = cv2.morphologyEx(
            result,
            cv2.MORPH_OPEN,
            kernel,
            iterations=params.open_iterations,
        )

    # Erode to thin lines
    if params.erode_iterations > 0:
        result = cv2.erode(result, kernel, iterations=params.erode_iterations)

    # Skeletonize to 1px width
    if params.skeletonize:
        # Convert to boolean for skimage
        bool_img = result > 127
        skeleton = skimage_skeletonize(bool_img)
        result = (skeleton * 255).astype(np.uint8)

    return result
