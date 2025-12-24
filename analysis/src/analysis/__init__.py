"""Analysis modules."""

from .rolling_windows import calculate_rolling_returns, calculate_1129_day_stats
from .window_optimization import (
    sweep_windows,
    find_threshold_windows,
    find_optimal_conservative,
    find_optimal_practical,
    find_optimal_sharpe,
    find_optimal_robust,
    generate_report,
    WindowStats,
    OptimalWindowResult,
)

__all__ = [
    "calculate_rolling_returns",
    "calculate_1129_day_stats",
    "sweep_windows",
    "find_threshold_windows",
    "find_optimal_conservative",
    "find_optimal_practical",
    "find_optimal_sharpe",
    "find_optimal_robust",
    "generate_report",
    "WindowStats",
    "OptimalWindowResult",
]
