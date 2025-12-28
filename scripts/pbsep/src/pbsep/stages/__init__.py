"""Pipeline stages for PBSEP-256."""

from pbsep.stages.normalize import normalize_input
from pbsep.stages.luminance import extract_luminance
from pbsep.stages.downscale import downscale
from pbsep.stages.edges import detect_edges
from pbsep.stages.binarize import binarize
from pbsep.stages.contrast import enhance_local_contrast
from pbsep.stages.morphology import apply_morphological_correction
from pbsep.stages.export import export_outputs
from pbsep.stages.vectorize import vectorize_bitmap

__all__ = [
    "normalize_input",
    "extract_luminance",
    "downscale",
    "detect_edges",
    "binarize",
    "enhance_local_contrast",
    "apply_morphological_correction",
    "export_outputs",
    "vectorize_bitmap",
]
