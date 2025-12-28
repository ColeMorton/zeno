"""Profile loading and validation."""

from pathlib import Path

import yaml

from pbsep.types import (
    BinarizeParams,
    ContrastParams,
    DownscaleParams,
    ExportParams,
    LuminanceParams,
    MorphologyParams,
    NormalizeParams,
    ProfileConfig,
    ProfileNotFoundError,
    StageParams,
)

PROFILES_DIR = Path(__file__).parent / "defaults"


def load_profile(name_or_path: str | Path) -> ProfileConfig:
    """
    Load a profile by name (built-in) or path (custom).

    Args:
        name_or_path: Profile name (e.g., "medallion") or path to YAML file

    Returns:
        ProfileConfig with all stage parameters

    Raises:
        ProfileNotFoundError: If profile doesn't exist
    """
    path = Path(name_or_path)

    # Check if it's a path to a file
    if path.suffix in (".yaml", ".yml") or "/" in str(name_or_path):
        if not path.exists():
            raise ProfileNotFoundError(f"Profile file not found: {path}")
    else:
        # Built-in profile
        path = PROFILES_DIR / f"{name_or_path}.yaml"
        if not path.exists():
            available = [p.stem for p in PROFILES_DIR.glob("*.yaml")]
            raise ProfileNotFoundError(
                f"Unknown profile '{name_or_path}'. Available: {', '.join(available)}"
            )

    with open(path) as f:
        data = yaml.safe_load(f)

    return _parse_profile(data)


def _parse_profile(data: dict) -> ProfileConfig:
    """Parse profile data into ProfileConfig."""
    stages = data.get("stages", {})

    # Support both 'binarize' (new) and 'edges' (legacy) keys
    binarize_data = stages.get("binarize", stages.get("edges", {}))

    # Parse optional contrast stage
    contrast_data = stages.get("contrast")
    contrast_params = None
    if contrast_data:
        contrast_params = ContrastParams(
            method=contrast_data.get("method", "clahe"),
            clip_limit=contrast_data.get("clip_limit", 2.0),
            tile_size=contrast_data.get("tile_size", 8),
        )

    return ProfileConfig(
        name=data["name"],
        stages=StageParams(
            normalize=NormalizeParams(
                gamma=stages.get("normalize", {}).get("gamma", 2.2),
                percentile_low=stages.get("normalize", {}).get("percentile_low", 1),
                percentile_high=stages.get("normalize", {}).get("percentile_high", 99),
            ),
            luminance=LuminanceParams(
                method=stages.get("luminance", {}).get("method", "lab_l"),
            ),
            downscale=DownscaleParams(
                interpolation=stages.get("downscale", {}).get("interpolation", "area"),
            ),
            binarize=BinarizeParams(
                method=binarize_data.get("method", "canny"),
                pre_blur_sigma=binarize_data.get("pre_blur_sigma", 0.5),
                low_threshold=binarize_data.get("low_threshold", 50),
                high_threshold=binarize_data.get("high_threshold", 150),
                dilate_kernel=binarize_data.get("dilate_kernel", 3),
                dilate_iterations=binarize_data.get("dilate_iterations", 0),
                block_size=binarize_data.get("block_size", 15),
                c_constant=binarize_data.get("c_constant", 5),
            ),
            morphology=MorphologyParams(
                kernel_shape=stages.get("morphology", {}).get("kernel_shape", "ellipse"),
                kernel_size=stages.get("morphology", {}).get("kernel_size", 3),
                close_iterations=stages.get("morphology", {}).get("close_iterations", 1),
                open_iterations=stages.get("morphology", {}).get("open_iterations", 1),
            ),
            export=ExportParams(
                format=stages.get("export", {}).get("format", "1bit_png"),
                foreground_color=stages.get("export", {}).get(
                    "foreground_color", "000000"
                ),
            ),
            contrast=contrast_params,
        ),
    )
