"""CLI entry point for PBSEP-256."""

from pathlib import Path

import click

from pbsep.pipeline import PBSEP256Pipeline
from pbsep.solidity import generate_solidity_library
from pbsep.types import PipelineConfig, PipelineError, ProfileNotFoundError


@click.command()
@click.argument("input_path", type=click.Path(exists=True, path_type=Path))
@click.argument("output_name")
@click.option(
    "--size",
    type=click.Choice(["128", "256"]),
    default="256",
    help="Output size (128x128 or 256x256)",
)
@click.option(
    "--profile",
    type=str,
    default="medallion",
    help="Profile name or path to YAML file",
)
@click.option(
    "--invert/--no-invert",
    default=True,
    help="Invert: light areas become foreground (default: black on white)",
)
@click.option(
    "--output-dir",
    type=click.Path(path_type=Path),
    default=None,
    help="Output directory (default: same as input)",
)
@click.option(
    "--matrix",
    is_flag=True,
    default=False,
    help="Run matrix configuration (20 variants) for parameter exploration",
)
@click.option(
    "--reference",
    type=click.Path(exists=True, path_type=Path),
    default=None,
    help="Reference image for matrix gallery comparison",
)
def main(
    input_path: Path,
    output_name: str,
    size: str,
    profile: str,
    invert: bool,
    output_dir: Path | None,
    matrix: bool,
    reference: Path | None,
) -> None:
    """
    Convert photorealistic image to 1-bit monochrome bitmap.

    INPUT_PATH: Path to input image (PNG, JPG, TIFF, etc.)

    OUTPUT_NAME: Base name for output files
    """
    # Resolve paths
    input_path = input_path.resolve()
    if output_dir is None:
        output_dir = input_path.parent
    else:
        output_dir = output_dir.resolve()

    # Matrix mode: run 20 configurations
    if matrix:
        from pbsep.gallery import generate_gallery
        from pbsep.matrix import run_matrix

        matrix_dir = output_dir / f"{output_name}_matrix"
        click.echo(f"Input: {input_path}")
        click.echo(f"Target size: {size}x{size}")
        click.echo(f"Running matrix configuration (20 variants)...")
        click.echo(f"Output directory: {matrix_dir}\n")

        try:
            results = run_matrix(input_path, matrix_dir, output_name, int(size))
        except PipelineError as e:
            raise click.ClickException(str(e))

        # Copy reference image to matrix directory if provided
        ref_in_dir = None
        if reference:
            import shutil

            ref_in_dir = matrix_dir / reference.name
            shutil.copy(reference, ref_in_dir)

        gallery_path = generate_gallery(results, matrix_dir, ref_in_dir)

        click.echo(f"\nGenerated {len(results)} configurations")
        click.echo(f"Gallery: {gallery_path}")
        click.echo(f"Matrix JSON: {matrix_dir / 'matrix.json'}")

        # Show top 5 by opacity closest to 17% target
        sorted_by_target = sorted(results, key=lambda r: abs(r.opacity_pct - 17.0))
        click.echo("\nTop 5 closest to 17% target:")
        for r in sorted_by_target[:5]:
            click.echo(
                f"  #{r.config.id:02d}: {r.opacity_pct:5.1f}% - "
                f"low={r.config.low_threshold}, high={r.config.high_threshold}, "
                f"blur={r.config.pre_blur_sigma}"
            )
        return

    click.echo(f"Input: {input_path}")
    click.echo(f"Target size: {size}x{size}")
    if invert:
        click.echo("Mode: inverted (light areas become foreground)")

    # Build config
    config = PipelineConfig(
        input_path=input_path,
        output_name=output_name,
        output_dir=output_dir,
        size=int(size),
        profile_name=profile,
        invert=invert,
    )

    # Execute pipeline
    try:
        pipeline = PBSEP256Pipeline(config)
        result = pipeline.execute()
    except ProfileNotFoundError as e:
        raise click.ClickException(str(e))
    except PipelineError as e:
        raise click.ClickException(str(e))

    # Report results
    pct = (result.opaque_count / result.total_pixels) * 100
    click.echo(
        f"\nOpaque pixels: {result.opaque_count} / {result.total_pixels} ({pct:.1f}%)"
    )
    click.echo(f"Bitmap size: {len(result.bitmap)} bytes")
    click.echo(f"Processing time: {result.processing_time_ms:.1f}ms")

    # Output paths
    svg_path = output_dir / f"{output_name}_{size}x{size}_1bit.svg"
    png_path = output_dir / f"{output_name}_{size}x{size}_1bit.png"
    metadata_path = output_dir / f"{output_name}_{size}x{size}_metadata.json"

    click.echo(f"\nPreview SVG: {svg_path}")
    click.echo(f"Preview PNG: {png_path}")
    click.echo(f"Metadata: {metadata_path}")

    # Generate Solidity library
    sol_name = output_name[0].upper() + output_name[1:] + f"{size}Mono"
    sol_path = output_dir / f"{sol_name}.sol"
    sol_code = generate_solidity_library(
        output_name,
        result.bitmap,
        int(size),
    )
    sol_path.write_text(sol_code)
    click.echo(f"Solidity: {sol_path}")


if __name__ == "__main__":
    main()
