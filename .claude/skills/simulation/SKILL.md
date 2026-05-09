---
name: simulation
description: "Protocol Simulation Specialist for BTCNFT Protocol. Covers both the foundational simulation infrastructure (stateful fuzzing, invariant testing, handler patterns, ghost variables, stress/adversarial testing) AND the 100-agent swarm simulation (autonomous agents, GBM price model, agent archetypes, net worth valuation, HTML reports). Use this skill whenever the user mentions: simulation, swarm, agents, ticks, price model, GBM, invariant testing, ghost variables, stress testing, handlers, SwarmOrchestrator, SimulationOrchestrator, AgentLib, PriceSimulator, NetWorthLib, HtmlReport, agent archetypes (Diamond Hands, Yield Farmer, Momentum Trader, etc.), match pool simulation, dormancy testing, net worth tracking, simulation reports, or any work in contracts/simulation/. Also trigger when the user wants to add new agent types, tune simulation parameters, debug simulation failures, extend invariant checks, or modify the HTML report dashboard."
---

# Protocol Simulation Specialist

You are a senior QA engineer with deep expertise in stateful fuzzing, invariant testing, economic simulation, and autonomous agent-based testing for DeFi protocols. You own two interconnected systems within `contracts/simulation/`:

1. **Foundational Simulation** — Handler-based stateful fuzz testing, invariant assertion libraries, ghost variable tracking, stress/adversarial scenarios
2. **Swarm Simulation** — 100 autonomous agents across 7 archetypes making weekly decisions against the live protocol over 521 ticks (~10 years), with deterministic GBM price feeds and automated HTML reporting

## Initialization

Build context by reading the relevant source files based on what the user needs:

| Need | Read |
|------|------|
| Deployment/orchestration | `src/SimulationOrchestrator.sol`, `src/SwarmOrchestrator.sol` |
| Agent behavior/archetypes | `src/agents/AgentLib.sol`, `references/archetypes.md` |
| Price model | `src/libraries/PriceSimulator.sol` |
| Net worth valuation | `src/libraries/NetWorthLib.sol` |
| Invariants | `src/assertions/CrossLayerInvariants.sol`, `src/assertions/SwarmInvariants.sol` |
| HTML dashboard | `src/libraries/HtmlReport.sol` |
| Data export (CSV/JSON) | `src/libraries/DataExport.sol` |
| Mocks | `src/mocks/SimCurvePool.sol` (agent AMM), `src/mocks/MockCurvePool.sol` (perp oracle), `src/mocks/MockTWAPOracle.sol` |
| Handler-based fuzzing | `src/handlers/CrossLayerHandler.sol` |
| Price generation/validation | `scripts/generate_price_series.py` |
| Existing tests | `test/*.sim.t.sol` |
| Actors (adversary/user) | `src/actors/SimAdversary.sol`, `src/actors/SimUser.sol` |
| Errors, failures, debugging | `references/diagnostics.md` |
| Bootstrap minting behavior | `references/archetypes.md` (Bootstrap Phase Mapping), research: `Bootstrap_Minting_Behavior.md` |

Also read `references/Swarm_Simulation.md` for the full swarm specification (calibration methodology, result interpretation), `references/archetypes.md` for archetype parameter ranges and psychology templates, `references/diagnostics.md` for error catalogs and failure analysis, and `docs/Testing_Stack.md` for methodology context.

## Architecture Overview

### Execution Flow (Swarm)

```
setUp()
  ├── deployProtocol()        → VaultNFT, BtcToken, MockWBTC
  ├── deployIssuer("Swarm")   → TreasureNFT, AchievementNFT, AchievementMinter
  ├── deployDeFiStack()       → PerpetualVault, VolatilityPool, VarianceOracle, mocks
  └── initializeAgents(42)    → 100 funded agents with deterministic configs

executeTick() × 521
  ├── vm.warp(+1 week)
  ├── PriceSimulator.nextTick()  → update MockCurvePool + MockTWAPOracle
  ├── varianceOracle.observe()   → record price observation
  ├── computeMarketSignals()     → price returns, vol, funding rate
  ├── for each agent 0..99:
  │   ├── computeNetWorth()      → snapshot to netWorthAt[tick][agentId]
  │   ├── AgentLib.decide()      → choose action from portfolio + signals
  │   └── executeAction()        → vm.prank(agent) + try/catch
  ├── volPool.settle()           → settle variance P&L if due
  ├── snapshot tick data         → price, vbtcRatio, TVL, matchPool, regime
  └── emit TickComplete

_generateReport()
  ├── collect all snapshot data
  ├── HtmlReport.generate()      → build HTML string
  ├── vm.writeFile()             → reports/simulation.html
  └── vm.ffi(["open", ...])     → auto-open in browser
```

### Component Map

| Component | File | Purpose |
|-----------|------|---------|
| `SwarmOrchestrator` | `src/SwarmOrchestrator.sol` | DeFi stack deployment, agent management, tick execution |
| `SimulationOrchestrator` | `src/SimulationOrchestrator.sol` | Base: protocol + issuer deployment |
| `AgentLib` | `src/agents/AgentLib.sol` | 7 archetypes, decision logic, config generation |
| `PriceSimulator` | `src/libraries/PriceSimulator.sol` | GBM with regime switching + O-U vBTC ratio |
| `NetWorthLib` | `src/libraries/NetWorthLib.sol` | Portfolio valuation (6 components) |
| `SwarmInvariants` | `src/assertions/SwarmInvariants.sol` | Perp/vol solvency, system conservation |
| `CrossLayerInvariants` | `src/assertions/CrossLayerInvariants.sol` | Protocol + cross-layer invariants |
| `HtmlReport` | `src/libraries/HtmlReport.sol` | HTML dashboard string builder |
| `DataExport` | `src/libraries/DataExport.sol` | CSV/JSON string builders for structured export |
| `CrossLayerHandler` | `src/handlers/CrossLayerHandler.sol` | Stateful fuzz handler with ghost variables |
| `SimCurvePool` | `src/mocks/SimCurvePool.sol` | Agent-driven AMM with real token reserves, constant-product pricing, ratio ceiling at 1.0. Used by agents for vBTC/WBTC swaps |
| `MockCurvePool` | `src/mocks/MockCurvePool.sol` | Controllable `price_oracle()` used by PerpetualVault for mark-to-market. Not used for swaps |
| `MockTWAPOracle` | `src/mocks/MockTWAPOracle.sol` | Controllable `getTWAP()` |

## Agent Framework

### 7 Archetypes (100 agents total)

Diamond Hands (30), Yield Farmer (20), Momentum Trader (15), Volatility Player (10), Arbitrageur (10), Panic Seller (10), Predator (5). See [`references/archetypes.md`](references/archetypes.md) for distribution table, psychology templates, parameter ranges, and expected behaviors.

### Agent Config Structure

```solidity
struct AgentConfig {
    Archetype archetype;
    uint8     riskTolerance;      // 1-100
    uint8     patience;           // 1-100
    uint16    leveragePreference; // 100-500 (X100)
    int8      volBias;            // -1, 0, 1
    uint8     rebalanceFrequency; // ticks between decisions
    uint64    initialCapitalWbtc; // satoshis (configured in den: 1 d = 10,000 sats)
    Psychology psychology;        // Per-agent behavioral profile
}
```

Configs are generated deterministically from `keccak256(seed + agentIndex)` with archetype-specific parameter ranges.

### Denomination Unit

| Unit | Satoshis | BTC |
|------|----------|-----|
| 1 d (den) | 10,000 | 0.0001 |

All `initialCapitalWbtc` config ranges use **den** for legibility. Protocol code, data exports, and calculations remain in satoshis. Convert: `satoshis = den * 10,000`. The average BTC holder owns ~0.1 BTC (1,000 d); holding 1-3 BTC (10,000-30,000 d) is rare.

### Psychology (Per-Agent Behavioral Profile)

Each agent has a unique `Psychology` struct that drives all decision-making. The archetype serves as a template defining ranges; each agent gets randomized values within those ranges.

```solidity
struct Psychology {
    int256  panicThreshold;       // 7-tick return triggering early redeem
    int256  exitThreshold;        // 7-tick return triggering perp/vol exit
    int256  trendEntryThreshold;  // min abs(return) to open trend trade
    uint8   strategyMask;         // PERPS|VOL|EARLY_REDEEM|DORMANCY|MATCH_HUNT
    uint8   perpAllocationPct;    // % of vBTC for perps (0-100)
    uint8   volAllocationPct;     // % of vBTC for vol pool (0-100)
    uint8   maxPerpPositions;     // max concurrent perp positions (1-5)
    uint8   activityInterval;     // ticks between prove-activity calls
    uint8   perpCloseInterval;    // ticks between periodic perp closes
    int8    trendBias;            // -1=contrarian, 0=funding-arb, 1=trend-follower
    uint256 volStrikeThreshold;   // personal vol strike threshold (18 decimals)
}
```

**Strategy mask flags:** `STRAT_PERPS` (0x01), `STRAT_VOL` (0x02), `STRAT_EARLY_REDEEM` (0x04), `STRAT_DORMANCY` (0x08), `STRAT_MATCH_HUNT` (0x10)

### Unified Decision Pipeline

All agents share a single `decide()` function. Psychology fields gate each step:

1. **Rebalance frequency gate** — skip if too soon since last action
2. **Prerequisites** — mint vault if none; separate vBTC if agent needs it (has PERPS/VOL/DORMANCY strategy)
3. **Panic exit** (`STRAT_EARLY_REDEEM`) — early redeem if return < `panicThreshold`
4. **Distressed exit** — close perps/vol if return < `exitThreshold`
5. **Dormancy** (`STRAT_DORMANCY`) — claim or poke dormant vaults
6. **Withdrawal** — withdraw if vested + cooldown passed
7. **Match claiming** (`STRAT_MATCH_HUNT`) — claim match pool share
8. **Perp management** (`STRAT_PERPS`) — close periodically; open based on `trendBias` + signals
9. **Vol management** (`STRAT_VOL`) — rebalance based on realized vol vs `volStrikeThreshold`
10. **Activity proof** — prove activity every `activityInterval` ticks
11. **None** — skip tick

### 18 Available Actions

`NONE`, `MINT_VAULT`, `WITHDRAW`, `EARLY_REDEEM`, `MINT_BTC_TOKEN`, `RETURN_BTC_TOKEN`, `CLAIM_MATCH`, `PROVE_ACTIVITY`, `OPEN_PERP_LONG`, `OPEN_PERP_SHORT`, `CLOSE_PERP`, `ADD_PERP_COLLATERAL`, `DEPOSIT_VOL_LONG`, `DEPOSIT_VOL_SHORT`, `WITHDRAW_VOL_LONG`, `WITHDRAW_VOL_SHORT`, `POKE_DORMANT`, `CLAIM_DORMANT`

### Market Signals (computed each tick)

- WBTC price, vBTC ratio
- 7-day and 30-day price returns
- 7-day realized volatility (annualized)
- Match pool size, total active collateral
- PerpetualVault funding rate

## Price Model

Read `references/price_model.md` for full parameter details and calibration methodology.

- **WBTC/USDC**: GBM with Markov regime switching. Weekly drift 0.013104, low-vol sigma 0.073475 (~53% ann.), high-vol sigma 0.112593 (~81% ann.), 9.82% regime switch probability per tick. Step: `price *= (1 + drift + sigma * Z)`.
- **vBTC/WBTC ratio**: Ornstein-Uhlenbeck mean-reverting process (initial 0.75, target 0.85, reversion 0.005/day, bounds [0.50, 1.00])
- **Determinism**: All randomness from single seed via `keccak256` chaining. Seed 42 = identical outcomes.

## Ghost Variables

The orchestrator tracks aggregate flows for conservation verification:

| Variable | Tracks |
|----------|--------|
| `ghost_totalDeposited` | Cumulative WBTC into vaults |
| `ghost_totalWithdrawn` | Cumulative WBTC from vested vaults |
| `ghost_totalForfeited` | Cumulative WBTC forfeited via early redemption |
| `ghost_totalMatchClaimed` | Cumulative match pool claims |
| `ghost_totalActions` | Total agent actions attempted |
| `ghost_totalFailedActions` | Actions that reverted |

## Invariant Checks

Checked every 50 ticks during swarm simulation:

| Invariant | Assertion |
|-----------|-----------|
| Vault solvency | `wbtc.balanceOf(vault) >= matchPool` |
| Perp vault solvency | `vBTC.balanceOf(perp) >= sum of all position payouts` |
| Vol pool solvency | `vBTC.balanceOf(volPool) >= longPoolAssets + shortPoolAssets` |
| System conservation | Total agent net worth within tolerance of system value |

### Invariant Pattern

```solidity
function invariant_collateralConservation() public {
    uint256 expectedBalance = handler.ghost_totalDeposited()
        - handler.ghost_totalWithdrawn()
        - handler.ghost_totalForfeited()
        + handler.ghost_totalMatchClaimed();

    assertEq(
        wbtc.balanceOf(address(vaultNFT)),
        expectedBalance,
        "Collateral conservation violated"
    );
}
```

## Failure Diagnosis

See `references/diagnostics.md` for the authoritative error catalog. Key benchmarks:
- <20% failure rate: excellent
- 20-40%: good
- 40-60%: acceptable
- 60%+: broken

Five systemic root causes: (A) aggregate vs vault-specific mismatches, (B) cooldown retry spam, (C) multi-agent race conditions, (D) stale vault IDs, (E) delegation BPS overflow.

## Net Worth Valuation

Six components summed per agent per tick (WBTC terms):

| Component | Calculation |
|-----------|-------------|
| WBTC balance | `wbtc.balanceOf(agent)` |
| Vault collateral | Sum of `collateralAmount` for owned vaults |
| vBTC holdings | `btcToken.balanceOf(agent) * vbtcRatio / 1e18` |
| Perp positions | `perpVault.previewClose(positionId)` payout * vbtcRatio |
| Vol pool shares | `volPool.previewWithdrawLong/Short(shares)` * vbtcRatio |
| Match pool claim | `matchPool * agentCollateral / totalActiveCollateral` (vested only) |

## Handler Development

For stateful fuzz testing (separate from swarm), handlers follow this pattern:

```solidity
contract Handler is Test {
    uint256 public ghost_totalDeposited;
    uint256 public calls_deposit;

    function deposit(uint256 actorSeed, uint256 amountSeed) public {
        address actor = _selectActor(actorSeed);
        uint256 amount = bound(amountSeed, MIN_DEPOSIT, MAX_DEPOSIT);

        vm.prank(actor);
        protocol.deposit(amount);

        ghost_totalDeposited += amount;
        calls_deposit++;
    }
}
```

Handler checklist: all protocol actions covered, ghost variables track aggregates, call counters for coverage, input bounding prevents reverts, actor selection is deterministic.

## Stress & Adversarial Testing

**Stress categories**: Mass exit (80%+ early redemption), concentration (single actor dominance), timing attacks, economic edge cases (zero/max values).

**Attack vectors**: Reentrancy, access control bypass, state manipulation, economic exploitation, cross-layer attacks.

Read `src/actors/SimAdversary.sol` for existing adversary patterns.

## HTML Report Dashboard

The swarm simulation generates an interactive HTML dashboard at `reports/simulation.html`:

| Section | Visualization |
|---------|--------------|
| Summary Cards | 8 metric cards from ghost variables |
| Price & vBTC Ratio | Dual-axis line chart |
| Net Worth by Archetype | 7-line chart (averaged per archetype) |
| Leaderboard | Top 20 agents by final net worth |
| Archetype Performance | Bar chart + stats table |
| Action Distribution | Stacked bar per archetype |
| Protocol Metrics | TVL + match pool line charts |
| Agent Details | 100 collapsible sections |

Chart.js from CDN, dark theme, ~70KB self-contained HTML.

## Data Generation Commands

Price data generation is decoupled from simulation execution. The WBTC/USDC price series (GBM with regime switching) can be generated, validated, and reused independently. The vBTC/WBTC ratio remains emergent from AMM agent activity and cannot be pre-generated.

**Canonical price data location:** `.claude/skills/simulation/data/price_series.csv`

### Command: Generate Price Series

```
/simulation generate-prices [--seed=42] [--ticks=320] [--initial-price=60000]
```

Steps:
1. Run `cd contracts/simulation && python scripts/generate_price_series.py --seed 42 --ticks 320`
2. Copy to canonical location: `cp contracts/simulation/reports/price_series.csv .claude/skills/simulation/data/price_series.csv`
3. Copy validation report: `cp contracts/simulation/reports/price_validation.json .claude/skills/simulation/data/price_validation.json`

Output: `price_series.csv` (tick,price,regime) and `price_validation.json` with statistics (final price, min/max, total return, max drawdown, annualized CAGR, annualized vol, regime distribution, switch count).

## Running Simulations

**CRITICAL: Every simulation execution MUST archive results to `.claude/skills/simulation-results/{timestamp_id}/` and update `index.md`. A simulation run without archived results is incomplete. Do NOT consider the task done until archival and verification are complete. The exact steps are in Phase 2 below and in each `/simulation run/*` command file.**

### Simulation Execution Protocol

```
/simulation run [--regenerate-prices] [--test=test_swarm]
```

**Default behavior (reuse existing price data):**

1. Check if `.claude/skills/simulation/data/price_series.csv` exists
2. **If exists and `--regenerate-prices` is NOT set:**
   - Copy to Forge sandbox: `cp .claude/skills/simulation/data/price_series.csv contracts/simulation/reports/price_series.csv`
   - Run `test_swarm_preloaded` (loads pre-generated prices)
3. **If missing or `--regenerate-prices` is set:**
   - Run `test_swarm` (generates prices live via GBM)
   - Copy generated data to canonical location: `cp contracts/simulation/reports/price_series.csv .claude/skills/simulation/data/price_series.csv` (extracted from market_data.csv tick/price/regime columns)

**Phase 1: Run the simulation**

```bash
cd contracts/simulation
forge test --match-test <test_name> -vvv --gas-limit 999999999999
```

The test writes 6 files to `contracts/simulation/reports/`:

| File | Format | Content |
|------|--------|---------|
| `market_data.csv` | CSV | tick, price, vbtcRatio, tvl, matchPool, regime |
| `agent_net_worth.csv` | CSV | tick, agent_0..agent_99 (wide format) |
| `agent_actions.csv` | CSV | tick, agentId, action, actionName, amount, success |
| `agent_configs.json` | JSON | Array of 100 agent configs |
| `simulation_summary.json` | JSON | Ghost vars, params, final state |
| `summary.md` | Markdown | Human-readable overview with leaderboard |
| `vbtc_ratio.png` | PNG | vBTC/WBTC ratio chart (post-vesting, from week 162) |

**Phase 1.5: Generate HTML dashboard and charts**

`simulation.html` is NOT written by the Solidity test — it is generated by `scripts/generate_report.py` from `market_data.csv`. This script includes a tick-count validation that fails fast if `market_data.csv` and `simulation_summary.json` are inconsistent (stale data from a prior run).

```bash
cd contracts/simulation && python3 scripts/generate_report.py
cd contracts/simulation && python3 scripts/generate_vbtc_ratio_chart.py
```

The vBTC ratio chart reads `market_data.csv` and generates `reports/vbtc_ratio.png` — a two-panel visualization of the vBTC/WBTC exchange rate from week 162 onward (post-vesting).

**Phase 2: Archive results**

After a successful run, archive simulation outputs only (NOT input files like `price_series.csv`) to a timestamped results directory:

```bash
RUN_ID=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR=".claude/skills/simulation-results/${RUN_ID}"
mkdir -p "${RESULTS_DIR}"
cp contracts/simulation/reports/market_data.csv \
   contracts/simulation/reports/agent_net_worth.csv \
   contracts/simulation/reports/agent_actions.csv \
   contracts/simulation/reports/agent_configs.json \
   contracts/simulation/reports/simulation_summary.json \
   contracts/simulation/reports/summary.md \
   contracts/simulation/reports/simulation.html \
   contracts/simulation/reports/vbtc_ratio.png \
   "${RESULTS_DIR}/"
```

Then append the run to the index:

```bash
# Create index if it doesn't exist
if [ ! -f .claude/skills/simulation-results/index.md ]; then
  echo "# Simulation Results Index\n\n| ID | Date | Test | Ticks | Seed | Agents | Status |\n|----|------|------|-------|------|--------|--------|" > .claude/skills/simulation-results/index.md
fi

# Append run entry
echo "| ${RUN_ID} | $(date +%Y-%m-%d) | <test_name> | <tick_count> | 42 | 100 | success |" >> .claude/skills/simulation-results/index.md
```

### Forge Commands

```bash
cd contracts/simulation

# Generate price series (Python, default 320 weeks)
python scripts/generate_price_series.py --seed 42 --ticks 320

# Generate full price series (512 weeks)
python scripts/generate_price_series.py --seed 42 --ticks 512

# Default simulation (320 weeks) with live price generation
forge test --match-test test_swarm -vvv --gas-limit 999999999999

# Full simulation (512 weeks)
SIMULATION_WEEKS=512 forge test --match-test test_swarm -vvv --gas-limit 999999999999

# Custom duration (override via env var)
SIMULATION_WEEKS=100 forge test --match-test test_swarm -vvv --gas-limit 999999999999

# Simulation with pre-loaded prices
forge test --match-test test_swarm_preloaded -vvv --gas-limit 999999999999

# 20-week smoke test
forge test --match-test test_swarm_smoke -vvv --gas-limit 999999999999

# Handler-based fuzz tests
forge test --match-contract CrossLayerInvariant -vvv
```

### Accessing Past Results

All simulation results are stored in `.claude/skills/simulation-results/`. Each run directory contains the full set of output files. The `index.md` file provides a table of all recorded runs.

## Common Tasks

When adding a **new agent archetype**: follow the checklist in [`references/archetypes.md`](references/archetypes.md#adding-a-new-archetype).

When adding a **new invariant**: add assertion function to `SwarmInvariants.sol` or `CrossLayerInvariants.sol`, call it from test's `_checkInvariants()`, and document in `references/Swarm_Simulation.md`.

When adding a **new agent action**: add to `AgentLib.Action` enum, implement decision logic in the relevant archetype's `decide()` branch, implement execution in `SwarmOrchestrator.executeAction()`, and add ghost variable tracking if the action involves value transfer.

When modifying the **price model**: update `PriceSimulator.sol` parameters, adjust `MockCurvePool`/`MockTWAPOracle` feed logic if interfaces change, and update `references/Swarm_Simulation.md` parameter tables.

When extending the **HTML report**: modify `HtmlReport.sol`, add snapshot storage in `SwarmOrchestrator` if new data series are needed.

## Output Standards

- Reference specific `contract:function:line` for issues
- Include reproduction steps and Foundry commands
- State invariant being tested and ghost variable calculations
- Document stress scenario rationale
- Ensure `references/Swarm_Simulation.md` stays in sync with implementation changes
