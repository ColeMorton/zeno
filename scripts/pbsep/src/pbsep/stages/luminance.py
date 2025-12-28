"""Stage 2: Semantic luminance extraction via LAB L* channel."""

import cv2
import numpy as np

from pbsep.types import LuminanceParams


def extract_luminance(image: np.ndarray, params: LuminanceParams) -> np.ndarray:
    """
    Extract perceptual luminance via LAB L* channel.

    LAB L* is perceptually uniform and handles edge cases better than
    simple grayscale conversion (0.299R + 0.587G + 0.114B).

    Args:
        image: Linear RGB image as float32 [0, 1]
        params: Luminance extraction parameters

    Returns:
        Luminance channel as float32 [0, 1]
    """
    if params.method != "lab_l":
        raise ValueError(f"Unknown luminance method: {params.method}")

    # Convert back to sRGB for LAB conversion (OpenCV expects sRGB)
    srgb = np.power(image, 1.0 / 2.2)
    srgb_uint8 = (srgb * 255).astype(np.uint8)

    # Convert to LAB and extract L* channel
    lab = cv2.cvtColor(srgb_uint8, cv2.COLOR_RGB2LAB)
    l_channel = lab[:, :, 0].astype(np.float32) / 255.0

    return l_channel
