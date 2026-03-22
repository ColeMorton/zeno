# Agent Archetypes

## Distribution

| Archetype | Count | Index Range | Capital (den) | Strategy Mask | Character |
|-----------|-------|-------------|---------------|---------------|-----------|
| Diamond Hands | 30 | 0–29 | 500–1,500 | `MATCH_HUNT` | Patient holders |
| Yield Farmer | 20 | 30–49 | 300–1,200 | `PERPS\|VOL\|MATCH_HUNT\|SWAP` | DeFi optimizers |
| Momentum Trader | 15 | 50–64 | 100–800 | `PERPS\|MATCH_HUNT\|SWAP` | Trend followers |
| Volatility Player | 10 | 65–74 | 100–800 | `VOL\|MATCH_HUNT` | Vol surface traders |
| Arbitrageur | 10 | 75–84 | 200–1,000 | `DORMANCY\|MATCH_HUNT\|SWAP` | Protocol mechanics exploiters |
| Panic Seller | 10 | 85–94 | 100–800 | `EARLY_REDEEM\|PERPS\|VOL\|SWAP` | Fear-driven exits |
| Predator | 5 | 95–99 | 100–500 | `DORMANCY\|MATCH_HUNT` | Dormancy hunters |

## Psychology Templates

Each archetype seeds a unique psychology with randomized values within archetype-specific ranges. Two agents of the same archetype will have different thresholds, allocation percentages, and intervals.

### Diamond Hands (30 agents)

Strategy: `MATCH_HUNT` only. Capital: 500–1,500 d (0.05–0.15 BTC), vault allocation: 90-100%. Very high panic/exit thresholds (-30% to -50%), no DeFi exposure. Activity interval: 80-200 ticks. Patience range: 70-100. These agents hold through volatility and claim match pool rewards. Long activity intervals create dormancy targets for Predators.

### Yield Farmer (20 agents)

Strategy: `PERPS|VOL|MATCH_HUNT|SWAP`. Capital: 300–1,200 d (0.03–0.12 BTC), vault allocation: 40-60%. Moderate thresholds (-12% to -25% panic). Perp allocation: 20-45%, vol allocation: 30-60%, max 1-3 perps. Funding-rate driven (trendBias=0). Vol strike: 3-6%. Activity interval: 40-100 ticks. Close perps every 15-30 ticks. Keep significant capital liquid for DeFi deployment.

### Momentum Trader (15 agents)

Strategy: `PERPS|MATCH_HUNT|SWAP`. Capital: 100–800 d (0.01–0.08 BTC), vault allocation: 30-50%. Aggressive allocation: 40-90% to perps, 2-5 max positions. 80% are trend-followers (trendBias=1), 20% are contrarians (trendBias=-1). Entry threshold: 0-3%. Close perps every 8-20 ticks. Smallest vault allocation — prioritize trading capital over holding.

### Volatility Player (10 agents)

Strategy: `VOL|MATCH_HUNT`. Capital: 100–800 d (0.01–0.08 BTC), vault allocation: 40-60%. Vol allocation: 40-80%. Unique vol strike thresholds (2-8%) create genuine disagreement on vol positioning. Activity interval: 15-40 ticks.

### Arbitrageur (10 agents)

Strategy: `DORMANCY|MATCH_HUNT|SWAP`. Capital: 200–1,000 d (0.02–0.10 BTC), vault allocation: 20-40%. Focused on match pool claims, dormancy hunting, and vBTC/WBTC ratio arbitrage. High composure (panic at -20% to -35%). Activity interval: 7-20 ticks. Rebalance frequency: 1 (every tick). Lowest vault allocation — maximum liquidity for arbitrage.

### Panic Seller (10 agents)

Strategy: `EARLY_REDEEM|PERPS|VOL|SWAP`. Capital: 100–800 d (0.01–0.08 BTC), vault allocation: 60-80%. Low panic thresholds (-3% to -15%), low exit thresholds (-2% to -10%). Small DeFi exposure (10-30% allocation). Close perps every 3-10 ticks. Activity interval: 60-150 ticks. These agents feed the match pool and are prone to vault neglect.

### Predator (5 agents)

Strategy: `DORMANCY|MATCH_HUNT`. Capital: 100–500 d (0.01–0.05 BTC), vault allocation: 50-70%. High composure (panic at -25% to -40%). Focused on poke/claim dormancy mechanics. Activity interval: 7-20 ticks. Critical for testing dormancy lifecycle. Diamond Hands and Panic Sellers provide dormancy targets due to long activity intervals.

## Expected Behavior in Simulation

- Net worth trajectories diverge after vesting (~week 162) when withdrawals, match claims, and early redemption forfeitures create differentiated outcomes
- **Diamond Hands** outperform on vault appreciation due to high vault allocation (90-100%) capturing the full BTC CAGR
- **DeFi-focused archetypes** (Yield Farmer, Momentum Trader, Volatility Player) sacrifice vault upside (30-60% vault allocation) for trading alpha — they must outperform with their DeFi strategies to compensate
- **Arbitrageurs** keep maximum liquidity (20-40% vault allocation) for ratio arbitrage and dormancy hunting
- **Panic Sellers** feed the match pool, reducing their own returns while subsidizing patient holders; long activity intervals (60-150 ticks) make them dormancy targets
- **Predators** hunt dormant Diamond Hands (80-200 tick activity intervals) and negligent Panic Sellers
- See [`diagnostics.md`](diagnostics.md) for action failure analysis and expected failure rates per archetype

## Bootstrap Phase Mapping

The [Bootstrap Minting Behavior](../../research/references/Bootstrap_Minting_Behavior.md) research models a three-phase minting pattern during the 1129-day bootstrap (simulation ticks 0–161). Each archetype maps differently to these phases:

| Archetype | Phase I: Surge (Days 0-30) | Phase II: Trough (Days 31-1098) | Phase III: Rally (Days 1099-1128) |
|-----------|---------------------------|--------------------------------|----------------------------------|
| Diamond Hands | Primary minters (high conviction, 90-100% allocation) | Absent (already committed) | Absent |
| Yield Farmer | Active (mint to farm xBTC) | Punctuation minters (xBTC DeFi catalysts) | Absent |
| Momentum Trader | Active if launch momentum is strong | BTC price-correlated sub-peaks | Attention-driven if vBTC narrative builds |
| Volatility Player | Absent (no vol products during bootstrap) | Absent | Absent |
| Arbitrageur | Active (match pool positioning) | Match Pool Watcher profile | Structural minters (vBTC arbitrage positioning) |
| Panic Seller | Active (FOMO-driven) | Latecomer profile | Attention-driven |
| Predator | Absent (no dormancy targets yet) | Absent | Absent |

### Trough Minter Profile Mapping

The research identifies four trough minter profiles. Their archetype correspondences:

- **The Strategist** → Arbitrageur (understands vBTC pricing, mints to start vesting clock)
- **The Accumulator** → Diamond Hands multi-vault variant (DCA into vaults for staggered vesting)
- **The Match Pool Watcher** → Arbitrageur (monitors on-chain match pool, mints when pro-rata returns look attractive)
- **The Latecomer** → Panic Seller, Momentum Trader (organic discovery, uncorrelated with protocol timeline)

### Multi-Vault Batch Minting

Expected average vault size is 0.005 WBTC (50 den) per [Minting Economics](../../research/references/Minting_Economics.md). Minters create multiple vaults per session for early-redemption optionality rather than one large vault.

| Archetype | Capital (den) | Vault Alloc % | Allocated (den) | Vaults @ 50 den | Batch Pattern |
|-----------|:------------:|:------------:|:--------------:|:--------------:|---------------|
| Diamond Hands | 500–1,500 | 90-100% | 450–1,500 | 9–30 | Single large batch (all-in) |
| Yield Farmer | 300–1,200 | 40-60% | 120–720 | 2–14 | Moderate batch, keep capital for DeFi |
| Momentum Trader | 100–800 | 30-50% | 30–400 | 1–8 | Small batch, prioritize trading capital |
| Volatility Player | 100–800 | 40-60% | 40–480 | 1–10 | Moderate batch |
| Arbitrageur | 200–1,000 | 20-40% | 40–400 | 1–8 | Small batch, maximum liquidity |
| Panic Seller | 100–800 | 60-80% | 60–640 | 1–13 | Impulsive batch (FOMO), regret later |
| Predator | 100–500 | 50-70% | 50–350 | 1–7 | Moderate batch |

**Current gap:** The simulation creates 1 vault per agent with `vaultAllocationPct` of capital, rather than N vaults of 0.005 WBTC each. Withdrawals are mathematically equivalent (see Minting Economics Section 5), but multi-vault optionality for partial early redemption is not modeled.

## Adding a New Archetype

1. `AgentLib.sol` — add to `Archetype` enum, implement decision logic branch, add config generation with parameter ranges
2. `SwarmOrchestrator.sol` — adjust `AGENT_COUNT` and distribution in `initializeAgents()`
3. `HtmlReport.sol` — add archetype to color/label arrays
4. This file (`references/archetypes.md`) — add distribution row, psychology template, and expected behavior
