Review the latest simulation results with **infrastructure focus** using the simulation-agent.

## Steps

1. Read `.claude/skills/simulation-results/index.md` and identify the most recent run ID.

2. Launch a **simulation-agent** subagent with this prompt:

   > Review the simulation results in `.claude/skills/simulation-results/{run-id}/`. Perform an infrastructure analysis:
   > - GBM price model behavior — regime transitions, volatility clustering, price range
   > - Agent decision patterns — action type distribution across ticks and archetypes
   > - Tick progression consistency and state transitions
   > - Action success/failure rates by type
   > - Anomalies or unexpected patterns in the data
   > - Orchestrator state machine correctness
   > Read: `summary.md`, `simulation_summary.json`, `market_data.csv`, `agent_actions.csv`, `agent_configs.json`

3. Present the agent's infrastructure findings.
