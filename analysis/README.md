# BTCNFT Protocol Quantitative Analysis

Local-only quantitative analysis tooling for validating protocol research assertions.

## Purpose

This workspace provides:
- BTC price data fetching via Yahoo Finance (yfinance)
- Rolling window return calculations (1129-day vesting period validation)
- Statistical analysis supporting `docs/protocol/` and `docs/research/`

**Note:** This is internal analysis tooling. Raw data (`data/`) is git-ignored; derived results (`results/`) are versioned.

## Requirements

- Python 3.11+
- [uv](https://docs.astral.sh/uv/) (recommended) or pip

## Setup

```bash
cd analysis

# Install dependencies with uv
uv sync

# Or with pip
pip install -e ".[dev]"
```

## Usage

### 1. Fetch Price Data

```bash
uv run scripts/fetch_btc_data.py
```

Downloads BTC-USD daily prices to `data/btc_usd.csv`.

### 2. Run Analysis

```bash
uv run scripts/run_analysis.py
```

Computes rolling window statistics and exports to `results/rolling_window_stats.json`.

### 3. Reference in Documentation

Analysis results are referenced by protocol documentation:

```markdown
<!-- docs/protocol/Quantitative_Validation.md -->
| Metric | Value |
|--------|-------|
| Mean annual return | +63.11% |

*Source: `analysis/results/rolling_window_stats.json`*
```

## Directory Structure

```
analysis/
├── src/                    # Python source code
│   ├── fetch/             # Data fetching (yfinance)
│   ├── analysis/          # Statistical analysis
│   └── export/            # Documentation exporters
├── scripts/               # CLI entry points
├── data/                  # Raw price data (git-ignored)
├── results/               # Derived statistics (git-tracked)
├── notebooks/             # Jupyter notebooks (exploratory)
└── pyproject.toml         # Python project config
```

## Key Constants

From `contracts/protocol/src/libraries/VaultMath.sol`:

| Constant | Value | Purpose |
|----------|-------|---------|
| `VESTING_PERIOD` | 1129 days | Lock before withdrawals |
| `WITHDRAWAL_RATE` | 1000 (1.0%) | Monthly withdrawal rate |
| `WITHDRAWAL_PERIOD` | 30 days | Interval between withdrawals |

Annual withdrawal rate: 1.0% × 12 = **12%**

## Analysis Outputs

### `results/rolling_window_stats.json`

```json
{
  "data_range": {
    "start": "2014-09-17",
    "end": "2025-12-22",
    "observations": 4000
  },
  "vesting_1129_day": {
    "sample_count": 2900,
    "mean_return": 3.13,
    "min_return": 0.78,
    "max_return": 9.03,
    "exceeds_breakeven_pct": 100.0
  }
}
```
