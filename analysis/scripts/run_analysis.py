#!/usr/bin/env python3
"""Run quantitative analysis and export results."""

import json
import sys
from dataclasses import asdict
from pathlib import Path

# Add src to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent / "src"))

from fetch.btc_prices import load_cached_prices
from analysis.rolling_windows import (
    calculate_1129_day_stats,
    calculate_monthly_stats,
    calculate_yearly_stats,
)

RESULTS_DIR = Path(__file__).parent.parent / "results"


def main() -> None:
    """Run all analyses and export results."""
    print("Loading cached BTC price data...")

    try:
        df = load_cached_prices()
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        print("Run 'uv run scripts/fetch_btc_data.py' first.", file=sys.stderr)
        sys.exit(1)

    print(f"Loaded {len(df)} observations ({df['Date'].min()} to {df['Date'].max()})")

    # Run analyses
    print("\nCalculating rolling window statistics...")

    monthly = calculate_monthly_stats(df)
    yearly = calculate_yearly_stats(df)
    vesting = calculate_1129_day_stats(df)

    # Compile results
    results = {
        "data_range": {
            "start": str(df["Date"].min()),
            "end": str(df["Date"].max()),
            "observations": len(df),
        },
        "monthly_30_day": asdict(monthly),
        "yearly_365_day": asdict(yearly),
        "vesting_1129_day": asdict(vesting),
    }

    # Export to JSON
    output_path = RESULTS_DIR / "rolling_window_stats.json"
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with open(output_path, "w") as f:
        json.dump(results, f, indent=2)

    print(f"\nResults saved to: {output_path}")

    # Print summary
    print("\n" + "=" * 60)
    print("QUANTITATIVE VALIDATION SUMMARY")
    print("=" * 60)

    print(f"\n1129-Day Rolling Windows (Vesting Period):")
    print(f"  Samples:           {vesting.sample_count:,}")
    print(f"  Mean return:       {vesting.mean_return * 100:+.2f}%")
    print(f"  Min return:        {vesting.min_return * 100:+.2f}%")
    print(f"  Max return:        {vesting.max_return * 100:+.2f}%")
    print(f"  Std deviation:     {vesting.std_dev * 100:.2f}%")
    print(f"  Positive windows:  {vesting.positive_pct:.1f}%")
    print(f"  Exceeds breakeven: {vesting.exceeds_breakeven_pct:.1f}%")

    print(f"\nYearly Rolling Windows (365 days):")
    print(f"  Samples:           {yearly.sample_count:,}")
    print(f"  Mean return:       {yearly.mean_return * 100:+.2f}%")
    print(f"  Min return:        {yearly.min_return * 100:+.2f}%")
    print(f"  Exceeds breakeven: {yearly.exceeds_breakeven_pct:.1f}%")

    print(f"\nMonthly Rolling Windows (30 days):")
    print(f"  Samples:           {monthly.sample_count:,}")
    print(f"  Mean return:       {monthly.mean_return * 100:+.2f}%")
    print(f"  Positive windows:  {monthly.positive_pct:.1f}%")


if __name__ == "__main__":
    main()
