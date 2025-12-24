#!/usr/bin/env python3
"""Optimal vesting window analysis."""

import json
import sys
from dataclasses import asdict
from pathlib import Path

# Add src to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent / "src"))

from fetch.btc_prices import load_cached_prices
from analysis.window_optimization import (
    sweep_windows,
    find_threshold_windows,
    find_optimal_conservative,
    find_optimal_practical,
    find_optimal_sharpe,
    find_optimal_robust,
    generate_report,
)

RESULTS_DIR = Path(__file__).parent.parent / "results"


def main() -> None:
    """Run optimal vesting window analysis."""
    print("=" * 70)
    print("OPTIMAL VESTING WINDOW ANALYSIS")
    print("=" * 70)

    # Load data
    print("\nLoading cached BTC price data...")
    try:
        df = load_cached_prices()
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        print("Run 'uv run scripts/fetch_btc_data.py' first.", file=sys.stderr)
        sys.exit(1)

    print(f"Loaded {len(df)} observations ({df['Date'].min()} to {df['Date'].max()})")

    # Phase 1: Window sweep
    print("\n" + "-" * 70)
    print("PHASE 1: Window Sweep [30, 2000] days, step=7")
    print("-" * 70)

    sweep_results = sweep_windows(df, min_days=30, max_days=2000, step=7)
    print(f"Analyzed {len(sweep_results)} window sizes")

    # Save sweep results
    sweep_path = RESULTS_DIR / "window_sweep.json"
    with open(sweep_path, "w") as f:
        json.dump([asdict(s) for s in sweep_results], f, indent=2)
    print(f"Saved to: {sweep_path}")

    # Phase 2: Threshold analysis
    print("\n" + "-" * 70)
    print("PHASE 2: Threshold Analysis")
    print("-" * 70)

    thresholds = find_threshold_windows(sweep_results)

    print("\nMinimum window to achieve P(positive) threshold:")
    for pct, days in thresholds["positive"].items():
        status = f"{days} days" if days else "NOT ACHIEVABLE"
        print(f"  {pct:>5.1f}%: {status}")

    print("\nMinimum window to achieve P(breakeven) threshold:")
    for pct, days in thresholds["breakeven"].items():
        status = f"{days} days" if days else "NOT ACHIEVABLE"
        print(f"  {pct:>5.1f}%: {status}")

    # Save threshold results
    threshold_path = RESULTS_DIR / "threshold_windows.json"
    with open(threshold_path, "w") as f:
        json.dump(thresholds, f, indent=2)

    # Phase 3: Find optimal windows for each objective
    print("\n" + "-" * 70)
    print("PHASE 3: Optimal Window Identification")
    print("-" * 70)

    optimal_results = []

    # Objective 1: Conservative
    print("\n1. Conservative (100% positive):")
    conservative = find_optimal_conservative(sweep_results)
    optimal_results.append(conservative)
    print(f"   Optimal: {conservative.optimal_days} days")
    print(f"   P(positive): {conservative.positive_pct:.2f}%")
    print(f"   Confidence: {conservative.confidence}")

    # Objective 2: Practical
    print("\n2. Practical (99.5% positive, 95% breakeven):")
    practical = find_optimal_practical(sweep_results)
    optimal_results.append(practical)
    print(f"   Optimal: {practical.optimal_days} days")
    print(f"   P(positive): {practical.positive_pct:.2f}%")
    print(f"   P(breakeven): {practical.breakeven_pct:.2f}%")
    print(f"   Confidence: {practical.confidence}")

    # Objective 3: Risk-adjusted
    print("\n3. Risk-adjusted (max Sharpe):")
    sharpe = find_optimal_sharpe(sweep_results)
    optimal_results.append(sharpe)
    print(f"   Optimal: {sharpe.optimal_days} days")
    print(f"   Sharpe ratio: {sharpe.sharpe_ratio:.3f}")
    print(f"   Confidence: {sharpe.confidence}")

    # Objective 4: Robustness
    print("\n4. Robustness (consistent across periods):")
    periods = {
        "full": ("2014-01-01", "2025-12-31"),
        "early": ("2014-01-01", "2019-12-31"),
        "recent": ("2019-01-01", "2025-12-31"),
    }
    robust = find_optimal_robust(df, periods, target_positive=99.5, step=7)
    optimal_results.append(robust)
    print(f"   Optimal: {robust.optimal_days} days")
    print(f"   P(positive): {robust.positive_pct:.2f}%")
    print(f"   Confidence: {robust.confidence}")

    # Phase 4: Cross-validation details
    print("\n" + "-" * 70)
    print("PHASE 4: Cross-Validation")
    print("-" * 70)

    cross_validation = {}
    for period_name, (start, end) in periods.items():
        df_copy = df.copy()
        df_copy["Date"] = df_copy["Date"].astype(str)
        mask = (df_copy["Date"] >= start) & (df_copy["Date"] <= end)
        period_df = df[mask].reset_index(drop=True)

        if len(period_df) < 730:
            print(f"\n{period_name}: Insufficient data ({len(period_df)} days)")
            continue

        period_sweep = sweep_windows(period_df, min_days=365, max_days=2000, step=7)

        # Find 99.5% threshold
        optimal_995 = None
        for stats in period_sweep:
            if stats.positive_pct >= 99.5:
                optimal_995 = stats.days
                break

        # Find 100% threshold
        optimal_100 = None
        for stats in period_sweep:
            if stats.positive_pct >= 100.0:
                optimal_100 = stats.days
                break

        cross_validation[period_name] = {
            "observations": len(period_df),
            "optimal_99.5%": optimal_995,
            "optimal_100%": optimal_100,
        }

        print(f"\n{period_name.upper()} ({len(period_df)} days):")
        print(f"  99.5% positive: {optimal_995 if optimal_995 else 'N/A'} days")
        print(f"  100% positive:  {optimal_100 if optimal_100 else 'N/A'} days")

    # Save cross-validation
    cv_path = RESULTS_DIR / "cross_validation.json"
    with open(cv_path, "w") as f:
        json.dump(cross_validation, f, indent=2)

    # Generate and save final report
    print("\n" + "-" * 70)
    print("FINAL REPORT")
    print("-" * 70)

    report = generate_report(sweep_results, thresholds, optimal_results, current_window=1129)

    report_path = RESULTS_DIR / "optimal_window_report.json"
    with open(report_path, "w") as f:
        json.dump(report, f, indent=2, default=lambda x: asdict(x) if hasattr(x, '__dataclass_fields__') else str(x))

    print(f"\nReport saved to: {report_path}")

    # Summary comparison
    print("\n" + "=" * 70)
    print("SUMMARY: Optimal Windows by Objective")
    print("=" * 70)

    print(f"\n{'Objective':<45} {'Days':>8} {'P(+)':>8} {'P(BE)':>8}")
    print("-" * 70)
    print(f"{'Current (1129 days)':<45} {'1129':>8} {'100.0%':>8} {'96.0%':>8}")
    print("-" * 70)

    for result in optimal_results:
        name = result.objective[:44]
        print(f"{name:<45} {result.optimal_days:>8} {result.positive_pct:>7.1f}% {result.breakeven_pct:>7.1f}%")

    print("\n" + "=" * 70)
    print("RECOMMENDATION")
    print("=" * 70)

    # Find the window that satisfies the most stringent criteria
    conservative_days = conservative.optimal_days if "NOT ACHIEVABLE" not in conservative.objective else None

    if conservative_days:
        print(f"\nFor ABSOLUTE SAFETY (100% historical positive):")
        print(f"  Recommended window: {conservative_days} days ({conservative_days/365:.2f} years)")
    else:
        print(f"\n100% positive is NOT achievable in 2014-2025 dataset.")
        print(f"Best available: {practical.optimal_days} days with {practical.positive_pct:.1f}% positive")

    print(f"\nFor PRACTICAL BALANCE (99.5% positive, 95% breakeven):")
    print(f"  Recommended window: {practical.optimal_days} days ({practical.optimal_days/365:.2f} years)")

    print(f"\nCurrent protocol window: 1129 days (3.09 years)")

    # Comparison with current
    current_stats = next((s for s in sweep_results if s.days == 1129), None)
    if current_stats:
        print(f"  P(positive): {current_stats.positive_pct:.2f}%")
        print(f"  P(breakeven): {current_stats.exceeds_breakeven_pct:.2f}%")


if __name__ == "__main__":
    main()
