Review a simulation run from three domain perspectives in parallel. Optionally accepts a run ID as an argument.

## Steps

1. **Determine the run ID:**
   - If `$ARGUMENTS` is provided, use it as the run ID directly. Verify the directory `.claude/skills/simulation-results/$ARGUMENTS/` exists — if not, fail with: "No simulation results found for ID: $ARGUMENTS"
   - If `$ARGUMENTS` is empty, read `.claude/skills/simulation-results/index.md` and identify the **last row** (most recent run). Extract the run ID (e.g., `20260322_102619`).

2. Launch **three Agent subagents in parallel** (single message, three tool calls) targeting the result directory `.claude/skills/simulation-results/{run-id}/`:

   **Agent 1 — btcnft-agent** (Protocol Layer):
   > Review the simulation results in `.claude/skills/simulation-results/{run-id}/`. Focus on protocol-layer analysis:
   > - Ghost variable conservation: verify Total Deposited - Total Withdrawn - Total Forfeited aligns with TVL
   > - Match pool accumulation and claim patterns
   > - Vault lifecycle metrics (mints, separations, recombinations, early redemptions)
   > - vBTC ratio behavior across ticks
   > - Failed action breakdown — which protocol operations failed and why
   > Read: `summary.md`, `simulation_summary.json`, `agent_actions.csv`, `market_data.csv`

   **Agent 2 — issuer-agent** (Issuer Layer):
   > Review the simulation results in `.claude/skills/simulation-results/{run-id}/`. Focus on issuer-layer analysis:
   > - Leaderboard distribution — which archetypes dominate top positions and why
   > - Agent archetype performance comparison (net worth delta by archetype)
   > - Net worth trajectory patterns from `agent_net_worth.csv`
   > - Holder concentration and distribution analysis
   > Read: `summary.md`, `agent_net_worth.csv`, `agent_configs.json`, `market_data.csv`

   **Agent 3 — simulation-agent** (Simulation Infrastructure):
   > Review the simulation results in `.claude/skills/simulation-results/{run-id}/`. Focus on infrastructure analysis:
   > - GBM price model behavior — regime transitions, volatility clustering, price range
   > - Agent decision patterns — action type distribution across ticks and archetypes
   > - Tick progression consistency and state transitions
   > - Action success/failure rates by type
   > - Anomalies or unexpected patterns in the data
   > Read: `summary.md`, `simulation_summary.json`, `market_data.csv`, `agent_actions.csv`, `agent_configs.json`

3. Present a **consolidated review** with three sections (Protocol, Issuer, Infrastructure), each summarizing the agent's findings. End with a combined assessment of simulation health and any issues requiring attention.
