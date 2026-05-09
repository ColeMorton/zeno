#!/usr/bin/env python3
"""
Generate GBM price series with Markov regime switching for BTCNFT simulation.

Produces a deterministic WBTC/USDC price path using calibrated parameters from
walk-forward analysis (calibrate_gbm.py). Outputs CSV compatible with Solidity
SwarmOrchestrator.loadPriceSeries().

Usage:
    python generate_price_series.py [--seed 42] [--ticks 320] [--initial-price 60000]
"""

import argparse
import json
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

REPORTS_DIR = Path(__file__).resolve().parent.parent / "reports"

# Calibrated parameters (from walk-forward analysis, see calibrate_gbm.py)
# Volatility and regime switching are scenario-independent (calibrated from history)
LOW_VOL_SIGMA = 0.073475307025204032
HIGH_VOL_SIGMA = 0.112592509543873504
P_SWITCH_TO_HIGH = 0.1100  # low-vol → high-vol (empirically faster)
P_SWITCH_TO_LOW = 0.0864   # high-vol → low-vol (empirically slower)

# Scenario-specific drift rates (only drift changes between scenarios)
SCENARIO_DRIFTS = {
    "bull": 0.013104373957047678,    # ~56% CAGR (historical calibration)
    "moderate": 0.003846,             # ~22% CAGR (institutional forward consensus)
    "stagnant": 0.000962,             # ~5% CAGR (post-maturation, gold-like)
    "bear": -0.001923,                # ~-10% CAGR (extended bear cycle)
}
DEFAULT_SCENARIO = "bull"

PRECISION = 10**18


def generate(seed: int, ticks: int, initial_price: float, scenario: str = DEFAULT_SCENARIO) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Generate GBM price series with asymmetric regime switching.

    Returns (prices, regimes, ticks_arr) where prices are in USD float.
    """
    drift = SCENARIO_DRIFTS[scenario]
    rng = np.random.default_rng(seed)

    prices = np.empty(ticks)
    regimes = np.empty(ticks, dtype=np.uint8)

    price = initial_price
    regime = 0  # start low-vol

    for t in range(ticks):
        # Asymmetric regime switching: faster to panic, slower to calm
        p_switch = P_SWITCH_TO_HIGH if regime == 0 else P_SWITCH_TO_LOW
        if rng.random() < p_switch:
            regime = 1 - regime

        sigma = LOW_VOL_SIGMA if regime == 0 else HIGH_VOL_SIGMA
        z = rng.standard_normal()
        price *= np.exp(drift + sigma * z)

        prices[t] = price
        regimes[t] = regime

    return prices, regimes, np.arange(ticks)


def validate(prices: np.ndarray, regimes: np.ndarray, initial_price: float) -> dict:
    """Compute validation statistics for the generated series."""
    final_price = prices[-1]
    min_price = prices.min()
    max_price = prices.max()
    ticks = len(prices)

    # Total return
    total_return_pct = round((final_price / initial_price - 1) * 100, 2)

    # Max drawdown
    peak = np.maximum.accumulate(np.concatenate([[initial_price], prices]))
    all_prices = np.concatenate([[initial_price], prices])
    drawdowns = (peak - all_prices) / peak
    max_drawdown_pct = round(float(drawdowns.max()) * 100, 2)

    # Annualized vol from weekly log returns
    all_prices_for_returns = np.concatenate([[initial_price], prices])
    log_returns = np.diff(np.log(all_prices_for_returns))
    weekly_vol = np.std(log_returns, ddof=1)
    annualized_vol = weekly_vol * np.sqrt(52)

    # Annualized CAGR
    n_years = ticks / 52.0
    cagr = (final_price / initial_price) ** (1 / n_years) - 1

    # Regime stats
    low_vol_ticks = int(np.sum(regimes == 0))
    high_vol_ticks = int(np.sum(regimes == 1))
    regime_switches = int(np.sum(np.diff(regimes.astype(int)) != 0))

    return {
        "seed": 0,  # set by caller
        "initialPrice": str(int(initial_price * PRECISION)),
        "ticks": ticks,
        "finalPrice": str(int(final_price * PRECISION)),
        "minPrice": str(int(min_price * PRECISION)),
        "maxPrice": str(int(max_price * PRECISION)),
        "totalReturnPct": total_return_pct,
        "maxDrawdownPct": max_drawdown_pct,
        "annualizedVol": f"{annualized_vol:.6f}",
        "annualizedCAGR": f"{cagr:.6f}",
        "lowVolTicks": low_vol_ticks,
        "highVolTicks": high_vol_ticks,
        "regimeSwitches": regime_switches,
    }


def generate_chart(prices: np.ndarray, regimes: np.ndarray, initial_price: float,
                    stats: dict, seed: int, output: Path) -> None:
    """Generate WBTC/USDC price chart PNG with regime shading and log returns."""
    ticks = len(prices)
    weeks = np.arange(ticks)
    all_prices = np.concatenate([[initial_price], prices])
    log_returns = np.diff(np.log(all_prices))

    fig, (ax_price, ax_returns) = plt.subplots(2, 1, figsize=(12, 8),
                                                gridspec_kw={"height_ratios": [3, 1]},
                                                sharex=True)
    n_years = ticks / 52.0
    fig.suptitle(
        f"WBTC/USDC Price Series — Seed {seed}, {ticks} weeks ({n_years:.1f}y), "
        f"CAGR {float(stats['annualizedCAGR']):.1%}, Max DD {stats['maxDrawdownPct']}%",
        fontsize=12,
    )

    # Regime background shading
    regime_colors = {0: ("tab:blue", 0.08), 1: ("tab:red", 0.08)}
    start_idx = 0
    for i in range(1, ticks):
        if regimes[i] != regimes[start_idx]:
            color, alpha = regime_colors[regimes[start_idx]]
            for ax in (ax_price, ax_returns):
                ax.axvspan(start_idx, i, color=color, alpha=alpha)
            start_idx = i
    color, alpha = regime_colors[regimes[start_idx]]
    for ax in (ax_price, ax_returns):
        ax.axvspan(start_idx, ticks - 1, color=color, alpha=alpha)

    # Price line
    ax_price.plot(weeks, prices, color="white", linewidth=0.8)
    ax_price.set_ylabel("WBTC/USDC ($)")
    ax_price.set_yscale("log")
    ax_price.yaxis.set_major_formatter(plt.FuncFormatter(lambda x, _: f"${x:,.0f}"))
    ax_price.grid(True, alpha=0.3)
    ax_price.set_facecolor("#1a1a2e")

    # Log returns
    colors = np.where(regimes == 0, "tab:blue", "tab:red")
    ax_returns.bar(weeks, log_returns, width=1.0, color=colors, alpha=0.7)
    ax_returns.axhline(0, color="white", linewidth=0.5, alpha=0.5)
    ax_returns.set_ylabel("Weekly Log Return")
    ax_returns.set_xlabel("Week")
    ax_returns.grid(True, alpha=0.3)
    ax_returns.set_facecolor("#1a1a2e")

    fig.patch.set_facecolor("#0d1117")
    for ax in (ax_price, ax_returns):
        ax.tick_params(colors="white")
        ax.xaxis.label.set_color("white")
        ax.yaxis.label.set_color("white")
        ax.title.set_color("white") if ax.get_title() else None
        for spine in ax.spines.values():
            spine.set_color("white")
    fig.suptitle(fig._suptitle.get_text(), fontsize=12, color="white")

    plt.tight_layout()
    png_path = output.with_suffix(".png")
    fig.savefig(png_path, dpi=150, facecolor=fig.get_facecolor())
    plt.close(fig)
    print(f"PNG: {png_path}")


def export_csv(prices: np.ndarray, regimes: np.ndarray, output: Path) -> None:
    """Write price series CSV in Solidity-compatible format (18-decimal fixed-point)."""
    output.parent.mkdir(parents=True, exist_ok=True)
    with open(output, "w") as f:
        f.write("tick,price,regime\n")
        for t in range(len(prices)):
            price_fp = int(prices[t] * PRECISION)
            f.write(f"{t},{price_fp},{regimes[t]}\n")


def main():
    parser = argparse.ArgumentParser(description="Generate GBM price series for simulation")
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--ticks", type=int, default=320)
    parser.add_argument("--initial-price", type=float, default=60_000.0)
    parser.add_argument("--scenario", type=str, default=DEFAULT_SCENARIO, choices=SCENARIO_DRIFTS.keys(),
                        help="Price scenario: bull (~56%% CAGR), moderate (~22%%), stagnant (~5%%), bear (~-10%%)")
    parser.add_argument("--output", type=str, default=str(REPORTS_DIR / "price_series.csv"))
    args = parser.parse_args()

    output_path = Path(args.output)

    # Generate
    prices, regimes, _ = generate(args.seed, args.ticks, args.initial_price, args.scenario)

    # Export CSV
    export_csv(prices, regimes, output_path)

    # Validate
    stats = validate(prices, regimes, args.initial_price)
    stats["seed"] = args.seed
    stats["scenario"] = args.scenario

    # Export validation JSON
    json_path = output_path.parent / "price_validation.json"
    with open(json_path, "w") as f:
        json.dump(stats, f, indent=2)

    # Generate chart PNG
    generate_chart(prices, regimes, args.initial_price, stats, args.seed, output_path)

    # Print summary
    n_years = args.ticks / 52.0
    print(f"=== PRICE SERIES GENERATED ===")
    print(f"Scenario: {args.scenario} (drift={SCENARIO_DRIFTS[args.scenario]:.6f})")
    print(f"Seed: {args.seed} | Ticks: {args.ticks} ({n_years:.1f} years) | Initial: ${args.initial_price:,.0f}")
    print(f"Final: ${prices[-1]:,.0f} | Min: ${prices.min():,.0f} | Max: ${prices.max():,.0f}")
    print(f"Total return: {stats['totalReturnPct']}% | CAGR: {float(stats['annualizedCAGR']):.2%}")
    print(f"Max drawdown: {stats['maxDrawdownPct']}% | Annualized vol: {float(stats['annualizedVol']):.2%}")
    print(f"Regimes: {stats['lowVolTicks']} low-vol / {stats['highVolTicks']} high-vol | {stats['regimeSwitches']} switches")
    print(f"CSV: {output_path}")
    print(f"JSON: {json_path}")


if __name__ == "__main__":
    main()
