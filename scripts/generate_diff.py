#!/usr/bin/env python3
"""Generate a diff report comparing two simulation run directories.

Usage:
    python scripts/generate_diff.py --baseline <path> --current <path> [--output diff.md]

A run directory can be:
  - A single-seed directory containing simulation_summary.json and market_data.csv
  - A multi-seed archive with subdirectories like reports_sim_*/ or sim_seed_*/

The script aggregates metrics, compares baseline vs current, and produces a markdown
report with regression gates suitable for copy-pasting into a GitHub PR.
"""

import argparse
import csv
import json
import sys
from pathlib import Path
from typing import Any


def discover_seed_dirs(run_dir: Path) -> list[Path]:
    """Find all seed subdirectories, or treat run_dir itself as a single seed."""
    if not run_dir.is_dir():
        print(f"ERROR: Not a directory: {run_dir}", file=sys.stderr)
        sys.exit(1)

    # Look for typical seed subdirectory patterns
    patterns = ["reports_sim_*", "sim_seed_*", "seed_*", "sim_*_seed_*"]
    seed_dirs = []
    for pat in patterns:
        seed_dirs.extend(run_dir.glob(pat))

    # If no subdirs found, check if run_dir itself has the required files
    if not seed_dirs and (run_dir / "simulation_summary.json").exists():
        seed_dirs = [run_dir]

    if not seed_dirs:
        print(f"ERROR: No simulation data found in {run_dir}", file=sys.stderr)
        sys.exit(1)

    return sorted(seed_dirs)


def load_summary(seed_dir: Path) -> dict[str, Any]:
    path = seed_dir / "simulation_summary.json"
    if not path.exists():
        print(f"ERROR: Missing {path}", file=sys.stderr)
        sys.exit(1)
    with open(path) as f:
        return json.load(f)


def load_market_data(seed_dir: Path) -> list[dict[str, Any]]:
    path = seed_dir / "market_data.csv"
    if not path.exists():
        return []
    rows = []
    with open(path) as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append({
                "tick": int(row["tick"]),
                "price": int(row["price"]),
                "vbtcRatio": int(row["vbtcRatio"]),
                "tvl": int(row["tvl"]),
                "matchPool": int(row["matchPool"]),
                "regime": int(row["regime"]),
            })
    return rows


def format_btc(sats: int) -> str:
    sign = "-" if sats < 0 else ""
    sats = abs(sats)
    whole = sats // 10**8
    frac = (sats % 10**8) // 10**4
    return f"{sign}{whole}.{frac:04d} BTC"


def format_pct(numerator: int, denominator: int) -> str:
    if denominator == 0:
        return "0.0%"
    return f"{(numerator / denominator) * 100:.1f}%"


def format_ratio(ratio_raw: int) -> str:
    """Convert fixed-point ratio (1e18 = 1.0) to human-readable x."""
    return f"{ratio_raw / 1e18:.2f}x"


def compute_seed_metrics(summary: dict, market: list[dict]) -> dict[str, Any]:
    ghost = summary.get("ghostVariables", {})
    final = summary.get("finalState", {})

    total_actions = int(ghost.get("totalActions", 0))
    failed_actions = int(ghost.get("totalFailedActions", 0))
    expected = int(ghost.get("expectedFailures", 0))
    unexpected = int(ghost.get("unexpectedFailures", 0))

    # Failure rate from ghost counters
    failure_rate = (failed_actions / total_actions * 100) if total_actions > 0 else 0.0

    # vBTC ratio stats from market data
    vbtc_ratios = [r["vbtcRatio"] for r in market if r["vbtcRatio"] > 0]
    vbtc_max = max(vbtc_ratios) if vbtc_ratios else 0
    vbtc_min = min(vbtc_ratios) if vbtc_ratios else 0
    vbtc_final = int(final.get("vbtcRatio", 0))

    return {
        "seed": summary.get("seed", "?"),
        "tick_count": summary.get("tickCount", 0),
        "total_actions": total_actions,
        "failed_actions": failed_actions,
        "failure_rate": failure_rate,
        "expected_failures": expected,
        "unexpected_failures": unexpected,
        "total_deposited": int(ghost.get("totalDeposited", 0)),
        "total_withdrawn": int(ghost.get("totalWithdrawn", 0)),
        "total_forfeited": int(ghost.get("totalForfeited", 0)),
        "total_match_claimed": int(ghost.get("totalMatchClaimed", 0)),
        "total_swaps": int(ghost.get("totalSwaps", 0)),
        "vbtc_max": vbtc_max,
        "vbtc_min": vbtc_min,
        "vbtc_final": vbtc_final,
        "final_tvl": int(final.get("tvl", 0)),
        "final_match_pool": int(final.get("matchPool", 0)),
    }


def aggregate_metrics(seed_metrics: list[dict]) -> dict[str, Any]:
    """Average metrics across seeds."""
    if not seed_metrics:
        return {}

    n = len(seed_metrics)

    def avg(key: str) -> float:
        return sum(m[key] for m in seed_metrics) / n

    def avg_int(key: str) -> int:
        return int(round(avg(key)))

    # For failure rate, recalculate from aggregated numerators/denominators
    total_actions = sum(m["total_actions"] for m in seed_metrics)
    failed_actions = sum(m["failed_actions"] for m in seed_metrics)
    failure_rate = (failed_actions / total_actions * 100) if total_actions > 0 else 0.0

    return {
        "seeds": [m["seed"] for m in seed_metrics],
        "tick_count": seed_metrics[0]["tick_count"],
        "total_actions": total_actions,
        "failed_actions": failed_actions,
        "failure_rate": failure_rate,
        "expected_failures": sum(m["expected_failures"] for m in seed_metrics),
        "unexpected_failures": sum(m["unexpected_failures"] for m in seed_metrics),
        "total_deposited": avg_int("total_deposited"),
        "total_withdrawn": avg_int("total_withdrawn"),
        "total_forfeited": avg_int("total_forfeited"),
        "total_match_claimed": avg_int("total_match_claimed"),
        "total_swaps": avg_int("total_swaps"),
        "vbtc_max": max(m["vbtc_max"] for m in seed_metrics),
        "vbtc_min": min(m["vbtc_min"] for m in seed_metrics),
        "vbtc_final": avg_int("vbtc_final"),
        "final_tvl": avg_int("final_tvl"),
        "final_match_pool": avg_int("final_match_pool"),
        "per_seed": seed_metrics,
    }


def delta_emoji(old: float, new: float, lower_is_better: bool = True) -> str:
    """Return emoji based on whether the change is good or bad."""
    if old == 0 and new == 0:
        return "\u2795"  # no change
    diff = new - old
    if abs(diff) < 0.01:
        return "\u2795"  # no meaningful change

    improved = (diff < 0) if lower_is_better else (diff > 0)
    regressed = (diff > 0) if lower_is_better else (diff < 0)

    if improved:
        return "\u2705"
    if regressed:
        return "\U0001f534"
    return "\u2795"


def delta_emoji_bounded(old: float, new: float, bound: float, bound_name: str) -> str:
    """For metrics that should stay within a bound (e.g., ratio <= 1.0)."""
    if new <= bound and old <= bound:
        return "\u2705"
    if new <= bound and old > bound:
        return "\u2705"  # fixed
    if new > bound and old <= bound:
        return "\U0001f534"  # regression: broke bound
    # both above bound
    if new < old:
        return "\u26a0\ufe0f"  # improving but still bad
    if new > old:
        return "\U0001f534"  # getting worse
    return "\u26a0\ufe0f"


def compare_metrics(baseline: dict, current: dict) -> list[dict[str, Any]]:
    """Generate comparison rows."""
    comparisons = []

    # Failure rate
    comparisons.append({
        "metric": "Failure rate",
        "baseline": f"{baseline['failure_rate']:.1f}%",
        "current": f"{current['failure_rate']:.1f}%",
        "emoji": delta_emoji(baseline["failure_rate"], current["failure_rate"], lower_is_better=True),
        "note": "threshold: <10%" if current["failure_rate"] < 10 else "threshold: <10% (EXCEEDED)",
    })

    # Unexpected failures
    comparisons.append({
        "metric": "Unexpected failures",
        "baseline": str(baseline["unexpected_failures"]),
        "current": str(current["unexpected_failures"]),
        "emoji": "\u2705" if current["unexpected_failures"] == 0 else "\U0001f534",
        "note": "threshold: 0" if current["unexpected_failures"] == 0 else "threshold: 0 (VIOLATED)",
    })

    # vBTC ratio max
    vbtc_max_old = baseline["vbtc_max"] / 1e18
    vbtc_max_new = current["vbtc_max"] / 1e18
    comparisons.append({
        "metric": "vBTC ratio max",
        "baseline": f"{vbtc_max_old:.2f}x",
        "current": f"{vbtc_max_new:.2f}x",
        "emoji": delta_emoji_bounded(vbtc_max_old, vbtc_max_new, 1.0, "1.0x"),
        "note": "bound: <=1.0x" if vbtc_max_new <= 1.0 else f"bound: <=1.0x (EXCEEDED by {vbtc_max_new - 1.0:.2f}x)",
    })

    # vBTC ratio min
    vbtc_min_old = baseline["vbtc_min"] / 1e18
    vbtc_min_new = current["vbtc_min"] / 1e18
    comparisons.append({
        "metric": "vBTC ratio min",
        "baseline": f"{vbtc_min_old:.2f}x" if baseline["vbtc_min"] > 0 else "N/A",
        "current": f"{vbtc_min_new:.2f}x" if current["vbtc_min"] > 0 else "N/A",
        "emoji": "\u2705" if vbtc_min_new >= 0.50 else "\U0001f534",
        "note": "bound: >=0.50x" if vbtc_min_new >= 0.50 else "bound: >=0.50x (VIOLATED)",
    })

    # vBTC ratio final
    vbtc_final_old = baseline["vbtc_final"] / 1e18
    vbtc_final_new = current["vbtc_final"] / 1e18
    comparisons.append({
        "metric": "vBTC ratio final",
        "baseline": f"{vbtc_final_old:.2f}x",
        "current": f"{vbtc_final_new:.2f}x",
        "emoji": "\u2705" if 0.50 <= vbtc_final_new <= 1.00 else "\U0001f534",
        "note": "target: [0.50x, 1.00x]" if 0.50 <= vbtc_final_new <= 1.00 else "target: [0.50x, 1.00x] (OUT OF RANGE)",
    })

    # Total actions
    comparisons.append({
        "metric": "Total actions",
        "baseline": f"{baseline['total_actions']:,}",
        "current": f"{current['total_actions']:,}",
        "emoji": delta_emoji(baseline["total_actions"], current["total_actions"], lower_is_better=False),
        "note": "more coverage is better" if current["total_actions"] >= baseline["total_actions"] else "reduced coverage",
    })

    # Action success rate
    baseline_success = ((baseline["total_actions"] - baseline["failed_actions"]) / baseline["total_actions"] * 100) if baseline["total_actions"] > 0 else 0.0
    current_success = ((current["total_actions"] - current["failed_actions"]) / current["total_actions"] * 100) if current["total_actions"] > 0 else 0.0
    comparisons.append({
        "metric": "Action success rate",
        "baseline": f"{baseline_success:.1f}%",
        "current": f"{current_success:.1f}%",
        "emoji": delta_emoji(100 - baseline_success, 100 - current_success, lower_is_better=True),
        "note": "threshold: >90%" if current_success > 90 else "threshold: >90% (BELOW)",
    })

    # Total deposited
    comparisons.append({
        "metric": "Total deposited",
        "baseline": format_btc(baseline["total_deposited"]),
        "current": format_btc(current["total_deposited"]),
        "emoji": "\u2795",  # neutral
        "note": "",
    })

    # Total withdrawn
    comparisons.append({
        "metric": "Total withdrawn",
        "baseline": format_btc(baseline["total_withdrawn"]),
        "current": format_btc(current["total_withdrawn"]),
        "emoji": "\u2795",
        "note": "",
    })

    # Total forfeited
    comparisons.append({
        "metric": "Total forfeited",
        "baseline": format_btc(baseline["total_forfeited"]),
        "current": format_btc(current["total_forfeited"]),
        "emoji": "\u2795",
        "note": "",
    })

    # Total swaps
    comparisons.append({
        "metric": "Total swaps",
        "baseline": str(baseline["total_swaps"]),
        "current": str(current["total_swaps"]),
        "emoji": delta_emoji(baseline["total_swaps"], current["total_swaps"], lower_is_better=False),
        "note": "AMM activity indicator",
    })

    # Final TVL
    comparisons.append({
        "metric": "Final TVL",
        "baseline": format_btc(baseline["final_tvl"]),
        "current": format_btc(current["final_tvl"]),
        "emoji": "\u2795",
        "note": "",
    })

    return comparisons


def regression_gate(comparisons: list[dict]) -> dict[str, Any]:
    """Evaluate overall pass/fail based on key thresholds."""
    gates = []
    overall = "PASS"

    # Gate 1: Failure rate < 10%
    failure_cmp = next(c for c in comparisons if c["metric"] == "Failure rate")
    failure_pass = "PASS" if float(failure_cmp["current"].rstrip("%")) < 10 else "FAIL"
    if failure_pass == "FAIL":
        overall = "FAIL"
    gates.append({"name": "Failure rate < 10%", "status": failure_pass, "value": failure_cmp["current"]})

    # Gate 2: Unexpected failures == 0
    unexpected_cmp = next(c for c in comparisons if c["metric"] == "Unexpected failures")
    unexpected_pass = "PASS" if int(unexpected_cmp["current"]) == 0 else "FAIL"
    if unexpected_pass == "FAIL":
        overall = "FAIL"
    gates.append({"name": "Unexpected failures == 0", "status": unexpected_pass, "value": unexpected_cmp["current"]})

    # Gate 3: vBTC ratio max <= 1.0x
    vmax_cmp = next(c for c in comparisons if c["metric"] == "vBTC ratio max")
    vmax_val = float(vmax_cmp["current"].rstrip("x"))
    vmax_pass = "PASS" if vmax_val <= 1.0 else "FAIL"
    if vmax_pass == "FAIL":
        overall = "FAIL"
    gates.append({"name": "vBTC ratio max <= 1.0x", "status": vmax_pass, "value": vmax_cmp["current"]})

    # Gate 4: vBTC ratio min >= 0.50x
    vmin_cmp = next(c for c in comparisons if c["metric"] == "vBTC ratio min")
    vmin_val = float(vmin_cmp["current"].rstrip("x")) if vmin_cmp["current"] != "N/A" else 0.0
    vmin_pass = "PASS" if vmin_val >= 0.50 else "FAIL"
    if vmin_pass == "FAIL":
        overall = "FAIL"
    gates.append({"name": "vBTC ratio min >= 0.50x", "status": vmin_pass, "value": vmin_cmp["current"]})

    # Gate 5: Action success rate > 90%
    success_cmp = next(c for c in comparisons if c["metric"] == "Action success rate")
    success_val = float(success_cmp["current"].rstrip("%"))
    success_pass = "PASS" if success_val > 90 else "FAIL"
    if success_pass == "FAIL":
        overall = "FAIL"
    gates.append({"name": "Action success rate > 90%", "status": success_pass, "value": success_cmp["current"]})

    return {"overall": overall, "gates": gates}


def generate_markdown(
    baseline_dir: Path,
    current_dir: Path,
    baseline_agg: dict,
    current_agg: dict,
    comparisons: list[dict],
    gate: dict,
) -> str:
    lines = []
    lines.append("# Simulation Regression Diff Report")
    lines.append("")
    lines.append(f"**Baseline:** `{baseline_dir}`  ")
    lines.append(f"**Current:** `{current_dir}`  ")
    lines.append(f"**Seeds compared:** {', '.join(str(s) for s in current_agg['seeds'])}  ")
    lines.append(f"**Ticks per seed:** {current_agg['tick_count']}  ")
    lines.append("")
    lines.append("---")
    lines.append("")

    # Regression gate summary
    overall_emoji = "\u2705" if gate["overall"] == "PASS" else "\U0001f534"
    lines.append(f"## Regression Gate: {overall_emoji} {gate['overall']}")
    lines.append("")
    lines.append("| Gate | Status | Value |")
    lines.append("|---|---|---|")
    for g in gate["gates"]:
        emoji = "\u2705" if g["status"] == "PASS" else "\U0001f534"
        lines.append(f"| {g['name']} | {emoji} {g['status']} | {g['value']} |")
    lines.append("")
    lines.append("---")
    lines.append("")

    # Detailed diff
    lines.append("## Detailed Comparison")
    lines.append("")
    lines.append("| Metric | Baseline | Current | | Note |")
    lines.append("|---|---|---|---|---|")
    for c in comparisons:
        lines.append(f"| {c['metric']} | {c['baseline']} | {c['current']} | {c['emoji']} | {c['note']} |")
    lines.append("")
    lines.append("---")
    lines.append("")

    # Per-seed breakdown
    lines.append("## Per-Seed Breakdown")
    lines.append("")
    lines.append("### Baseline")
    lines.append("| Seed | Failure Rate | vBTC Max | vBTC Min | Actions |")
    lines.append("|---|---|---|---|---|")
    for m in baseline_agg.get("per_seed", []):
        vmin = f"{m['vbtc_min'] / 1e18:.2f}x" if m["vbtc_min"] > 0 else "N/A"
        lines.append(
            f"| {m['seed']} | {m['failure_rate']:.1f}% | {m['vbtc_max'] / 1e18:.2f}x | {vmin} | {m['total_actions']:,} |"
        )
    lines.append("")
    lines.append("### Current")
    lines.append("| Seed | Failure Rate | vBTC Max | vBTC Min | Actions |")
    lines.append("|---|---|---|---|---|")
    for m in current_agg.get("per_seed", []):
        vmin = f"{m['vbtc_min'] / 1e18:.2f}x" if m["vbtc_min"] > 0 else "N/A"
        lines.append(
            f"| {m['seed']} | {m['failure_rate']:.1f}% | {m['vbtc_max'] / 1e18:.2f}x | {vmin} | {m['total_actions']:,} |"
        )
    lines.append("")
    lines.append("---")
    lines.append("")

    lines.append("*Generated by `scripts/generate_diff.py`*")
    lines.append("")

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Compare two simulation runs and generate a diff report.")
    parser.add_argument("--baseline", required=True, help="Path to baseline run directory")
    parser.add_argument("--current", required=True, help="Path to current run directory")
    parser.add_argument("--output", "-o", default="diff_report.md", help="Output markdown file (default: diff_report.md)")
    args = parser.parse_args()

    baseline_dir = Path(args.baseline).expanduser().resolve()
    current_dir = Path(args.current).expanduser().resolve()

    print(f"Loading baseline from {baseline_dir} ...")
    baseline_seed_dirs = discover_seed_dirs(baseline_dir)
    baseline_metrics = [compute_seed_metrics(load_summary(d), load_market_data(d)) for d in baseline_seed_dirs]
    baseline_agg = aggregate_metrics(baseline_metrics)
    print(f"  Baseline seeds: {baseline_agg['seeds']}")

    print(f"Loading current from {current_dir} ...")
    current_seed_dirs = discover_seed_dirs(current_dir)
    current_metrics = [compute_seed_metrics(load_summary(d), load_market_data(d)) for d in current_seed_dirs]
    current_agg = aggregate_metrics(current_metrics)
    print(f"  Current seeds: {current_agg['seeds']}")

    # Warn if seed sets don't match
    if set(baseline_agg["seeds"]) != set(current_agg["seeds"]):
        print("  WARNING: Seed sets differ between baseline and current!")

    print("Comparing metrics ...")
    comparisons = compare_metrics(baseline_agg, current_agg)
    gate = regression_gate(comparisons)

    print(f"Regression gate: {gate['overall']}")
    for g in gate["gates"]:
        status = "\u2713" if g["status"] == "PASS" else "\u2717"
        print(f"  {status} {g['name']}: {g['value']}")

    md = generate_markdown(baseline_dir, current_dir, baseline_agg, current_agg, comparisons, gate)

    out_path = Path(args.output)
    with open(out_path, "w") as f:
        f.write(md)

    print(f"\nDiff report written to {out_path}")

    # Print summary to stdout for quick review
    print("\n--- Summary ---")
    for c in comparisons:
        print(f"{c['emoji']} {c['metric']}: {c['baseline']} \u2192 {c['current']}")


if __name__ == "__main__":
    main()
