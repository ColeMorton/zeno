# Swarm Simulation: 100-Agent Autonomous Protocol Testing

> **Version:** 1.0
> **Status:** Final
> **Last Updated:** 2026-03-21
> **Related Documents:**
> - [Testing Stack](./Testing_Stack.md)
> - [Technical Specification](./protocol/Technical_Specification.md)
> - [Glossary](./GLOSSARY.md)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Price Model](#3-price-model)
4. [Agent Framework](#4-agent-framework)
5. [Agent Archetypes](#5-agent-archetypes)
6. [Net Worth Valuation](#6-net-worth-valuation)
7. [Invariant Checks](#7-invariant-checks)
8. [HTML Report Dashboard](#8-html-report-dashboard)
9. [File Reference](#9-file-reference)
10. [Usage](#10-usage)

---

## 1. Overview

The swarm simulation is a deterministic Foundry-based testing framework that deploys 100 autonomous agents against the live BTCNFT Protocol smart contracts. Each agent has a unique behavioral configuration and seeks to maximize net worth over a simulated period. A walk-forward WBTC price feed drives market dynamics, with each tick representing one week.

**Key characteristics:**

- **100 agents** across 7 behavioral archetypes
- **521 weekly ticks** covering a ~10-year period (3647 days)
- **Deterministic** — same seed always produces the same simulation
- **On-chain** — all agent logic runs in Solidity for reproducibility
- **Full protocol interaction** — agents call real VaultNFT, PerpetualVault, VolatilityPool contracts
- **Automated HTML report** generated on each execution with interactive charts

---

## 2. Architecture

The simulation is orchestrated by `SwarmOrchestrator`, which inherits from `SimulationOrchestrator` and adds DeFi stack deployment, agent management, and daily tick execution.

### Execution Flow

```
setUp()
  ├── deployProtocol()        → VaultNFT, BtcToken, MockWBTC
  ├── deployIssuer("Swarm")   → TreasureNFT, AchievementNFT, AchievementMinter
  ├── deployDeFiStack()       → PerpetualVault, VolatilityPool, VarianceOracle, mocks
  └── initializeAgents(42)    → 100 funded agents with deterministic configs

executeTick() × 521
  ├── vm.warp(+1 week)
  ├── PriceSimulator.nextTick()  → update WBTC/USDC price (GBM + regime switching)
  ├── varianceOracle.observe()   → record daily price observation
  ├── computeMarketSignals()     → reads vbtcRatio from SimCurvePool.spotPrice(), price returns, vol, funding rate
  ├── twapOracle.setTWAP(vbtcRatio) → feed MockTWAPOracle from current AMM spot ratio
  ├── for each agent 0..99:
  │   ├── computeNetWorth()      → snapshot to netWorthAt[tick][agentId]
  │   ├── AgentLib.decide()      → choose action from portfolio + signals
  │   └── executeAction()        → vm.prank(agent) + try/catch (SWAP actions move the SimCurvePool ratio)
  ├── volPool.settle()           → settle variance P&L if due
  ├── snapshot tick data         → price, vbtcRatio, TVL, matchPool, regime
  └── emit TickComplete

_generateReport()
  ├── collect all snapshot data
  ├── HtmlReport.generate()      → build HTML string
  ├── vm.writeFile()             → reports/simulation.html
  └── vm.ffi(["open", ...])     → auto-open in browser
```

### Component Composition

| Component | Purpose | Type |
|-----------|---------|------|
| `SwarmOrchestrator` | Deploys stack, manages agents, runs ticks | Contract (inherits SimulationOrchestrator) |
| `AgentLib` | Decision logic for 7 archetypes | Pure library |
| `PriceSimulator` | Walk-forward GBM with regime switching | Pure library |
| `NetWorthLib` | Portfolio valuation across all positions | View library |
| `SwarmInvariants` | Per-tick solvency assertions | Pure/view library |
| `HtmlReport` | HTML dashboard string builder | Pure library |
| `SimCurvePool` | Constant-product AMM for vBTC/WBTC, enforces ratio bounds [0.5, 1.0] on swaps, read directly by PerpetualVault | Mock contract |
| `MockTWAPOracle` | Controllable TWAP, fed each tick from `SimCurvePool.spotPrice()`, read by VarianceOracle | Mock contract |

---

## 3. Price Model

The simulation uses a **Geometric Brownian Motion (GBM)** model with **regime switching** for the WBTC/USDC price. The vBTC/WBTC ratio is **endogenous** — it emerges from agent trading on `SimCurvePool`, a constant-product AMM. There is no external mean-reverting process overriding it.

### WBTC/USDC Price (GBM)

| Parameter | Value | Description |
|-----------|-------|-------------|
| Initial price | 60,000 USDC | Starting WBTC/USDC |
| Weekly drift (mu) | 0.013104 | Arithmetic drift (CAGR ~56% + vol drag correction) |
| Low-vol sigma | 0.073475 | ~53% annualized (regime 0) |
| High-vol sigma | 0.112593 | ~81% annualized (regime 1) |
| Regime switch prob | 9.82% per tick | Markov switching between regimes |

Drift = full-history CAGR (0.008586/week) + volatility drag correction (σ²/2 ≈ 0.004519/week). The arithmetic return formulation `price *= (1 + drift + σZ)` has expected log growth = `drift - σ²/2`, so the correction ensures the simulation reproduces the historical ~56% CAGR. Volatility and switch probability calibrated via walk-forward analysis (18 folds). See `contracts/simulation/scripts/calibrate_gbm.py`.

**Step formula:** `price *= (1 + drift + sigma * Z)` where Z ~ N(0,1) via Irwin-Hall approximation (sum of 12 uniforms - 6).

### vBTC/WBTC Ratio (Endogenous, AMM-Driven)

| Parameter | Value | Description |
|-----------|-------|-------------|
| Initial ratio | 0.75 | Set by first liquidity provider |
| AMM model | Constant-product (x*y=k) | `SimCurvePool.sol` |
| Fee | 0.3% (30 BPS) | Per swap |
| Oracle | EMA (10% new, 90% prior) | `SimCurvePool.price_oracle()` |
| Bounds | [0.50, 1.00] | Enforced in `exchange()`/`add_liquidity()` via `RatioBoundsExceeded` revert |

`SimCurvePool.spotPrice()` (`reserve0 * PRECISION / reserve1`) feeds `SwarmOrchestrator`, which reads it directly for `PerpetualVault` and pushes it into `MockTWAPOracle.setTWAP()` each tick for `VarianceOracle`. Agent swaps move the ratio — Panic Sellers dumping vBTC crash it, Arbitrageurs buying cheap vBTC restore it — creating a natural feedback loop, not an external stochastic process.

### SimCurvePool Ratio Ceiling

`SimCurvePool.exchange()` and `add_liquidity()` enforce a hard [0.50, 1.00] bound on `reserve0/reserve1`, reverting with `RatioBoundsExceeded` if a swap or deposit would push the ratio outside that band. This models external arbitrage pressure — in reality, any exceedance above 1.0 creates risk-free profit via the separate-and-sell loop, which rational actors would immediately exploit. See `vBTC_Ratio_Upper_Bound.md` for the formal argument and `RCA-SimCurvePool-Ratio-Ceiling.md` for the incident where this bound was found unenforced (ratio spiked 12-46x) before the fix landed.

### Determinism

All randomness derives from a single seed via `keccak256` chaining. The same seed (default: `42`) always produces identical price paths, agent configs, and simulation outcomes.

---

## 4. Agent Framework

Each agent is an EOA address controlled by the test harness via `vm.prank`. Agents receive one action per tick, ensuring bounded gas costs and realistic weekly decision-making cadence.

### Denomination Unit

| Unit | Satoshis | BTC |
|------|----------|-----|
| 1 d (den) | 10,000 | 0.0001 |

All `initialCapitalWbtc` config ranges use **den** for legibility. Protocol code, data exports, and calculations remain in satoshis. Convert: `satoshis = den * 10,000`. The average BTC holder owns ~0.1 BTC (1,000 d); holding 1-3 BTC (10,000-30,000 d) is rare.

### Agent Configuration

```solidity
struct AgentConfig {
    Archetype archetype;          // Archetype template (7 types, used for grouping)
    uint8     riskTolerance;      // 1-100 (aggression level)
    uint8     patience;           // 1-100 (holding duration preference)
    uint16    leveragePreference; // 100-500 (1x-5x in X100 format)
    int8      volBias;            // -1=short vol, 0=neutral, 1=long vol
    uint8     rebalanceFrequency; // Ticks between rebalance decisions
    uint64    initialCapitalWbtc; // satoshis (configured in den: 1 d = 10,000 sats)
    Psychology psychology;        // Per-agent behavioral profile
}
```

Configs are generated deterministically from `seed + agentIndex`. The archetype seeds an individualized `Psychology` with unique threshold values per agent.

### Psychology (Per-Agent Behavioral Profile)

Each agent has a unique `Psychology` struct that drives all decision-making. The archetype serves as a template that defines ranges; each agent gets its own randomized values within those ranges.

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

### Agent State

Each agent tracks:
- **Vault IDs** — owned VaultNFT token IDs
- **Perp position IDs** — open PerpetualVault positions
- **Vol pool shares** — long and short VolatilityPool exposure
- **vBTC separation** — whether `mintBtcToken` has been called
- **Last action tick** — for rebalance frequency gating

### Market Signals

Computed each tick from on-chain state:
- WBTC price and vBTC ratio (from price simulator)
- 7-day and 30-day price returns
- 7-day realized volatility (annualized)
- Match pool size and total active collateral
- PerpetualVault funding rate

### Portfolio View

Before deciding, each agent's portfolio is aggregated:
- WBTC and vBTC token balances
- Total vault collateral and vesting status
- Withdrawal eligibility (30-day cooldown)
- Perp position count and vol pool exposure
- Dormant vault targets (for agents with `STRAT_DORMANCY`)

### Available Actions (18 total)

| Action | Protocol Layer | Description |
|--------|---------------|-------------|
| `MINT_VAULT` | VaultNFT | Deposit WBTC + Treasure NFT |
| `WITHDRAW` | VaultNFT | 1% monthly withdrawal (post-vesting) |
| `EARLY_REDEEM` | VaultNFT | Exit early, forfeit to match pool |
| `MINT_BTC_TOKEN` | VaultNFT | Separate vBTC from vested vault |
| `RETURN_BTC_TOKEN` | VaultNFT | Recombine vBTC with vault |
| `CLAIM_MATCH` | VaultNFT | Claim pro-rata match pool share |
| `PROVE_ACTIVITY` | VaultNFT | Reset dormancy timer |
| `OPEN_PERP_LONG` | PerpetualVault | Open leveraged long position |
| `OPEN_PERP_SHORT` | PerpetualVault | Open leveraged short position |
| `CLOSE_PERP` | PerpetualVault | Close position, receive payout |
| `ADD_PERP_COLLATERAL` | PerpetualVault | Reduce effective leverage |
| `DEPOSIT_VOL_LONG` | VolatilityPool | Long volatility exposure |
| `DEPOSIT_VOL_SHORT` | VolatilityPool | Short volatility exposure |
| `WITHDRAW_VOL_LONG` | VolatilityPool | Exit long vol position |
| `WITHDRAW_VOL_SHORT` | VolatilityPool | Exit short vol position |
| `POKE_DORMANT` | VaultNFT | Initiate dormancy grace period |
| `CLAIM_DORMANT` | VaultNFT | Claim dormant vault collateral |
| `NONE` | — | Skip tick (rebalance frequency) |

---

## 5. Agent Archetypes

See [`archetypes.md`](archetypes.md) for the complete archetype reference including distribution table, psychology templates with parameter ranges, and expected simulation behaviors.

---

## 5.5. Bootstrap Phase in Simulation

### Timeline Mapping

| Phase | Days | Ticks | Protocol State |
|-------|------|-------|---------------|
| Bootstrap | 0–1128 | 0–161 | xBTC minted 1:1 with collateral; no vBTC, no withdrawals, no match claims |
| Post-bootstrap | 1129+ | 162+ | vBTC separation available; withdrawals enabled; match pool claimable; xBTC minting stops |

### Current Behavior

All 100 agents mint on their first eligible tick regardless of bootstrap phase. The simulation produces a **Phase I surge-only pattern** -- no trough or terminal rally is modeled. Agents do not track xBTC holdings or make phase-aware minting decisions.

`ExpeditionCredits.mint()` is called by `VaultNFT.mint()` during bootstrap ticks (the protocol contract checks `block.timestamp <= expeditionCredits.bootstrapEnd()`), so agents do receive xBTC 1:1 with collateral. However, agents never use xBTC in decision-making -- it accumulates passively.

### Three-Phase Model

Research proposes a three-phase minting distribution during bootstrap. See [Bootstrap Minting Behavior](../../research/references/Bootstrap_Minting_Behavior.md) for the full analysis.

| Phase | Ticks | Expected Pattern |
|-------|-------|-----------------|
| I. Initial Surge | 0–4 | Front-loaded demand from pre-launch community, decaying as audience exhausts |
| II. Punctuated Trough | 5–157 | Low baseline with irregular sub-peaks from BTC price, xBTC DeFi integrations, match pool milestones, issuer launches |
| III. Terminal Rally | 157–161 | Renewed minting driven by vBTC launch attention (primary) and structural protocol milestone (secondary) |

See [`archetypes.md`](archetypes.md#bootstrap-phase-mapping) for which archetypes participate in each phase and expected multi-vault batch sizes.

---

## 6. Net Worth Valuation

Each agent's net worth is computed every tick in WBTC terms by summing six components:

| Component | Calculation |
|-----------|-------------|
| WBTC balance | `wbtc.balanceOf(agent)` |
| Vault collateral | Sum of `collateralAmount` for all owned vaults |
| vBTC holdings | `btcToken.balanceOf(agent) * vbtcRatio / 1e18` |
| Perp positions | `perpVault.previewClose(positionId)` payout * vbtcRatio |
| Vol pool shares | `volPool.previewWithdrawLong/Short(shares)` * vbtcRatio |
| Match pool claim | `matchPool * agentCollateral / totalActiveCollateral` (vested only) |

Vault collateral is valued at full face value (not time-discounted) since the agent holds a real claim regardless of vesting status.

---

## 7. Invariant Checks

Invariants are checked every 50 ticks during simulation to ensure protocol correctness, with **vBTC ratio bounds checked every tick** once the Curve pool is initialized (ratio-sensitive phase):

| Invariant | Assertion | Frequency |
|-----------|-----------|-----------|
| Vault solvency | `wbtc.balanceOf(vault) >= matchPool` | Every 50 ticks |
| Perp vault solvency | `vBTC.balanceOf(perp) >= sum of all position payouts` | Every 50 ticks |
| Vol pool solvency | `vBTC.balanceOf(volPool) >= longPoolAssets + shortPoolAssets` | Every 50 ticks |
| System conservation | Total agent net worth within tolerance of system value | Every 50 ticks |
| **vBTC ratio ceiling** | `vbtcRatio <= 1.0e18` (1.0) | **Every tick** (post-init) |
| **vBTC ratio floor** | `vbtcRatio >= 0.5e18` (0.5) | **Every tick** (post-init) |

The ratio bounds are enforced by `_checkRatioInvariants()` which runs every tick once `SimCurvePool` is initialized. On breach, the simulation halts with a clear error message including the tick number and the offending ratio value (e.g., `Tick 123: Ratio ceiling breached. vbtcRatio=1005000000000000000`).

The `SwarmInvariants` library also exports `invariant_vbtcRatioBounds(uint256 vbtcRatio)` for standalone fuzz testing.

These extend the existing `CrossLayerInvariants` library with DeFi-layer assertions via `SwarmInvariants`.

### Ghost Variables

The orchestrator tracks aggregate flows for conservation verification:

| Variable | Tracks |
|----------|--------|
| `ghost_totalDeposited` | Cumulative WBTC deposited into vaults |
| `ghost_totalWithdrawn` | Cumulative WBTC withdrawn from vested vaults |
| `ghost_totalForfeited` | Cumulative WBTC forfeited via early redemption |
| `ghost_totalMatchClaimed` | Cumulative match pool claims |
| `ghost_totalActions` | Total agent actions attempted |
| `ghost_totalFailedActions` | Actions that reverted (preconditions unmet) |

---

## 8. HTML Report Dashboard

An interactive HTML dashboard is generated automatically after each simulation run, written to `reports/simulation.html` via Foundry's `vm.writeFile()` cheatcode and auto-opened in the browser.

### Dashboard Sections

| Section | Visualization | Data Source |
|---------|--------------|-------------|
| Summary Cards | 8 metric cards | Ghost variables, match pool |
| Price & vBTC Ratio | Dual-axis line chart | `priceSnapshots`, `vbtcRatioSnapshots` |
| Net Worth by Archetype | 7-line chart (averaged) | `netWorthAt[tick][agentId]` averaged per archetype |
| Leaderboard | Top 20 table | Agents sorted by final net worth |
| Archetype Performance | Bar chart + stats table | Aggregated return per archetype |
| Action Distribution | Stacked bar chart | `agentActionCounts` aggregated per archetype |
| Protocol Metrics | 2-line chart | `tvlSnapshots`, `matchPoolSnapshots` |
| Agent Details | 100 collapsible sections | Per-agent config, return, net worth |

### Technical Details

- **Charting:** Chart.js loaded from CDN (`cdn.jsdelivr.net/npm/chart.js`)
- **Styling:** Dark theme with responsive CSS grid layout
- **Data embedding:** Chart data serialized as JSON arrays in `<script>` tags
- **Collapsible agents:** Native HTML `<details>/<summary>` elements
- **Return calculation:** `(final / initial - 1) * 10000` in basis points with 1e18 intermediate precision
- **Output size:** ~70KB self-contained HTML

---

## 9. File Reference

```
contracts/simulation/
├── foundry.toml                              # Solc 0.8.24, FFI enabled, fs_permissions
├── reports/
│   └── simulation.html                       # Generated HTML dashboard
├── src/
│   ├── SimulationOrchestrator.sol            # Base: protocol + issuer deployment
│   ├── SwarmOrchestrator.sol                 # DeFi stack, 100 agents, tick execution
│   ├── agents/
│   │   └── AgentLib.sol                      # 7 archetypes, decision logic, config gen
│   ├── assertions/
│   │   ├── CrossLayerInvariants.sol          # Protocol + cross-layer invariants
│   │   └── SwarmInvariants.sol               # Perp/vol solvency, system conservation
│   ├── libraries/
│   │   ├── HtmlReport.sol                    # HTML dashboard string builder
│   │   ├── NetWorthLib.sol                   # Portfolio valuation (6 components)
│   │   └── PriceSimulator.sol               # GBM + regime switching (WBTC/USDC price only)
│   └── mocks/
│       ├── SimCurvePool.sol                  # Constant-product AMM, endogenous vBTC/WBTC ratio, ratio-bounds enforcement
│       └── MockTWAPOracle.sol                # Controllable getTWAP(), fed from SimCurvePool each tick
└── test/
    └── SwarmSimulation.sim.t.sol             # Test harness: 1200-day + 100-day smoke
```

---

## 10. Usage

### Run Default Simulation (320 weeks)

```bash
cd contracts/simulation
forge test --match-test test_swarm -vvv --gas-limit 999999999999
```

### Run Full Simulation (512 weeks)

```bash
cd contracts/simulation
SIMULATION_WEEKS=512 forge test --match-test test_swarm -vvv --gas-limit 999999999999
```

### Run Custom Duration

```bash
cd contracts/simulation
SIMULATION_WEEKS=100 forge test --match-test test_swarm -vvv --gas-limit 999999999999
```

The HTML report auto-opens in the browser upon completion.

### Run Smoke Test (20 weeks)

```bash
cd contracts/simulation
forge test --match-test test_swarm_smoke -vvv --gas-limit 999999999999
```

### Configuration

| Parameter | Location | Default |
|-----------|----------|---------|
| Random seed | `initializeAgents(42)` in test `setUp()` | 42 |
| Simulation duration | `SIMULATION_WEEKS` env var / `_simulationWeeks()` helper | 320 (override via `SIMULATION_WEEKS` env var) |
| Initial WBTC price | `INITIAL_PRICE` in SwarmOrchestrator | 60,000 USDC |
| Initial vBTC ratio | `INITIAL_VBTC_RATIO` in SwarmOrchestrator | 0.75 |
| Invariant check interval | `INVARIANT_CHECK_INTERVAL` in test | Every 50 ticks (full suite); ratio bounds every tick post-init |
| Agent count | `AGENT_COUNT` in SwarmOrchestrator | 100 |
| Treasures per agent | `TREASURES_PER_AGENT` in SwarmOrchestrator | 10 |

### Interpreting Results

- **Net worth trajectories** diverge after vesting (~week 162) when withdrawals, match claims, and early redemption forfeitures create differentiated outcomes
- See [`archetypes.md`](archetypes.md#expected-behavior-in-simulation) for archetype-specific performance expectations
- See [`diagnostics.md`](diagnostics.md) for action failure analysis, error catalogs, and debugging methodology
