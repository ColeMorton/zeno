#!/usr/bin/env python3
"""
Generate vBTC/WBTC ratio chart from simulation market data.

Reads market_data.csv (exported by SwarmSimulation) and produces a two-panel
PNG showing the vBTC/WBTC exchange rate from the post-vesting period onward.

Usage:
    python generate_vbtc_ratio_chart.py [--input reports/market_data.csv] [--start-week 162]
"""

import argparse
import csv
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

REPORTS_DIR = Path(__file__).resolve().parent.parent / "reports"
PRECISION = 10**18


def load_market_data(csv_path: Path, start_week: int) -> tuple[np.ndarray, np.ndarray]:
    """Load vBTC/WBTC ratio from market_data.csv, filtered to start_week onward.

    Returns (weeks, ratios) where ratios are floats (0.0-2.0 range).
    """
    weeks = []
    ratios = []
    with open(csv_path) as f:
        reader = csv.DictReader(f)
        for row in reader:
            tick = int(row["tick"])
            if tick < start_week:
                continue
            ratio_raw = int(row["vbtcRatio"])
            if ratio_raw == 0:
                continue
            weeks.append(tick)
            ratios.append(ratio_raw / PRECISION)
    return np.array(weeks), np.array(ratios)


def generate_chart(weeks: np.ndarray, ratios: np.ndarray, start_week: int, output: Path) -> None:
    """Generate vBTC/WBTC ratio chart PNG matching price_series.png style."""
    deltas = np.diff(ratios)
    delta_weeks = weeks[1:]

    fig, (ax_ratio, ax_delta) = plt.subplots(
        2, 1, figsize=(12, 8),
        gridspec_kw={"height_ratios": [3, 1]},
        sharex=True,
    )

    n_weeks = len(weeks)
    min_r, max_r, mean_r = ratios.min(), ratios.max(), ratios.mean()
    fig.suptitle(
        f"vBTC/WBTC Ratio — Weeks {weeks[0]}\u2013{weeks[-1]} ({n_weeks} weeks), "
        f"Min {min_r:.3f}, Max {max_r:.3f}, Mean {mean_r:.3f}",
        fontsize=12, color="white",
    )

    # Top panel: ratio line
    ax_ratio.plot(weeks, ratios, color="#58a6ff", linewidth=1.0)
    ax_ratio.axhline(1.0, color="white", linewidth=0.5, alpha=0.4, linestyle="--", label="Parity (1.0)")
    ax_ratio.axhline(0.75, color="#f0883e", linewidth=0.5, alpha=0.4, linestyle="--", label="Seed (0.75)")
    ax_ratio.set_ylabel("vBTC/WBTC")
    ax_ratio.legend(loc="upper right", fontsize=8, facecolor="#1a1a2e", edgecolor="white", labelcolor="white")
    ax_ratio.grid(True, alpha=0.3)
    ax_ratio.set_facecolor("#1a1a2e")

    # Bottom panel: weekly delta bars
    colors = np.where(deltas >= 0, "#3fb950", "#f85149")
    ax_delta.bar(delta_weeks, deltas, width=1.0, color=colors, alpha=0.7)
    ax_delta.axhline(0, color="white", linewidth=0.5, alpha=0.5)
    ax_delta.set_ylabel("Weekly \u0394")
    ax_delta.set_xlabel("Week")
    ax_delta.grid(True, alpha=0.3)
    ax_delta.set_facecolor("#1a1a2e")

    # Dark theme styling (matches price_series.png)
    fig.patch.set_facecolor("#0d1117")
    for ax in (ax_ratio, ax_delta):
        ax.tick_params(colors="white")
        ax.xaxis.label.set_color("white")
        ax.yaxis.label.set_color("white")
        for spine in ax.spines.values():
            spine.set_color("white")

    plt.tight_layout()
    fig.savefig(output, dpi=150, facecolor=fig.get_facecolor())
    plt.close(fig)
    print(f"PNG: {output}")


def main():
    parser = argparse.ArgumentParser(description="Generate vBTC/WBTC ratio chart from simulation data")
    parser.add_argument("--input", type=str, default=str(REPORTS_DIR / "market_data.csv"))
    parser.add_argument("--start-week", type=int, default=162)
    parser.add_argument("--output", type=str, default=str(REPORTS_DIR / "vbtc_ratio.png"))
    args = parser.parse_args()

    input_path = Path(args.input)
    if not input_path.exists():
        raise FileNotFoundError(f"market_data.csv not found: {input_path}")

    weeks, ratios = load_market_data(input_path, args.start_week)
    if len(weeks) == 0:
        print(f"SKIP: No vBTC ratio data from week {args.start_week} onward (expected for short runs)")
        return

    output_path = Path(args.output)
    generate_chart(weeks, ratios, args.start_week, output_path)

    print(f"=== vBTC/WBTC RATIO CHART ===")
    print(f"Data: weeks {weeks[0]}-{weeks[-1]} ({len(weeks)} points)")
    print(f"Ratio: min={ratios.min():.4f}, max={ratios.max():.4f}, mean={ratios.mean():.4f}")


if __name__ == "__main__":
    main()
