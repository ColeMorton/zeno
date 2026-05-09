#!/usr/bin/env python3
"""Generate interactive Control Tower dashboard for multi-run simulation comparison.

Discovers runs in contracts/simulation/sim_results/ and generates:
  - reports/control_tower.html

Features:
  - Cross-run metric comparison with deltas
  - Failure drill-down: treemap + time-series per tick
  - Invariant alert system: configurable bounds with R/Y/G indicators
  - Trend regression diff: auto-compare against baseline
"""

import csv
import json
import os
import sys
from collections import defaultdict
from pathlib import Path

SIM_ROOT = Path(__file__).parent.parent
REPORTS_DIR = SIM_ROOT / "reports"
SIM_RESULTS_DIR = SIM_ROOT / "sim_results"

ARCHETYPE_NAMES = [
    "Diamond Hands", "Yield Farmer", "Momentum Trader",
    "Volatility Player", "Arbitrageur", "Panic Seller", "Predator"
]
ARCHETYPE_KEYS = ["dh", "yf", "mt", "vp", "ab", "ps", "pr"]
ARCHETYPE_COLORS = [
    "#3fb950", "#58a6ff", "#d29922", "#bc8cff", "#56d4dd", "#f85149", "#e3b341"
]
ARCHETYPE_ENUM = {
    "DIAMOND_HANDS": 0, "YIELD_FARMER": 1, "MOMENTUM_TRADER": 2,
    "VOLATILITY_PLAYER": 3, "ARBITRAGEUR": 4, "PANIC_SELLER": 5, "PREDATOR": 6
}

ACTION_NAMES = [
    "NONE", "MINT_VAULT", "WITHDRAW", "EARLY_REDEEM", "MINT_BTC_TOKEN",
    "RETURN_BTC_TOKEN", "CLAIM_MATCH", "PROVE_ACTIVITY", "OPEN_PERP_LONG",
    "OPEN_PERP_SHORT", "CLOSE_PERP", "ADD_PERP_COLLATERAL", "DEPOSIT_VOL_LONG",
    "DEPOSIT_VOL_SHORT", "WITHDRAW_VOL_LONG", "WITHDRAW_VOL_SHORT",
    "POKE_DORMANT", "CLAIM_DORMANT", "SWAP_VBTC_TO_WBTC", "SWAP_WBTC_TO_VBTC",
    "ADD_LIQUIDITY"
]


def format_btc(sats: int) -> str:
    sign = "-" if sats < 0 else ""
    sats = abs(sats)
    whole = sats // 10**8
    frac = (sats % 10**8) // 10**4
    return f"{sign}{whole}.{frac:04d}"


def discover_runs():
    runs = []
    if not SIM_RESULTS_DIR.exists():
        return runs
    for entry in sorted(SIM_RESULTS_DIR.iterdir()):
        if entry.is_dir() and entry.name.startswith("sim_"):
            summary_path = entry / "simulation_summary.json"
            actions_path = entry / "agent_actions.csv"
            market_path = entry / "market_data.csv"
            if summary_path.exists() and actions_path.exists():
                runs.append({
                    "id": entry.name,
                    "dir": entry,
                    "summary_path": summary_path,
                    "actions_path": actions_path,
                    "market_path": market_path,
                })
    return runs


def load_summary(path):
    with open(path) as f:
        return json.load(f)


def load_actions(path):
    actions = []
    with open(path) as f:
        reader = csv.DictReader(f)
        for row in reader:
            actions.append({
                "tick": int(row["tick"]),
                "agentId": int(row["agentId"]),
                "action": int(row["action"]),
                "actionName": row["actionName"],
                "amount": int(row["amount"]),
                "success": row["success"] == "true",
            })
    return actions


def aggregate_run(run_info):
    summary = load_summary(run_info["summary_path"])
    actions = load_actions(run_info["actions_path"])
    ghost = summary["ghostVariables"]

    total_actions = int(ghost["totalActions"])
    failed_actions = int(ghost["totalFailedActions"])
    success_rate = round((total_actions - failed_actions) / total_actions * 100, 1) if total_actions > 0 else 0

    # Failure breakdown by action name
    fail_by_action = defaultdict(int)
    success_by_action = defaultdict(int)
    fail_by_tick = defaultdict(int)
    for act in actions:
        if act["success"]:
            success_by_action[act["actionName"]] += 1
        else:
            fail_by_action[act["actionName"]] += 1
            fail_by_tick[act["tick"]] += 1

    # Ensure all ticks present
    tick_count = summary["tickCount"]
    fail_series = [fail_by_tick.get(t, 0) for t in range(tick_count)]

    return {
        "id": run_info["id"],
        "seed": summary["seed"],
        "tickCount": tick_count,
        "agentCount": summary["agentCount"],
        "totalDeposited": int(ghost["totalDeposited"]),
        "totalWithdrawn": int(ghost["totalWithdrawn"]),
        "totalForfeited": int(ghost["totalForfeited"]),
        "totalMatchClaimed": int(ghost["totalMatchClaimed"]),
        "totalSwaps": int(ghost["totalSwaps"]),
        "totalActions": total_actions,
        "failedActions": failed_actions,
        "successRate": success_rate,
        "finalPrice": int(summary["finalState"]["price"]),
        "finalVbtcRatio": int(summary["finalState"]["vbtcRatio"]),
        "finalTvl": int(summary["finalState"]["tvl"]),
        "finalMatchPool": int(summary["finalState"]["matchPool"]),
        "failByAction": dict(fail_by_action),
        "successByAction": dict(success_by_action),
        "failSeries": fail_series,
    }


def generate_control_tower(runs_data):
    baseline = runs_data[0] if runs_data else {}
    baseline_id = baseline.get("id", "none")

    # Invariant defaults (can be tuned)
    invariant_defaults = {
        "successRate": {"min": 50, "max": 100, "warn": 55},
        "finalTvl": {"min": 300_000_000, "max": 600_000_000, "warn": 350_000_000},
        "finalMatchPool": {"min": 30_000_000, "max": 60_000_000, "warn": 35_000_000},
        "failedActionsRatio": {"min": 0, "max": 50, "warn": 45},  # percent
    }

    # Build comparison rows
    metrics = [
        ("seed", "Seed", "num"),
        ("tickCount", "Weeks", "num"),
        ("totalDeposited", "Total Deposited (BTC)", "btc"),
        ("totalWithdrawn", "Total Withdrawn (BTC)", "btc"),
        ("totalForfeited", "Total Forfeited (BTC)", "btc"),
        ("totalMatchClaimed", "Match Claimed (BTC)", "btc"),
        ("totalSwaps", "Total Swaps", "num"),
        ("totalActions", "Total Actions", "num"),
        ("failedActions", "Failed Actions", "num"),
        ("successRate", "Success Rate (%)", "pct"),
        ("finalTvl", "Final TVL (BTC)", "btc"),
        ("finalMatchPool", "Final Match Pool (BTC)", "btc"),
        ("finalVbtcRatio", "Final vBTC Ratio", "eth"),
    ]

    # Failure treemap data: action -> total across runs with fail count
    action_totals = defaultdict(lambda: {"success": 0, "fail": 0})
    for r in runs_data:
        for act, cnt in r["successByAction"].items():
            action_totals[act]["success"] += cnt
        for act, cnt in r["failByAction"].items():
            action_totals[act]["fail"] += cnt

    # HTML generation
    html_parts = []
    html_parts.append(_head())
    html_parts.append(_nav())
    html_parts.append(_overview(runs_data))
    html_parts.append(_cross_run(runs_data, baseline, metrics))
    html_parts.append(_failures(runs_data, action_totals))
    html_parts.append(_invariants(runs_data, invariant_defaults))
    html_parts.append(_trend(runs_data, baseline_id))
    html_parts.append(_footer(runs_data, baseline_id, invariant_defaults, action_totals))
    return "\n".join(html_parts)


def _head():
    return """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Simulation Control Tower</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,monospace;background:#0d1117;color:#c9d1d9;line-height:1.6}
.container{max-width:1600px;margin:0 auto;padding:24px}
h1{color:#f0f6fc;font-size:28px;margin-bottom:4px}
.subtitle{color:#8b949e;margin-bottom:24px;font-size:14px}
.nav{display:flex;gap:8px;margin-bottom:24px;border-bottom:1px solid #21262d;padding-bottom:8px;flex-wrap:wrap}
.nav button{background:#161b22;border:1px solid #30363d;color:#c9d1d9;padding:8px 16px;border-radius:6px;cursor:pointer;font-size:13px}
.nav button.active{background:#238636;border-color:#238636;color:#fff}
.nav button:hover:not(.active){background:#21262d}
.section{display:none}
.section.active{display:block}
.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:12px;margin-bottom:32px}
.card{background:#161b22;border:1px solid #21262d;border-radius:8px;padding:16px;text-align:center}
.card .value{font-size:22px;font-weight:700;color:#58a6ff}
.card .label{font-size:11px;color:#8b949e;margin-top:4px;text-transform:uppercase;letter-spacing:0.5px}
.chart-box{background:#161b22;border:1px solid #21262d;border-radius:8px;padding:16px;margin-bottom:24px}
.canvas-wrap{position:relative;height:320px}
canvas{width:100%!important}
table{width:100%;border-collapse:collapse;margin-bottom:16px;font-size:13px}
th{background:#161b22;color:#8b949e;text-align:left;padding:10px 12px;border-bottom:2px solid #30363d;position:sticky;top:0}
td{padding:10px 12px;border-bottom:1px solid #21262d}
tr:hover{background:#161b22}
.pos{color:#3fb950;font-weight:600}.neg{color:#f85149;font-weight:600}
.neutral{color:#8b949e}
.badge{display:inline-block;padding:2px 8px;border-radius:12px;font-size:11px;font-weight:600}
.alert-red{background:#3a1f1f;color:#f85149}.alert-yellow{background:#3a2d1f;color:#d29922}.alert-green{background:#1f3a1f;color:#3fb950}
.treemap{display:flex;flex-wrap:wrap;gap:4px;margin-top:16px}
.treemap-node{background:#161b22;border:1px solid #21262d;border-radius:6px;padding:12px;flex:1 1 auto;min-width:140px;text-align:center;transition:transform .1s}
.treemap-node:hover{transform:scale(1.02);border-color:#30363d}
.treemap-node .name{font-size:12px;color:#8b949e;margin-bottom:4px}
.treemap-node .count{font-size:18px;font-weight:700}
.treemap-node .sub{font-size:11px;color:#484f58;margin-top:2px}
.invariant-row{display:grid;grid-template-columns:2fr 1fr 1fr 1fr 1fr 1fr;gap:8px;align-items:center;padding:10px 12px;border-bottom:1px solid #21262d;font-size:13px}
.invariant-row.header{color:#8b949e;font-weight:600;border-bottom:2px solid #30363d}
.invariant-row .status{font-size:16px;text-align:center}
.two-col{display:grid;grid-template-columns:1fr 1fr;gap:24px}
@media(max-width:900px){.two-col{grid-template-columns:1fr}}
.scroll-x{overflow-x:auto}
input[type=number]{background:#0d1117;border:1px solid #30363d;color:#c9d1d9;padding:4px 8px;border-radius:4px;width:100px;font-size:13px}
.hint{color:#484f58;font-size:12px;margin-top:8px}
</style>
</head>
<body>
<div class="container">
<h1>Simulation Control Tower</h1>
<p class="subtitle">BTCNFT Protocol | Multi-Run Comparison & Invariant Monitoring</p>
"""


def _nav():
    tabs = [
        ("overview", "Overview"),
        ("crossrun", "Cross-Run Comparison"),
        ("failures", "Failure Drill-Down"),
        ("invariants", "Invariant Alerts"),
        ("trend", "Trend Regression"),
    ]
    buttons = "".join(
        f'<button class="nav-btn{" active" if i == 0 else ""}" data-target="{t[0]}">{t[1]}</button>'
        for i, t in enumerate(tabs)
    )
    return f'<div class="nav">{buttons}</div>'


def _overview(runs_data):
    cards = []
    total_runs = len(runs_data)
    avg_success = round(sum(r["successRate"] for r in runs_data) / total_runs, 1) if total_runs else 0
    total_actions = sum(r["totalActions"] for r in runs_data)
    total_fails = sum(r["failedActions"] for r in runs_data)

    cards.append(_card(total_runs, "Runs Loaded"))
    cards.append(_card(avg_success, "Avg Success Rate (%)", color="#d29922" if avg_success < 60 else "#58a6ff"))
    cards.append(_card(total_actions, "Total Actions"))
    cards.append(_card(total_fails, "Total Failures", color="#f85149"))
    cards.append(_card(format_btc(sum(r["finalTvl"] for r in runs_data) // total_runs) if total_runs else "0.0000", "Avg Final TVL (BTC)"))
    cards.append(_card(format_btc(sum(r["finalMatchPool"] for r in runs_data) // total_runs) if total_runs else "0.0000", "Avg Match Pool (BTC)"))

    return f'<div id="overview" class="section active"><div class="cards">{"".join(cards)}</div></div>'


def _card(value, label, color=None):
    c = color or "#58a6ff"
    return f'<div class="card"><div class="value" style="color:{c}">{value}</div><div class="label">{label}</div></div>'


def _cross_run(runs_data, baseline, metrics):
    headers = ['<th>Metric</th>']
    for r in runs_data:
        headers.append(f'<th>{r["id"]}<br><span style="font-weight:400;color:#8b949e;font-size:11px">seed={r["seed"]}</span></th>')
    if len(runs_data) > 1:
        headers.append('<th>Spread (Max-Min)</th>')
        headers.append('<th>vs Baseline</th>')

    rows = []
    for key, label, fmt in metrics:
        cells = [f'<td>{label}</td>']
        vals = []
        for r in runs_data:
            raw = r.get(key, 0)
            if fmt == "btc":
                disp = format_btc(raw)
                vals.append(raw)
            elif fmt == "pct":
                disp = f"{raw}%"
                vals.append(raw)
            elif fmt == "eth":
                disp = f"{raw / 1e18:.4f}"
                vals.append(raw)
            else:
                disp = str(raw)
                vals.append(raw)
            cells.append(f'<td>{disp}</td>')

        if len(runs_data) > 1:
            spread = max(vals) - min(vals)
            if fmt == "btc":
                spread_disp = format_btc(spread)
            elif fmt == "pct":
                spread_disp = f"{spread:.1f}%"
            elif fmt == "eth":
                spread_disp = f"{spread / 1e18:.4f}"
            else:
                spread_disp = str(spread)
            cells.append(f'<td class="neutral">{spread_disp}</td>')

            base_val = baseline.get(key, 0)
            if base_val != 0 and fmt in ("pct", "btc", "eth", "num"):
                last_val = vals[-1] if vals else 0
                delta = last_val - base_val
                delta_pct = (delta / base_val) * 100 if base_val else 0
                if fmt == "btc":
                    delta_disp = f"{format_btc(delta)} ({delta_pct:+.1f}%)"
                elif fmt == "pct":
                    delta_disp = f"{delta:+.1f}pp"
                elif fmt == "eth":
                    delta_disp = f"{delta / 1e18:+.4f} ({delta_pct:+.1f}%)"
                else:
                    delta_disp = f"{delta:+} ({delta_pct:+.1f}%)"
                cls = "pos" if delta >= 0 else "neg"
                cells.append(f'<td class="{cls}">{delta_disp}</td>')
            else:
                cells.append('<td class="neutral">-</td>')

        rows.append("<tr>" + "".join(cells) + "</tr>")

    return f'''<div id="crossrun" class="section">
<h2>Cross-Run Comparison</h2>
<div class="scroll-x">
<table>
<thead><tr>{"".join(headers)}</tr></thead>
<tbody>{"".join(rows)}</tbody>
</table>
</div>
<div class="hint">Baseline = {baseline.get("id", "?")}. Spread shows max-min across all runs. Delta shows last run vs baseline.</div>
</div>'''


def _failures(runs_data, action_totals):
    # Build treemap HTML
    nodes = []
    sorted_actions = sorted(action_totals.items(), key=lambda x: x[1]["fail"] + x[1]["success"], reverse=True)
    for act, counts in sorted_actions:
        total = counts["success"] + counts["fail"]
        fail_pct = round(counts["fail"] / total * 100, 1) if total else 0
        color = "#f85149" if fail_pct > 30 else "#d29922" if fail_pct > 10 else "#3fb950"
        nodes.append(
            f'<div class="treemap-node">'
            f'<div class="name">{act}</div>'
            f'<div class="count" style="color:{color}">{counts["fail"]} / {total}</div>'
            f'<div class="sub">{fail_pct}% fail rate</div>'
            f'</div>'
        )

    return f'''<div id="failures" class="section">
<h2>Failure Drill-Down</h2>
<div class="two-col">
<div class="chart-box">
<h3 style="color:#8b949e;font-size:14px;margin-bottom:8px">Action Treemap (Fail / Total)</h3>
<div class="treemap">{"".join(nodes)}</div>
</div>
<div class="chart-box">
<h3 style="color:#8b949e;font-size:14px;margin-bottom:8px">Failures per Tick (Latest Run)</h3>
<div class="canvas-wrap"><canvas id="failTickChart"></canvas></div>
</div>
</div>
<div class="chart-box" style="margin-top:24px">
<h3 style="color:#8b949e;font-size:14px;margin-bottom:8px">Failure Rate by Run</h3>
<div class="canvas-wrap"><canvas id="failRateChart"></canvas></div>
</div>
</div>'''


def _invariants(runs_data, invariant_defaults):
    rows = []
    inv_list = [
        ("successRate", "Success Rate (%)", "pct"),
        ("finalTvl", "Final TVL (BTC)", "btc"),
        ("finalMatchPool", "Final Match Pool (BTC)", "btc"),
        ("failedActionsRatio", "Failure Ratio (%)", "pct"),
    ]

    for key, label, fmt in inv_list:
        d = invariant_defaults.get(key, {})
        min_v = d.get("min", 0)
        max_v = d.get("max", 100)
        warn_v = d.get("warn", min_v)
        rows.append(
            f'<div class="invariant-row" data-inv="{key}">'
            f'<div>{label}</div>'
            f'<div><input type="number" class="inv-min" value="{min_v}" step="any"></div>'
            f'<div><input type="number" class="inv-warn" value="{warn_v}" step="any"></div>'
            f'<div><input type="number" class="inv-max" value="{max_v}" step="any"></div>'
            f'<div class="inv-reading">-</div>'
            f'<div class="status">-</div>'
            f'</div>'
        )

    run_options = "".join(f'<option value="{r["id"]}">{r["id"]}</option>' for r in runs_data)

    return f'''<div id="invariants" class="section">
<h2>Invariant Alerts</h2>
<div style="margin-bottom:16px">
<label style="color:#8b949e;font-size:13px;margin-right:8px">Select Run:</label>
<select id="invRunSelect" style="background:#0d1117;border:1px solid #30363d;color:#c9d1d9;padding:6px 12px;border-radius:4px;font-size:13px">
{run_options}
</select>
<button id="invCheckBtn" style="background:#238636;border:1px solid #238636;color:#fff;padding:6px 12px;border-radius:4px;margin-left:8px;cursor:pointer;font-size:13px">Check Invariants</button>
</div>
<div class="invariant-row header">
<div>Metric</div><div>Min Bound</div><div>Warn Bound</div><div>Max Bound</div><div>Reading</div><div>Status</div>
</div>
{"".join(rows)}
<div class="hint">Green = within bounds. Yellow = in warning zone. Red = outside bounds.</div>
</div>'''


def _trend(runs_data, baseline_id):
    return f'''<div id="trend" class="section">
<h2>Trend Regression Diff</h2>
<p style="color:#8b949e;font-size:13px;margin-bottom:16px">Baseline: <strong>{baseline_id}</strong>. Each bar shows the latest run delta from baseline.</p>
<div class="chart-box">
<div class="canvas-wrap"><canvas id="trendChart"></canvas></div>
</div>
<div class="chart-box">
<div class="canvas-wrap"><canvas id="trendScatterChart"></canvas></div>
</div>
</div>'''


def _footer(runs_data, baseline_id, invariant_defaults, action_totals):
    runs_json = json.dumps(runs_data)
    inv_json = json.dumps(invariant_defaults)
    action_json = json.dumps(action_totals)
    baseline_json = json.dumps(runs_data[0] if runs_data else {})

    return f'''<script>
const runs = {runs_json};
const baseline = {baseline_json};
const invariants = {inv_json};
const actionTotals = {action_json};
const toBtc = x => (x / 1e8).toFixed(4);
const toEth = x => (x / 1e18).toFixed(2);

// Tab navigation
document.querySelectorAll('.nav-btn').forEach(btn => {{
  btn.addEventListener('click', () => {{
    document.querySelectorAll('.nav-btn').forEach(b => b.classList.remove('active'));
    document.querySelectorAll('.section').forEach(s => s.classList.remove('active'));
    btn.classList.add('active');
    document.getElementById(btn.dataset.target).classList.add('active');
  }});
}});

// Failure tick chart (latest run)
const latestRun = runs[runs.length - 1];
const failCtx = document.getElementById('failTickChart');
if (failCtx && latestRun) {{
  new Chart(failCtx, {{
    type: 'bar',
    data: {{
      labels: latestRun.failSeries.map((_, i) => i),
      datasets: [{{
        label: 'Failures per Tick',
        data: latestRun.failSeries,
        backgroundColor: '#f85149',
        borderRadius: 2
      }}]
    }},
    options: {{
      responsive: true,
      maintainAspectRatio: false,
      scales: {{
        x: {{ display: false }},
        y: {{ ticks: {{ color: '#8b949e' }}, grid: {{ color: '#21262d' }} }}
      }},
      plugins: {{ legend: {{ display: false }} }}
    }}
  }});
}}

// Failure rate by run
const rateCtx = document.getElementById('failRateChart');
if (rateCtx) {{
  new Chart(rateCtx, {{
    type: 'bar',
    data: {{
      labels: runs.map(r => r.id),
      datasets: [
        {{ label: 'Success', data: runs.map(r => r.totalActions - r.failedActions), backgroundColor: '#3fb950', borderRadius: 4 }},
        {{ label: 'Failed', data: runs.map(r => r.failedActions), backgroundColor: '#f85149', borderRadius: 4 }}
      ]
    }},
    options: {{
      responsive: true,
      maintainAspectRatio: false,
      scales: {{
        x: {{ stacked: true, ticks: {{ color: '#8b949e' }} }},
        y: {{ stacked: true, ticks: {{ color: '#8b949e' }}, grid: {{ color: '#21262d' }} }}
      }},
      plugins: {{ legend: {{ labels: {{ color: '#c9d1d9' }} }} }}
    }}
  }});
}}

// Trend regression chart
const trendCtx = document.getElementById('trendChart');
if (trendCtx && baseline) {{
  const trendKeys = [
    {{k:'successRate', l:'Success Rate', f:v=>v+'%'}},
    {{k:'finalTvl', l:'Final TVL', f:v=>toBtc(v)}},
    {{k:'finalMatchPool', l:'Match Pool', f:v=>toBtc(v)}},
    {{k:'totalDeposited', l:'Total Deposited', f:v=>toBtc(v)}},
    {{k:'totalForfeited', l:'Total Forfeited', f:v=>toBtc(v)}},
  ];
  const lastRun = runs[runs.length - 1];
  const deltas = trendKeys.map(t => {{
    const b = baseline[t.k] || 0;
    const v = lastRun[t.k] || 0;
    return b ? ((v - b) / b * 100) : 0;
  }});
  new Chart(trendCtx, {{
    type: 'bar',
    data: {{
      labels: trendKeys.map(t => t.l),
      datasets: [{{
        label: 'Delta from Baseline (%)',
        data: deltas,
        backgroundColor: deltas.map(d => d >= 0 ? '#3fb950' : '#f85149'),
        borderRadius: 4
      }}]
    }},
    options: {{
      responsive: true,
      maintainAspectRatio: false,
      scales: {{
        y: {{ ticks: {{ color: '#8b949e', callback:v=>v+'%' }}, grid: {{ color: '#21262d' }} }},
        x: {{ ticks: {{ color: '#8b949e' }} }}
      }},
      plugins: {{ legend: {{ display: false }} }}
    }}
  }});
}}

// Trend scatter: success rate vs failure count
const scatterCtx = document.getElementById('trendScatterChart');
if (scatterCtx) {{
  new Chart(scatterCtx, {{
    type: 'scatter',
    data: {{
      datasets: [{{
        label: 'Runs',
        data: runs.map(r => ({{ x: r.successRate, y: r.failedActions }})),
        backgroundColor: '#58a6ff',
        pointRadius: 6
      }}]
    }},
    options: {{
      responsive: true,
      maintainAspectRatio: false,
      scales: {{
        x: {{ title: {{ display:true, text:'Success Rate (%)', color:'#8b949e' }}, ticks:{{color:'#8b949e'}}, grid:{{color:'#21262d'}} }},
        y: {{ title: {{ display:true, text:'Failed Actions', color:'#8b949e' }}, ticks:{{color:'#8b949e'}}, grid:{{color:'#21262d'}} }}
      }},
      plugins: {{ legend: {{ display: false }} }}
    }}
  }});
}}

// Invariant checking
function getInvValue(run, key) {{
  if (key === 'failedActionsRatio') {{
    return run.totalActions ? (run.failedActions / run.totalActions * 100) : 0;
  }}
  return run[key] || 0;
}}

function checkInvariants() {{
  const runId = document.getElementById('invRunSelect').value;
  const run = runs.find(r => r.id === runId);
  if (!run) return;
  document.querySelectorAll('.invariant-row[data-inv]').forEach(row => {{
    const key = row.dataset.inv;
    const minVal = parseFloat(row.querySelector('.inv-min').value);
    const warnVal = parseFloat(row.querySelector('.inv-warn').value);
    const maxVal = parseFloat(row.querySelector('.inv-max').value);
    const val = getInvValue(run, key);
    const readingEl = row.querySelector('.inv-reading');
    const statusEl = row.querySelector('.status');

    let disp = val.toFixed(2);
    if (key === 'finalTvl' || key === 'finalMatchPool') disp = toBtc(val);
    readingEl.textContent = disp;

    if (val < minVal || val > maxVal) {{
      statusEl.textContent = '🔴';
      row.style.background = '#3a1f1f';
    }} else if (val < warnVal || val > (maxVal - (warnVal - minVal))) {{
      statusEl.textContent = '🟡';
      row.style.background = '#3a2d1f';
    }} else {{
      statusEl.textContent = '🟢';
      row.style.background = 'transparent';
    }}
  }});
}}

document.getElementById('invCheckBtn').addEventListener('click', checkInvariants);
document.getElementById('invRunSelect').addEventListener('change', checkInvariants);
// Auto-check on load for first run
if (runs.length) checkInvariants();
</script>
<p style="text-align:center;color:#484f58;margin-top:32px;font-size:12px">
Generated by BTCNFT Protocol Simulation Control Tower</p>
</div>
</body>
</html>'''


def main():
    print("Discovering simulation runs...")
    runs = discover_runs()
    if not runs:
        print(f"ERROR: No simulation runs found in {SIM_RESULTS_DIR}", file=sys.stderr)
        sys.exit(1)

    print(f"  Found {len(runs)} run(s)")
    runs_data = [aggregate_run(r) for r in runs]

    print("Generating Control Tower dashboard...")
    html = generate_control_tower(runs_data)

    out_path = REPORTS_DIR / "control_tower.html"
    with open(out_path, "w") as f:
        f.write(html)

    print(f"Dashboard written to {out_path} ({len(html):,} bytes)")

    if sys.platform == "darwin":
        os.system(f'open "{out_path}"')


if __name__ == "__main__":
    main()
