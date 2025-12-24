"""Rolling window analysis for BTC returns."""

from dataclasses import dataclass

import numpy as np
import pandas as pd


# Protocol constant from VaultMath.sol
VESTING_PERIOD_DAYS = 1129
WITHDRAWAL_RATE_ANNUAL = 0.12  # 12%


@dataclass
class RollingWindowStats:
    """Statistics for a specific rolling window size."""

    window_days: int
    sample_count: int
    mean_return: float
    min_return: float
    max_return: float
    std_dev: float
    positive_count: int
    positive_pct: float
    exceeds_breakeven_count: int
    exceeds_breakeven_pct: float


def calculate_rolling_returns(
    df: pd.DataFrame,
    window_days: int = VESTING_PERIOD_DAYS,
    price_col: str = "Close",
) -> pd.Series:
    """
    Calculate rolling window returns.

    Args:
        df: DataFrame with Date and price columns.
        window_days: Rolling window size in days.
        price_col: Column name for price data.

    Returns:
        Series of rolling returns (as decimals, e.g., 0.50 = 50%).
    """
    prices = df[price_col].values
    returns = []

    for i in range(window_days, len(prices)):
        start_price = prices[i - window_days]
        end_price = prices[i]
        if start_price > 0:
            ret = (end_price - start_price) / start_price
            returns.append(ret)
        else:
            returns.append(np.nan)

    return pd.Series(returns)


def calculate_1129_day_stats(df: pd.DataFrame) -> RollingWindowStats:
    """
    Calculate statistics for 1129-day rolling windows.

    This is the core analysis for validating the protocol's vesting period.

    Args:
        df: DataFrame with BTC price data.

    Returns:
        RollingWindowStats with comprehensive statistics.
    """
    returns = calculate_rolling_returns(df, window_days=VESTING_PERIOD_DAYS)
    returns = returns.dropna()

    if len(returns) == 0:
        raise ValueError("Insufficient data for 1129-day rolling windows")

    # Annualized breakeven threshold
    # For 1129 days (~3.09 years), need cumulative return of:
    # (1 + 0.12)^3.09 - 1 ≈ 43.5%
    years = VESTING_PERIOD_DAYS / 365.25
    breakeven_cumulative = (1 + WITHDRAWAL_RATE_ANNUAL) ** years - 1

    positive_count = int((returns > 0).sum())
    exceeds_breakeven = int((returns > breakeven_cumulative).sum())

    return RollingWindowStats(
        window_days=VESTING_PERIOD_DAYS,
        sample_count=len(returns),
        mean_return=float(returns.mean()),
        min_return=float(returns.min()),
        max_return=float(returns.max()),
        std_dev=float(returns.std()),
        positive_count=positive_count,
        positive_pct=positive_count / len(returns) * 100,
        exceeds_breakeven_count=exceeds_breakeven,
        exceeds_breakeven_pct=exceeds_breakeven / len(returns) * 100,
    )


def calculate_monthly_stats(df: pd.DataFrame) -> RollingWindowStats:
    """Calculate statistics for 30-day rolling windows."""
    returns = calculate_rolling_returns(df, window_days=30)
    returns = returns.dropna()

    breakeven_monthly = WITHDRAWAL_RATE_ANNUAL / 12  # ~0.875%
    positive_count = int((returns > 0).sum())
    exceeds_breakeven = int((returns > breakeven_monthly).sum())

    return RollingWindowStats(
        window_days=30,
        sample_count=len(returns),
        mean_return=float(returns.mean()),
        min_return=float(returns.min()),
        max_return=float(returns.max()),
        std_dev=float(returns.std()),
        positive_count=positive_count,
        positive_pct=positive_count / len(returns) * 100,
        exceeds_breakeven_count=exceeds_breakeven,
        exceeds_breakeven_pct=exceeds_breakeven / len(returns) * 100,
    )


def calculate_yearly_stats(df: pd.DataFrame) -> RollingWindowStats:
    """Calculate statistics for 365-day rolling windows."""
    returns = calculate_rolling_returns(df, window_days=365)
    returns = returns.dropna()

    positive_count = int((returns > 0).sum())
    exceeds_breakeven = int((returns > WITHDRAWAL_RATE_ANNUAL).sum())

    return RollingWindowStats(
        window_days=365,
        sample_count=len(returns),
        mean_return=float(returns.mean()),
        min_return=float(returns.min()),
        max_return=float(returns.max()),
        std_dev=float(returns.std()),
        positive_count=positive_count,
        positive_pct=positive_count / len(returns) * 100,
        exceeds_breakeven_count=exceeds_breakeven,
        exceeds_breakeven_pct=exceeds_breakeven / len(returns) * 100,
    )
