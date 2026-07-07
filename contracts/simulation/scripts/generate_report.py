#!/usr/bin/env python3
"""Generate interactive HTML dashboard from swarm simulation CSV/JSON data.

Reads from contracts/simulation/reports/:
  - market_data.csv         tick-level price/TVL/regime
  - agent_net_worth.csv     tick x 100 agent net worth matrix
  - agent_actions.csv       action log
  - agent_configs.json      100 agent configs
  - simulation_summary.json ghost variables + final state

Writes:
  - reports/simulation.html self-contained Chart.js dashboard
"""

import csv
import json
import os
import sys
from collections import defaultdict
from pathlib import Path

REPORTS_DIR = Path(__file__).parent.parent / "reports"

# Load invariant configuration
INVARIANTS_PATH = Path(__file__).parent / "invariants.json"


def load_invariants():
    if INVARIANTS_PATH.exists():
        with open(INVARIANTS_PATH) as f:
            return json.load(f)
    return {"invariants": []}

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
    return f"{sign}{whole}.{frac:04d} BTC"


def calc_return_pct(final_val: int, initial_val: int) -> float:
    if initial_val == 0:
        return 0.0
    return round((final_val / initial_val - 1) * 100, 2)


def load_market_data():
    rows = []
    with open(REPORTS_DIR / "market_data.csv") as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append({
                "tick": int(row["tick"]),
                "price": int(row["price"]),
                "vbtcRatio": int(row["vbtcRatio"]),
                "tvl": int(row["tvl"]),
                "matchPool": int(row["matchPool"]),
                "regime": int(row["regime"]),
                "perpVaultBalance": int(row.get("perpVaultBalance", 0) or 0),
                "perpTotalCollateral": int(row.get("perpTotalCollateral", 0) or 0),
                "volPoolBalance": int(row.get("volPoolBalance", 0) or 0),
                "volPoolAssets": int(row.get("volPoolAssets", 0) or 0),
            })
    return rows


def load_agent_net_worth():
    """Returns dict: agent_id -> [nw_tick0, nw_tick1, ...]"""
    nw = defaultdict(list)
    with open(REPORTS_DIR / "agent_net_worth.csv") as f:
        reader = csv.DictReader(f)
        for row in reader:
            for i in range(100):
                nw[i].append(int(row[f"agent_{i}"]))
    return nw


def load_agent_actions():
    actions = []
    with open(REPORTS_DIR / "agent_actions.csv") as f:
        reader = csv.DictReader(f)
        for row in reader:
            actions.append({
                "tick": int(row["tick"]),
                "agentId": int(row["agentId"]),
                "action": int(row["action"]),
                "actionName": row["actionName"],
                "amount": int(row["amount"]),
                "success": row["success"] == "true",
                "errorType": row.get("errorType", ""),
            })
    return actions


def load_agent_configs():
    with open(REPORTS_DIR / "agent_configs.json") as f:
        return json.load(f)


def load_summary():
    with open(REPORTS_DIR / "simulation_summary.json") as f:
        return json.load(f)


def compute_tick_alerts(market, actions, tick_count, inv_config):
    """Compute alerts per tick based on invariant configuration.

    Returns list of alerts: {tick, invariant_id, label, severity, message}
    """
    invs = inv_config.get("invariants", [])
    alerts = []

    # Pre-compute per-tick failure counts from actions
    tick_fail_counts = defaultdict(int)
    tick_total_counts = defaultdict(int)
    for act in actions:
        t = act["tick"]
        tick_total_counts[t] += 1
        if not act["success"]:
            tick_fail_counts[t] += 1

    for tick in range(tick_count):
        row = market[tick] if tick < len(market) else {}
        for inv in invs:
            if not inv.get("enabled", True):
                continue
            inv_type = inv.get("type", "")
            inv_id = inv.get("id", "")
            label = inv.get("label", inv_id)
            severity = inv.get("severity", "critical")

            if inv_type == "range":
                scale = inv.get("scale", 1)
                raw = row.get(inv.get("column", ""), 0)
                # Skip uninitialized pool (vbtcRatio == 0 before AMM seeding)
                if inv_id == "vbtc_ratio_bounds" and raw == 0:
                    continue
                val = raw / scale
                min_v = inv.get("min", float("-inf"))
                max_v = inv.get("max", float("inf"))
                if val < min_v or val > max_v:
                    alerts.append({
                        "tick": tick,
                        "id": inv_id,
                        "label": label,
                        "severity": severity,
                        "message": f"{label} = {val:.4f} (bounds [{min_v}, {max_v}])",
                    })

            elif inv_type == "threshold_high":
                window = inv.get("window_ticks", 1)
                total_actions = sum(tick_total_counts.get(t, 0) for t in range(max(0, tick - window + 1), tick + 1))
                failed_actions = sum(tick_fail_counts.get(t, 0) for t in range(max(0, tick - window + 1), tick + 1))
                rate = (failed_actions / total_actions * 100) if total_actions > 0 else 0.0
                crit = inv.get("critical_threshold", float("inf"))
                warn = inv.get("warn_threshold", float("inf"))
                if rate > crit:
                    alerts.append({
                        "tick": tick,
                        "id": inv_id,
                        "label": label,
                        "severity": "critical",
                        "message": f"{label} = {rate:.1f}% (critical threshold {crit}%)",
                    })
                elif rate > warn and severity == "warning":
                    alerts.append({
                        "tick": tick,
                        "id": inv_id,
                        "label": label,
                        "severity": "warning",
                        "message": f"{label} = {rate:.1f}% (warning threshold {warn}%)",
                    })

            elif inv_type == "solvency":
                bal = row.get(inv.get("balance_column", ""), 0)
                liab = row.get(inv.get("liability_column", ""), 0)
                mult = inv.get("multiplier", 1)
                # Skip when no activity (both zero)
                if bal == 0 and liab == 0:
                    continue
                if bal < liab * mult:
                    alerts.append({
                        "tick": tick,
                        "id": inv_id,
                        "label": label,
                        "severity": severity,
                        "message": f"{label}: balance {bal} < liability {liab} x{mult}",
                    })

            elif inv_type == "max_ratio":
                num = row.get(inv.get("numerator_column", ""), 0)
                den = row.get(inv.get("denominator_column", ""), 0)
                max_r = inv.get("max_ratio", float("inf"))
                if den > 0 and (num / den) > max_r:
                    ratio = num / den
                    alerts.append({
                        "tick": tick,
                        "id": inv_id,
                        "label": label,
                        "severity": severity,
                        "message": f"{label}: ratio {ratio:.4f} > max {max_r}",
                    })

    return alerts


def format_alert_html(alerts):
    """Render alert list as HTML rows."""
    rows = []
    for a in alerts:
        severity = a["severity"]
        icon = "🔴" if severity == "critical" else "🟡"
        cls = "alert-critical" if severity == "critical" else "alert-warning"
        rows.append(
            f'<div class="alert-row {cls}">'
            f'<span class="alert-icon">{icon}</span>'
            f'<span class="alert-tick">Tick {a["tick"]}</span>'
            f'<span class="alert-label">{a["label"]}</span>'
            f'<span class="alert-msg">{a["message"]}</span>'
            f'</div>'
        )
    return "\n".join(rows)


def build_archetype_avg_nw(configs, agent_nw, tick_count):
    """Build per-archetype averaged net worth time series."""
    arch_agents = defaultdict(list)
    for cfg in configs:
        arch_id = ARCHETYPE_ENUM.get(cfg["archetype"], -1)
        if arch_id >= 0:
            arch_agents[arch_id].append(cfg["agentId"])

    result = {}
    for arch_id in range(7):
        agents = arch_agents.get(arch_id, [])
        if not agents:
            result[ARCHETYPE_KEYS[arch_id]] = [0] * tick_count
            continue
        avg = []
        for t in range(tick_count):
            total = sum(agent_nw[a][t] for a in agents)
            avg.append(total // len(agents))
        result[ARCHETYPE_KEYS[arch_id]] = avg
    return result


def build_archetype_action_counts(configs, actions):
    """Build per-archetype action distribution (7 x 21)."""
    agent_to_arch = {}
    for cfg in configs:
        arch_id = ARCHETYPE_ENUM.get(cfg["archetype"], -1)
        agent_to_arch[cfg["agentId"]] = arch_id

    counts = {k: [0] * 21 for k in ARCHETYPE_KEYS}
    for act in actions:
        arch_id = agent_to_arch.get(act["agentId"], -1)
        if 0 <= arch_id < 7 and 0 <= act["action"] < 21:
            counts[ARCHETYPE_KEYS[arch_id]][act["action"]] += 1
    return counts


def build_leaderboard(configs, agent_nw, tick_count, top_n=20):
    """Build top N agents by final net worth."""
    agents = []
    for cfg in configs:
        aid = cfg["agentId"]
        final_nw = agent_nw[aid][-1] if tick_count > 0 else 0
        initial = cfg["initialCapitalWbtc"]
        agents.append({
            "agentId": aid,
            "archetype": cfg["archetype"],
            "riskTolerance": cfg["riskTolerance"],
            "patience": cfg["patience"],
            "leveragePreference": cfg["leveragePreference"],
            "volBias": cfg["volBias"],
            "initialCapital": initial,
            "finalNetWorth": final_nw,
            "returnPct": calc_return_pct(final_nw, initial),
        })
    agents.sort(key=lambda a: a["finalNetWorth"], reverse=True)
    return agents[:top_n], agents


def build_failure_data(actions, configs, tick_count):
    """Build structures for failure drill-down panel.

    Returns dict with:
      - agent_to_arch: agentId -> archetype key
      - tick_total: tick -> total actions
      - tick_fail: tick -> failed actions
      - action_total: actionName -> total count
      - action_fail: actionName -> fail count
      - action_error: actionName -> errorType -> count
      - arch_fail: archetype key -> fail count
      - worst_tick: tick with max failures
      - total_failures: int
      - total_actions: int
      - filtered_actions: list of action dicts with archetype key added
    """
    agent_to_arch = {}
    for cfg in configs:
        arch_id = ARCHETYPE_ENUM.get(cfg["archetype"], -1)
        agent_to_arch[cfg["agentId"]] = ARCHETYPE_KEYS[arch_id] if arch_id >= 0 else "unknown"

    tick_total = defaultdict(int)
    tick_fail = defaultdict(int)
    action_total = defaultdict(int)
    action_fail = defaultdict(int)
    action_error = defaultdict(lambda: defaultdict(int))
    arch_fail = defaultdict(int)
    total_failures = 0
    total_actions = 0
    filtered_actions = []

    for act in actions:
        t = act["tick"]
        an = act["actionName"]
        arch = agent_to_arch.get(act["agentId"], "unknown")
        tick_total[t] += 1
        action_total[an] += 1
        total_actions += 1

        enriched = {**act, "archetype": arch}
        filtered_actions.append(enriched)

        if not act["success"]:
            tick_fail[t] += 1
            action_fail[an] += 1
            arch_fail[arch] += 1
            total_failures += 1
            err = act.get("errorType", "") or "Unknown"
            action_error[an][err] += 1

    worst_tick = max(tick_fail, key=tick_fail.get, default=0) if tick_fail else 0

    return {
        "agent_to_arch": agent_to_arch,
        "tick_total": dict(tick_total),
        "tick_fail": dict(tick_fail),
        "action_total": dict(action_total),
        "action_fail": dict(action_fail),
        "action_error": {k: dict(v) for k, v in action_error.items()},
        "arch_fail": dict(arch_fail),
        "worst_tick": worst_tick,
        "total_failures": total_failures,
        "total_actions": total_actions,
        "filtered_actions": filtered_actions,
    }


def generate_html(market, agent_nw, configs, summary, actions):
    tick_count = summary["tickCount"]
    ghost = summary["ghostVariables"]
    total_actions = int(ghost["totalActions"])
    failed_actions = int(ghost["totalFailedActions"])
    success_rate = ((total_actions - failed_actions) * 100 // total_actions) if total_actions > 0 else 0

    prices = [r["price"] for r in market]
    vbtc_ratios = [r["vbtcRatio"] for r in market]
    tvls = [r["tvl"] for r in market]
    match_pools = [r["matchPool"] for r in market]
    regimes = [r["regime"] for r in market]

    # Compute invariant alerts
    inv_config = load_invariants()
    alerts = compute_tick_alerts(market, actions, tick_count, inv_config)
    alert_json = json.dumps(alerts)
    current_tick_alerts = [a for a in alerts if a["tick"] == tick_count - 1]

    arch_nw = build_archetype_avg_nw(configs, agent_nw, tick_count)
    arch_actions = build_archetype_action_counts(configs, actions)
    leaderboard, all_agents = build_leaderboard(configs, agent_nw, tick_count)
    failure_data = build_failure_data(actions, configs, tick_count)

    # Archetype performance stats
    arch_perf = []
    for arch_id in range(7):
        agents_of_type = [a for a in all_agents if ARCHETYPE_ENUM.get(a["archetype"], -1) == arch_id]
        if agents_of_type:
            count = len(agents_of_type)
            avg_initial = sum(a["initialCapital"] for a in agents_of_type) // count
            avg_final = sum(a["finalNetWorth"] for a in agents_of_type) // count
            avg_ret = calc_return_pct(avg_final, avg_initial)
            arch_perf.append({"count": count, "avgInitial": avg_initial, "avgFinal": avg_final, "avgReturn": avg_ret})
        else:
            arch_perf.append({"count": 0, "avgInitial": 0, "avgFinal": 0, "avgReturn": 0})

    html = []
    html.append(_head())
    html.append(_alert_panel(current_tick_alerts, len(alerts)))
    html.append(_summary_cards(summary, success_rate))
    html.append(_alert_history_section(alerts))
    html.append(_failure_drilldown_section(failure_data, tick_count))
    html.append(_price_chart_section(prices, vbtc_ratios, regimes))
    html.append(_nw_chart_section(arch_nw))
    html.append(_leaderboard_section(leaderboard))
    html.append(_archetype_performance_section(arch_perf))
    html.append(_action_distribution_section(arch_actions))
    html.append(_protocol_metrics_section(tvls, match_pools))
    html.append(_agent_details_section(all_agents))
    html.append(_footer(tick_count, alert_json, failure_data))
    return "\n".join(html)


def _head():
    return f"""<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Swarm Simulation Report</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<style>
*{{margin:0;padding:0;box-sizing:border-box}}
body{{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,monospace;background:#0d1117;color:#c9d1d9;line-height:1.6}}
.container{{max-width:1400px;margin:0 auto;padding:24px}}
h1{{color:#f0f6fc;font-size:28px;margin-bottom:4px}}
.subtitle{{color:#8b949e;margin-bottom:24px;font-size:14px}}
h2{{color:#f0f6fc;font-size:20px;margin:32px 0 16px;border-bottom:1px solid #21262d;padding-bottom:8px}}
.cards{{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:12px;margin-bottom:32px}}
.card{{background:#161b22;border:1px solid #21262d;border-radius:8px;padding:16px;text-align:center}}
.card .value{{font-size:24px;font-weight:700;color:#58a6ff}}
.card .label{{font-size:12px;color:#8b949e;margin-top:4px}}
.chart-box{{background:#161b22;border:1px solid #21262d;border-radius:8px;padding:16px;margin-bottom:24px}}
canvas{{width:100%!important;max-height:400px}}
table{{width:100%;border-collapse:collapse;margin-bottom:16px;font-size:13px}}
th{{background:#161b22;color:#8b949e;text-align:left;padding:8px 12px;border-bottom:2px solid #21262d}}
td{{padding:8px 12px;border-bottom:1px solid #21262d}}
tr:hover{{background:#161b22}}
.pos{{color:#3fb950}}.neg{{color:#f85149}}
details{{background:#161b22;border:1px solid #21262d;border-radius:6px;margin-bottom:8px}}
summary{{padding:10px 16px;cursor:pointer;font-weight:600;color:#58a6ff;font-size:13px}}
summary:hover{{background:#1c2128}}
.detail-content{{padding:12px 16px;font-size:12px}}
.detail-content table{{font-size:12px}}
.badge{{display:inline-block;padding:2px 8px;border-radius:12px;font-size:11px;font-weight:600}}
.b0{{background:#1f3a1f;color:#3fb950}}.b1{{background:#1f2d3a;color:#58a6ff}}
.b2{{background:#3a2d1f;color:#d29922}}.b3{{background:#2d1f3a;color:#bc8cff}}
.b4{{background:#1f3a3a;color:#56d4dd}}.b5{{background:#3a1f1f;color:#f85149}}
.b6{{background:#3a3a1f;color:#e3b341}}
.two-col{{display:grid;grid-template-columns:1fr 1fr;gap:24px}}
@media(max-width:800px){{.two-col{{grid-template-columns:1fr}}}}
/* Alert panel styles */
.alert-panel{{background:#161b22;border:1px solid #21262d;border-radius:8px;padding:16px;margin-bottom:24px}}
.alert-panel-header{{display:flex;align-items:center;gap:12px;margin-bottom:12px}}
.alert-panel-title{{font-size:16px;font-weight:600;color:#f0f6fc}}
.alert-status{{font-size:20px}}
.alert-count{{font-size:12px;color:#8b949e;margin-left:auto}}
.alert-row{{display:flex;align-items:center;gap:10px;padding:8px 12px;border-radius:6px;margin-bottom:6px;font-size:13px}}
.alert-critical{{background:#3a1f1f;color:#f85149;border:1px solid #5a2f2f}}
.alert-warning{{background:#3a2d1f;color:#d29922;border:1px solid #5a4a2f}}
.alert-icon{{font-size:16px;flex-shrink:0}}
.alert-tick{{font-weight:600;min-width:60px;flex-shrink:0}}
.alert-label{{font-weight:600;min-width:140px;flex-shrink:0}}
.alert-msg{{color:#c9d1d9}}
.alert-history{{max-height:300px;overflow-y:auto;border:1px solid #21262d;border-radius:6px;padding:8px;background:#0d1117}}
.alert-history-empty{{color:#484f58;text-align:center;padding:20px;font-size:13px}}
/* Failure drill-down panel styles */
.drill-grid{{display:grid;grid-template-columns:1fr 1fr;gap:24px;margin-bottom:24px}}
@media(max-width:900px){{.drill-grid{{grid-template-columns:1fr}}}}
.drill-filters{{display:flex;gap:12px;flex-wrap:wrap;margin-bottom:16px;align-items:center}}
.drill-filters label{{font-size:12px;color:#8b949e}}
.drill-filters select,.drill-filters input{{background:#0d1117;border:1px solid #30363d;color:#c9d1d9;padding:6px 10px;border-radius:6px;font-size:13px}}
.drill-filters button{{background:#238636;border:none;color:#fff;padding:6px 14px;border-radius:6px;cursor:pointer;font-size:13px}}
.drill-filters button:hover{{background:#2ea043}}
.treemap-wrap{{display:flex;flex-wrap:wrap;gap:4px;max-height:360px;overflow-y:auto}}
.treemap-node{{background:#161b22;border:1px solid #21262d;border-radius:6px;padding:10px;flex:1 1 auto;min-width:120px;text-align:center;cursor:pointer;transition:transform .1s,border-color .1s}}
.treemap-node:hover{{transform:scale(1.02);border-color:#58a6ff}}
.treemap-node.active{{border-color:#58a6ff;background:#1c2d3a}}
.treemap-node .name{{font-size:12px;color:#8b949e;margin-bottom:4px}}
.treemap-node .count{{font-size:16px;font-weight:700}}
.treemap-node .sub{{font-size:11px;color:#484f58;margin-top:2px}}
.error-sub{{display:flex;flex-wrap:wrap;gap:2px;margin-top:4px;justify-content:center}}
.error-pill{{font-size:10px;padding:1px 6px;border-radius:10px;background:#21262d;color:#c9d1d9}}
.stats-row{{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:12px;margin-bottom:16px}}
.stat-card{{background:#161b22;border:1px solid #21262d;border-radius:8px;padding:14px;text-align:center}}
.stat-card .value{{font-size:20px;font-weight:700;color:#f85149}}
.stat-card .label{{font-size:11px;color:#8b949e;margin-top:4px;text-transform:uppercase;letter-spacing:0.5px}}
.no-failures{{color:#3fb950;text-align:center;padding:24px;font-size:14px}}
</style></head><body>
<div class="container">
<h1>100-Agent Swarm Simulation Report</h1>
<p class="subtitle">BTCNFT Protocol | Deterministic Walk-Forward Simulation</p>"""


def _alert_panel(current_alerts, total_alerts):
    if not current_alerts:
        return '''<div class="alert-panel">
<div class="alert-panel-header">
<span class="alert-status">✅</span>
<div class="alert-panel-title">All Invariants Pass</div>
<div class="alert-count">0 active alerts</div>
</div>
<div style="color:#3fb950;font-size:13px">All configured invariants are within bounds for the current tick.</div>
</div>'''

    critical = sum(1 for a in current_alerts if a["severity"] == "critical")
    warning = sum(1 for a in current_alerts if a["severity"] == "warning")
    icon = "🔴" if critical > 0 else "🟡"
    status_text = f"{critical} critical, {warning} warning" if critical > 0 else f"{warning} warning"

    rows = format_alert_html(current_alerts)
    return f'''<div class="alert-panel">
<div class="alert-panel-header">
<span class="alert-status">{icon}</span>
<div class="alert-panel-title">Invariant Alerts</div>
<div class="alert-count">{status_text} | {total_alerts} total across simulation</div>
</div>
{rows}
</div>'''


def _alert_history_section(alerts):
    if not alerts:
        return '''<h2>⚖️ Alert History</h2>
<div class="alert-history-empty">No alerts triggered during this simulation. All invariants passed.</div>'''

    rows = format_alert_html(alerts)
    return f'''<h2>⚖️ Alert History ({len(alerts)} total)</h2>
<div class="alert-history">
{rows}
</div>'''


def _failure_drilldown_section(fd, tick_count):
    total_failures = fd["total_failures"]
    total_actions = fd["total_actions"]
    failure_rate = round(total_failures / total_actions * 100, 2) if total_actions else 0.0
    worst_tick = fd["worst_tick"]
    worst_count = fd["tick_fail"].get(worst_tick, 0)

    # Most-failed action
    action_fail = fd["action_fail"]
    most_failed_action = max(action_fail, key=action_fail.get, default="—") if action_fail else "—"
    most_failed_count = action_fail.get(most_failed_action, 0)

    # Stats cards
    stats_html = f'''<div class="stats-row">
<div class="stat-card"><div class="value">{total_failures}</div><div class="label">Total Failures</div></div>
<div class="stat-card"><div class="value">{failure_rate}%</div><div class="label">Failure Rate</div></div>
<div class="stat-card"><div class="value">{most_failed_action}</div><div class="label">Most-Failed Action ({most_failed_count})</div></div>
<div class="stat-card"><div class="value">Tick {worst_tick}</div><div class="label">Worst Tick ({worst_count})</div></div>
</div>'''

    if total_failures == 0:
        return f'''<h2>🔍 Failure Drill-Down</h2>
{stats_html}
<div class="no-failures">✅ Zero failures detected — all actions succeeded.</div>'''

    # Treemap nodes: action → error breakdown
    action_error = fd["action_error"]
    action_total = fd["action_total"]
    nodes = []
    sorted_actions = sorted(action_error.items(), key=lambda x: sum(x[1].values()), reverse=True)
    for act, err_counts in sorted_actions:
        fail_cnt = sum(err_counts.values())
        tot = action_total.get(act, 0)
        pct = round(fail_cnt / tot * 100, 1) if tot else 0
        color = "#f85149" if pct > 30 else "#d29922" if pct > 10 else "#3fb950"
        err_pills = "".join(
            f'<span class="error-pill">{err}:{cnt}</span>' for err, cnt in sorted(err_counts.items(), key=lambda x: -x[1])
        )
        nodes.append(
            f'<div class="treemap-node" data-action="{act}" onclick="filterByAction(this)">'
            f'<div class="name">{act}</div>'
            f'<div class="count" style="color:{color}">{fail_cnt}</div>'
            f'<div class="sub">{pct}% of {tot}</div>'
            f'<div class="error-sub">{err_pills}</div>'
            f'</div>'
        )

    # Action options for dropdown
    action_options = "".join(f'<option value="{a}">{a}</option>' for a in sorted(action_total.keys()))
    arch_options = "".join(f'<option value="{k}">{ARCHETYPE_NAMES[i]}</option>' for i, k in enumerate(ARCHETYPE_KEYS))

    # JSON data for JS
    actions_json = json.dumps(fd["filtered_actions"])

    return f'''<h2>🔍 Failure Drill-Down</h2>
{stats_html}
<div class="drill-filters">
<label>Archetype <select id="filterArchetype" onchange="updateDrilldown()"><option value="all">All</option>{arch_options}</select></label>
<label>Action <select id="filterAction" onchange="updateDrilldown()"><option value="all">All</option>{action_options}</select></label>
<label>Status <select id="filterStatus" onchange="updateDrilldown()"><option value="all">All</option><option value="failure">Failure</option><option value="success">Success</option></select></label>
<label>Tick from <input type="number" id="filterTickFrom" value="0" min="0" max="{tick_count-1}" onchange="updateDrilldown()"></label>
<label>to <input type="number" id="filterTickTo" value="{tick_count-1}" min="0" max="{tick_count-1}" onchange="updateDrilldown()"></label>
<button onclick="exportDrilldownCSV()">⬇️ Export CSV</button>
</div>
<div class="drill-grid">
<div class="chart-box">
<h3 style="color:#8b949e;font-size:14px;margin-bottom:8px">Action Treemap (click to filter)</h3>
<div class="treemap-wrap" id="treemapWrap">{"".join(nodes)}</div>
</div>
<div class="chart-box">
<h3 style="color:#8b949e;font-size:14px;margin-bottom:8px">Failure Rate per Tick</h3>
<div class="canvas-wrap"><canvas id="failTickChart"></canvas></div>
</div>
</div>
<script>
const allActions = {actions_json};
const tickCount = {tick_count};
let failTickChart = null;

function filterByAction(node) {{
  document.querySelectorAll('.treemap-node').forEach(n => n.classList.remove('active'));
  node.classList.add('active');
  const act = node.dataset.action;
  document.getElementById('filterAction').value = act;
  updateDrilldown();
}}

function getFiltered() {{
  const arch = document.getElementById('filterArchetype').value;
  const act = document.getElementById('filterAction').value;
  const status = document.getElementById('filterStatus').value;
  const fromTick = parseInt(document.getElementById('filterTickFrom').value) || 0;
  const toTick = parseInt(document.getElementById('filterTickTo').value) || tickCount - 1;
  return allActions.filter(a => {{
    if (arch !== 'all' && a.archetype !== arch) return false;
    if (act !== 'all' && a.actionName !== act) return false;
    if (status === 'failure' && a.success) return false;
    if (status === 'success' && !a.success) return false;
    if (a.tick < fromTick || a.tick > toTick) return false;
    return true;
  }});
}}

function updateDrilldown() {{
  const filtered = getFiltered();
  const tickFail = {{}};
  const tickTotal = {{}};
  for (let t = 0; t < tickCount; t++) {{ tickFail[t] = 0; tickTotal[t] = 0; }}
  for (const a of filtered) {{
    tickTotal[a.tick] = (tickTotal[a.tick] || 0) + 1;
    if (!a.success) tickFail[a.tick] = (tickFail[a.tick] || 0) + 1;
  }}
  const labels = Array.from({{length:tickCount}}, (_,i)=>i);
  const rateData = labels.map(t => {{
    const tot = tickTotal[t] || 0;
    return tot ? (tickFail[t] || 0) / tot * 100 : 0;
  }});
  const failData = labels.map(t => tickFail[t] || 0);

  if (failTickChart) {{ failTickChart.destroy(); }}
  const ctx = document.getElementById('failTickChart').getContext('2d');
  failTickChart = new Chart(ctx, {{
    type: 'line',
    data: {{
      labels: labels,
      datasets: [
        {{ label: 'Failure Count', data: failData, borderColor: '#f85149', backgroundColor: 'rgba(248,81,73,0.1)', borderWidth: 1.5, pointRadius: 2, fill: true, tension: 0.3 }},
        {{ label: 'Failure Rate %', data: rateData, borderColor: '#d29922', borderWidth: 1.5, pointRadius: 0, yAxisID: 'y1' }}
      ]
    }},
    options: {{
      responsive: true, maintainAspectRatio: false,
      interaction: {{ mode: 'index', intersect: false }},
      scales: {{
        y: {{ ticks: {{ color: '#8b949e' }}, grid: {{ color: '#21262d' }} }},
        y1: {{ position: 'right', ticks: {{ color: '#d29922', callback: v=>v.toFixed(1)+'%' }}, grid: {{ drawOnChartArea: false }} }},
        x: {{ ticks: {{ color: '#8b949e' }}, grid: {{ color: '#21262d' }} }}
      }},
      plugins: {{ legend: {{ labels: {{ color: '#c9d1d9' }} }} }}
    }}
  }});
}}

function exportDrilldownCSV() {{
  const rows = getFiltered().filter(a => !a.success);
  if (!rows.length) {{ alert('No failures match current filters.'); return; }}
  const header = 'tick,agentId,actionName,amount,success,errorType,archetype';
  const lines = rows.map(r => `${{r.tick}},${{r.agentId}},${{r.actionName}},${{r.amount}},${{r.success}},${{r.errorType || ''}},${{r.archetype}}`);
  const blob = new Blob([header + '\n' + lines.join('\n')], {{ type: 'text/csv' }});
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = 'filtered_failures.csv';
  a.click();
  URL.revokeObjectURL(url);
}}

// Init chart on load
updateDrilldown();
</script>'''


def _card(value, label):
    return f'<div class="card"><div class="value">{value}</div><div class="label">{label}</div></div>'


def _summary_cards(summary, success_rate):
    ghost = summary["ghostVariables"]
    expected = int(ghost.get("expectedFailures", 0))
    unexpected = int(ghost.get("unexpectedFailures", 0))
    cards = [
        _card(str(summary["tickCount"]), "Simulation Weeks"),
        _card("100", "Total Agents"),
        _card(format_btc(int(ghost["totalDeposited"])), "Total Deposited"),
        _card(format_btc(int(ghost["totalWithdrawn"])), "Total Withdrawn"),
        _card(format_btc(int(ghost["totalForfeited"])), "Total Forfeited"),
        _card(format_btc(int(ghost["totalMatchClaimed"])), "Match Claimed"),
        _card(f"{success_rate}%", "Action Success Rate"),
        _card(str(unexpected), "Unexpected Failures"),
    ]
    return '<div class="cards">' + "".join(cards) + '</div>'


def _price_chart_section(prices, vbtc_ratios, regimes):
    return f"""<h2>Price &amp; vBTC Ratio</h2>
<div class="chart-box"><canvas id="priceChart"></canvas></div>
<script>
const priceData={json.dumps(prices)};
const vbtcData={json.dumps(vbtc_ratios)};
const regimeData={json.dumps(regimes)};
</script>"""


def _nw_chart_section(arch_nw):
    data_obj = ",".join(f"{k}:{json.dumps(v)}" for k, v in arch_nw.items())
    return f"""<h2>Net Worth by Archetype (Average)</h2>
<div class="chart-box"><canvas id="nwChart"></canvas></div>
<script>const nwData={{{data_obj}}};</script>"""


def _leaderboard_section(leaderboard):
    rows = []
    for i, agent in enumerate(leaderboard):
        ret = agent["returnPct"]
        cls = "pos" if ret >= 0 else "neg"
        arch_id = ARCHETYPE_ENUM.get(agent["archetype"], 0)
        badge = f'<span class="badge b{arch_id}">{ARCHETYPE_NAMES[arch_id]}</span>'
        rows.append(
            f'<tr><td>{i+1}</td><td>{agent["agentId"]}</td><td>{badge}</td>'
            f'<td>{format_btc(agent["initialCapital"])}</td>'
            f'<td>{format_btc(agent["finalNetWorth"])}</td>'
            f'<td class="{cls}">{ret}%</td></tr>'
        )
    return f"""<h2>Leaderboard (Top 20)</h2>
<table><thead><tr><th>#</th><th>Agent</th><th>Archetype</th><th>Initial</th><th>Final NW</th><th>Return</th></tr></thead>
<tbody>{"".join(rows)}</tbody></table>"""


def _archetype_performance_section(arch_perf):
    rows = []
    vals = []
    for i, perf in enumerate(arch_perf):
        if perf["count"] > 0:
            cls = "pos" if perf["avgReturn"] >= 0 else "neg"
            badge = f'<span class="badge b{i}">{ARCHETYPE_NAMES[i]}</span>'
            rows.append(
                f'<tr><td>{badge}</td><td>{perf["count"]}</td>'
                f'<td>{format_btc(perf["avgInitial"])}</td>'
                f'<td>{format_btc(perf["avgFinal"])}</td>'
                f'<td class="{cls}">{perf["avgReturn"]}%</td></tr>'
            )
        vals.append(perf["avgReturn"])

    return f"""<h2>Archetype Performance</h2>
<div class="two-col">
<div class="chart-box"><canvas id="archChart"></canvas></div>
<div>
<table><thead><tr><th>Archetype</th><th>Count</th><th>Avg Initial</th><th>Avg Final</th><th>Avg Return</th></tr></thead>
<tbody>{"".join(rows)}</tbody></table>
</div></div>
<script>const archPerfVals={json.dumps(vals)};</script>"""


def _action_distribution_section(arch_actions):
    data_obj = ",".join(f"{k}:{json.dumps(v)}" for k, v in arch_actions.items())
    return f"""<h2>Action Distribution by Archetype</h2>
<script>const actionData={{{data_obj}}};</script>
<div class="two-col">
<div class="chart-box"><h3 style="color:#8b949e;font-size:14px;margin-bottom:8px">Vault Operations</h3><canvas id="vaultActChart"></canvas></div>
<div class="chart-box"><h3 style="color:#8b949e;font-size:14px;margin-bottom:8px">Perpetual Trading</h3><canvas id="perpActChart"></canvas></div>
</div>
<div class="two-col">
<div class="chart-box"><h3 style="color:#8b949e;font-size:14px;margin-bottom:8px">Volatility Pool</h3><canvas id="volActChart"></canvas></div>
<div class="chart-box"><h3 style="color:#8b949e;font-size:14px;margin-bottom:8px">Dormancy &amp; Swaps</h3><canvas id="dormActChart"></canvas></div>
</div>"""


def _protocol_metrics_section(tvls, match_pools):
    return f"""<h2>Protocol Metrics</h2>
<div class="chart-box"><canvas id="protocolChart"></canvas></div>
<script>
const tvlData={json.dumps(tvls)};
const mpData={json.dumps(match_pools)};
</script>"""


def _agent_details_section(all_agents):
    parts = ['<h2>Agent Details</h2>']
    for agent in all_agents:
        ret = agent["returnPct"]
        arch_id = ARCHETYPE_ENUM.get(agent["archetype"], 0)
        badge = f'<span class="badge b{arch_id}">{ARCHETYPE_NAMES[arch_id]}</span>'
        parts.append(
            f'<details><summary>Agent {agent["agentId"]} | {badge}'
            f' | NW: {format_btc(agent["finalNetWorth"])}'
            f' | Return: {ret}%</summary>'
            f'<div class="detail-content"><table>'
            f'<tr><td>Risk Tolerance</td><td>{agent["riskTolerance"]}</td></tr>'
            f'<tr><td>Patience</td><td>{agent["patience"]}</td></tr>'
            f'<tr><td>Leverage Pref</td><td>{agent["leveragePreference"]}x/100</td></tr>'
            f'<tr><td>Vol Bias</td><td>{agent["volBias"]}</td></tr>'
            f'<tr><td>Initial Capital</td><td>{format_btc(agent["initialCapital"])}</td></tr>'
            f'<tr><td>Final Net Worth</td><td>{format_btc(agent["finalNetWorth"])}</td></tr>'
            f'</table></div></details>'
        )
    return "\n".join(parts)


def _footer(tick_count, alert_json, failure_data):
    # Build per-tick arrays for the base time-series (all actions)
    tick_fail_arr = [failure_data["tick_fail"].get(str(t), 0) for t in range(tick_count)]
    tick_total_arr = [failure_data["tick_total"].get(str(t), 0) for t in range(tick_count)]
    tick_rate_arr = [
        (failure_data["tick_fail"].get(str(t), 0) / failure_data["tick_total"].get(str(t), 1) * 100)
        if failure_data["tick_total"].get(str(t), 0) else 0
        for t in range(tick_count)
    ]

    return f"""<script>
const toEth=x=>x/1e18;
const toBtc=x=>x/1e8;
const days=Array.from({{length:{tick_count}}},(_,i)=>i);
const archNames={json.dumps(ARCHETYPE_NAMES)};
const archColors={json.dumps(ARCHETYPE_COLORS)};
const allAlerts={alert_json};
const baseTickFail={json.dumps(tick_fail_arr)};
const baseTickTotal={json.dumps(tick_total_arr)};
const baseTickRate={json.dumps(tick_rate_arr)};

// Alert persistence in localStorage
(function(){{
  const key = 'zeno_sim_alerts_' + location.pathname;
  const stored = localStorage.getItem(key);
  const storedAlerts = stored ? JSON.parse(stored) : [];
  // Merge with current run alerts (dedup by tick+id)
  const seen = new Set(storedAlerts.map(a => a.tick + '|' + a.id));
  for (const a of allAlerts) {{
    const k = a.tick + '|' + a.id;
    if (!seen.has(k)) {{ storedAlerts.push(a); seen.add(k); }}
  }}
  localStorage.setItem(key, JSON.stringify(storedAlerts));
  // Expose for console debugging
  window.zenoAlerts = storedAlerts;
}})();

// Price chart
new Chart(document.getElementById("priceChart"),{{type:"line",data:{{labels:days,datasets:[
{{label:"WBTC/USDC",data:priceData.map(toEth),borderColor:"#f0f6fc",borderWidth:1.5,pointRadius:0,yAxisID:"y"}},
{{label:"vBTC/WBTC",data:vbtcData.map(toEth),borderColor:"#58a6ff",borderWidth:1.5,pointRadius:0,yAxisID:"y1"}}
]}},options:{{responsive:true,interaction:{{mode:"index",intersect:false}},
scales:{{y:{{type:"linear",position:"left",ticks:{{color:"#8b949e"}},grid:{{color:"#21262d"}}}},
y1:{{type:"linear",position:"right",min:0.4,max:1.1,ticks:{{color:"#58a6ff"}},grid:{{drawOnChartArea:false}}}}}},
plugins:{{legend:{{labels:{{color:"#c9d1d9"}}}}}}}}}});

// Net worth chart
const nwKeys={json.dumps(ARCHETYPE_KEYS)};
new Chart(document.getElementById("nwChart"),{{type:"line",data:{{labels:days,datasets:nwKeys.map((k,i)=>({{
label:archNames[i],data:nwData[k].map(toBtc),borderColor:archColors[i],borderWidth:1.5,pointRadius:0
}}))}},options:{{responsive:true,interaction:{{mode:"index",intersect:false}},
scales:{{y:{{ticks:{{color:"#8b949e"}},grid:{{color:"#21262d"}}}}}},
plugins:{{legend:{{labels:{{color:"#c9d1d9",font:{{size:11}}}}}}}}}}}});

// Archetype performance chart
new Chart(document.getElementById("archChart"),{{type:"bar",data:{{labels:archNames,datasets:[{{
label:"Avg Return (%)",data:archPerfVals,backgroundColor:archColors}}]}},
options:{{responsive:true,scales:{{y:{{ticks:{{color:"#8b949e"}},grid:{{color:"#21262d"}}}},x:{{ticks:{{color:"#8b949e"}}}}}},
plugins:{{legend:{{display:false}}}}}}}});

// Action charts
const actKeys={json.dumps(ARCHETYPE_KEYS)};
const actOpts={{responsive:true,scales:{{x:{{stacked:true,ticks:{{color:"#8b949e"}}}},y:{{stacked:true,ticks:{{color:"#8b949e"}},grid:{{color:"#21262d"}}}}}},plugins:{{legend:{{labels:{{color:"#c9d1d9",font:{{size:10}}}},position:"bottom"}}}}}};

new Chart(document.getElementById("vaultActChart"),{{type:"bar",data:{{labels:archNames,datasets:[
{{label:"MINT_VAULT",data:actKeys.map(k=>actionData[k][1]||0),backgroundColor:"#58a6ff"}},
{{label:"WITHDRAW",data:actKeys.map(k=>actionData[k][2]||0),backgroundColor:"#3fb950"}},
{{label:"EARLY_REDEEM",data:actKeys.map(k=>actionData[k][3]||0),backgroundColor:"#f85149"}},
{{label:"MINT_BTC_TOKEN",data:actKeys.map(k=>actionData[k][4]||0),backgroundColor:"#d29922"}},
{{label:"RETURN_BTC_TOKEN",data:actKeys.map(k=>actionData[k][5]||0),backgroundColor:"#bc8cff"}},
{{label:"CLAIM_MATCH",data:actKeys.map(k=>actionData[k][6]||0),backgroundColor:"#56d4dd"}},
{{label:"PROVE_ACTIVITY",data:actKeys.map(k=>actionData[k][7]||0),backgroundColor:"#f0883e"}}
]}},options:actOpts}});

new Chart(document.getElementById("perpActChart"),{{type:"bar",data:{{labels:archNames,datasets:[
{{label:"OPEN_PERP_LONG",data:actKeys.map(k=>actionData[k][8]||0),backgroundColor:"#7ee787"}},
{{label:"OPEN_PERP_SHORT",data:actKeys.map(k=>actionData[k][9]||0),backgroundColor:"#ff7b72"}},
{{label:"CLOSE_PERP",data:actKeys.map(k=>actionData[k][10]||0),backgroundColor:"#79c0ff"}},
{{label:"ADD_PERP_COLLATERAL",data:actKeys.map(k=>actionData[k][11]||0),backgroundColor:"#ffa657"}}
]}},options:actOpts}});

new Chart(document.getElementById("volActChart"),{{type:"bar",data:{{labels:archNames,datasets:[
{{label:"DEPOSIT_VOL_LONG",data:actKeys.map(k=>actionData[k][12]||0),backgroundColor:"#d2a8ff"}},
{{label:"DEPOSIT_VOL_SHORT",data:actKeys.map(k=>actionData[k][13]||0),backgroundColor:"#f778ba"}},
{{label:"WITHDRAW_VOL_LONG",data:actKeys.map(k=>actionData[k][14]||0),backgroundColor:"#a5d6ff"}},
{{label:"WITHDRAW_VOL_SHORT",data:actKeys.map(k=>actionData[k][15]||0),backgroundColor:"#ffd33d"}}
]}},options:actOpts}});

new Chart(document.getElementById("dormActChart"),{{type:"bar",data:{{labels:archNames,datasets:[
{{label:"POKE_DORMANT",data:actKeys.map(k=>actionData[k][16]||0),backgroundColor:"#7ee787"}},
{{label:"CLAIM_DORMANT",data:actKeys.map(k=>actionData[k][17]||0),backgroundColor:"#e3b341"}},
{{label:"SWAP_VBTC_TO_WBTC",data:actKeys.map(k=>actionData[k][18]||0),backgroundColor:"#58a6ff"}},
{{label:"SWAP_WBTC_TO_VBTC",data:actKeys.map(k=>actionData[k][19]||0),backgroundColor:"#ff7b72"}},
{{label:"ADD_LIQUIDITY",data:actKeys.map(k=>actionData[k][20]||0),backgroundColor:"#d2a8ff"}}
]}},options:actOpts}});

// Protocol metrics chart
new Chart(document.getElementById("protocolChart"),{{type:"line",data:{{labels:days,datasets:[
{{label:"TVL (BTC)",data:tvlData.map(toBtc),borderColor:"#3fb950",borderWidth:1.5,pointRadius:0}},
{{label:"Match Pool (BTC)",data:mpData.map(toBtc),borderColor:"#f85149",borderWidth:1.5,pointRadius:0}}
]}},options:{{responsive:true,interaction:{{mode:"index",intersect:false}},
scales:{{y:{{ticks:{{color:"#8b949e"}},grid:{{color:"#21262d"}}}}}},
plugins:{{legend:{{labels:{{color:"#c9d1d9"}}}}}}}}}});
</script>
<p style="text-align:center;color:#484f58;margin-top:32px;font-size:12px">
Generated by BTCNFT Protocol Swarm Simulation</p>
</div></body></html>"""


def main():
    required_files = [
        "market_data.csv", "agent_net_worth.csv", "agent_actions.csv",
        "agent_configs.json", "simulation_summary.json"
    ]
    for f in required_files:
        path = REPORTS_DIR / f
        if not path.exists():
            print(f"ERROR: Missing {path}", file=sys.stderr)
            sys.exit(1)

    print("Loading simulation data...")
    market = load_market_data()
    agent_nw = load_agent_net_worth()
    configs = load_agent_configs()
    summary = load_summary()
    actions = load_agent_actions()

    print(f"  Ticks: {summary['tickCount']} | Agents: {summary['agentCount']}")
    print(f"  Actions: {len(actions)} | Market rows: {len(market)}")

    if len(market) != summary["tickCount"]:
        print(
            f"ERROR: market_data.csv has {len(market)} rows but "
            f"simulation_summary.json reports tickCount={summary['tickCount']}. "
            f"Stale data from a previous run detected — re-run forge test first.",
            file=sys.stderr,
        )
        sys.exit(1)

    print("Generating HTML dashboard...")
    html = generate_html(market, agent_nw, configs, summary, actions)

    out_path = REPORTS_DIR / "simulation.html"
    with open(out_path, "w") as f:
        f.write(html)

    print(f"Dashboard written to {out_path} ({len(html):,} bytes)")

    if sys.platform == "darwin":
        os.system(f'open "{out_path}"')


if __name__ == "__main__":
    main()
