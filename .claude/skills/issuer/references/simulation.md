# Simulation Guide

> **Scope:** Running simulations and reviewing results from an issuer perspective.
> **Source contracts:** `contracts/simulation/`
> **Reports directory:** `contracts/simulation/reports/`

---

## How to Run Simulations

All commands run from `contracts/simulation/`:

```bash
cd contracts/simulation
```

### Simulation Types

| Type | Command | Duration | Scope |
|------|---------|----------|-------|
| Smoke test | `forge test --match-test test_swarm_smoke -vv` | ~5s | 20-week, 100 agents, full DeFi stack |
| Default swarm | `forge test --match-test test_swarm -vv` | Minutes | 320-week (default), 100 agents, all reports |
| Full swarm | `SIMULATION_WEEKS=512 forge test --match-test test_swarm -vv` | Minutes | 512-week, 100 agents, all reports |
| Preloaded prices | `forge test --match-test test_swarm_preloaded -vv` | Minutes | Default weeks with CSV price series |
| Protocol-only | `forge test --match-test test_protocolSwarm -vv` | Minutes | Vault lifecycle, delegation, dormancy (no perps/vol) |
| Protocol smoke | `forge test --match-test test_protocolSwarm_smoke -vv` | ~5s | 20-week protocol-only |
| Dormancy tests | `forge test --match-contract DormancyTest -vv` | ~2s | 11 state machine tests |
| Price generation | `python scripts/generate_price_series.py --seed 42 --ticks 320` | <1s | Writes `reports/price_series.csv` |

### What Each Type Covers

**SwarmSimulation** (full stack): VaultNFT, vBTC, PerpetualVault, VolatilityPool, SimCurvePool, MockTWAPOracle, delegation, dormancy, match pool. Generates HTML dashboard, CSV, JSON, and markdown reports.

**ProtocolSwarmSimulation** (protocol-only): VaultNFT, vBTC, delegation, dormancy, match pool. No perpetuals or volatility pools. Console output only (no HTML report).

**DormancyTest**: Focused state machine tests — ACTIVE → POKE_PENDING → CLAIMABLE transitions, grace period resets, transfer resets, vBTC holding requirements, multi-vault independence.

### Execution Workflow

1. **Smoke test first** — validates basic mechanics quickly
2. **Full swarm** — generates complete reports to `reports/`
3. **Review reports** — HTML auto-opens via FFI; CSV/JSON for analysis

### Configuration

| Setting | Value | Source |
|---------|-------|--------|
| Agents | 100 | `SwarmOrchestrator.sol` |
| Ticks | 521 (full) / 20 (smoke) | Test file |
| Seed | 42 | Test file |
| Invariant check interval | Every 50 ticks | `SwarmOrchestrator.sol` |
| Fuzz runs | 256 | `foundry.toml` |
| Gas limit | 1 trillion | `foundry.toml` |
| FFI | Enabled (required for report writing) | `foundry.toml` |
| Initial capital/agent | 0.03–0.15 BTC (varies by archetype) | `SwarmOrchestrator.sol` |

---

## Report Files

| File | Format | Content |
|------|--------|---------|
| `simulation.html` | HTML | Interactive dashboard with charts, leaderboard, agent details |
| `summary.md` | Markdown | Parameter table, ghost variables, final state, top-20 leaderboard |
| `simulation_summary.json` | JSON | Seed, agent count, tick count, all ghost variables, final state |
| `market_data.csv` | CSV | Per-tick: price, vbtcRatio, tvl, matchPool, regime |
| `agent_net_worth.csv` | CSV | Per-tick: tick + 100 agent columns (WBTC-equivalent, 8 decimals) |
| `agent_actions.csv` | CSV | Per-action: tick, agentId, action, actionName, amount, success |
| `agent_configs.json` | JSON | 100 agent configs: archetype, riskTolerance, patience, leverage, etc. |

All files written to `contracts/simulation/reports/`.

---

## HTML Dashboard Sections

| Section | What to Look For |
|---------|-----------------|
| **Summary Cards** (8) | Ghost variable totals. Check failed action ratio and forfeiture volume. |
| **Price & vBTC Ratio Chart** | Dual-axis time series. vBTC ratio should converge toward 0.85, stay within [0.50, 1.00]. |
| **Net Worth by Archetype** | 7 averaged lines. Check archetype divergence and whether Panic Sellers lose disproportionately. |
| **Leaderboard** (top 20) | Archetype diversity in top ranks. Compare initial vs final capital. |
| **Archetype Performance** | Mean return by archetype. Risk-adjusted performance. |
| **Action Distribution** | 4 stacked bar charts (vault, perps, vol, dormancy/swaps). Check for unexpected zero-counts. |
| **Protocol Metrics** | TVL + match pool over time. TVL should be stable or growing. |
| **Agent Details** | 100 collapsible sections. Investigate individual outliers. |

---

## Key Metrics — Issuer Interpretation

| Metric | Source | Healthy Range | Issuer Concern |
|--------|--------|---------------|----------------|
| `ghost_totalDeposited` | `simulation_summary.json` | Grows monotonically | Total BTC entering vaults |
| `ghost_totalWithdrawn` | `simulation_summary.json` | Non-zero after tick ~161 (1129 days) | Withdrawal activity post-vesting |
| `ghost_totalForfeited` | `simulation_summary.json` | < 20% of deposited | Early redemption pressure; high = panic |
| `ghost_totalMatchClaimed` | `simulation_summary.json` | Non-zero after vesting starts | Match pool utilization |
| `ghost_totalActions` / `ghost_totalFailedActions` | `simulation_summary.json` | Failure rate < 30% | High failure = contract errors or bad agent logic |
| `ghost_totalDelegatedWithdrawals` | `simulation_summary.json` | Non-zero if delegation active | Delegation feature adoption |
| `ghost_totalSeparations` / `ghost_totalRecombinations` | `simulation_summary.json` | Separations > recombinations | vBTC supply dynamics |
| vBTC Ratio | `market_data.csv` | 0.50–1.00, converging to 0.85 | Ratio collapse = vBTC depeg |
| TVL | `market_data.csv` | Stable or growing | TVL crash = mass exit |
| Match Pool | `market_data.csv` | Growing from forfeitures | Rewards pool for loyal holders |
| Market Regime | `market_data.csv` | 0=low-vol, 1=high-vol, 2/3=transition | Regime distribution affects strategy performance |

---

## Diagnostic Checklists

### 1. High Failed Action Rate (>30%)

1. Open `agent_actions.csv`, filter `success=false`
2. Group by `actionName` — which actions fail most?
3. Common expected failures:
   - `WITHDRAW` before vesting (tick < 161) — not a bug
   - `MINT_BTC_TOKEN` with no collateral — agent has no vault yet
   - `CLOSE_PERP` on non-existent position — timing issue
   - `CLAIM_MATCH` before vesting — expected
4. If unexpected action is failing: check the contract logic

### 2. vBTC Ratio Anomaly

1. Plot `vbtcRatio` from `market_data.csv`
2. Ratio = 0 throughout → vBTC was never separated (no `MINT_BTC_TOKEN` actions)
3. Ratio drops below 0.50 → excessive selling pressure or AMM drain
4. Ratio exceeds 1.00 → **invariant violation** — escalate immediately
5. Cross-reference with `agent_actions.csv` for `SWAP_VBTC_TO_WBTC` / `SWAP_WBTC_TO_VBTC` volume

### 3. Invariant Failure

Invariants are checked every 50 ticks. Four invariants:

| Invariant | Condition | If Violated |
|-----------|-----------|-------------|
| Vault solvency | `wbtc.balanceOf(vault) >= matchPool` | Ghost variable accounting is inconsistent |
| Perp vault solvency | vBTC balance >= sum of position payouts | Position sizing or settlement bug |
| Vol pool solvency | vBTC balance >= longPoolAssets + shortPoolAssets | Pool accounting bug |
| System conservation | Total agent net worth ≈ system value | Value leaking or being created |

Check Forge test output for assertion failures. If conservation fails, trace all value transfer paths.

### 4. Archetype Dominance / Imbalance

1. Check leaderboard (in `summary.md`) — archetype distribution of top 20
2. If single archetype dominates (>15 of top 20): strategy may be overpowered or others are broken
3. Cross-reference with action distribution — are underperforming archetypes taking actions?
4. Check if Predator agents (5 total) are extracting value disproportionately

### 5. Stagnant Net Worth (No Growth)

1. In `agent_net_worth.csv`, check if values are flat across ticks
2. Flat for all agents → no vBTC separation happening, or price feed is flat
3. Flat for specific archetype → check if that archetype's strategy mask enables relevant actions
4. 20-tick smoke tests will not show vesting-dependent behaviors (vesting requires tick ~161)

### 6. Zero Match Pool

1. Match pool grows from forfeitures (early redemptions)
2. If zero: no agent performed `EARLY_REDEEM` — check if `PANIC_SELLER` archetype has `STRAT_EARLY_REDEEM` enabled
3. Match claiming requires vested vaults (tick >= 161)

---

## Agent Archetypes — Issuer Perspective

| Archetype | Count | Represents | Issuer Cares About |
|-----------|-------|------------|-------------------|
| Diamond Hands | 30 | Long-term holders (HODLers) | Core user base; should grow steadily |
| Yield Farmer | 20 | Passive income seekers | DeFi integration health |
| Momentum Trader | 15 | Trend followers | Market-driven churn |
| Volatility Player | 10 | Vol strategy users | VolatilityPool product-market fit |
| Arbitrageur | 10 | Efficiency seekers | vBTC peg stability |
| Panic Seller | 10 | Fear-driven exits | Worst-case forfeiture rate |
| Predator | 5 | Adversarial actors | Dormancy/match pool exploitation risk |

---

## Cross-Referencing Results

### Comparing Two Runs

1. Compare `simulation_summary.json` ghost variables side by side
2. Compare `market_data.csv` final rows for TVL and match pool
3. Use `agent_net_worth.csv` to compare archetype performance distributions

### Correlating Actions to Outcomes

1. Pick an agent from the leaderboard (e.g., agent #4)
2. Filter `agent_actions.csv` for `agentId=4`
3. Check `agent_configs.json` for agent #4's archetype and psychology
4. Trace net worth in `agent_net_worth.csv` column `agent_4`
5. Correlate action timing with price movements in `market_data.csv`

### Net Worth Valuation Components

Agent net worth is calculated across 6 components (via `NetWorthLib.sol`):

1. Raw WBTC balance
2. Vault collateral (full amount regardless of vesting status)
3. vBTC balance × vBTC/WBTC ratio
4. Perpetual position mark-to-market (via `previewClose()`)
5. Volatility pool shares (long + short via `previewWithdraw*()`)
6. Match pool claim estimate (pro-rata based on vested vault collateral)
