"""
Data Fetcher
============
Thin wrapper around TWELVEDATA.  All network calls are isolated here
so they can be swapped for a paid data provider without touching
signal_engine.py.
"""

import os
import logging
from datetime import datetime, timedelta

import pandas as pd
from twelvedata import TDClient

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Client initialisation (reads from env / config)
# ---------------------------------------------------------------------------

_TWELVEDATA_API_KEY = os.getenv("TWELVEDATA_API_KEY", "")

if not _TWELVEDATA_API_KEY:
    logger.warning("TWELVEDATA_API_KEY is not set — data fetching will fail.")

_td = TDClient(apikey=_TWELVEDATA_API_KEY)

# ---------------------------------------------------------------------------
# period string → outputsize (number of daily bars to request)
# Mirrors the yfinance period= convention used in the original code.
# ---------------------------------------------------------------------------

_PERIOD_TO_DAYS: dict[str, int] = {
    "1d":  2,
    "5d":  7,
    "1mo": 30,
    "3mo": 90,
    "6mo": 180,
    "1y":  365,
    "2y":  730,
    "5y":  1825,
    "ytd": (datetime.now() - datetime(datetime.now().year, 1, 1)).days + 1,
    "max": 5000,
}


def _period_to_outputsize(period: str) -> int:
    """Convert a yfinance-style period string to a bar count for Twelve Data."""
    return _PERIOD_TO_DAYS.get(period, 90)


# ---------------------------------------------------------------------------
# Public helpers
# ---------------------------------------------------------------------------

def get_stock_data(ticker: str, period: str = "3mo") -> pd.DataFrame | None:
    """
    Fetch daily OHLCV data for *ticker* covering approximately *period*.

    Returns a pandas DataFrame with columns:
        Open, High, Low, Close, Volume
    and a DatetimeIndex (newest first, matching yfinance default).

    Returns None on any error so callers can handle gracefully.
    """
    outputsize = _period_to_outputsize(period)
    try:
        df: pd.DataFrame = (
            _td.time_series(
                symbol=ticker,
                interval="1day",
                outputsize=outputsize,
                timezone="America/New_York",
            )
            .as_pandas()
        )

        if df is None or df.empty:
            logger.warning("No data returned for %s", ticker)
            return None

        # Twelve Data returns lowercase column names; rename to match yfinance.
        df = df.rename(columns={
            "open":   "Open",
            "high":   "High",
            "low":    "Low",
            "close":  "Close",
            "volume": "Volume",
        })

        # Ensure numeric types
        for col in ["Open", "High", "Low", "Close", "Volume"]:
            if col in df.columns:
                df[col] = pd.to_numeric(df[col], errors="coerce")

        # Twelve Data returns newest-first; keep that convention (same as yfinance).
        return df

    except Exception as exc:
        logger.error("Failed to get ticker '%s' reason: %s", ticker, exc)
        return None


def get_current_price(ticker: str) -> float | None:
    """
    Return the latest closing price for *ticker*, or None on failure.
    Uses the /quote endpoint — counts as 1 API credit.
    """
    try:
        quote = _td.quote(symbol=ticker).as_json()
        price = quote.get("close") or quote.get("price")
        if price is None:
            logger.warning("No price in quote response for %s: %s", ticker, quote)
            return None
        return float(price)
    except Exception as exc:
        logger.error("Failed to get price for '%s': %s", ticker, exc)
        return None


def get_multiple_prices(tickers: list[str]) -> dict[str, float | None]:
    """
    Batch-fetch the latest price for up to 120 tickers in a single API call.
    Returns {ticker: price_or_None}.
    """
    if not tickers:
        return {}

    # Twelve Data batch quote: comma-separated symbols
    symbol_str = ",".join(tickers)
    try:
        result = _td.quote(symbol=symbol_str).as_json()

        prices: dict[str, float | None] = {}

        # Single ticker → dict; multiple → dict-of-dicts
        if isinstance(result, dict) and len(tickers) == 1:
            price = result.get("close") or result.get("price")
            prices[tickers[0]] = float(price) if price else None
        elif isinstance(result, dict):
            for ticker in tickers:
                entry = result.get(ticker, {})
                price = entry.get("close") or entry.get("price")
                prices[ticker] = float(price) if price else None
        else:
            # Unexpected format — fall back to individual calls
            logger.warning("Unexpected batch quote format; falling back to individual calls.")
            for ticker in tickers:
                prices[ticker] = get_current_price(ticker)

        return prices

    except Exception as exc:
        logger.error("Batch price fetch failed: %s", exc)
        return {t: None for t in tickers}

def fetch_stock_info(ticker: str) -> dict:
    """
    Return basic stock metadata.
    """

    try:
        quote = _td.quote(symbol=ticker).as_json()

        return {
            "name": quote.get("name", ticker),
            "sector": quote.get("exchange", "Unknown"),
        }

    except Exception as exc:
        logger.error("Failed to fetch stock info for '%s': %s", ticker, exc)

        return {
            "name": ticker,
            "sector": "Unknown",
        }
# Aliases for backward compatibility with main.py
fetch_stock_data = get_stock_data