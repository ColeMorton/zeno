"""Optimal vesting window analysis."""

from dataclasses import dataclass, asdict
from typing import Any

import numpy as np
import pandas as pd


WITHDRAWAL_RATE_ANNUAL = 0.12  # 12%


@dataclass
class WindowStats:
    """Statistics for a single window size."""

    days: int
    samples: int
    mean_return: float
    min_return: float
    max_return: float
    std_dev: float
    positive_count: int
    positive_pct: float
    exceeds_breakeven_count: int
    exceeds_breakeven_pct: float
    sharpe_ratio: float
    calmar_ratio: float


@dataclass
class OptimalWindowResult:
    """Result of optimization for a single objective."""

    objective: str
    optimal_days: int
    positive_pct: float
    breakeven_pct: float
    sharpe_ratio: float
    samples: int
    confidence: str


def calculate_breakeven_threshold(window_days: int) -> float:
    """
    Calculate the cumulative return threshold for a given window.

    For USD value stability, the return over the window must exceed
    the cumulative withdrawal rate.
    """
    years = window_days / 365.25
    return (1 + WITHDRAWAL_RATE_ANNUAL) ** years - 1


def calculate_window_stats(
    df: pd.DataFrame,
    window_days: int,
    price_col: str = "Close",
) -> WindowStats:
    """Calculate comprehensive statistics for a single window size."""
    prices = df[price_col].values
    returns = []

    for i in range(window_days, len(prices)):
        start_price = prices[i - window_days]
        end_price = prices[i]
        if start_price > 0:
            ret = (end_price - start_price) / start_price
            returns.append(ret)

    if len(returns) == 0:
        raise ValueError(f"Insufficient data for {window_days}-day windows")

    returns = np.array(returns)
    breakeven = calculate_breakeven_threshold(window_days)

    positive_count = int((returns > 0).sum())
    exceeds_breakeven = int((returns > breakeven).sum())

    # Annualized Sharpe ratio (assuming risk-free rate = 0 for simplicity)
    years = window_days / 365.25
    annualized_mean = (1 + returns.mean()) ** (1 / years) - 1
    annualized_std = returns.std() * np.sqrt(365.25 / window_days)
    sharpe = annualized_mean / annualized_std if annualized_std > 0 else 0

    # Calmar ratio (annualized return / max drawdown)
    max_drawdown = abs(returns.min()) if returns.min() < 0 else 0.01
    calmar = annualized_mean / max_drawdown if max_drawdown > 0 else annualized_mean * 100

    return WindowStats(
        days=window_days,
        samples=len(returns),
        mean_return=float(returns.mean()),
        min_return=float(returns.min()),
        max_return=float(returns.max()),
        std_dev=float(returns.std()),
        positive_count=positive_count,
        positive_pct=positive_count / len(returns) * 100,
        exceeds_breakeven_count=exceeds_breakeven,
        exceeds_breakeven_pct=exceeds_breakeven / len(returns) * 100,
        sharpe_ratio=float(sharpe),
        calmar_ratio=float(calmar),
    )


def sweep_windows(
    df: pd.DataFrame,
    min_days: int = 30,
    max_days: int = 2000,
    step: int = 7,
) -> list[WindowStats]:
    """
    Calculate statistics for all window sizes in range.

    Args:
        df: DataFrame with price data.
        min_days: Minimum window size.
        max_days: Maximum window size.
        step: Step size between windows.

    Returns:
        List of WindowStats for each window size.
    """
    results = []
    max_possible = len(df) - 1

    for days in range(min_days, min(max_days, max_possible) + 1, step):
        try:
            stats = calculate_window_stats(df, days)
            results.append(stats)
        except ValueError:
            break

    return results


def find_threshold_windows(
    sweep_results: list[WindowStats],
    positive_thresholds: list[float] = [95.0, 99.0, 99.5, 100.0],
    breakeven_thresholds: list[float] = [90.0, 95.0, 99.0, 100.0],
) -> dict[str, dict[float, int | None]]:
    """
    Find minimum window achieving each threshold.

    Returns dict with keys 'positive' and 'breakeven', each containing
    a dict mapping threshold -> minimum window days (or None if not achieved).
    """
    results: dict[str, dict[float, int | None]] = {
        "positive": {},
        "breakeven": {},
    }

    for threshold in positive_thresholds:
        window = None
        for stats in sweep_results:
            if stats.positive_pct >= threshold:
                window = stats.days
                break
        results["positive"][threshold] = window

    for threshold in breakeven_thresholds:
        window = None
        for stats in sweep_results:
            if stats.exceeds_breakeven_pct >= threshold:
                window = stats.days
                break
        results["breakeven"][threshold] = window

    return results


def find_optimal_conservative(sweep_results: list[WindowStats]) -> OptimalWindowResult:
    """
    Find minimum window where 100% of samples are positive.

    Objective 1: Absolute safety.
    """
    for stats in sweep_results:
        if stats.positive_pct >= 100.0:
            return OptimalWindowResult(
                objective="Conservative (100% positive)",
                optimal_days=stats.days,
                positive_pct=stats.positive_pct,
                breakeven_pct=stats.exceeds_breakeven_pct,
                sharpe_ratio=stats.sharpe_ratio,
                samples=stats.samples,
                confidence="High" if stats.samples >= 500 else "Medium",
            )

    # If 100% not achievable, return the best available
    best = max(sweep_results, key=lambda s: s.positive_pct)
    return OptimalWindowResult(
        objective="Conservative (100% positive) - NOT ACHIEVABLE",
        optimal_days=best.days,
        positive_pct=best.positive_pct,
        breakeven_pct=best.exceeds_breakeven_pct,
        sharpe_ratio=best.sharpe_ratio,
        samples=best.samples,
        confidence="Low - 100% not achievable in dataset",
    )


def find_optimal_practical(sweep_results: list[WindowStats]) -> OptimalWindowResult:
    """
    Find minimum window where P(positive) >= 99.5% AND P(breakeven) >= 95%.

    Objective 2: Balance safety with UX.
    """
    for stats in sweep_results:
        if stats.positive_pct >= 99.5 and stats.exceeds_breakeven_pct >= 95.0:
            return OptimalWindowResult(
                objective="Practical (99.5% positive, 95% breakeven)",
                optimal_days=stats.days,
                positive_pct=stats.positive_pct,
                breakeven_pct=stats.exceeds_breakeven_pct,
                sharpe_ratio=stats.sharpe_ratio,
                samples=stats.samples,
                confidence="High" if stats.samples >= 500 else "Medium",
            )

    # Fallback: find best trade-off
    candidates = [s for s in sweep_results if s.positive_pct >= 99.0]
    if candidates:
        best = max(candidates, key=lambda s: s.exceeds_breakeven_pct)
    else:
        best = max(sweep_results, key=lambda s: s.positive_pct + s.exceeds_breakeven_pct)

    return OptimalWindowResult(
        objective="Practical - RELAXED CRITERIA",
        optimal_days=best.days,
        positive_pct=best.positive_pct,
        breakeven_pct=best.exceeds_breakeven_pct,
        sharpe_ratio=best.sharpe_ratio,
        samples=best.samples,
        confidence="Medium - exact criteria not met",
    )


def find_optimal_sharpe(sweep_results: list[WindowStats]) -> OptimalWindowResult:
    """
    Find window that maximizes Sharpe ratio.

    Objective 3: Risk-adjusted efficiency.
    """
    best = max(sweep_results, key=lambda s: s.sharpe_ratio)
    return OptimalWindowResult(
        objective="Risk-adjusted (max Sharpe)",
        optimal_days=best.days,
        positive_pct=best.positive_pct,
        breakeven_pct=best.exceeds_breakeven_pct,
        sharpe_ratio=best.sharpe_ratio,
        samples=best.samples,
        confidence="High",
    )


def find_optimal_robust(
    df: pd.DataFrame,
    periods: dict[str, tuple[str, str]],
    target_positive: float = 99.5,
    step: int = 7,
) -> OptimalWindowResult:
    """
    Find minimum window achieving targets across ALL sample periods.

    Objective 4: Stability across time.

    Args:
        df: Full DataFrame with Date column.
        periods: Dict of period_name -> (start_date, end_date).
        target_positive: Target positive percentage.
        step: Window sweep step size.
    """
    df = df.copy()
    df["Date"] = pd.to_datetime(df["Date"])

    period_optima: dict[str, int] = {}

    for period_name, (start, end) in periods.items():
        mask = (df["Date"] >= start) & (df["Date"] <= end)
        period_df = df[mask].reset_index(drop=True)

        if len(period_df) < 365:
            continue

        sweep = sweep_windows(period_df, min_days=365, max_days=2000, step=step)

        optimal = None
        for stats in sweep:
            if stats.positive_pct >= target_positive:
                optimal = stats.days
                break

        if optimal:
            period_optima[period_name] = optimal

    if not period_optima:
        return OptimalWindowResult(
            objective="Robustness - INSUFFICIENT DATA",
            optimal_days=0,
            positive_pct=0,
            breakeven_pct=0,
            sharpe_ratio=0,
            samples=0,
            confidence="Low - insufficient data for cross-validation",
        )

    # Take the maximum optimal window across all periods (most conservative)
    robust_window = max(period_optima.values())

    # Get stats for this window from full dataset
    full_stats = calculate_window_stats(df, robust_window)

    # Assess confidence based on consistency
    window_range = max(period_optima.values()) - min(period_optima.values())
    if window_range <= 50:
        confidence = "High"
    elif window_range <= 100:
        confidence = "Medium"
    else:
        confidence = "Low"

    return OptimalWindowResult(
        objective=f"Robustness ({target_positive}% across periods)",
        optimal_days=robust_window,
        positive_pct=full_stats.positive_pct,
        breakeven_pct=full_stats.exceeds_breakeven_pct,
        sharpe_ratio=full_stats.sharpe_ratio,
        samples=full_stats.samples,
        confidence=f"{confidence} (range: {window_range} days)",
    )


def generate_report(
    sweep_results: list[WindowStats],
    threshold_windows: dict[str, dict[float, int | None]],
    optimal_results: list[OptimalWindowResult],
    current_window: int = 1129,
) -> dict[str, Any]:
    """Generate comprehensive optimization report."""
    # Find current window stats
    current_stats = None
    for stats in sweep_results:
        if stats.days == current_window:
            current_stats = stats
            break

    return {
        "current_window": {
            "days": current_window,
            "stats": asdict(current_stats) if current_stats else None,
        },
        "threshold_analysis": threshold_windows,
        "optimal_windows": {
            result.objective: asdict(result) for result in optimal_results
        },
        "recommendation": {
            "conservative": next(
                (r for r in optimal_results if "Conservative" in r.objective), None
            ),
            "practical": next(
                (r for r in optimal_results if "Practical" in r.objective), None
            ),
            "risk_adjusted": next(
                (r for r in optimal_results if "Risk-adjusted" in r.objective), None
            ),
            "robust": next(
                (r for r in optimal_results if "Robustness" in r.objective), None
            ),
        },
        "sweep_summary": {
            "min_window": sweep_results[0].days,
            "max_window": sweep_results[-1].days,
            "total_windows_analyzed": len(sweep_results),
        },
    }
