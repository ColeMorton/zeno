#!/usr/bin/env python3
"""
Walk-Forward Analysis for GBM Calibration from BTC-USD Weekly Price History.

Calibrates regime-switching GBM parameters (drift, low/high volatility, switch probability)
using rolling windows on real BTC-USD weekly data. Outputs Solidity-ready constants for
PriceSimulator.sol.

Usage:
    python calibrate_gbm.py
"""

import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import yfinance as yf

REPORTS_DIR = Path(__file__).resolve().parent.parent / "reports"

# Walk-forward parameters
IN_SAMPLE_WEEKS = 104   # 2 years
OOS_WEEKS = 52           # 1 year
STEP_WEEKS = 26          # 6 months
ROLLING_VOL_WINDOW = 12  # weeks for regime classification
SIMULATION_PATHS = 1000  # Monte Carlo paths for OOS validation
DATA_START = "2014-01-01"


def fetch_btc_weekly() -> pd.DataFrame:
    """Fetch BTC-USD daily data from Yahoo Finance, resample to weekly closes."""
    ticker = yf.Ticker("BTC-USD")
    daily = ticker.history(start=DATA_START, auto_adjust=True)
    if daily.empty:
        raise RuntimeError("Failed to fetch BTC-USD data from Yahoo Finance")

    weekly = daily["Close"].resample("W-FRI").last().dropna()
    df = pd.DataFrame({"close": weekly})
    df["log_return"] = np.log(df["close"] / df["close"].shift(1))
    df = df.dropna()

    print(f"Fetched {len(df)} weekly observations ({df.index[0].date()} to {df.index[-1].date()})")
    return df


def compute_cagr(df: pd.DataFrame) -> dict:
    """Compute full-history CAGR and mean weekly log return from price data."""
    first_close = df["close"].iloc[0]
    last_close = df["close"].iloc[-1]
    n_weeks = len(df)
    n_years = n_weeks / 52.0

    total_log_return = np.log(last_close / first_close)
    weekly_log_return = total_log_return / n_weeks
    cagr = (last_close / first_close) ** (1 / n_years) - 1

    return {
        "first_close": first_close,
        "last_close": last_close,
        "n_weeks": n_weeks,
        "n_years": n_years,
        "total_log_return": total_log_return,
        "weekly_log_return": weekly_log_return,
        "cagr": cagr,
    }


def classify_regimes(log_returns: np.ndarray, window: int = ROLLING_VOL_WINDOW) -> np.ndarray:
    """Classify each week as low-vol (0) or high-vol (1) using rolling volatility threshold."""
    rolling_vol = pd.Series(log_returns).rolling(window).std().values
    threshold = np.nanmedian(rolling_vol)
    regimes = np.where(rolling_vol > threshold, 1, 0)
    # First `window-1` entries have NaN rolling vol — assign regime 0
    regimes[:window - 1] = 0
    return regimes


def estimate_params(log_returns: np.ndarray, regimes: np.ndarray) -> dict:
    """Estimate GBM parameters from classified weekly returns."""
    low_mask = regimes == 0
    high_mask = regimes == 1

    if low_mask.sum() < 2 or high_mask.sum() < 2:
        raise ValueError("Insufficient data in one or both regimes for parameter estimation")

    sigma_low = np.std(log_returns[low_mask], ddof=1)
    sigma_high = np.std(log_returns[high_mask], ddof=1)
    mu = np.mean(log_returns)

    # Transition counts for switch probability
    transitions = np.diff(regimes)
    low_to_high = np.sum((regimes[:-1] == 0) & (regimes[1:] == 1))
    high_to_low = np.sum((regimes[:-1] == 1) & (regimes[1:] == 0))
    count_low = np.sum(regimes[:-1] == 0)
    count_high = np.sum(regimes[:-1] == 1)

    p_switch_low = low_to_high / count_low if count_low > 0 else 0.0
    p_switch_high = high_to_low / count_high if count_high > 0 else 0.0
    p_switch = (p_switch_low + p_switch_high) / 2.0

    return {
        "mu": mu,
        "sigma_low": sigma_low,
        "sigma_high": sigma_high,
        "p_switch": p_switch,
        "p_switch_low_to_high": p_switch_low,
        "p_switch_high_to_low": p_switch_high,
        "n_low": int(low_mask.sum()),
        "n_high": int(high_mask.sum()),
    }


def simulate_gbm(params: dict, n_steps: int, n_paths: int, seed: int = 42) -> np.ndarray:
    """Simulate regime-switching GBM paths for validation."""
    rng = np.random.default_rng(seed)
    prices = np.ones((n_paths, n_steps + 1))
    regimes = np.zeros(n_paths, dtype=int)

    for t in range(1, n_steps + 1):
        # Regime switching
        switch_rolls = rng.random(n_paths)
        regimes = np.where(switch_rolls < params["p_switch"], 1 - regimes, regimes)

        # GBM step
        sigma = np.where(regimes == 0, params["sigma_low"], params["sigma_high"])
        z = rng.standard_normal(n_paths)
        log_ret = params["mu"] + sigma * z
        prices[:, t] = prices[:, t - 1] * np.exp(log_ret)

    return prices


def walk_forward(df: pd.DataFrame) -> pd.DataFrame:
    """Execute walk-forward analysis with rolling calibration/validation windows."""
    log_returns = df["log_return"].values
    n = len(log_returns)
    min_required = IN_SAMPLE_WEEKS + OOS_WEEKS

    if n < min_required:
        raise ValueError(f"Need at least {min_required} weeks, have {n}")

    folds = []
    fold_idx = 0
    start = 0

    while start + min_required <= n:
        is_end = start + IN_SAMPLE_WEEKS
        oos_end = is_end + OOS_WEEKS

        # In-sample calibration
        is_returns = log_returns[start:is_end]
        is_regimes = classify_regimes(is_returns)
        params = estimate_params(is_returns, is_regimes)

        # Out-of-sample validation
        oos_returns = log_returns[is_end:oos_end]
        oos_actual_vol = np.std(oos_returns, ddof=1)
        oos_actual_total_return = np.sum(oos_returns)

        # Simulate OOS paths
        sim_prices = simulate_gbm(params, len(oos_returns), SIMULATION_PATHS, seed=fold_idx)
        sim_total_returns = np.log(sim_prices[:, -1])
        sim_vol = np.std(np.diff(np.log(sim_prices), axis=1), axis=1, ddof=1).mean()

        vol_ratio = sim_vol / oos_actual_vol if oos_actual_vol > 0 else float("nan")
        return_mae = np.abs(np.median(sim_total_returns) - oos_actual_total_return)

        is_start_date = df.index[start].date()
        oos_end_date = df.index[min(oos_end - 1, n - 1)].date()

        folds.append({
            "fold": fold_idx,
            "is_start": str(is_start_date),
            "oos_end": str(oos_end_date),
            "mu": params["mu"],
            "sigma_low": params["sigma_low"],
            "sigma_high": params["sigma_high"],
            "p_switch": params["p_switch"],
            "p_switch_low_to_high": params["p_switch_low_to_high"],
            "p_switch_high_to_low": params["p_switch_high_to_low"],
            "n_low": params["n_low"],
            "n_high": params["n_high"],
            "oos_vol_ratio": vol_ratio,
            "oos_return_mae": return_mae,
        })

        print(f"  Fold {fold_idx}: IS {is_start_date} | OOS→{oos_end_date} | "
              f"σ_low={params['sigma_low']:.4f} σ_high={params['sigma_high']:.4f} "
              f"μ={params['mu']:.6f} p_sw={params['p_switch']:.4f} "
              f"vol_ratio={vol_ratio:.3f}")

        fold_idx += 1
        start += STEP_WEEKS

    return pd.DataFrame(folds)


def to_solidity_constants(params: dict) -> str:
    """Format calibrated parameters as Solidity constant declarations."""
    # Convert to 18-decimal fixed-point
    sigma_low_fp = int(round(params["sigma_low"] * 1e18))
    sigma_high_fp = int(round(params["sigma_high"] * 1e18))
    mu_fp = int(round(params["mu"] * 1e18))
    p_to_high_bps = int(round(params.get("p_switch_to_high", params["p_switch"]) * 10000))
    p_to_low_bps = int(round(params.get("p_switch_to_low", params["p_switch"]) * 10000))

    lines = [
        f"    /// @dev Regime parameters (weekly sigma in 18 decimals, calibrated from BTC-USD {DATA_START}–present)",
        f"    uint256 private constant LOW_VOL_SIGMA = {sigma_low_fp}; // {params['sigma_low']:.6f}",
        f"    uint256 private constant HIGH_VOL_SIGMA = {sigma_high_fp}; // {params['sigma_high']:.6f}",
        f"",
        f"    /// @dev Weekly arithmetic drift (CAGR + vol drag correction, {DATA_START}–present)",
        f"    int256 private constant WEEKLY_DRIFT = {mu_fp}; // {params['mu']:.8f} per week",
        f"",
        f"    /// @dev Asymmetric regime switching probabilities (basis points out of 10000)",
        f"    uint256 private constant P_SWITCH_TO_HIGH = {p_to_high_bps}; // low→high: {params.get('p_switch_to_high', params['p_switch']):.4f}",
        f"    uint256 private constant P_SWITCH_TO_LOW = {p_to_low_bps}; // high→low: {params.get('p_switch_to_low', params['p_switch']):.4f}",
    ]
    return "\n".join(lines)


def save_diagnostics(results: pd.DataFrame) -> None:
    """Save parameter stability plot and CSV results."""
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)

    # CSV
    csv_path = REPORTS_DIR / "wfa_results.csv"
    results.to_csv(csv_path, index=False)
    print(f"\nSaved per-fold results to {csv_path}")

    # Parameter stability plot
    fig, axes = plt.subplots(2, 2, figsize=(12, 8))
    fig.suptitle("Walk-Forward GBM Calibration — Parameter Stability", fontsize=14)

    params_to_plot = [
        ("sigma_low", "Low-Vol σ (weekly)", "tab:blue"),
        ("sigma_high", "High-Vol σ (weekly)", "tab:red"),
        ("mu", "Drift μ (weekly)", "tab:green"),
        ("p_switch", "Switch Probability", "tab:orange"),
    ]

    for ax, (col, label, color) in zip(axes.flat, params_to_plot):
        ax.plot(results["fold"], results[col], "o-", color=color, markersize=5)
        median_val = results[col].median()
        ax.axhline(median_val, color=color, linestyle="--", alpha=0.5, label=f"median={median_val:.5f}")
        ax.set_xlabel("Fold")
        ax.set_ylabel(label)
        ax.set_title(label)
        ax.legend(fontsize=8)
        ax.grid(True, alpha=0.3)

    plt.tight_layout()
    png_path = REPORTS_DIR / "wfa_diagnostics.png"
    fig.savefig(png_path, dpi=150)
    plt.close(fig)
    print(f"Saved diagnostics plot to {png_path}")


def main():
    print("=" * 60)
    print("Walk-Forward GBM Calibration — BTC-USD Weekly")
    print("=" * 60)

    # Fetch data
    print("\n[1/4] Fetching BTC-USD weekly data...")
    df = fetch_btc_weekly()

    # Walk-forward analysis
    print(f"\n[2/4] Running walk-forward analysis (IS={IN_SAMPLE_WEEKS}w, OOS={OOS_WEEKS}w, step={STEP_WEEKS}w)...")
    results = walk_forward(df)

    # Compute full-history CAGR for drift
    print(f"\n[3/5] Computing full-history CAGR...")
    cagr_data = compute_cagr(df)
    print(f"  Price: ${cagr_data['first_close']:,.0f} → ${cagr_data['last_close']:,.0f} over {cagr_data['n_years']:.1f} years")
    print(f"  CAGR:  {cagr_data['cagr']:.2%}")
    print(f"  Mean weekly log return: {cagr_data['weekly_log_return']:.8f}")

    # Aggregate — CAGR for drift, median across folds for vol/switch
    print(f"\n[4/5] Aggregating {len(results)} folds (vol + switch) with CAGR drift...")
    sigma_low = results["sigma_low"].median()
    sigma_high = results["sigma_high"].median()
    p_switch = results["p_switch"].median()

    # Volatility drag correction: generate_price_series uses log-normal returns
    # (price *= exp(drift + sigma*Z)), so E[log(P_new/P_old)] = drift.
    # To match the historical CAGR (= mean log return), set:
    #   drift = mean_log_return + weighted_avg(sigma²) / 2
    # Weight by ergodic (stationary) regime distribution, NOT 50/50.

    # Asymmetric switch probabilities from walk-forward folds
    p_to_high = results["p_switch_low_to_high"].median() if "p_switch_low_to_high" in results.columns else p_switch
    p_to_low = results["p_switch_high_to_low"].median() if "p_switch_high_to_low" in results.columns else p_switch

    # Ergodic regime distribution: pi_high = p_to_high / (p_to_high + p_to_low)
    p_sum = p_to_high + p_to_low
    if p_sum > 0:
        pi_high = p_to_high / p_sum
        pi_low = 1.0 - pi_high
    else:
        pi_high = 0.5
        pi_low = 0.5

    avg_sigma_sq = pi_low * sigma_low**2 + pi_high * sigma_high**2
    vol_drag = avg_sigma_sq / 2
    drift_corrected = cagr_data["weekly_log_return"] + vol_drag

    print(f"\n  Volatility drag correction (ergodic weights):")
    print(f"    p_to_high={p_to_high:.4f}, p_to_low={p_to_low:.4f} → π_low={pi_low:.3f}, π_high={pi_high:.3f}")
    print(f"    avg(σ²)/2 = {pi_low:.3f}×{sigma_low:.6f}² + {pi_high:.3f}×{sigma_high:.6f}² / 2 = {vol_drag:.8f}")
    print(f"    drift = CAGR_weekly + vol_drag = {cagr_data['weekly_log_return']:.8f} + {vol_drag:.8f} = {drift_corrected:.8f}")

    final_params = {
        "mu": drift_corrected,
        "sigma_low": sigma_low,
        "sigma_high": sigma_high,
        "p_switch": p_switch,
        "p_switch_to_high": p_to_high,
        "p_switch_to_low": p_to_low,
    }

    # Annualized equivalents for context
    effective_log_growth = drift_corrected - vol_drag  # should equal CAGR weekly
    annual_log_growth = effective_log_growth * 52
    annual_cagr = np.exp(annual_log_growth) - 1
    annual_sigma_low = final_params["sigma_low"] * np.sqrt(52)
    annual_sigma_high = final_params["sigma_high"] * np.sqrt(52)

    print("\n" + "=" * 60)
    print("CALIBRATED PARAMETERS")
    print("=" * 60)
    print(f"  Weekly drift (μ):          {final_params['mu']:.8f}  (arithmetic, includes vol drag correction)")
    print(f"  Effective log growth:      {effective_log_growth:.8f}/week  (CAGR: {annual_cagr:.2%})")
    print(f"  Low-vol sigma (weekly):    {final_params['sigma_low']:.6f}  (~{annual_sigma_low:.2%} annualized)")
    print(f"  High-vol sigma (weekly):   {final_params['sigma_high']:.6f}  (~{annual_sigma_high:.2%} annualized)")
    print(f"  Regime switch probability: {final_params['p_switch']:.4f}  ({final_params['p_switch']*100:.2f}%)")
    print(f"  Drift source: full-history CAGR + vol drag | Vol/switch source: WFA median ({len(results)} folds)")

    print("\n" + "=" * 60)
    print("SOLIDITY CONSTANTS (PriceSimulator.sol)")
    print("=" * 60)
    print(to_solidity_constants(final_params))

    # Validation summary
    print("\n" + "=" * 60)
    print("WALK-FORWARD VALIDATION METRICS")
    print("=" * 60)
    print(f"  Median OOS vol ratio:      {results['oos_vol_ratio'].median():.3f}  (1.0 = perfect)")
    print(f"  Median OOS return MAE:     {results['oos_return_mae'].median():.4f}")

    # Save diagnostics
    print("\n[5/5] Saving diagnostics...")
    save_diagnostics(results)

    print("\nDone.")


if __name__ == "__main__":
    main()
