# Price Model Reference

## WBTC/USDC — Geometric Brownian Motion with Asymmetric Regime Switching

| Parameter | Value | Description |
|-----------|-------|-------------|
| Initial price | 60,000 USDC | Starting WBTC/USDC |
| Low-vol sigma | 0.073475 | ~53% annualized (regime 0) |
| High-vol sigma | 0.112593 | ~81% annualized (regime 1) |
| P(low→high) | ~11.00% per tick | Asymmetric: faster to panic |
| P(high→low) | ~8.64% per tick | Asymmetric: slower to calm |

### Scenario-Based Drift

The weekly drift is parameterized by scenario to test protocol robustness across different market regimes:

| Scenario | Weekly Drift | Annualized CAGR | Use Case |
|----------|-------------|-----------------|----------|
| `bull` | 0.013104 | ~56% | Historical calibration (default) |
| `moderate` | 0.003846 | ~22% | Institutional forward consensus |
| `stagnant` | 0.000962 | ~5% | Post-maturation, gold-like |
| `bear` | -0.001923 | ~-10% | Extended bear cycle stress test |

Generate with: `python generate_price_series.py --scenario moderate`

Volatility and regime switching are scenario-independent (calibrated from history). Only drift changes. This isolates the variable that matters most (expected return) while preserving realistic volatility dynamics.

### Vol Drag Correction

Drift = CAGR_weekly + vol_drag, where vol_drag uses the **ergodic regime distribution** (not 50/50):
- π_high = P(low→high) / (P(low→high) + P(high→low))
- avg(σ²) = π_low × σ_low² + π_high × σ_high²
- vol_drag = avg(σ²) / 2

**Step formula:** `price *= exp(drift + sigma * Z)` where Z ~ N(0,1).

**Generation:** Primary generation via `scripts/generate_price_series.py` (numpy). `PriceSimulator.sol` provides a Solidity fallback for live/non-preloaded simulation runs.

## vBTC/WBTC Ratio — Endogenous (AMM-Driven)

The vBTC/WBTC ratio is **endogenous** — it emerges from agent trading on the SimCurvePool (constant-product AMM). There is no external Ornstein-Uhlenbeck process overriding the ratio.

| Parameter | Value | Description |
|-----------|-------|-------------|
| Initial ratio | 0.75 | Set by first liquidity provider |
| AMM model | Constant-product (x*y=k) | SimCurvePool.sol |
| Fee | 0.3% (30 BPS) | Per swap |
| Oracle | EMA (10% new, 90% prior) | SimCurvePool.price_oracle() |
| TWAP bounds | [0.50, 1.00] | MockTWAPOracle enforcement |

The TWAP oracle reads directly from the AMM's EMA price (`SimCurvePool.price_oracle()`), which the `SwarmOrchestrator` feeds each tick (lines 264-268). Agent swaps move the ratio — Panic Sellers dumping vBTC crash it, Arbitrageurs buying cheap vBTC restore it. This creates a natural feedback loop.

## Determinism

All randomness derives from a single seed. The Python generator uses `numpy.random.default_rng(seed)` for exact normal distribution sampling. The Solidity fallback uses `keccak256` chaining with Irwin-Hall N(0,1) approximation (sum of 12 uniforms - 6). Same seed produces identical paths within each implementation, but Python and Solidity sequences differ due to different PRNGs.

## Regime Switching

The volatility regime follows a two-state **asymmetric** Markov chain:
- **State 0** (low vol): sigma = 0.073475 (~53% annualized)
- **State 1** (high vol): sigma = 0.112593 (~81% annualized)
- **P(low→high)**: ~11.00% per tick (faster transition into volatility)
- **P(high→low)**: ~8.64% per tick (slower recovery to calm)
- Regime state is part of `PriceState` and deterministically derived from the random seed

The asymmetry captures empirical behavior: markets transition into high-vol regimes quickly (crash-driven) but recover slowly (gradual confidence restoration).
