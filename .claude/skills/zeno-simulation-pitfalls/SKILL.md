---
name: zeno-simulation-pitfalls
description: "Pitfalls and hard-won lessons from running the Zeno/BTCNFT protocol simulation suite. Covers Foundry test-matching substring traps, the SIMULATION_SEED env-var pattern for multi-seed comparison, interpreting the misleading failure-rate metric, and the SimCurvePool ratio-ceiling gap. Use alongside the simulation skill."
category: zeno
---

# Zeno Simulation Pitfalls

Companion to the `simulation` skill. These are operational lessons learned the hard way.

## 1. Foundry `--match-test` Substring Matching Trap

**Problem:** Foundry's `--match-test` does SUBSTRING matching, not exact matching.

```bash
# DANGEROUS: matches BOTH test_swarm() AND test_swarm_smoke()
forge test --match-test test_swarm

# The smoke test runs first (20 ticks), overwrites all reports,
# and the full 320-tick run never produces its output.
```

**Fix:** Use a regex word boundary:

```bash
forge test --match-test 'test_swarm\b' -vvv --gas-limit 999999999999
```

Always use `\b` when there's any risk of substring collision (`test_swarm_smoke`, `test_swarm_preloaded`, etc.).

## 2. Multi-Seed Runs via `SIMULATION_SEED` Env Var

**Problem:** The simulation tests hardcode `initializeAgents(42)`. To run multiple seeds for cross-comparison, you must patch the test to read an env var.

**Required patches in `test/SwarmSimulation.sim.t.sol`:**

```solidity
function setUp() public {
    uint256 seed = vm.envOr("SIMULATION_SEED", uint256(42));
    orchestrator.initializeAgents(seed);
    // ...
}

function test_swarm() public {
    uint256 weeks_ = _simulationWeeks();
    uint256 seed = vm.envOr("SIMULATION_SEED", uint256(42));
    _loadPriceSeries();
    console.log("Agents: 100 | Ticks: %d | Seed: %d", weeks_, seed);
    // ...
}
```

Also patch `_exportSimulationSummary()` and `_exportSummaryMarkdown()` to read and export the seed.

**Batch script:**

```bash
for seed in 42 123 777; do
    SIMULATION_SEED=$seed forge test --match-test 'test_swarm\b' -vvv --gas-limit 999999999999
    mkdir -p "sim_results/sim_${seed}"
    cp reports/* "sim_results/sim_${seed}/"
done
```

## 3. The Failure Rate is Misleading

**Reality:** In the current swarm, ~99% of "failures" are `WITHDRAW` actions reverting with `WithdrawalTooSoon`. These are correct protocol behavior (30-day cooldown), not bugs.

**Implication:** A 42% failure rate does NOT mean 42% of actions are buggy. It means agents are retrying withdrawals every tick and succeeding ~1 in 4 attempts.

**Diagnostic:**

```bash
# Quick check: what actions fail?
cd contracts/simulation
python3 -c "
import csv
from collections import Counter
with open('reports/agent_actions.csv') as f:
    rows = [r for r in csv.DictReader(f) if r['success'] == 'false']
print(Counter(r['actionName'] for r in rows).most_common(5))
"
```

If >80% are `WITHDRAW`, the agent logic is working correctly. The failure rate metric is noise.

## 4. SimCurvePool Ratio Ceiling is Not Enforced

**Documentation says:** "ratio ceiling at 1.0"

**Observed reality:** vBTC/WBTC ratio peaks at 12–46x across different seeds.

**Impact:** Corrupts perp mark-to-market, swap decisions, and net worth calculations.

**Check:**

```bash
python3 -c "
import csv
with open('reports/market_data.csv') as f:
    ratios = [float(r['vbtcRatio'])/1e18 for r in csv.DictReader(f)]
print(f'Max ratio: {max(ratios):.2f}x')
print(f'Min ratio: {min(ratios):.2f}x')
"
```

If max > 1.0, the AMM invariant is broken. This is a known issue requiring a fix in `src/mocks/SimCurvePool.sol`.
