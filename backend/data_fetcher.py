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
from typing import Optional, Tuple

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
# Cache functions
# ---------------------------------------------------------------------------

def _get_cached_price(ticker: str) -> Optional[Tuple[float, datetime]]:
    """Get cached price and timestamp for ticker. Returns (price, updated_at) or None."""
    try:
        from database import get_db, StockCache
        db = next(get_db())
        cached = db.query(StockCache).filter(StockCache.ticker == ticker.upper()).first()
        db.close()
        if cached and cached.price is not None:
            return cached.price, cached.updated_at
        return None
    except Exception as exc:
        logger.error("Failed to get cached price for %s: %s", ticker, exc)
        return None


def _update_cache_price(ticker: str, price: float) -> None:
    """Update cached price for ticker."""
    try:
        from database import get_db, StockCache
        db = next(get_db())
        cached = db.query(StockCache).filter(StockCache.ticker == ticker.upper()).first()
        if cached:
            cached.price = price
            cached.updated_at = datetime.utcnow()
        else:
            cached = StockCache(ticker=ticker.upper(), price=price)
            db.add(cached)
        db.commit()
        db.close()
    except Exception as exc:
        logger.error("Failed to update cache for %s: %s", ticker, exc)


def _get_cached_data(ticker: str) -> Optional[dict]:
    """Get cached data (signals, indicators) for ticker. Returns dict or None."""
    try:
        from database import get_db, StockCache
        db = next(get_db())
        cached = db.query(StockCache).filter(StockCache.ticker == ticker.upper()).first()
        db.close()
        if cached:
            return {
                "price": cached.price,
                "signals": cached.signals,
                "indicators": cached.indicators,
                "updated_at": cached.updated_at.isoformat() if cached.updated_at else None,
            }
        return None
    except Exception as exc:
        logger.error("Failed to get cached data for %s: %s", ticker, exc)
        return None


def _update_cache_data(ticker: str, price: float, signals: dict = None, indicators: dict = None) -> None:
    """Update cached data for ticker."""
    try:
        from database import get_db, StockCache
        db = next(get_db())
        cached = db.query(StockCache).filter(StockCache.ticker == ticker.upper()).first()
        if cached:
            cached.price = price
            cached.signals = signals
            cached.indicators = indicators
            cached.updated_at = datetime.utcnow()
        else:
            cached = StockCache(
                ticker=ticker.upper(),
                price=price,
                signals=signals,
                indicators=indicators
            )
            db.add(cached)
        db.commit()
        db.close()
    except Exception as exc:
        logger.error("Failed to update cache for %s: %s", ticker, exc)

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


def get_current_price(ticker: str) -> Tuple[float | None, bool, datetime | None]:
    """
    Return the latest closing price for *ticker*, with cache fallback.
    Returns (price, is_stale, updated_at) tuple.
    Uses the /quote endpoint — counts as 1 API credit.
    """
    # Try API first
    try:
        quote = _td.quote(symbol=ticker).as_json()
        price = quote.get("close") or quote.get("price")
        if price is not None:
            price_float = float(price)
            # Update cache with fresh data
            _update_cache_price(ticker, price_float)
            return price_float, False, datetime.utcnow()
        logger.warning("No price in quote response for %s: %s", ticker, quote)
    except Exception as exc:
        logger.error("Failed to get price for '%s': %s", ticker, exc)

    # API failed, try cache
    cached = _get_cached_price(ticker)
    if cached:
        cached_price, cached_time = cached
        logger.info("Using cached price for %s: %s (from %s)", ticker, cached_price, cached_time)
        return cached_price, True, cached_time

    # No cache available
    return None, False, None


def get_multiple_prices(tickers: list[str]) -> dict[str, Tuple[float | None, bool, datetime | None]]:
    """
    Batch-fetch the latest price for up to 120 tickers in a single API call.
    Returns {ticker: (price, is_stale, updated_at)}.
    """
    if not tickers:
        return {}

    # Twelve Data batch quote: comma-separated symbols
    symbol_str = ",".join(tickers)
    try:
        result = _td.quote(symbol=symbol_str).as_json()

        prices: dict[str, Tuple[float | None, bool, datetime | None]] = {}

        # Single ticker → dict; multiple → dict-of-dicts
        if isinstance(result, dict) and len(tickers) == 1:
            price = result.get("close") or result.get("price")
            if price:
                price_float = float(price)
                _update_cache_price(tickers[0], price_float)
                prices[tickers[0]] = (price_float, False, datetime.utcnow())
            else:
                # Try cache
                cached = _get_cached_price(tickers[0])
                prices[tickers[0]] = (cached[0], True, cached[1]) if cached else (None, False, None)
        elif isinstance(result, dict):
            for ticker in tickers:
                entry = result.get(ticker, {})
                price = entry.get("close") or entry.get("price")
                if price:
                    price_float = float(price)
                    _update_cache_price(ticker, price_float)
                    prices[ticker] = (price_float, False, datetime.utcnow())
                else:
                    # Try cache
                    cached = _get_cached_price(ticker)
                    prices[ticker] = (cached[0], True, cached[1]) if cached else (None, False, None)
        else:
            # Unexpected format — fall back to individual calls
            logger.warning("Unexpected batch quote format; falling back to individual calls.")
            for ticker in tickers:
                prices[ticker] = get_current_price(ticker)

        return prices

    except Exception as exc:
        logger.error("Batch price fetch failed: %s", exc)
        # Fall back to cache for all
        result = {}
        for ticker in tickers:
            cached = _get_cached_price(ticker)
            result[ticker] = (cached[0], True, cached[1]) if cached else (None, False, None)
        return result

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