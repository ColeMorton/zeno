"""BTC price data fetcher using yfinance."""

from pathlib import Path
from datetime import datetime

import pandas as pd
import yfinance as yf

DATA_DIR = Path(__file__).parent.parent.parent / "data"
DEFAULT_CACHE_FILE = DATA_DIR / "btc_usd.csv"


def fetch_btc_prices(
    start_date: str = "2014-09-17",
    end_date: str | None = None,
    cache_path: Path | None = None,
) -> pd.DataFrame:
    """
    Fetch BTC-USD daily price data from Yahoo Finance.

    Args:
        start_date: Start date in YYYY-MM-DD format. Defaults to BTC listing date.
        end_date: End date in YYYY-MM-DD format. Defaults to today.
        cache_path: Path to save CSV cache. Defaults to data/btc_usd.csv.

    Returns:
        DataFrame with columns: Date, Open, High, Low, Close, Volume

    Raises:
        RuntimeError: If data fetch fails or returns empty.
    """
    if end_date is None:
        end_date = datetime.now().strftime("%Y-%m-%d")

    if cache_path is None:
        cache_path = DEFAULT_CACHE_FILE

    ticker = yf.Ticker("BTC-USD")
    df = ticker.history(start=start_date, end=end_date)

    if df.empty:
        raise RuntimeError(f"No data returned for BTC-USD from {start_date} to {end_date}")

    df = df.reset_index()
    df = df[["Date", "Open", "High", "Low", "Close", "Volume"]]
    df["Date"] = pd.to_datetime(df["Date"]).dt.date

    cache_path.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(cache_path, index=False)

    return df


def load_cached_prices(cache_path: Path | None = None) -> pd.DataFrame:
    """
    Load cached BTC price data from CSV.

    Args:
        cache_path: Path to CSV file. Defaults to data/btc_usd.csv.

    Returns:
        DataFrame with BTC price data.

    Raises:
        FileNotFoundError: If cache file doesn't exist.
    """
    if cache_path is None:
        cache_path = DEFAULT_CACHE_FILE

    if not cache_path.exists():
        raise FileNotFoundError(
            f"Cache file not found: {cache_path}. Run fetch_btc_data.py first."
        )

    df = pd.read_csv(cache_path, parse_dates=["Date"])
    return df
