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
            })
    return actions


def load_agent_configs():
    with open(REPORTS_DIR / "agent_configs.json") as f:
        return json.load(f)


def load_summary():
    with open(REPORTS_DIR / "simulation_summary.json") as f:
        return json.load(f)


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

    arch_nw = build_archetype_avg_nw(configs, agent_nw, tick_count)
    arch_actions = build_archetype_action_counts(configs, actions)
    leaderboard, all_agents = build_leaderboard(configs, agent_nw, tick_count)

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
    html.append(_summary_cards(summary, success_rate))
    html.append(_price_chart_section(prices, vbtc_ratios, regimes))
    html.append(_nw_chart_section(arch_nw))
    html.append(_leaderboard_section(leaderboard))
    html.append(_archetype_performance_section(arch_perf))
    html.append(_action_distribution_section(arch_actions))
    html.append(_protocol_metrics_section(tvls, match_pools))
    html.append(_agent_details_section(all_agents))
    html.append(_footer(tick_count))
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
</style></head><body>
<div class="container">
<h1>100-Agent Swarm Simulation Report</h1>
<p class="subtitle">BTCNFT Protocol | Deterministic Walk-Forward Simulation</p>"""


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


def _footer(tick_count):
    return f"""<script>
const toEth=x=>x/1e18;
const toBtc=x=>x/1e8;
const days=Array.from({{length:{tick_count}}},(_,i)=>i);
const archNames={json.dumps(ARCHETYPE_NAMES)};
const archColors={json.dumps(ARCHETYPE_COLORS)};

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
