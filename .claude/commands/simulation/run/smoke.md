Run the simulation skill to execute a **20-week smoke** swarm simulation.

## Steps

### 1. Run simulation

```bash
cd contracts/simulation && forge test --match-test test_swarm_smoke -vvv --gas-limit 999999999999
```

### 2. Validate forge output (MANDATORY — do NOT skip)

Check that `_exportData()` ran successfully:

```bash
test -f contracts/simulation/reports/simulation_summary.json || { echo "ERROR: simulation_summary.json not found — forge test likely timed out or failed before _exportData() ran"; exit 1; }
```

### 3. Generate HTML dashboard

```bash
cd contracts/simulation && python3 scripts/generate_report.py
```

### 3.5. Generate vBTC ratio chart

```bash
cd contracts/simulation && python3 scripts/generate_vbtc_ratio_chart.py
```

### 4. Archive results (MANDATORY — do NOT skip)

After a successful run, archive simulation outputs (NOT input files like `price_series.csv`) to a timestamped results directory:

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

### 5. Update index (MANDATORY — do NOT skip)

```bash
if [ ! -f .claude/skills/simulation-results/index.md ]; then
  printf '# Simulation Results Index\n\n| ID | Date | Test | Ticks | Seed | Agents | Status |\n|----|------|------|-------|------|--------|--------|\n' > .claude/skills/simulation-results/index.md
fi
echo "| ${RUN_ID} | $(date +%Y-%m-%d) | test_swarm_smoke | 20 | 42 | 100 | success |" >> .claude/skills/simulation-results/index.md
```

### 6. Verify archival

Confirm the results directory exists and contains the expected files:

```bash
ls -la "${RESULTS_DIR}/"
```

Report the `RUN_ID` to the user.

### 7. Open dashboard (MANDATORY — do NOT skip)

```bash
open "${RESULTS_DIR}/simulation.html"
```

### 8. Cleanup reports directory

```bash
rm -f contracts/simulation/reports/*
```
