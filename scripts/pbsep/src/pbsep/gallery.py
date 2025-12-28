"""HTML gallery generator for matrix comparison."""

import json
from pathlib import Path

from pbsep.matrix import MatrixResult


def generate_gallery(
    results: list[MatrixResult],
    output_dir: Path,
    reference_path: Path | None = None,
) -> Path:
    """
    Generate HTML gallery for visual comparison of matrix results.

    Args:
        results: List of MatrixResult from matrix run
        output_dir: Output directory
        reference_path: Optional reference image path (e.g., Adobe output)

    Returns:
        Path to generated gallery.html
    """
    # Sort by opacity for comparison
    sorted_results = sorted(results, key=lambda r: r.opacity_pct)

    # Generate matrix.json
    matrix_data = {
        "results": [
            {
                "id": r.config.id,
                "method": r.config.method,
                "pre_blur_sigma": r.config.pre_blur_sigma,
                "opaque_count": r.opaque_count,
                "total_pixels": r.total_pixels,
                "opacity_pct": r.opacity_pct,
                "png_path": r.png_path.name,
                # Canny-specific
                **({"low_threshold": r.config.low_threshold,
                    "high_threshold": r.config.high_threshold,
                    "pipeline_order": r.config.pipeline_order,
                    "dilate_kernel": r.config.dilate_kernel,
                    "dilate_iterations": r.config.dilate_iterations,
                    "erode_iterations": r.config.erode_iterations,
                    "skeletonize": r.config.skeletonize}
                   if r.config.method == "canny" else {}),
                # Adaptive-specific
                **({"block_size": r.config.block_size,
                    "c_constant": r.config.c_constant,
                    "use_clahe": r.config.use_clahe}
                   if r.config.method != "canny" else {}),
            }
            for r in sorted_results
        ]
    }

    json_path = output_dir / "matrix.json"
    with open(json_path, "w") as f:
        json.dump(matrix_data, f, indent=2)

    # Generate HTML
    html_content = _generate_html(sorted_results, reference_path)

    gallery_path = output_dir / "gallery.html"
    with open(gallery_path, "w") as f:
        f.write(html_content)

    return gallery_path


def _generate_html(
    results: list[MatrixResult],
    reference_path: Path | None,
) -> str:
    """Generate HTML content for gallery."""
    cards_html = ""

    # Add reference card if provided
    if reference_path and reference_path.exists():
        cards_html += f"""
        <div class="card reference">
            <img src="{reference_path.name}" alt="Reference (Adobe)" onclick="showModal(this.src)">
            <div class="info">
                <strong>REFERENCE (Adobe)</strong><br>
                Target quality
            </div>
        </div>
        """

    # Add result cards
    for r in results:
        if r.config.method == "canny":
            # Canny-specific card info
            pipeline_label = "down→edge" if r.config.pipeline_order == "down_edge" else "edge→down"
            extra_info = ""
            if r.config.dilate_iterations > 0:
                extra_info += f", dilate={r.config.dilate_kernel}"
            if r.config.erode_iterations > 0:
                extra_info += f", erode={r.config.erode_iterations}"
            if r.config.skeletonize:
                extra_info += ", skel"

            method_label = "CANNY"
            detail_line1 = f"low={r.config.low_threshold}, high={r.config.high_threshold}"
            detail_line2 = f"blur={r.config.pre_blur_sigma}, {pipeline_label}{extra_info}"
        else:
            # Adaptive threshold card info
            method_label = "ADAPTIVE"
            detail_line1 = f"block={r.config.block_size}, C={r.config.c_constant}"
            detail_line2 = f"blur={r.config.pre_blur_sigma}"
            if r.config.use_clahe:
                detail_line2 += ", CLAHE"

        # Method-specific card styling
        card_class = "card canny" if r.config.method == "canny" else "card adaptive"

        cards_html += f"""
        <div class="{card_class}">
            <img src="{r.png_path.name}" alt="Config {r.config.id}" onclick="showModal(this.src)">
            <div class="info">
                <strong>#{r.config.id}</strong> <span class="method-badge">{method_label}</span> - {r.opacity_pct:.1f}%<br>
                {detail_line1}<br>
                {detail_line2}
            </div>
        </div>
        """

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PBSEP Matrix Comparison</title>
    <style>
        * {{ box-sizing: border-box; }}
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #1a1a1a;
            color: #fff;
            margin: 0;
            padding: 20px;
        }}
        h1 {{
            text-align: center;
            margin-bottom: 10px;
        }}
        .subtitle {{
            text-align: center;
            color: #888;
            margin-bottom: 30px;
        }}
        .grid {{
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
            gap: 20px;
            max-width: 1800px;
            margin: 0 auto;
        }}
        .card {{
            background: #2a2a2a;
            border-radius: 8px;
            overflow: hidden;
            transition: transform 0.2s;
        }}
        .card:hover {{
            transform: scale(1.02);
        }}
        .card.reference {{
            border: 2px solid #4CAF50;
        }}
        .card.canny {{
            border-left: 3px solid #2196F3;
        }}
        .card.adaptive {{
            border-left: 3px solid #FF9800;
        }}
        .method-badge {{
            font-size: 10px;
            padding: 2px 6px;
            border-radius: 3px;
            font-weight: bold;
        }}
        .card.canny .method-badge {{
            background: #2196F3;
            color: #fff;
        }}
        .card.adaptive .method-badge {{
            background: #FF9800;
            color: #000;
        }}
        .card img {{
            width: 100%;
            height: auto;
            display: block;
            cursor: pointer;
            background: #fff;
        }}
        .info {{
            padding: 12px;
            font-size: 13px;
            line-height: 1.4;
        }}
        .info strong {{
            color: #4CAF50;
        }}
        .modal {{
            display: none;
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(0,0,0,0.9);
            z-index: 1000;
            justify-content: center;
            align-items: center;
        }}
        .modal.active {{
            display: flex;
        }}
        .modal img {{
            max-width: 90%;
            max-height: 90%;
            background: #fff;
        }}
        .modal-close {{
            position: absolute;
            top: 20px;
            right: 30px;
            font-size: 40px;
            color: #fff;
            cursor: pointer;
        }}
        .legend {{
            max-width: 1800px;
            margin: 0 auto 30px;
            padding: 15px;
            background: #2a2a2a;
            border-radius: 8px;
            font-size: 13px;
        }}
        .legend h3 {{
            margin: 0 0 10px 0;
            color: #4CAF50;
        }}
    </style>
</head>
<body>
    <h1>PBSEP Matrix Comparison</h1>
    <p class="subtitle">Sorted by opacity % (ascending) - Click image to enlarge</p>

    <div class="legend">
        <h3>Methods</h3>
        <p>
        <span style="color:#2196F3;font-weight:bold">CANNY</span> - Edge detection (outline style, ~15-25% opacity)<br>
        <span style="color:#FF9800;font-weight:bold">ADAPTIVE</span> - Local threshold (filled style, ~60-90% opacity)
        </p>
        <h3>Canny Parameters</h3>
        <p><strong>low/high</strong>: Canny thresholds (lower = more edges)<br>
        <strong>blur</strong>: Pre-blur sigma (0 = no blur, higher = smoother)<br>
        <strong>down→edge</strong>: Downscale first, then edge detection (thinner lines)<br>
        <strong>edge→down</strong>: Edge detection first, then downscale (needs dilation)</p>
        <h3>Adaptive Parameters</h3>
        <p><strong>block</strong>: Local window size (larger = smoother transitions)<br>
        <strong>C</strong>: Constant subtracted from local mean (higher = less filled)<br>
        <strong>CLAHE</strong>: Contrast enhancement enabled</p>
    </div>

    <div class="grid">
        {cards_html}
    </div>

    <div class="modal" id="modal" onclick="hideModal()">
        <span class="modal-close">&times;</span>
        <img id="modal-img" src="" alt="Enlarged">
    </div>

    <script>
        function showModal(src) {{
            document.getElementById('modal-img').src = src;
            document.getElementById('modal').classList.add('active');
        }}
        function hideModal() {{
            document.getElementById('modal').classList.remove('active');
        }}
        document.addEventListener('keydown', (e) => {{
            if (e.key === 'Escape') hideModal();
        }});
    </script>
</body>
</html>
"""
