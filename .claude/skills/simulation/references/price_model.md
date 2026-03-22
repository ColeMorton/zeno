# Price Model Reference

## WBTC/USDC — Geometric Brownian Motion with Regime Switching

| Parameter | Value | Description |
|-----------|-------|-------------|
| Initial price | 60,000 USDC | Starting WBTC/USDC |
| Weekly drift (mu) | 0.013104 | Arithmetic drift (CAGR ~56% + vol drag correction) |
| Low-vol sigma | 0.073475 | ~53% annualized (regime 0) |
| High-vol sigma | 0.112593 | ~81% annualized (regime 1) |
| Regime switch prob | 9.82% per tick | Markov switching between regimes |

Drift = CAGR_weekly (0.008586) + vol drag correction (avg(σ²)/2 ≈ 0.004519). The `price *= exp(drift + σZ)` formulation has E[log return] = drift, so the vol drag correction ensures the simulation reproduces the historical ~56% CAGR. Volatility and switch probability calibrated via walk-forward analysis (18 folds, median). See `contracts/simulation/scripts/calibrate_gbm.py` and `reports/wfa_results.csv`.

**Step formula:** `price *= exp(drift + sigma * Z)` where Z ~ N(0,1).

**Generation:** Primary generation via `scripts/generate_price_series.py` (numpy). `PriceSimulator.sol` provides a Solidity fallback for live/non-preloaded simulation runs using 6th-order Taylor exp(x) and Irwin-Hall N(0,1) approximations.

## vBTC/WBTC Ratio — Ornstein-Uhlenbeck Process

| Parameter | Value | Description |
|-----------|-------|-------------|
| Initial ratio | 0.75 | Starting vBTC discount |
| Mean target | 0.85 | Long-run equilibrium |
| Reversion speed | 0.005/day | Mean-reversion pull |
| Daily sigma | 0.005 | Noise amplitude |
| Bounds | [0.50, 1.00] | Hard clamp matching PerpetualVault |

The vBTC ratio feeds into `MockCurvePool.price_oracle()` and `MockTWAPOracle.getTWAP()`, read by PerpetualVault and VarianceOracle respectively.

## Determinism

All randomness derives from a single seed. The Python generator uses `numpy.random.default_rng(seed)` for exact normal distribution sampling. The Solidity fallback uses `keccak256` chaining with Irwin-Hall N(0,1) approximation (sum of 12 uniforms - 6). Same seed produces identical paths within each implementation, but Python and Solidity sequences differ due to different PRNGs.

## Regime Switching

The volatility regime follows a two-state Markov chain:
- **State 0** (low vol): sigma = 0.073475 (~53% annualized)
- **State 1** (high vol): sigma = 0.112593 (~81% annualized)
- Transition probability: 9.82% per tick in either direction
- Regime state is part of `PriceState` and deterministically derived from the random seed
