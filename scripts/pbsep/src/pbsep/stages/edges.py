"""Stage: Edge detection using Canny algorithm with pre-blur and dilation."""

import cv2
import numpy as np

from pbsep.types import EdgesParams


def detect_edges(image: np.ndarray, params: EdgesParams) -> np.ndarray:
    """
    Detect edges using Canny edge detection with preprocessing.

    Pipeline:
    1. Gaussian blur (reduce noise, standard practice for Canny)
    2. Canny edge detection
    3. Dilation (thicken edges for better downscale survival)

    Args:
        image: Grayscale image as float32 [0, 1] or uint8 [0, 255]
        params: Edge detection parameters

    Returns:
        Binary image as uint8 (0=background, 255=edges)
    """
    if params.method != "canny":
        raise ValueError(f"Unknown edge method: {params.method}")

    # Convert to uint8 if needed
    if image.dtype == np.float32 or image.dtype == np.float64:
        img_uint8 = (image * 255).astype(np.uint8)
    else:
        img_uint8 = image

    # Pre-blur to reduce noise (standard practice for Canny)
    if params.pre_blur_sigma > 0:
        # Kernel size must be odd, derive from sigma
        ksize = int(params.pre_blur_sigma * 6) | 1  # Ensure odd
        ksize = max(3, ksize)
        img_uint8 = cv2.GaussianBlur(img_uint8, (ksize, ksize), params.pre_blur_sigma)

    # Apply Canny edge detection
    edges = cv2.Canny(
        img_uint8,
        params.low_threshold,
        params.high_threshold,
    )

    # Dilate edges to make them thicker (survives downscale better)
    if params.dilate_iterations > 0 and params.dilate_kernel > 0:
        kernel = cv2.getStructuringElement(
            cv2.MORPH_ELLIPSE,
            (params.dilate_kernel, params.dilate_kernel),
        )
        edges = cv2.dilate(edges, kernel, iterations=params.dilate_iterations)

    return edges
