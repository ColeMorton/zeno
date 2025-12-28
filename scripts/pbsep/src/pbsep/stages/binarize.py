"""Unified binarization stage supporting multiple methods."""

import cv2
import numpy as np

from pbsep.types import BinarizeParams


def binarize(image: np.ndarray, params: BinarizeParams) -> np.ndarray:
    """
    Convert grayscale image to binary using specified method.

    Methods:
    - canny: Edge detection (outline style, ~18% opacity)
    - adaptive_gaussian: Local Gaussian threshold (filled style, ~35% opacity)
    - adaptive_mean: Local mean threshold (filled style)

    Args:
        image: Grayscale image as float32 [0, 1] or uint8 [0, 255]
        params: Binarization parameters

    Returns:
        Binary image as uint8 (0=background, 255=foreground)
    """
    # Convert to uint8 if needed
    if image.dtype == np.float32 or image.dtype == np.float64:
        img_uint8 = (image * 255).astype(np.uint8)
    else:
        img_uint8 = image

    # Optional pre-blur
    if params.pre_blur_sigma > 0:
        ksize = int(params.pre_blur_sigma * 6) | 1  # Ensure odd
        ksize = max(3, ksize)
        img_uint8 = cv2.GaussianBlur(img_uint8, (ksize, ksize), params.pre_blur_sigma)

    if params.method == "canny":
        binary = _apply_canny(img_uint8, params)
    elif params.method == "adaptive_gaussian":
        binary = _apply_adaptive_gaussian(img_uint8, params)
    elif params.method == "adaptive_mean":
        binary = _apply_adaptive_mean(img_uint8, params)
    else:
        raise ValueError(f"Unknown binarization method: {params.method}")

    return binary


def _apply_canny(img_uint8: np.ndarray, params: BinarizeParams) -> np.ndarray:
    """Apply Canny edge detection (outline style)."""
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


def _apply_adaptive_gaussian(img_uint8: np.ndarray, params: BinarizeParams) -> np.ndarray:
    """Apply adaptive Gaussian threshold (filled style)."""
    return cv2.adaptiveThreshold(
        img_uint8,
        255,
        cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY_INV,
        params.block_size,
        params.c_constant,
    )


def _apply_adaptive_mean(img_uint8: np.ndarray, params: BinarizeParams) -> np.ndarray:
    """Apply adaptive mean threshold (filled style)."""
    return cv2.adaptiveThreshold(
        img_uint8,
        255,
        cv2.ADAPTIVE_THRESH_MEAN_C,
        cv2.THRESH_BINARY_INV,
        params.block_size,
        params.c_constant,
    )
