Review the latest simulation results with **issuer-layer focus** using the issuer-agent.

## Steps

1. Read `.claude/skills/simulation-results/index.md` and identify the most recent run ID.

2. Launch an **issuer-agent** subagent with this prompt:

   > Review the simulation results in `.claude/skills/simulation-results/{run-id}/`. Perform an issuer-layer analysis:
   > - Leaderboard distribution — which archetypes dominate top positions and why
   > - Agent archetype performance comparison (net worth delta by archetype)
   > - Net worth trajectory patterns from `agent_net_worth.csv`
   > - Holder concentration and distribution analysis
   > - Capital efficiency across archetype strategies
   > Read: `summary.md`, `agent_net_worth.csv`, `agent_configs.json`, `market_data.csv`

3. Present the agent's issuer-layer findings.
