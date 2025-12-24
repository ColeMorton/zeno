#!/usr/bin/env python3
"""Fetch BTC price data from Yahoo Finance."""

import sys
from pathlib import Path

# Add src to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent / "src"))

from fetch.btc_prices import fetch_btc_prices


def main() -> None:
    """Fetch and cache BTC-USD price data."""
    print("Fetching BTC-USD price data from Yahoo Finance...")

    try:
        df = fetch_btc_prices()
        print(f"Fetched {len(df)} daily observations")
        print(f"Date range: {df['Date'].min()} to {df['Date'].max()}")
        print(f"Saved to: analysis/data/btc_usd.csv")
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
