#!/usr/bin/env python3
"""Generate standalone 'Compare Runs' HTML page for side-by-side metric deltas.

Discovers run directories (reports_sim_* or sim_results/seed_*) and generates:
  - reports/comparison.html

Features (S3.1 acceptance criteria):
  - Side-by-side metric cards for 2-5 runs
  - Delta columns: absolute + %
  - Color-coded: green=improvement, red=regression, gray=neutral
  - Stability indicator: flags metrics with >15% CV as 'unstable'
"""

import json
import os
import sys
from pathlib import Path
from collections import defaultdict

SIM_ROOT = Path(__file__).parent.parent
REPORTS_DIR = SIM_ROOT / "reports"


def format_btc(sats: int) -> str:
    sign = "-" if sats < 0 else ""
    sats = abs(sats)
    # Round to 4 decimal places (1e4 sats)
    rounded = (sats + 5000) // 10**4
    whole = rounded // 10**4
    frac = rounded % 10**4
    return f"{sign}{whole}.{frac:04d} BTC"


def discover_runs():
    """Find run directories containing simulation_summary.json, dedup by seed."""
    seen_seeds = set()
    runs = []
    # Priority 1: reports_sim_* directories (per-seed report dirs)
    for entry in sorted(SIM_ROOT.glob("reports_sim_*")):
        if entry.is_dir():
            summary_path = entry / "simulation_summary.json"
            if summary_path.exists():
                summary = load_summary(summary_path)
                seed = summary.get("seed")
                if seed is not None and seed not in seen_seeds:
                    seen_seeds.add(seed)
                    runs.append({"id": entry.name, "summary_path": summary_path})
    # Priority 2: sim_results/seed_* directories
    sim_results = SIM_ROOT / "sim_results"
    if sim_results.exists():
        for entry in sorted(sim_results.iterdir()):
            if entry.is_dir():
                summary_path = entry / "simulation_summary.json"
                if summary_path.exists():
                    summary = load_summary(summary_path)
                    seed = summary.get("seed")
                    if seed is not None and seed not in seen_seeds:
                        seen_seeds.add(seed)
                        runs.append({"id": entry.name, "summary_path": summary_path})
    return runs


def load_summary(path):
    with open(path) as f:
        return json.load(f)


def extract_metrics(summary):
    ghost = summary["ghostVariables"]
    final = summary["finalState"]
    total_actions = int(ghost.get("totalActions", 0))
    failed_actions = int(ghost.get("totalFailedActions", 0))
    success_rate = round((total_actions - failed_actions) / total_actions * 100, 2) if total_actions > 0 else 0.0
    failure_rate = round(failed_actions / total_actions * 100, 2) if total_actions > 0 else 0.0

    return {
        "seed": summary.get("seed", "?"),
        "agentCount": summary.get("agentCount", 0),
        "tickCount": summary.get("tickCount", 0),
        "totalDeposited": int(ghost.get("totalDeposited", 0)),
        "totalWithdrawn": int(ghost.get("totalWithdrawn", 0)),
        "totalForfeited": int(ghost.get("totalForfeited", 0)),
        "totalMatchClaimed": int(ghost.get("totalMatchClaimed", 0)),
        "totalSwaps": int(ghost.get("totalSwaps", 0)),
        "totalActions": total_actions,
        "failedActions": failed_actions,
        "successRate": success_rate,
        "failureRate": failure_rate,
        "finalTvl": int(final.get("tvl", 0)),
        "finalMatchPool": int(final.get("matchPool", 0)),
        "finalVbtcRatio": int(final.get("vbtcRatio", 0)),
    }


# Metric definitions: (key, label, format, lower_is_better)
METRICS = [
    ("totalDeposited", "Total Deposited", "btc", False),
    ("totalWithdrawn", "Total Withdrawn", "btc", False),
    ("totalForfeited", "Total Forfeited", "btc", True),
    ("failureRate", "Failure Rate", "pct", True),
    ("totalSwaps", "Total Swaps", "num", False),
    ("finalTvl", "Final TVL", "btc", False),
    ("finalMatchPool", "Final Match Pool", "btc", False),
]


def fmt(val, ftype):
    if ftype == "btc":
        return format_btc(int(round(val)))
    elif ftype == "pct":
        return f"{val:.2f}%"
    else:
        return f"{int(round(val)):,}"


def compute_cv(values):
    """Coefficient of variation (%)."""
    if not values or len(values) < 2:
        return 0.0
    mean = sum(values) / len(values)
    if mean == 0:
        return 0.0
    variance = sum((v - mean) ** 2 for v in values) / len(values)
    std = variance ** 0.5
    return (std / abs(mean)) * 100


def generate_html(runs):
    n = len(runs)
    if n < 2:
        return "<html><body><h1>Need at least 2 runs to compare</h1></body></html>"

    html = []
    html.append(_head())
    html.append(_title_block(runs))
    html.append(_metric_cards(runs))
    html.append(_comparison_table(runs))
    html.append(_stability_section(runs))
    html.append(_footer())
    return "\n".join(html)


def _head():
    return """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Compare Runs — BTCNFT Simulation</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,monospace;background:#0d1117;color:#c9d1d9;line-height:1.6}
.container{max-width:1400px;margin:0 auto;padding:24px}
h1{color:#f0f6fc;font-size:28px;margin-bottom:4px}
.subtitle{color:#8b949e;margin-bottom:24px;font-size:14px}
h2{color:#f0f6fc;font-size:20px;margin:32px 0 16px;border-bottom:1px solid #21262d;padding-bottom:8px}
.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:16px;margin-bottom:32px}
.card{background:#161b22;border:1px solid #21262d;border-radius:10px;padding:20px}
.card .metric-name{font-size:12px;color:#8b949e;text-transform:uppercase;letter-spacing:0.5px;margin-bottom:12px}
.run-row{display:flex;justify-content:space-between;align-items:center;padding:6px 0;border-bottom:1px solid #21262d;font-size:14px}
.run-row:last-child{border-bottom:none}
.run-label{color:#c9d1d9}
.run-value{font-weight:600;color:#f0f6fc;min-width:90px;text-align:right}
.delta-row{display:flex;justify-content:flex-end;align-items:center;gap:8px;margin-top:8px;font-size:12px;font-weight:600}
.delta-row .abs{color:#8b949e}
table{width:100%;border-collapse:collapse;margin-bottom:16px;font-size:13px}
th{background:#161b22;color:#8b949e;text-align:left;padding:10px 12px;border-bottom:2px solid #30363d;position:sticky;top:0}
td{padding:10px 12px;border-bottom:1px solid #21262d}
tr:hover{background:#161b22}
.pos{color:#3fb950}.neg{color:#f85149}.neutral{color:#8b949e}
.badge{display:inline-block;padding:2px 8px;border-radius:12px;font-size:11px;font-weight:600}
.badge-stable{background:#1f3a1f;color:#3fb950}
.badge-unstable{background:#3a2d1f;color:#d29922}
.scroll-x{overflow-x:auto}
.stability-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:12px;margin-bottom:32px}
.stability-card{background:#161b22;border:1px solid #21262d;border-radius:8px;padding:14px}
.stability-card .metric{font-size:13px;color:#c9d1d9;margin-bottom:6px}
.stability-card .cv{font-size:20px;font-weight:700}
.stability-card .range{font-size:11px;color:#484f58;margin-top:4px}
.hint{color:#484f58;font-size:12px;margin-top:8px}
</style>
</head>
<body>
<div class="container">"""


def _title_block(runs):
    run_names = ", ".join(r["id"] for r in runs)
    return f"""<h1>Compare Runs</h1>
<p class="subtitle">BTCNFT Protocol Swarm Simulation | {len(runs)} runs | {run_names}</p>"""


def _metric_cards(runs):
    """Side-by-side metric cards with per-run values and deltas."""
    parts = []
    parts.append('<div class="cards">')

    for key, label, ftype, lower_is_better in METRICS:
        values = [r["metrics"][key] for r in runs]
        min_val = min(values)
        max_val = max(values)
        mean_val = sum(values) / len(values)

        card_rows = []
        for r in runs:
            val = r["metrics"][key]
            card_rows.append(f'<div class="run-row"><span class="run-label">{r["id"]} (seed={r["seed"]})</span><span class="run-value">{fmt(val, ftype)}</span></div>')

        # Delta: compare each run to the mean
        deltas = []
        for r in runs:
            val = r["metrics"][key]
            delta = val - mean_val
            delta_pct = (delta / mean_val * 100) if mean_val != 0 else 0
            if lower_is_better:
                cls = "pos" if delta < 0 else ("neg" if delta > 0 else "neutral")
            else:
                cls = "pos" if delta > 0 else ("neg" if delta < 0 else "neutral")
            deltas.append(f'<span class="{cls}">{r["id"]}: {fmt(delta, ftype)} ({delta_pct:+.1f}%)</span>')

        parts.append(f"""<div class="card">
<div class="metric-name">{label}</div>
{''.join(card_rows)}
<div class="delta-row">
<span class="abs">vs mean:</span>{' '.join(deltas)}
</div>
</div>""")

    parts.append('</div>')
    return "\n".join(parts)


def _comparison_table(runs):
    """Full comparison table with delta columns."""
    n = len(runs)
    headers = ['<th>Metric</th>']
    for r in runs:
        headers.append(f'<th>{r["id"]}<br><span style="font-weight:400;color:#8b949e;font-size:11px">seed={r["seed"]}</span></th>')
    headers.append('<th>Mean</th>')
    headers.append('<th>Min</th>')
    headers.append('<th>Max</th>')
    headers.append('<th>Spread</th>')

    rows = []
    for key, label, ftype, lower_is_better in METRICS:
        values = [r["metrics"][key] for r in runs]
        mean_v = sum(values) / len(values)
        min_v = min(values)
        max_v = max(values)
        spread = max_v - min_v

        cells = [f'<td><strong>{label}</strong></td>']
        for r in runs:
            val = r["metrics"][key]
            delta = val - mean_v
            delta_pct = (delta / mean_v * 100) if mean_v != 0 else 0
            if lower_is_better:
                cls = "pos" if delta < 0 else ("neg" if delta > 0 else "neutral")
            else:
                cls = "pos" if delta > 0 else ("neg" if delta < 0 else "neutral")
            cells.append(f'<td>{fmt(val, ftype)}<br><span class="{cls}" style="font-size:11px">{fmt(delta, ftype)} ({delta_pct:+.1f}%)</span></td>')

        cells.append(f'<td class="neutral">{fmt(mean_v, ftype)}</td>')
        cells.append(f'<td class="neutral">{fmt(min_v, ftype)}</td>')
        cells.append(f'<td class="neutral">{fmt(max_v, ftype)}</td>')
        cells.append(f'<td class="neutral">{fmt(spread, ftype)}</td>')
        rows.append("<tr>" + "".join(cells) + "</tr>")

    return f"""<h2>Comparison Table</h2>
<div class="scroll-x">
<table>
<thead><tr>{''.join(headers)}</tr></thead>
<tbody>{''.join(rows)}</tbody>
</table>
</div>
<div class="hint">Delta on each cell = deviation from mean. Green = improvement, Red = regression, Gray = neutral.</div>"""


def _stability_section(runs):
    """Flag metrics with >15% coefficient of variation as unstable."""
    cards = []
    for key, label, ftype, _ in METRICS:
        values = [r["metrics"][key] for r in runs]
        cv = compute_cv(values)
        mean_v = sum(values) / len(values)
        min_v = min(values)
        max_v = max(values)
        is_unstable = cv > 15.0
        badge = '<span class="badge badge-unstable">UNSTABLE</span>' if is_unstable else '<span class="badge badge-stable">STABLE</span>'
        color = "#d29922" if is_unstable else "#3fb950"
        cards.append(f"""<div class="stability-card">
<div class="metric">{label} {badge}</div>
<div class="cv" style="color:{color}">{cv:.1f}% CV</div>
<div class="range">Range: {fmt(min_v, ftype)} – {fmt(max_v, ftype)} | Mean: {fmt(mean_v, ftype)}</div>
</div>""")

    return f"""<h2>Metric Stability</h2>
<p class="subtitle">Metrics with &gt;15% coefficient of variation are flagged as unstable.</p>
<div class="stability-grid">
{''.join(cards)}
</div>"""


def _footer():
    return """<p style="text-align:center;color:#484f58;margin-top:32px;font-size:12px">
Generated by BTCNFT Protocol Simulation | S3.1 Cross-Run Comparison</p>
</div></body></html>"""


def main():
    runs_info = discover_runs()
    if len(runs_info) < 2:
        print(f"ERROR: Need >=2 runs to compare. Found {len(runs_info)}.", file=sys.stderr)
        # Also check archived results
        archive_dir = Path.home() / ".hermes" / "skills" / "simulation-results"
        if archive_dir.exists():
            for entry in sorted(archive_dir.iterdir()):
                if entry.is_dir() and entry.name.startswith("sim_seed_"):
                    summary_path = entry / "simulation_summary.json"
                    if summary_path.exists():
                        runs_info.append({"id": entry.name, "summary_path": summary_path})
        if len(runs_info) < 2:
            print("ERROR: Still not enough runs. Run simulations first.", file=sys.stderr)
            sys.exit(1)

    # Load and extract
    runs = []
    for info in runs_info:
        summary = load_summary(info["summary_path"])
        metrics = extract_metrics(summary)
        runs.append({
            "id": info["id"],
            "seed": metrics["seed"],
            "metrics": metrics,
        })

    # Sort by seed for consistent ordering
    runs.sort(key=lambda r: str(r["seed"]))

    # Cap at 5 runs
    if len(runs) > 5:
        print(f"WARNING: Found {len(runs)} runs, using first 5.", file=sys.stderr)
        runs = runs[:5]

    print(f"Comparing {len(runs)} runs: {[r['id'] for r in runs]}")
    html = generate_html(runs)

    out_path = REPORTS_DIR / "comparison.html"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w") as f:
        f.write(html)

    print(f"Comparison page written to {out_path}")
    print(f"  Open: file://{out_path.absolute()}")


if __name__ == "__main__":
    main()
