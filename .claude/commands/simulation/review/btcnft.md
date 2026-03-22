Review the latest simulation results with **protocol-layer focus** using the btcnft-agent.

## Steps

1. Read `.claude/skills/simulation-results/index.md` and identify the most recent run ID.

2. Launch a **btcnft-agent** subagent with this prompt:

   > Review the simulation results in `.claude/skills/simulation-results/{run-id}/`. Perform a protocol-layer analysis:
   > - Ghost variable conservation: verify Total Deposited - Total Withdrawn - Total Forfeited aligns with TVL
   > - Match pool accumulation and claim patterns
   > - Vault lifecycle metrics (mints, separations, recombinations, early redemptions)
   > - vBTC ratio behavior across ticks
   > - Failed action breakdown — which protocol operations failed and why
   > - Collateral flow analysis from `market_data.csv`
   > Read: `summary.md`, `simulation_summary.json`, `agent_actions.csv`, `market_data.csv`

3. Present the agent's protocol-layer findings.
